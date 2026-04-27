param(
    [Parameter(Mandatory = $true)]
    [string]$BlendFile,

    [Parameter(Mandatory = $true)]
    [string]$OutputFile,

    [string]$BlenderPath,
    [switch]$ExportAnimations = $true
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

$resolvedBlend = (Resolve-Path $BlendFile).Path
$resolvedOutput = [System.IO.Path]::GetFullPath($OutputFile)
$blenderExe = Resolve-BlenderPath -ExplicitPath $BlenderPath

$exportDir = Split-Path -Parent $resolvedOutput
if (-not (Test-Path $exportDir)) {
    New-Item -ItemType Directory -Path $exportDir | Out-Null
}

$blendLiteral = $resolvedBlend.Replace("'", "''")
$outputLiteral = $resolvedOutput.Replace("'", "''")
$animationsFlag = if ($ExportAnimations) { 'True' } else { 'False' }

$pythonCode = @"
import bpy
import os

blend_path = r'$blendLiteral'
output_path = r'$outputLiteral'
export_animations = $animationsFlag

if bpy.data.filepath != blend_path:
    bpy.ops.wm.open_mainfile(filepath=blend_path)

os.makedirs(os.path.dirname(output_path), exist_ok=True)

bpy.ops.export_scene.gltf(
    filepath=output_path,
    export_format='GLB',
    export_apply=False,
    export_animations=export_animations,
    export_nla_strips=export_animations,
    export_cameras=False,
    export_lights=False,
    export_draco_mesh_compression_enable=False,
)

print('Export complete:', output_path)
"@

& $blenderExe --background --factory-startup --python-expr $pythonCode

Write-Output "GLB exportado a: $resolvedOutput"