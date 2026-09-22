# build_installer.ps1 — Build Utify Windows Installer
# Run from the project root: .\installer\build_installer.ps1
#
# What it does:
#   1. Builds the Flutter Windows release
#   2. Compiles the Inno Setup script → Utify_Setup_1.0.0.exe

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path $PSScriptRoot -Parent
$IsccPath    = if (Test-Path "C:\Program Files (x86)\Inno Setup 6\ISCC.exe") {
                  "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
               } elseif (Test-Path "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe") {
                  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
               } else { $null }
$IssScript   = Join-Path $PSScriptRoot "utify_setup.iss"
$OutputDir   = Join-Path $PSScriptRoot "output"

Write-Host ""
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  Utify — Windows Installer Builder" -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""

# ── Step 1: Flutter build ────────────────────────────────────────────────────
Write-Host "[1/2] Building Flutter Windows release..." -ForegroundColor Yellow
Push-Location $ProjectRoot
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build failed. Aborting."
    exit 1
}
Pop-Location
Write-Host "      Flutter build complete." -ForegroundColor Green
Write-Host ""

# ── Step 2: Create output directory ─────────────────────────────────────────
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir | Out-Null
}

# ── Step 3: Inno Setup compile ───────────────────────────────────────────────
Write-Host "[2/2] Compiling Inno Setup installer..." -ForegroundColor Yellow
if (-not (Test-Path $IsccPath)) {
    Write-Error "Inno Setup not found at: $IsccPath`nInstall it from https://jrsoftware.org/isdl.php"
    exit 1
}
& $IsccPath $IssScript
if ($LASTEXITCODE -ne 0) {
    Write-Error "Inno Setup compilation failed."
    exit 1
}
Write-Host "      Installer compiled successfully." -ForegroundColor Green
Write-Host ""

# ── Done ─────────────────────────────────────────────────────────────────────
$installer = Get-ChildItem -Path $OutputDir -Filter "Utify_Setup_*.exe" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "  DONE! Installer ready at:" -ForegroundColor Green
Write-Host "  $($installer.FullName)" -ForegroundColor White
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host ""
