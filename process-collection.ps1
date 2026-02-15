<#
.SYNOPSIS
    Batch processes a collection of ROM directories to find cheats.

.DESCRIPTION
    Iterates through subdirectories in the RomRootPath.
    Expects folder names to end with a short name in parentheses, e.g., "Super Nintendo (SFC)".
    Uses this short name to find the corresponding cheat directory in CheatRootPath (e.g., "SFC")
    and outputs cheats to OutputRootPath/ShortName (e.g., "Cheats/SFC").

.PARAMETER RomRootPath
    The root directory containing console subfolders.

.PARAMETER CheatPath
    The root directory containing cheat subfolders (named by short name).

.PARAMETER OutputRootPath
    The root directory for output. Defaults to a "Cheats" folder at the same level as RomRootPath.

.PARAMETER SkipExisting
    If set, passes the -SkipExisting switch to the underlying find-cheats.ps1 script.
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$RomRootPath,

    [Parameter(Mandatory = $true)]
    [string]$CheatPath, # Renamed from CheatRootPath to match user intent or keep consistent? Plan said CheatRootPath. Let's use CheatRootPath for clarity here to distinguish from specific cheat path.
    # Actually, the user requirement said "The cheats are held in directories using the system short name".
    # So we need a root folder where those short name folders live.
    
    [Parameter(Mandatory = $false)]
    [string]$OutputRootPath,

    [Parameter(Mandatory = $false)]
    [switch]$SkipExisting
)

$ErrorActionPreference = "Stop"

function Get-ScriptDirectory {
    if ($PSScriptRoot) { return $PSScriptRoot }
    if ($MyInvocation.MyCommand.Path) { return Split-Path $MyInvocation.MyCommand.Path }
    return Get-Location
}

if (-not (Test-Path $RomRootPath)) {
    Write-Error "RomRootPath '$RomRootPath' does not exist."
    exit 1
}

if (-not (Test-Path -Path $CheatPath)) {
    Write-Error "CheatPath '$CheatPath' does not exist."
    exit 1
}

# Default OutputRootPath to "../Cheats" relative to RomRootPath if not specified
if ([string]::IsNullOrWhiteSpace($OutputRootPath)) {
    $parentDir = Split-Path -Path $RomRootPath -Parent
    $OutputRootPath = Join-Path $parentDir "Cheats"
}

if (-not (Test-Path $OutputRootPath)) {
    New-Item -ItemType Directory -Force -Path $OutputRootPath | Out-Null
    Write-Host "Created OutputRootPath '$OutputRootPath'."
}

$scriptDir = Get-ScriptDirectory
$findCheatsScript = Join-Path $scriptDir "find-cheats.ps1"


# Add StringDistance type for fuzzy matching (same as find-cheats.ps1)
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

if (-not ([System.Management.Automation.PSTypeName]'StringDistance').Type) {
    Add-Type -TypeDefinition $stringDistanceType
}

function Find-BestCheatDirectory {
    param(
        [string]$RomDirName,
        [string]$ShortName,
        [string]$CheatRootPath
    )

    $cheatDirs = Get-ChildItem -Path $CheatRootPath -Directory
    
    # 1. Exact Short Name Match
    $exactMatch = $cheatDirs | Where-Object { $_.Name -eq $ShortName } | Select-Object -First 1
    if ($exactMatch) {
        return @{ Type = "Exact"; Dir = $exactMatch }
    }

    # 2. Containment Match (Cheat dir contains Full ROM dir name or vice versa)
    # Remove the (ShortName) part for cleaner matching
    $cleanRomName = $RomDirName -replace '\s*\([^)]+\)$', ''
    
    $containMatch = $cheatDirs | Where-Object { 
        $_.Name -like "*$cleanRomName*" -or $cleanRomName -like "*$($_.Name)*" 
    } | Select-Object -First 1
    
    if ($containMatch) {
        return @{ Type = "Containment"; Dir = $containMatch }
    }

    # 2.5 Normalized Containment Match (Ignore spaces, symbols, case)
    $normRom = $cleanRomName -replace '[^a-zA-Z0-9]', ''
    $normRom = $normRom.ToLower()
    
    # Pre-calculate normalized cheat dir names to avoid re-processing in loop if list is huge, 
    # but for typical console lists (~100), it's fine.
    
    foreach ($dir in $cheatDirs) {
        $normCheat = $dir.Name -replace '[^a-zA-Z0-9]', ''
        $normCheat = $normCheat.ToLower()
        
        if ($normRom.Length -gt 3 -and $normCheat.Contains($normRom)) {
            return @{ Type = "Normalized Containment"; Dir = $dir }
        }
    }

    # 3. Fuzzy Match
    $bestDist = [int]::MaxValue
    $bestDir = $null

    foreach ($dir in $cheatDirs) {
        $dist = [StringDistance]::Levenshtein($cleanRomName, $dir.Name)
        # Write-Host "DEBUG: '$cleanRomName' vs '$($dir.Name)' = $dist" -ForegroundColor DarkGray
        if ($dist -lt $bestDist) {
            $bestDist = $dist
            $bestDir = $dir
        }
    }

    # Threshold for fuzzy match (e.g. 50% of length or fixed value?)
    # Let's say if distance is less than 40% of the longer string length
    $maxLength = [Math]::Max($cleanRomName.Length, $bestDir.Name.Length)
    $threshold = $maxLength * 0.4
    
    # Write-Host "DEBUG: Best Match '$($bestDir.Name)' Dist: $bestDist Threshold: $threshold" -ForegroundColor DarkGray

    if ($bestDir -and ($bestDist -le $threshold)) {
        return @{ Type = "Fuzzy (Dist: $bestDist)"; Dir = $bestDir }
    }

    return $null
}

# Get immediate subdirectories
$consoleDirs = Get-ChildItem -Path $RomRootPath -Directory

foreach ($consoleDir in $consoleDirs) {
    $dirName = $consoleDir.Name
    $shortName = $null
    
    # Extract short name if present
    if ($dirName -match '\(([^)]+)\)$') {
        $shortName = $matches[1]
    }
    
    Write-Host "Processing '$dirName'..." -NoNewline
    
    $match = Find-BestCheatDirectory -RomDirName $dirName -ShortName $shortName -CheatRootPath $CheatPath
    
    if ($match) {
        $sourceCheatDir = $match.Dir.FullName
        $matchType = $match.Type
        
        Write-Host " Found Match [$matchType] -> '$($match.Dir.Name)'" -ForegroundColor Green
        
        # Use short name for output folder if available, otherwise use matched cheat folder name
        $outName = if ($shortName) { $shortName } else { $match.Dir.Name }
        $destCheatDir = Join-Path $OutputRootPath $outName
        
        # Write-Host "  Source: $sourceCheatDir"
        # Write-Host "  Dest:   $destCheatDir"
            
        $cmdArgs = @{
            RomPath      = $consoleDir.FullName
            CheatPath    = $sourceCheatDir
            OutputPath   = $destCheatDir
            SkipExisting = $SkipExisting
        }
        
        # Call the find-cheats.ps1 script
        & $findCheatsScript @cmdArgs
        
    }
    else {
        Write-Host " No matching cheat directory found." -ForegroundColor Yellow
    }
    Write-Host "" # Newline
}

Write-Host "Batch processing complete." -ForegroundColor Green
