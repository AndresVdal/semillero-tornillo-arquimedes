<#
.SYNOPSIS
    Reorganiza la carpeta Semillero en la estructura del repositorio:
    docs/ | Dellinger/ | Proyecto/

.DESCRIPCION
    Mueve el contenido existente (Archivos, Imagenes, Modelos) a la nueva
    estructura. Es idempotente: si ya se ejecuto, no hace nada.

.EJEMPLO
    # Primero SIEMPRE en modo simulacion, para ver que va a pasar:
    .\reorganizar.ps1 -Simular

    # Si el plan se ve bien, ejecutar de verdad:
    .\reorganizar.ps1
#>

[CmdletBinding()]
param(
    [string]$Raiz = $PSScriptRoot,
    [switch]$Simular
)

$ErrorActionPreference = "Stop"

# Si el script se ejecuta de forma que $PSScriptRoot quede vacio,
# se usa la carpeta actual como raiz.
if (-not $Raiz) { $Raiz = (Get-Location).Path }
$Raiz = (Resolve-Path $Raiz).Path

function Titulo { param($t) Write-Host "`n=== $t" -ForegroundColor Cyan }
function Ok     { param($t) Write-Host "    OK   $t" -ForegroundColor Green }
function Salto  { param($t) Write-Host "    --   $t" -ForegroundColor DarkGray }
function Plan   { param($t) Write-Host "    >>   $t" -ForegroundColor Yellow }

function Mover {
    param([string]$Origen, [string]$Destino)

    if (-not (Test-Path $Origen)) { Salto "no existe: $Origen"; return }

    $nombre  = Split-Path $Origen -Leaf
    $destino = Join-Path $Destino $nombre
    $rel     = $Origen.Replace($Raiz, ".")
    $relDest = $destino.Replace($Raiz, ".")

    if (Test-Path $destino) { Salto "ya estaba en destino: $relDest"; return }

    if ($Simular) { Plan "$rel  ->  $relDest"; return }

    if (-not (Test-Path $Destino)) { New-Item -Path $Destino -ItemType Directory -Force | Out-Null }
    Move-Item -Path $Origen -Destination $destino
    Ok "$rel  ->  $relDest"
}

if (-not (Test-Path $Raiz)) { throw "No existe la carpeta raiz: $Raiz" }
Set-Location $Raiz

if ($Simular) {
    Write-Host "`n############################################################" -ForegroundColor Yellow
    Write-Host " MODO SIMULACION - no se movera ningun archivo" -ForegroundColor Yellow
    Write-Host "############################################################" -ForegroundColor Yellow
}

# ------------------------------------------------------------------
Titulo "1. Creando la estructura de carpetas"

$carpetas = @(
    "docs",
    "docs\historico",
    "Dellinger",
    "Dellinger\docs",
    "Dellinger\CAD",
    "Dellinger\Workbench",
    "Dellinger\Imagenes",
    "Proyecto",
    "Proyecto\Sitio",
    "Proyecto\CAD",
    "Proyecto\Workbench"
)

foreach ($c in $carpetas) {
    $ruta = Join-Path $Raiz $c
    if (Test-Path $ruta) {
        Salto "ya existe: $c"
    } elseif ($Simular) {
        Plan "crear $c"
    } else {
        New-Item -Path $ruta -ItemType Directory -Force | Out-Null
        Ok "creada: $c"
    }
}

# Marcadores para que git conserve las carpetas vacias del Modelo P
if (-not $Simular) {
    foreach ($c in @("Proyecto\Sitio", "Proyecto\CAD", "Proyecto\Workbench")) {
        $gk = Join-Path (Join-Path $Raiz $c) ".gitkeep"
        if (-not (Test-Path $gk)) { New-Item -Path $gk -ItemType File -Force | Out-Null }
    }
    Ok ".gitkeep en las carpetas vacias de Proyecto"
}

# ------------------------------------------------------------------
Titulo "2. Documentos (carpeta Archivos)"

