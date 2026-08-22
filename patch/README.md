# Warcraft III 1.28.5 client patch

This kit contains the open-source W3L loader and a PowerShell realm manager. It does not contain Warcraft III, Blizzard assets, CD keys, or a configured private server address.

## Why this patch exists

Classic Warcraft III validates the identity and protocol behavior of the Battle.net service it connects to. A stock `1.28.5` client therefore cannot complete a normal login against a community PvPGN server. W3L is an open-source compatibility loader that starts the legally installed game and adjusts the relevant client-side behavior in memory so it can use PvPGN.

This repository does not patch Blizzard files on disk. The three generated W3L files are copied next to the game and used only when the player launches `w3l.exe`.

## How the files work together

- `w3l.exe` starts Warcraft III and arranges for the compatibility DLL to load.
- `w3lh.dll` supports the older post-1.22 game layout.
- `wl27.dll` contains the loader path used by Warcraft III 1.27 and 1.28, including the targeted 1.28.5 installation.
- `Manage-WarcraftRealms.ps1` edits the current user's Battle.net gateway list so the private realm appears in the game.
- `SHA256SUMS.txt` lets players verify that the release files were not modified after the build.

## How the source build works

The unmodified W3L project is pinned as `sources/w3l`. The build never edits that submodule. `build/w3l-mingw.patch` is checked first and then applied to the temporary source copy inside the Docker builder.

The source patch is intentionally small and reviewable. It:

1. Normalizes Windows SDK header names for the case-sensitive Linux filesystem used by the cross-compiler.
2. Replaces Microsoft-specific token concatenation and legacy file-handle calls with MinGW-compatible equivalents.
3. Disambiguates Windows SDK identifiers that now collide with names in the older W3L source.
4. Fixes two invalid pointer casts in the 1.27+ loader.
5. Replaces the compiler-specific naked `GameMain` trampoline with the small portable shim in `build/w3l-game-main.c`.

The resulting files are compiled as 32-bit PE binaries because Warcraft III 1.28.5 is a 32-bit process. The Docker build verifies their architecture and checks that both DLLs export `GameMain` before exporting them.

To reproduce the release build from the repository root:

```powershell
.\scripts\Build-Patch.ps1 -Archive -Version dev
```

## Requirements

- A legally owned Warcraft III: The Frozen Throne installation updated to `1.28.5.0`.
- Windows 10 or Windows 11.
- Windows PowerShell 5.1 or PowerShell 7 for realm management.

## Install the loader

Copy `w3l.exe`, `w3lh.dll`, and `wl27.dll` into the Warcraft III installation directory. Start the game with `w3l.exe` when connecting to a PvPGN realm.

Verify the files with:

```powershell
Get-FileHash -Algorithm SHA256 .\w3l.exe, .\w3lh.dll, .\wl27.dll
```

## Manage private realms

Open the interactive manager:

```powershell
.\Manage-WarcraftRealms.ps1
```

The same script can be automated:

```powershell
.\Manage-WarcraftRealms.ps1 -Action Add -Name 'Friends Realm' -Address 'realm.example.net'
.\Manage-WarcraftRealms.ps1 -Action List
.\Manage-WarcraftRealms.ps1 -Action Select -Index 1
```

The script edits only the current Windows user's registry and does not require administrator privileges. It intentionally provides no backup or restore feature. Close Warcraft III before changing the realm list.

Older game loaders can trigger antivirus warnings because they modify the Warcraft III process. Build from source or verify release checksums before running these files.
