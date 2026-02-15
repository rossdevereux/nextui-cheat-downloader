<#
.SYNOPSIS
    Finds and renames cheat files for ROMs from the libretro-database.

.DESCRIPTION
    This script takes a directory of ROM files, searches for matching cheat files
    in a local or remote copy of the libretro-database, and copies them to an output
    directory with the exact name of the ROM file.

.PARAMETER RomPath
    The directory containing the ROM files to search for.

.PARAMETER OutputPath
    The directory where matched cheat files will be saved.

.PARAMETER CheatPath
    The directory containing the cheat files (e.g. "C:\Cheats\NES").

.PARAMETER SkipExisting
    If set, skips ROMs that already have a corresponding cheat file in the OutputPath.

.EXAMPLE
    .\find-cheats.ps1 -RomPath "C:\Roms\NES" -OutputPath "C:\Cheats\NES"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$RomPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $true)]
    [string]$CheatPath,

    [Parameter(Mandatory = $false)]
    [switch]$SkipExisting
)

$ErrorActionPreference = "Stop"

$stringDistanceType = @"
using System;

public class StringDistance
{
    public static int Levenshtein(string s, string t)
    {
        if (string.IsNullOrEmpty(s)) return string.IsNullOrEmpty(t) ? 0 : t.Length;
        if (string.IsNullOrEmpty(t)) return s.Length;

        int n = s.Length;
        int m = t.Length;
        int[,] d = new int[n + 1, m + 1];

        for (int i = 0; i <= n; i++) d[i, 0] = i;
        for (int j = 0; j <= m; j++) d[0, j] = j;

        for (int i = 1; i <= n; i++)
        {
            for (int j = 1; j <= m; j++)
            {
                int cost = (t[j - 1] == s[i - 1]) ? 0 : 1;
                d[i, j] = Math.Min(
                    Math.Min(d[i - 1, j] + 1, d[i, j - 1] + 1),
                    d[i - 1, j - 1] + cost);
            }
        }
        return d[n, m];
    }
}
"@

# Add the type only if it's not already added (to avoid errors on re-run in same session)
if (-not ([System.Management.Automation.PSTypeName]'StringDistance').Type) {
    Add-Type -TypeDefinition $stringDistanceType
}


function Get-ScriptDirectory {
    if ($PSScriptRoot) { return $PSScriptRoot }
    if ($MyInvocation.MyCommand.Path) { return Split-Path $MyInvocation.MyCommand.Path }
    return Get-Location
}


# Validate Inputs
if (-not (Test-Path -Path $RomPath)) {
    Write-Error "RomPath '$RomPath' does not exist."
    exit 1
}


# Validate Inputs
if (-not (Test-Path -Path $RomPath)) {
    Write-Error "RomPath '$RomPath' does not exist."
    exit 1
}

if (-not (Test-Path -Path $OutputPath)) {
    New-Item -ItemType Directory -Force -Path $OutputPath | Out-Null
    Write-Host "Created OutputPath '$OutputPath'."
}

if (-not (Test-Path -Path $CheatPath)) {
    Write-Error "CheatPath '$CheatPath' does not exist."
    exit 1
}

# Process ROMs
$roms = Get-ChildItem -Path $RomPath -File
$allCheatsCached = $null

$count = 0
$totalRoms = $roms.Count

foreach ($rom in $roms) {
    $count++
    $percent = [int](($count / $totalRoms) * 100)
    $romName = $rom.BaseName
    
    Write-Progress -Activity "Finding Cheats" -Status "Processing $romName ($count of $totalRoms)" -PercentComplete $percent

    $destFileName = "$($rom.Name).cht"
    $destPath = Join-Path $OutputPath $destFileName

    if ($SkipExisting -and (Test-Path $destPath)) {
        # Write-Host "Skipping '$romName' (Cheat file exists)." -ForegroundColor DarkGray
        continue
    }

    $searchPattern = "$romName.cht"
    
    # Write-Host "Searching for '$searchPattern'..."
    
    # Search recursively for the cheat file (Exact Match)
    $foundCheats = Get-ChildItem -Path $CheatPath -Filter $searchPattern -File
    # Note: Recursive search removed as we expect CheatPath to be the specific console folder
    if ($foundCheats.Count -eq 0) {
        # Try recursive just in case? Or adhere to strict path?
        # Let's keep recursive for now but strict matched on CheatPath
        $foundCheats = Get-ChildItem -Path $CheatPath -Filter $searchPattern -Recurse -File
    }
    
    if ($foundCheats.Count -eq 0) {
        Write-Warning "No exact match found for '$romName'. Attempting fuzzy match..."
        
        # Lazy load all cheats for fuzzy matching
        if ($null -eq $allCheatsCached) {
            Write-Host "Indexing cheat database for fuzzy matching..."
            $allCheatsCached = Get-ChildItem -Path $CheatPath -Recurse -File
        }

        $bestMatch = $null
        $bestDistance = [int]::MaxValue

        foreach ($cheat in $allCheatsCached) {
            $distance = [StringDistance]::Levenshtein($romName, $cheat.BaseName)
            if ($distance -lt $bestDistance) {
                $bestDistance = $distance
                $bestMatch = $cheat
            }
        }

        # Threshold: Allow match if distance is less than 40% of the longer string's length
        # or a hard limit like 5 characters if strings are short.
        $threshold = [Math]::Max(5, [Math]::Ceiling([Math]::Max($romName.Length, $bestMatch.BaseName.Length) * 0.4))
        
        if ($bestDistance -le $threshold) {
            Write-Host "Fuzzy match found: '$($bestMatch.Name)' (Distance: $bestDistance)" -ForegroundColor Cyan
            $foundCheats = @($bestMatch)
        }
        else {
            Write-Warning "No suitable fuzzy match found. Best guess was '$($bestMatch.Name)' (Distance: $bestDistance)"
            continue
        }
    }
    
    # If multiple matches found (e.g. same game on different consoles?), pick the first one and warn
    if ($foundCheats.Count -gt 1) {
        Write-Warning "Multiple cheat files found for '$romName'. Using the first one: $($foundCheats[0].FullName)"
    }
    
    $sourceFile = $foundCheats[0]
    
    Copy-Item -Path $sourceFile.FullName -Destination $destPath -Force
    Write-Host "Copied '$destFileName' to OutputPath." -ForegroundColor Green
}




Write-Progress -Activity "Finding Cheats" -Completed
Write-Host "Done."