$archivos = Join-Path $Raiz "Archivos"
if (Test-Path $archivos) {

    # 2a. El protocolo es transversal: la version mas reciente va a docs\,
    #     las anteriores a docs\historico\
    $protocolos = Get-ChildItem -Path $archivos -Filter "Protocolo_validacion*.md" -File |
                  Sort-Object LastWriteTime -Descending

    if ($protocolos.Count -gt 0) {
        Mover $protocolos[0].FullName (Join-Path $Raiz "docs")
        if ($protocolos.Count -gt 1) {
            Write-Host "    (hay $($protocolos.Count) versiones del protocolo; se conserva la mas reciente en docs\)" -ForegroundColor DarkGray
            foreach ($p in $protocolos[1..($protocolos.Count - 1)]) {
                $sello  = $p.LastWriteTime.ToString("yyyy-MM-dd")
                $nuevo  = "{0}__{1}{2}" -f [IO.Path]::GetFileNameWithoutExtension($p.Name), $sello, $p.Extension
                $target = Join-Path (Join-Path $Raiz "docs\historico") $nuevo
                if ($Simular) {
                    Plan "$($p.Name)  ->  .\docs\historico\$nuevo"
                } elseif (-not (Test-Path $target)) {
                    Move-Item -Path $p.FullName -Destination $target
                    Ok "historico: $nuevo"
                }
            }
        }
    }

    # 2b. El resto de documentos son especificos de la validacion
    foreach ($f in (Get-ChildItem -Path $archivos -Filter "*.md" -File)) {
        Mover $f.FullName (Join-Path $Raiz "Dellinger\docs")
    }

    # 2c. Borrar la carpeta si quedo vacia
    if (-not $Simular) {
        if (-not (Get-ChildItem -Path $archivos -Force)) {
            Remove-Item $archivos -Force
            Ok "carpeta Archivos eliminada (quedo vacia)"
        } else {
            Write-Host "    !!   quedo contenido en Archivos\, revisalo a mano" -ForegroundColor Yellow
        }
    }
} else {
    Salto "no existe la carpeta Archivos"
}

# ------------------------------------------------------------------
Titulo "3. Geometria (Modelos\files y Modelos\SpaceClaim)"

$files = Join-Path $Raiz "Modelos\files"
if (Test-Path $files) {
    foreach ($f in (Get-ChildItem -Path $files -File)) {
        Mover $f.FullName (Join-Path $Raiz "Dellinger\CAD")
    }
    if (-not $Simular -and -not (Get-ChildItem -Path $files -Force)) {
        Remove-Item $files -Force
        Ok "carpeta Modelos\files eliminada"
    }
} else { Salto "no existe Modelos\files" }

Mover (Join-Path $Raiz "Modelos\SpaceClaim") (Join-Path $Raiz "Dellinger\CAD")

# ------------------------------------------------------------------
Titulo "4. Proyectos de Ansys (Modelos\Workbench)"

$wb = Join-Path $Raiz "Modelos\Workbench"
if (Test-Path $wb) {
    foreach ($i in (Get-ChildItem -Path $wb -Force)) {
        Mover $i.FullName (Join-Path $Raiz "Dellinger\Workbench")
    }
    if (-not $Simular -and -not (Get-ChildItem -Path $wb -Force)) {
        Remove-Item $wb -Force
        Ok "carpeta Modelos\Workbench eliminada"
    }
} else { Salto "no existe Modelos\Workbench" }

# Borrar Modelos si quedo vacia
if (-not $Simular) {
    $modelos = Join-Path $Raiz "Modelos"
    if ((Test-Path $modelos) -and -not (Get-ChildItem -Path $modelos -Force)) {
        Remove-Item $modelos -Force
        Ok "carpeta Modelos eliminada (quedo vacia)"
    }
}

# ------------------------------------------------------------------
Titulo "5. Capturas (carpeta Imagenes)"

$img = Join-Path $Raiz "Imagenes"
if (Test-Path $img) {
    $n = (Get-ChildItem -Path $img -File -Recurse).Count
    $mb = [math]::Round(((Get-ChildItem -Path $img -File -Recurse | Measure-Object Length -Sum).Sum / 1MB), 1)
    Write-Host "    $n imagen(es), $mb MB en total" -ForegroundColor DarkGray
    foreach ($f in (Get-ChildItem -Path $img -Force)) {
        Mover $f.FullName (Join-Path $Raiz "Dellinger\Imagenes")
    }
    if (-not $Simular -and -not (Get-ChildItem -Path $img -Force)) {
        Remove-Item $img -Force
        Ok "carpeta Imagenes eliminada"
    }
} else { Salto "no existe la carpeta Imagenes" }

# ------------------------------------------------------------------
Titulo "6. Revision de archivos grandes"

$grandes = Get-ChildItem -Path $Raiz -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -gt 95MB -and $_.FullName -notmatch "\\\.git\\" }

if ($grandes) {
    Write-Host "    Estos superan 95 MB. Confirma que el .gitignore los excluya:" -ForegroundColor Yellow
    $grandes | Sort-Object Length -Descending | ForEach-Object {
        "      {0,8:N1} MB  {1}" -f ($_.Length / 1MB), $_.FullName.Replace($Raiz, ".")
    } | Write-Host -ForegroundColor Yellow
} else {
    Ok "ningun archivo supera el limite de GitHub"
}

# ------------------------------------------------------------------
Write-Host "`n============================================================" -ForegroundColor Green
if ($Simular) {
    Write-Host " SIMULACION TERMINADA - no se movio nada" -ForegroundColor Yellow
    Write-Host " Si el plan se ve bien, ejecuta sin -Simular" -ForegroundColor Yellow
} else {
    Write-Host " REORGANIZACION TERMINADA" -ForegroundColor Green
    Write-Host "`n Siguiente paso:"
    Write-Host "   .\instalar_autopush.ps1 -RepoName 'semillero-tornillo-arquimedes'"
}
Write-Host "============================================================`n" -ForegroundColor Green
