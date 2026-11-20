# Links the NewbieNudge addon folder into the WoW Forever AddOns folder as a
# directory junction, so edits in this repo show up in game after /reload.
#
#   powershell -File tools\deploy.ps1
#   powershell -File tools\deploy.ps1 -Target "D:\Games\World of Warcraft\_forever_\Interface\AddOns\NewbieNudge"
param(
    [string]$Target = "G:\Games\World of Warcraft\_forever_\Interface\AddOns\NewbieNudge"
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$source = Join-Path $repo "NewbieNudge"

if (-not (Test-Path $source)) {
    Write-Error "Addon folder not found: $source"
}

$parent = Split-Path -Parent $Target
if (-not (Test-Path $parent)) {
    Write-Error "AddOns folder not found: $parent (is WoW Forever installed there? pass -Target)"
}

if (Test-Path $Target) {
    $item = Get-Item $Target -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        cmd /c rmdir "$Target" | Out-Null
    } else {
        Write-Error "A real folder already exists at $Target. Move it away first; this script only manages junctions."
    }
}

cmd /c mklink /J "$Target" "$source" | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Error "mklink failed with exit code $LASTEXITCODE"
}
Write-Output "Junction created: $Target -> $source"
