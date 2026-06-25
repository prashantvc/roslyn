#!/usr/bin/env bash
# Restore/build a single compiler project offline, using only packages committed to
# this repo at eng/offline-packages. No internet required.
#
# A fresh `git clone` already contains everything needed (see eng/offline-packages),
# provided a matching .NET SDK is installed (see global.json -> sdk.version).
#
# Restore the whole compiler subset solution (Compilers.slnf) is intentionally NOT
# supported offline: it pulls in the LanguageServer/Razor projects, which reference
# every OS/arch runtime pack (hundreds of MB) that are not committed. Build and test
# the compiler PROJECTS directly instead.
#
# Usage:
#   ./eng/build-offline.sh <project>            # restore + build (Debug, net10.0)
#   ./eng/build-offline.sh <project> -c Release -f net472
#
# Example:
#   ./eng/build-offline.sh src/Compilers/CSharp/Test/Syntax/Microsoft.CodeAnalysis.CSharp.Syntax.UnitTests.csproj

set -euo pipefail

repo_root="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <project.csproj|.vbproj> [extra dotnet build args]" >&2
  exit 2
fi
project="$1"; shift

# Prefer a repo-local SDK if present; otherwise use the machine's installed dotnet.
if [[ -x "$repo_root/.dotnet/dotnet" ]]; then
  dotnet="$repo_root/.dotnet/dotnet"
  export DOTNET_ROOT="$repo_root/.dotnet"
  export DOTNET_MULTILEVEL_LOOKUP=0
else
  dotnet="$(command -v dotnet)"
fi
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1

config="Debug"; framework="net10.0"; passthru=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--configuration) config="$2"; shift 2 ;;
    -f|--framework)     framework="$2"; shift 2 ;;
    *)                  passthru+=("$1"); shift ;;
  esac
done

cfg="$repo_root/NuGet.offline.config"
echo ">> restore (offline) $project"
"$dotnet" restore "$project" --configfile "$cfg" -v q "${passthru[@]}"
echo ">> build $project ($config/$framework)"
"$dotnet" build "$project" -c "$config" -f "$framework" --no-restore "${passthru[@]}"
