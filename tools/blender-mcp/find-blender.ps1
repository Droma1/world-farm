param()

$ErrorActionPreference = 'Stop'

$candidates = New-Object System.Collections.Generic.List[string]

function Add-Candidate {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    if ((Test-Path $Path) -and -not $candidates.Contains($Path)) {
        $candidates.Add($Path)
    }
}

Add-Candidate $env:BLENDER_EXE

$appPathKeys = @(
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\blender.exe',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\blender.exe'
)

foreach ($key in $appPathKeys) {
    try {
        $item = Get-ItemProperty $key -ErrorAction Stop
        Add-Candidate $item.'(default)'
        if ($item.Path) {
            Add-Candidate (Join-Path $item.Path 'blender.exe')
        }
    } catch {
    }
}

$commonRoots = @(
    'C:\Program Files\Blender Foundation',
    'C:\Program Files (x86)\Blender Foundation',
    (Join-Path $env:LOCALAPPDATA 'Programs\Blender Foundation')
)

foreach ($root in $commonRoots) {
    if (-not (Test-Path $root)) {
        continue
    }

    Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object {
            Add-Candidate (Join-Path $_.FullName 'blender.exe')
        }
}

$command = Get-Command blender -ErrorAction SilentlyContinue
if ($command) {
    Add-Candidate $command.Source
}

if ($candidates.Count -eq 0) {
    Write-Error 'No se encontro Blender. Define BLENDER_EXE o pasa -BlenderPath al script que lo necesite.'
}

$candidates[0]