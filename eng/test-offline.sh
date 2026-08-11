#!/usr/bin/env bash
# Run a compiler unit-test project (or all of them) offline, using only packages
# committed at eng/offline-packages. No internet required.
#
# Usage:
#   ./eng/test-offline.sh                       # run all compiler unit-test projects
#   ./eng/test-offline.sh <project>             # run a single project
#   ./eng/test-offline.sh <project> -f net472   # pick a target framework (default net10.0)

set -euo pipefail

repo_root="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
# shellcheck source=offline-init.sh
source "$repo_root/eng/offline-init.sh"

cfg="$repo_root/NuGet.offline.config"
config="Debug"; framework="net10.0"; project=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--configuration) config="$2"; shift 2 ;;
    -f|--framework)     framework="$2"; shift 2 ;;
    -*)                 echo "unknown flag: $1" >&2; exit 2 ;;
    *)                  project="$1"; shift ;;
  esac
done

run_one() {
  local p="$1"
  echo "::: $p"
  "$dotnet" restore "$p" --configfile "$cfg" -v q
  "$dotnet" build   "$p" -c "$config" -f "$framework" --no-restore -v q
  "$dotnet" test    "$p" -c "$config" -f "$framework" --no-restore --no-build
}

if [[ -n "$project" ]]; then
  run_one "$project"
else
  find "$repo_root/src/Compilers" -path '*/Test/*' \
       \( -name '*.UnitTests.csproj' -o -name '*.UnitTests.vbproj' \) | sort |
  while IFS= read -r p; do run_one "$p"; done
fi
