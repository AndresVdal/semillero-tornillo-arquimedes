<#
.SYNOPSIS
    Junta en una sola carpeta el repositorio que quedo partido en dos
    sitios, y elimina el nivel sobrante "repo".

.DESCRIPCION
    Situacion que corrige:

        Documentos\semillero_repo\repo\   <- scripts y READMEs (sin datos)
        Documentos\Semillero\             <- los datos de verdad

    Resultado:

        Documentos\semillero_repo\        <- todo junto, raiz del repositorio

    La fusion es recursiva y NO sobrescribe: si un archivo ya existe en el
    destino, lo deja donde esta y lo reporta. Nunca borra datos.

.EJEMPLO
    .\consolidar.ps1 -Simular
    .\consolidar.ps1
#>

[CmdletBinding()]
param(
    # Carpeta que sera la raiz definitiva del repositorio
    [string]$Destino = "C:\Users\estudiante.upb\Documents\semillero_repo",

    # Carpeta con los datos que hay que traer
    [string]$Origen = "C:\Users\estudiante.upb\Documents\Semillero",

    # Subcarpeta sobrante dentro del destino (se aplana)
    [string]$NivelSobrante = "repo",

    [switch]$Simular
)

$ErrorActionPreference = "Stop"

function Titulo { param($t) Write-Host "`n=== $t" -ForegroundColor Cyan }
function Ok     { param($t) Write-Host "    OK   $t" -ForegroundColor Green }
function Plan   { param($t) Write-Host "    >>   $t" -ForegroundColor Yellow }
function Info   { param($t) Write-Host "    ..   $t" -ForegroundColor DarkGray }
function Malo   { param($t) Write-Host "    XX   $t" -ForegroundColor Red }

if ($Simular) {
    Write-Host "`n############################################################" -ForegroundColor Yellow
    Write-Host " MODO SIMULACION - no se movera nada" -ForegroundColor Yellow
    Write-Host "############################################################" -ForegroundColor Yellow
}

$script:movidos    = 0
$script:conflictos = @()

<#
    Fusion recursiva.
    Move-Item tiene una trampa en Windows: si el destino ya existe como
    carpeta, mete el origen DENTRO en vez de fusionar. Por eso se recorre
    el arbol archivo por archivo.
#>
function Fusionar {
    param([string]$De, [string]$A)

    if (-not (Test-Path $A)) {
        if ($Simular) { Plan "crear carpeta $A" }
        else { New-Item -Path $A -ItemType Directory -Force | Out-Null }
    }

    foreach ($item in Get-ChildItem -Path $De -Force -ErrorAction SilentlyContinue) {

        $destinoItem = Join-Path $A $item.Name

        if ($item.PSIsContainer) {
            Fusionar -De $item.FullName -A $destinoItem
        }
        else {
            if (Test-Path $destinoItem) {
                $script:conflictos += $destinoItem
            }
            elseif ($Simular) {
                $script:movidos++
            }
            else {
                $padre = Split-Path $destinoItem -Parent
                if (-not (Test-Path $padre)) {
                    New-Item -Path $padre -ItemType Directory -Force | Out-Null
                }
                Move-Item -Path $item.FullName -Destination $destinoItem
                $script:movidos++
            }
        }
    }
}

# ==================================================================
Titulo "Situacion actual"

if (-not (Test-Path $Destino)) { throw "No existe el destino: $Destino" }
Ok "destino: $Destino"

$rutaSobrante = Join-Path $Destino $NivelSobrante
$haySobrante  = Test-Path $rutaSobrante
if ($haySobrante) { Info "nivel sobrante detectado: $rutaSobrante" }

$hayOrigen = Test-Path $Origen
if ($hayOrigen) {
    $n = (Get-ChildItem -Path $Origen -Force -ErrorAction SilentlyContinue).Count
    Info "origen: $Origen  ($n elemento(s) en el primer nivel)"
} else {
    Info "origen no existe, se omite ese paso"
}

# ==================================================================
if ($haySobrante) {
    Titulo "Paso 1: aplanar el nivel '$NivelSobrante'"

    $script:movidos = 0
    Fusionar -De $rutaSobrante -A $Destino

    if ($Simular) {
        Plan "$($script:movidos) archivo(s) subirian un nivel"
    } else {
        Ok "$($script:movidos) archivo(s) movidos"
        $resto = Get-ChildItem -Path $rutaSobrante -Recurse -File -Force -ErrorAction SilentlyContinue
        if (-not $resto) {
            Remove-Item $rutaSobrante -Recurse -Force
            Ok "carpeta '$NivelSobrante' eliminada"
        } else {
            Malo "quedaron $($resto.Count) archivo(s) en '$NivelSobrante', revisala"
        }
    }
} else {
    Titulo "Paso 1: no hay nivel sobrante que aplanar"
}

# ==================================================================
if ($hayOrigen) {
    Titulo "Paso 2: traer los datos desde $Origen"

    $script:movidos = 0
    Fusionar -De $Origen -A $Destino

    if ($Simular) {
        Plan "$($script:movidos) archivo(s) se traerian"
    } else {
        Ok "$($script:movidos) archivo(s) traidos"
        $resto = Get-ChildItem -Path $Origen -Recurse -File -Force -ErrorAction SilentlyContinue
        if (-not $resto) {
            Remove-Item $Origen -Recurse -Force
            Ok "carpeta origen eliminada (quedo vacia)"
        } else {
            Info "quedan $($resto.Count) archivo(s) en el origen (conflictos), no se borra"
        }
    }
}

# ==================================================================
if ($script:conflictos.Count -gt 0) {
    Titulo "Archivos que ya existian en el destino"
    Malo "$($script:conflictos.Count) conflicto(s). NO se sobrescribio nada:"
    $script:conflictos | Select-Object -First 15 | ForEach-Object {
        Write-Host "      $($_.Replace($Destino, '.'))" -ForegroundColor Red
    }
    if ($script:conflictos.Count -gt 15) {
        Write-Host "      ... y $($script:conflictos.Count - 15) mas" -ForegroundColor Red
    }
    Info "Suelen ser los README que venian en el zip. Decide cual conservar."
}

# ==================================================================
Titulo "Resultado"

if (-not $Simular) {
    Get-ChildItem -Path $Destino -Force | Sort-Object PSIsContainer -Descending | ForEach-Object {
        if ($_.PSIsContainer) {
            $peso = (Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
                     Measure-Object Length -Sum).Sum
            $mb = if ($peso) { [math]::Round($peso / 1MB, 1) } else { 0 }
            "      [dir] {0,-24} {1,8:N1} MB" -f $_.Name, $mb | Write-Host
        } else {
            "            {0,-24}" -f $_.Name | Write-Host -ForegroundColor DarkGray
        }
    }
}

Write-Host "`n============================================================" -ForegroundColor Green
if ($Simular) {
    Write-Host " SIMULACION TERMINADA" -ForegroundColor Yellow
    Write-Host " Si el plan se ve bien, ejecuta sin -Simular" -ForegroundColor Yellow
} else {
    Write-Host " CONSOLIDACION TERMINADA" -ForegroundColor Green
    Write-Host "`n Raiz del repositorio: $Destino"
    Write-Host "`n Siguiente paso:"
    Write-Host "   cd `"$Destino`""
    Write-Host "   .\arreglar_anidado.ps1 -Simular"
    Write-Host "   .\instalar_autopush.ps1"
}
Write-Host "============================================================`n" -ForegroundColor Green
