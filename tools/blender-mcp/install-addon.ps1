param(
    [string]$BlenderPath,
    [string]$AddonPath = (Join-Path $PSScriptRoot 'addon.py'),
    [string]$AddonUrl = 'https://raw.githubusercontent.com/ahujasid/blender-mcp/main/addon.py'
)

$ErrorActionPreference = 'Stop'

function Resolve-BlenderPath {
    param([string]$ExplicitPath)

    if ($ExplicitPath) {
        if (-not (Test-Path $ExplicitPath)) {
            throw "Blender no existe en: $ExplicitPath"
        }

        return (Resolve-Path $ExplicitPath).Path
    }

    $finder = Join-Path $PSScriptRoot 'find-blender.ps1'
    return (& $finder)
}

$blenderExe = Resolve-BlenderPath -ExplicitPath $BlenderPath

$addonDir = Split-Path -Parent $AddonPath
if (-not (Test-Path $addonDir)) {
    New-Item -ItemType Directory -Path $addonDir | Out-Null
}

Invoke-WebRequest -Uri $AddonUrl -OutFile $AddonPath

$addonLiteral = $AddonPath.Replace("'", "''")
$pythonCode = @"
import bpy
addon_path = r'$addonLiteral'
bpy.ops.preferences.addon_install(filepath=addon_path, overwrite=True)
bpy.ops.preferences.addon_enable(module='addon')
bpy.ops.wm.save_userpref()
print('Blender MCP addon installed and enabled from', addon_path)
"@

& $blenderExe --background --factory-startup --python-expr $pythonCode

Write-Output "Addon instalado en Blender usando: $blenderExe"
Write-Output "Archivo descargado: $AddonPath"