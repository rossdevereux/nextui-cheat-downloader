$ErrorActionPreference = "Stop"

# Setup Test Environment for Batch Processing
$testDir = Join-Path $PSScriptRoot "test_env_batch"
$romRoot = Join-Path $testDir "Roms"
$cheatRoot = Join-Path $testDir "Cheats_Source"
$outputRoot = Join-Path $testDir "Output"

# Clean up previous runs
if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force }

# Create Directories
New-Item -ItemType Directory -Force $romRoot | Out-Null
New-Item -ItemType Directory -Force $cheatRoot | Out-Null

# ----------------------------------------------------------------
# Setup Case 1: Exact Short Name Match "Test Console (TC)" -> "TC"
# ----------------------------------------------------------------
# ROM
$console1Dir = Join-Path $romRoot "Test Console (TC)"
New-Item -ItemType Directory -Force $console1Dir | Out-Null
$rom1 = Join-Path $console1Dir "GameOne.bin"
New-Item -ItemType File $rom1 | Out-Null

# Cheat Source (Folder "TC")
$cheatSrc1 = Join-Path $cheatRoot "TC"
New-Item -ItemType Directory -Force $cheatSrc1 | Out-Null
$cheatFile1 = Join-Path $cheatSrc1 "GameOne.cht"
Set-Content -Path $cheatFile1 -Value "cheat1_desc = Exact Match"


# ----------------------------------------------------------------
# Setup Case 2: Containment Match "Nintendo Game Boy (GB)" -> "Nintendo - Game Boy"
# ----------------------------------------------------------------
$console2Dir = Join-Path $romRoot "Nintendo Game Boy (GB)"
New-Item -ItemType Directory -Force $console2Dir | Out-Null
$rom2 = Join-Path $console2Dir "Mario.gb"
New-Item -ItemType File $rom2 | Out-Null

# Cheat Source with "Game Boy" in name
$cheatSrc2 = Join-Path $cheatRoot "Nintendo - Game Boy"
New-Item -ItemType Directory -Force $cheatSrc2 | Out-Null
$cheatFile2 = Join-Path $cheatSrc2 "Mario.cht"
Set-Content -Path $cheatFile2 -Value "cheat2_desc = Containment Match"


# ----------------------------------------------------------------
# Setup Case 3: Fuzzy Match "Megadrive" -> "Sega - Mega Drive - Genesis"
# ----------------------------------------------------------------
$console3Dir = Join-Path $romRoot "Megadrive (MD)" # Typo/Variation
New-Item -ItemType Directory -Force $console3Dir | Out-Null
$rom3 = Join-Path $console3Dir "Sonic.md"
New-Item -ItemType File $rom3 | Out-Null

# Cheat Source
$cheatSrc3 = Join-Path $cheatRoot "Sega - Mega Drive - Genesis"
New-Item -ItemType Directory -Force $cheatSrc3 | Out-Null
$cheatFile3 = Join-Path $cheatSrc3 "Sonic.cht"
Set-Content -Path $cheatFile3 -Value "cheat3_desc = Fuzzy Match"


# ----------------------------------------------------------------
# Setup Case 4: No Match "Unknown"
# ----------------------------------------------------------------
$console4Dir = Join-Path $romRoot "Unknown Console (UNK)"
New-Item -ItemType Directory -Force $console4Dir | Out-Null


# ----------------------------------------------------------------
# Run process-collection.ps1
# ----------------------------------------------------------------
$scriptPath = Join-Path $PSScriptRoot "process-collection.ps1"
Write-Host "Running process-collection.ps1..."
& $scriptPath -RomRootPath $romRoot -CheatPath $cheatRoot -OutputRootPath $outputRoot

# ----------------------------------------------------------------
# Verification
# ----------------------------------------------------------------
Write-Host "`nVerifying Results..."

# Verify Case 1: Exact Match (Output to 'TC' because shortname exists)
if (Test-Path (Join-Path $outputRoot "TC\GameOne.bin.cht")) {
    Write-Host "SUCCESS: Case 1 (Exact) - Found" -ForegroundColor Green
}
else {
    Write-Error "FAILURE: Case 1 (Exact) - Not Found"
}

# Verify Case 2: Containment Match (Output to 'GB' because shortname exists)
if (Test-Path (Join-Path $outputRoot "GB\Mario.gb.cht")) {
    Write-Host "SUCCESS: Case 2 (Containment) - Found" -ForegroundColor Green
}
else {
    Write-Error "FAILURE: Case 2 (Containment) - Not Found"
}

# Verify Case 3: Fuzzy Match (Output to 'MD' because shortname exists)
if (Test-Path (Join-Path $outputRoot "MD\Sonic.md.cht")) {
    Write-Host "SUCCESS: Case 3 (Fuzzy) - Found" -ForegroundColor Green
}
else {
    Write-Error "FAILURE: Case 3 (Fuzzy) - Not Found"
}

# Verify Case 4: No Match
if (-not (Test-Path (Join-Path $outputRoot "UNK"))) {
    Write-Host "SUCCESS: Case 4 (No Match) - Skipped correctly" -ForegroundColor Green
}
else {
    Write-Error "FAILURE: Case 4 (No Match) - Was processed unexpectedly"
}
