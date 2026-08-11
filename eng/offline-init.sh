#!/usr/bin/env bash
# Shared offline-restore setup for compiler projects.
# Sourced by build-offline.sh / test-offline.sh — not meant to be run directly.
#
# Seeds Microsoft.DotNet.Arcade.Sdk into the NuGet global-packages cache from the
# committed nupkg. The MSBuild SDK resolver looks at that cache (and at
# NuGet.config sources) *before* --configfile is applied, so without this
# bootstrap a clean machine would still try to download Arcade from the
# dnceng Azure feed — which is not on nuget.org.

if [[ -z "${repo_root:-}" ]]; then
  echo "offline-init.sh must be sourced after repo_root is set" >&2
  return 2 2>/dev/null || exit 2
fi

if [[ -x "$repo_root/.dotnet/dotnet" ]]; then
  dotnet="$repo_root/.dotnet/dotnet"
  export DOTNET_ROOT="$repo_root/.dotnet"
  export DOTNET_MULTILEVEL_LOOKUP=0
else
  dotnet="$(command -v dotnet)"
fi
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export DOTNET_NOLOGO=1

# Keep Restore from walking the Azure feeds in the repo NuGet.config.
export RestoreConfigFile="${RestoreConfigFile:-$repo_root/NuGet.offline.config}"

arcade_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["msbuild-sdks"]["Microsoft.DotNet.Arcade.Sdk"])' "$repo_root/global.json")"
arcade_id="microsoft.dotnet.arcade.sdk"
arcade_nupkg="$repo_root/eng/offline-packages/${arcade_id}.${arcade_version}.nupkg"

if [[ -z "${NUGET_PACKAGES:-}" ]]; then
  if [[ -n "${HOME:-}" && -d "$HOME/.nuget/packages" ]]; then
    NUGET_PACKAGES="$HOME/.nuget/packages"
  else
    NUGET_PACKAGES="$repo_root/.nuget/packages"
  fi
  export NUGET_PACKAGES
fi

arcade_dest="$NUGET_PACKAGES/${arcade_id}/${arcade_version}"
if [[ ! -f "$arcade_dest/sdk/Sdk.props" ]]; then
  if [[ ! -f "$arcade_nupkg" ]]; then
    echo "Arcade SDK nupkg missing: $arcade_nupkg" >&2
    echo "This package is not on nuget.org; it must travel with eng/offline-packages." >&2
    return 2 2>/dev/null || exit 2
  fi
  echo ">> bootstrap Arcade SDK $arcade_version -> $arcade_dest"
  mkdir -p "$arcade_dest"
  if command -v unzip >/dev/null 2>&1; then
    unzip -qo "$arcade_nupkg" -d "$arcade_dest"
  else
    python3 -c 'import zipfile,sys; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$arcade_nupkg" "$arcade_dest"
  fi
  cp -f "$arcade_nupkg" "$arcade_dest/${arcade_id}.${arcade_version}.nupkg"
  if [[ ! -f "$arcade_dest/.nupkg.metadata" ]]; then
    printf '%s\n' '{"version":2,"contentHash":"offline","source":"eng/offline-packages"}' > "$arcade_dest/.nupkg.metadata"
  fi
fi
