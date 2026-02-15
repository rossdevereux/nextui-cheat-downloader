
$ErrorActionPreference = "Stop"

# Setup Test Environment
$testDir = Join-Path $PSScriptRoot "test_env"
$romDir = Join-Path $testDir "roms"
$outDir = Join-Path $testDir "output"
$dbDir = Join-Path $testDir "database"
$chtDir = Join-Path $dbDir "cht"
$systemDir = Join-Path $chtDir "Nintendo - Nintendo Entertainment System"

# Clean up previous runs
if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force }

New-Item -ItemType Directory -Force $romDir | Out-Null
New-Item -ItemType Directory -Force $outDir | Out-Null
New-Item -ItemType Directory -Force $systemDir | Out-Null

# Create Dummy ROM
$romName = "Metroid (USA)"
New-Item -Path (Join-Path $romDir "$romName.nes") -ItemType File | Out-Null

# Create Dummy Cheat File
$cheatContent = "cheats = 1`ncheat0_desc = `"Infinite Energy`"`ncheat0_code = `"SZSZVO`"`ncheat0_enable = false"
$cheatFile = Join-Path $systemDir "$romName.cht"
Set-Content -Path $cheatFile -Value $cheatContent

# Run the Script
$scriptPath = Join-Path $PSScriptRoot "find-cheats.ps1"
Write-Host "Running find-cheats.ps1..."
& $scriptPath -RomPath $romDir -OutputPath $outDir -CheatPath $systemDir

# Verify Output
$expectedOutput = Join-Path $outDir "$romName.nes.cht"
if (Test-Path $expectedOutput) {
    Write-Host "SUCCESS: Cheat file found and copied to '$expectedOutput'." -ForegroundColor Green
    $content = Get-Content $expectedOutput -Raw
    if ($content.Trim() -eq $cheatContent.Trim()) {
        Write-Host "SUCCESS: Content matches." -ForegroundColor Green
    }
    else {
        Write-Error "FAILURE: Content mismatch.`nExpected: '$($cheatContent.Trim())'`nActual:   '$($content.Trim())'"
    }
}
else {
    Write-Error "FAILURE: Cheat file not found in output directory."
}

# ----------------------------------------------------------------
# Fuzzy Match Test
# ----------------------------------------------------------------
Write-Host "`nRunning Fuzzy Match Test..."
$fuzzyRomName = "Metroid (US)" # Should match "Metroid (USA).cht"
New-Item -Path (Join-Path $romDir "$fuzzyRomName.nes") -ItemType File | Out-Null

# Run the script again
& $scriptPath -RomPath $romDir -OutputPath $outDir -CheatPath $systemDir

$expectedFuzzyOutput = Join-Path $outDir "$fuzzyRomName.nes.cht"
if (Test-Path $expectedFuzzyOutput) {
    Write-Host "SUCCESS: Fuzzy matched cheat file found and copied to '$expectedFuzzyOutput'." -ForegroundColor Green
    $content = Get-Content $expectedFuzzyOutput -Raw
    if ($content.Trim() -eq $cheatContent.Trim()) {
        Write-Host "SUCCESS: Content matches." -ForegroundColor Green
    }
    else {
        Write-Error "FAILURE: Content mismatch."
    }
}
else {
    Write-Error "FAILURE: Fuzzy matched cheat file not found."
}

# ----------------------------------------------------------------
# Invalid Cheat Path Test
# ----------------------------------------------------------------
Write-Host "`nRunning Invalid Cheat Path Test..."
$invalidPath = Join-Path $testDir "does_not_exist"
try {
    & $scriptPath -RomPath $romDir -OutputPath $outDir -CheatPath $invalidPath 2>$null
    Write-Error "FAILURE: Script should have failed with invalid CheatPath."
}
catch {
    Write-Host "SUCCESS: Script correctly failed with invalid CheatPath." -ForegroundColor Green
}

# ----------------------------------------------------------------
# Skip Existing Test
# ----------------------------------------------------------------
Write-Host "`nRunning Skip Existing Test..."
# Create a dummy existing cheat file with unique content
$dummyContent = "EXISTING_CONTENT"
$existingCheatFile = Join-Path $outDir "$romName.nes.cht"
Set-Content -Path $existingCheatFile -Value $dummyContent

# Run script with -SkipExisting
& $scriptPath -RomPath $romDir -OutputPath $outDir -CheatPath $systemDir -SkipExisting

# Verify content was NOT overwritten
$currentContent = Get-Content $existingCheatFile -Raw
if ($currentContent.Trim() -eq $dummyContent) {
    Write-Host "SUCCESS: Existing cheat file was skipped (content preserved)." -ForegroundColor Green
}
else {
    Write-Error "FAILURE: Existing cheat file was overwritten."
}
