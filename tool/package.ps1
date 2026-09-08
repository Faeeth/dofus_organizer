<#
.SYNOPSIS
    Construit les deux paquets de diffusion : l'installateur et le portable.

.DESCRIPTION
    A lancer depuis la racine du depot :

        pwsh tool/package.ps1 -Version 1.0.0

    Produit dans dist\ :

        Dofus Organizer-<version>-installateur.exe   installation par utilisateur
        DofusOrganizer-<version>-portable.zip        dossier a decompresser

    La version est passee a la compilation : sans elle, le binaire se croit en
    developpement et ne propose jamais de mise a jour.

    L'installateur demande Inno Setup 6. S'il est absent, seul le portable est
    produit et le script le dit.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = 'Stop'

$racine = Split-Path -Parent $PSScriptRoot
Set-Location $racine

$release = 'build\windows\x64\runner\Release'
$dist = 'dist'

Write-Host "== Compilation $Version =="
flutter build windows --release "--dart-define=DOFUS_ORGANIZER_VERSION=$Version"
if ($LASTEXITCODE -ne 0) { throw "la compilation a echoue" }

New-Item -ItemType Directory -Force $dist | Out-Null

# ---------------------------------------------------------------- portable
# Le marqueur distingue une copie decompressee d'une installation : l'outil
# n'y propose pas de lancer l'installateur, qui poserait une seconde copie
# ailleurs et laisserait ce dossier en arriere.
Write-Host "== Archive portable =="
$marqueur = Join-Path $release 'portable.txt'
Set-Content -Path $marqueur -Encoding utf8 -Value @(
    "Dofus Organizer $Version, version portable.",
    "",
    "Lancez dofus_organizer.exe, rien a installer.",
    "La configuration est ecrite dans %LOCALAPPDATA%\DofusOrganizer et survit",
    "au remplacement de ce dossier."
)

$zip = Join-Path $dist "DofusOrganizer-$Version-portable.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $release '*') -DestinationPath $zip
Write-Host "  $zip"

# ------------------------------------------------------------ installateur
# Le marqueur est retire avant : le .iss l'exclut deja, mais laisser trainer
# un fichier qui ment sur la nature de la copie ne vaut rien.
Remove-Item $marqueur -Force

$iscc = @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $iscc) {
    Write-Warning "Inno Setup 6 introuvable : installateur non construit."
    Write-Warning "  winget install JRSoftware.InnoSetup"
    exit 0
}

Write-Host "== Installateur =="
& $iscc 'installer\dofus_organizer.iss' "/DVersion=$Version"
if ($LASTEXITCODE -ne 0) { throw "Inno Setup a echoue" }
Get-ChildItem $dist -Filter "*$Version*" | ForEach-Object { Write-Host "  $($_.FullName)" }
