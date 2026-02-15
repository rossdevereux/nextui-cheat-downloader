# Cheat Downloader

A PowerShell utility to automatically find and organize cheat files (`.cht`) for your ROM collection. This tool is designed to work with cheat databases like the [libretro-database](https://github.com/libretro/libretro-database).

## Features

- **Exact Matching**: Finds cheat files that match your ROM name exactly.
- **Fuzzy Matching**: Uses Levenshtein distance to find the closest matching cheat file if an exact match is missing (e.g., matching "Metroid (US)" to "Metroid (USA).cht").
  - *Note: Performance optimized with compiled C# code.*
- **Smart Renaming**: Copies the cheat file to the output directory and renames it to match your ROM file (e.g., `Game.nes` -> `Game.nes.cht`) for emulator compatibility.
- **Skip Existing**: Option to skip processing ROMs that already have a cheat file in the destination folder.
- **Progress Tracking**: Includes a progress bar to track processing status.

## Usage

### Prerequisites
- PowerShell 5.1 or later (Windows).
- A local copy of a cheat database (e.g., clone [libretro-database](https://github.com/libretro/libretro-database)).

### Command

```powershell
.\find-cheats.ps1 -RomPath "path\to\roms" -CheatPath "path\to\cheats" -OutputPath "path\to\output" [-SkipExisting]
```

### Parameters

| Parameter | Type | Mandatory | Description |
| :--- | :--- | :--- | :--- |
| `RomPath` | String | Yes | The directory containing your ROM files (e.g., `C:\Roms\NES`). |
| `CheatPath` | String | Yes | The directory containing the `.cht` files for the console (e.g., `C:\Cheats\Nintendo - NES`). |
| `OutputPath` | String | Yes | The directory where the matched cheat files will be saved. |
| `SkipExisting` | Switch | No | If set, skips any ROM that already has a corresponding `.cht` file in the output folder. |

### Example

```powershell
.\find-cheats.ps1 `
    -RomPath "C:\Emulation\Roms\NES" `
    -CheatPath "C:\Emulation\libretro-database\cht\Nintendo - Nintendo Entertainment System" `
    -OutputPath "C:\Emulation\Cheats\NES" `
    -SkipExisting
```

## Testing

A test script is included to verify the functionality:

```powershell
.\test-cheat-matcher.ps1
```
This script creates a temporary environment with dummy ROMs and cheats to test exact matching, fuzzy matching, and the skip-existing feature.
