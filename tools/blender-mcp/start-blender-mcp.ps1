param(
    [string]$BlenderPath,
    [int]$Port = 9876
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

$startupScript = Join-Path $PSScriptRoot 'start_blender_mcp.py'
if (-not (Test-Path $startupScript)) {
    throw "No existe el script de arranque: $startupScript"
}

Start-Process -FilePath $blenderExe -ArgumentList @('--python', $startupScript, '--', $Port)

Write-Output "Blender iniciado con MCP en: $blenderExe"
Write-Output "Puerto MCP: $Port"