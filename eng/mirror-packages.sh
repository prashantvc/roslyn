#!/usr/bin/env bash
# Maintenance helper: refresh the committed offline package feed (eng/offline-packages)
# from the NuGet global-packages cache. Run this ONLY when you need to add packages to
# the offline set (e.g. after a dependency bump), while you have internet.
#
# Typical flow to add packages for the compiler subset on linux-x64:
#     dotnet restore <project> /p:RuntimeIdentifier=linux-x64   # while online
#     ./eng/mirror-packages.sh                                  # copy new .nupkg into the feed
#     git add eng/offline-packages && git commit
#
# Note: the committed feed is intentionally scoped to what the compiler unit-test
# projects need (it does NOT cover the full Compilers.slnf, which drags in the
# LanguageServer/Razor all-RID runtime packs). See docs/Building Offline.md.

set -euo pipefail

repo_root="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
feed="$repo_root/eng/offline-packages"

dotnet="$repo_root/.dotnet/dotnet"
if [[ -x "$dotnet" ]]; then
  gp="$("$dotnet" nuget locals global-packages --list | sed 's/^global-packages: //')"
else
  gp="${NUGET_PACKAGES:-$HOME/.nuget/packages}"
fi

if [[ ! -d "$gp" ]]; then
  echo "global-packages folder not found: $gp" >&2
  exit 1
fi

echo "Mirroring .nupkg files from: $gp"
echo "                        to: $feed"
mkdir -p "$feed"

count=0
while IFS= read -r -d '' nupkg; do
  base="$(basename "$nupkg")"
  if [[ ! -f "$feed/$base" ]]; then
    cp "$nupkg" "$feed/"; count=$((count + 1))
  fi
done < <(find "$gp" -name '*.nupkg' ! -name '*.symbols.nupkg' -print0)

echo "Added $count new package(s). Feed now holds $(find "$feed" -name '*.nupkg' | wc -l | tr -d ' ')."
echo "Review the additions before committing: git status eng/offline-packages"
