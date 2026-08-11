# Building and Testing the Compiler Offline

This fork can build and run the **compiler unit tests** with **no internet access**,
straight from a `git clone`. The NuGet packages needed for the compiler projects are
committed to the repo at [`eng/offline-packages`](../eng/offline-packages).

## Requirements on the target machine

* The .NET SDK whose version matches [`global.json`](../global.json) (`sdk.version`,
  with `rollForward: patch`). The offline feed was prepared for **Ubuntu 24.04 / linux-x64**;
  the committed packages include the `linux-x64` runtime/host packs.
* No internet connection is required. **nuget.org is not enough** and is not used:
  the build SDK (`Microsoft.DotNet.Arcade.Sdk`) and several compiler packages are
  only on Azure DevOps feeds, so they are committed here instead.

> The SDK itself is **not** committed (it is large and you said the target already has
> it installed). Only the NuGet packages travel with the clone.

## What works offline

* Restoring, building and testing the individual **compiler unit-test projects** under
  `src/Compilers/**/Test/**` (17 projects). Verified from a completely empty NuGet
  cache against the committed feed.

## What does NOT work offline

* `dotnet restore Compilers.slnf` (or any `.slnf` based on `Roslyn.slnx`). A solution
  restore walks the whole solution graph, which includes the `LanguageServer` and
  `Razor` projects. Those reference **every** OS/arch runtime pack
  (`Microsoft.NETCore.App.Runtime.*`, `Microsoft.AspNetCore.App.Runtime.*`, etc.) —
  hundreds of MB that are deliberately not committed. Build the compiler **projects**
  directly instead of the solution.

## Build and test offline

Use the helper scripts (they pin the offline NuGet config and skip re-restore/rebuild
where possible):

```bash
# Run every compiler unit-test project offline.
./eng/test-offline.sh

# Run a single project offline.
./eng/test-offline.sh src/Compilers/CSharp/Test/Syntax/Microsoft.CodeAnalysis.CSharp.Syntax.UnitTests.csproj

# Just restore + build a project offline (no tests).
./eng/build-offline.sh src/Compilers/CSharp/Test/Syntax/Microsoft.CodeAnalysis.CSharp.Syntax.UnitTests.csproj
```

Or invoke the SDK directly with the offline config:

```bash
dotnet restore <project> --configfile NuGet.offline.config
dotnet build   <project> -f net10.0 -c Debug --no-restore
dotnet test    <project> -f net10.0 -c Debug --no-restore --no-build
```

`NuGet.offline.config` defines a single package source — `eng/offline-packages` — and
no network feeds, so restore can only ever use the committed packages.

The helper scripts also extract `Microsoft.DotNet.Arcade.Sdk` (from that same folder)
into the NuGet global-packages cache. MSBuild resolves Arcade as an SDK *before*
`--configfile` applies, and that package is **not published to nuget.org**.

## Verified

From a **completely empty** NuGet global-packages cache, using only the committed feed:

* All 17 `src/Compilers/**/Test/**` unit-test projects restore offline (linux-x64).
* End-to-end on one project (`Microsoft.CodeAnalysis.CSharp.Syntax.UnitTests`):
  restore + build + test succeeded — **10,288 passed, 0 failed, 25 skipped**.
* `Microsoft.CodeAnalysis.UnitTests`: **18,980 passed, 0 failed, 99 skipped**.

Skipped tests are platform-conditional (e.g. Windows-only assembly portability,
Shift-JIS encoding) and are skipped regardless of network state.

## Maintaining the offline feed

If a dependency changes and a package is missing offline, add it while online:

```bash
dotnet restore <project> /p:RuntimeIdentifier=linux-x64   # downloads to the global cache
./eng/mirror-packages.sh                                   # copies new .nupkg into eng/offline-packages
git add eng/offline-packages && git commit                # commit the additions
```
