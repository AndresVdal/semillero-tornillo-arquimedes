<#
.SYNOPSIS
    Corrige elementos envueltos en una carpeta con su mismo nombre.

.DESCRIPCION
    Un fallo de reorganizar.ps1 dejo cada elemento movido metido dentro de
    una carpeta con su propio nombre. Windows lo muestra como "Carpeta de
    archivos" y sin tamano, aunque en realidad sea un archivo.

    Corrige los dos casos:

        CAD\artesa_V.step\artesa_V.step          (archivo envuelto)
            ->  CAD\artesa_V.step

        Workbench\Testeo_files\Testeo_files\dp0  (carpeta envuelta)
            ->  Workbench\Testeo_files\dp0

    Trabaja de la ruta mas profunda a la menos profunda, no sobrescribe
    nada, y al final comprueba que el numero de archivos y los bytes
    totales sean identicos a los del inicio.

.EJEMPLO
    .\arreglar_anidado.ps1 -Simular
    .\arreglar_anidado.ps1
#>

[CmdletBinding()]
param(
    [string]$Raiz = $PSScriptRoot,
    [switch]$Simular
)

$ErrorActionPreference = "Stop"

if (-not $Raiz) { $Raiz = (Get-Location).Path }
$Raiz = (Resolve-Path $Raiz).Path

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

# ==================================================================
Titulo "Inventario inicial"

$antes = Get-ChildItem -LiteralPath $Raiz -Recurse -File -Force -ErrorAction SilentlyContinue |
         Where-Object { $_.FullName -notmatch "\\\.git\\" }
$antesN = ($antes | Measure-Object).Count
$antesB = ($antes | Measure-Object Length -Sum).Sum
Ok ("{0} archivo(s), {1:N1} MB" -f $antesN, ($antesB / 1MB))

# ==================================================================
Titulo "Buscando envoltorios"

$casos = @()

Get-ChildItem -LiteralPath $Raiz -Directory -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "\\\.git\\" } |
    ForEach-Object {
        $gemelo = Join-Path $_.FullName $_.Name
        if (Test-Path -LiteralPath $gemelo) {
            $casos += [pscustomobject]@{
                Envoltorio = $_.FullName
                Nombre     = $_.Name
                Profundidad = ($_.FullName -split "\\").Count
            }
        }
    }

if ($casos.Count -eq 0) {
    Ok "No hay envoltorios. La estructura esta correcta."
    Write-Host ""
    exit 0
}

Write-Host "    $($casos.Count) envoltorio(s) encontrado(s)" -ForegroundColor Yellow
$casos | Select-Object -First 12 | ForEach-Object {
    Write-Host "      $($_.Envoltorio.Replace($Raiz, '.'))" -ForegroundColor DarkGray
}
if ($casos.Count -gt 12) {
    Write-Host "      ... y $($casos.Count - 12) mas" -ForegroundColor DarkGray
}

# ==================================================================
Titulo "Corrigiendo (de lo mas profundo a lo mas superficial)"

$casos = $casos | Sort-Object Profundidad -Descending

$corregidos  = 0
$conflictos  = @()
$restantes   = @()

foreach ($c in $casos) {

    $envoltorio = $c.Envoltorio
    $nombre     = $c.Nombre
    $padre      = Split-Path $envoltorio -Parent

    if (-not (Test-Path -LiteralPath $envoltorio)) { continue }

    $hijos = @(Get-ChildItem -LiteralPath $envoltorio -Force -ErrorAction SilentlyContinue)
    if ($hijos.Count -eq 0) { continue }

    $etiqueta = $envoltorio.Replace($Raiz, ".")

    if ($Simular) {
        $solo = if ($hijos.Count -eq 1 -and $hijos[0].Name -eq $nombre) { "envoltorio puro" }
                else { "$($hijos.Count) elemento(s) a subir" }
        Plan "$etiqueta   [$solo]"
        $corregidos++
        continue
    }

    # Renombrar el envoltorio libera el nombre destino y evita que
    # Move-Item vuelva a meter el elemento dentro de si mismo.
    $tmpNombre = "__tmp_" + [guid]::NewGuid().ToString("N").Substring(0, 8)
    $tmpRuta   = Join-Path $padre $tmpNombre
    Rename-Item -LiteralPath $envoltorio -NewName $tmpNombre

    foreach ($h in Get-ChildItem -LiteralPath $tmpRuta -Force) {
        $destino = Join-Path $padre $h.Name
        if (Test-Path -LiteralPath $destino) {
            $conflictos += $destino
        } else {
            Move-Item -LiteralPath $h.FullName -Destination $destino
        }
    }

    $sobra = @(Get-ChildItem -LiteralPath $tmpRuta -Force -ErrorAction SilentlyContinue)
    if ($sobra.Count -eq 0) {
        Remove-Item -LiteralPath $tmpRuta -Force
        Ok $etiqueta
        $corregidos++
    } else {
        # Devolver el nombre original para no dejar basura sin identificar
        Rename-Item -LiteralPath $tmpRuta -NewName $nombre
        $restantes += $envoltorio
        Malo "$etiqueta  (quedaron $($sobra.Count) elemento(s))"
    }
}

# ==================================================================
if ($Simular) {
    Write-Host "`n============================================================" -ForegroundColor Yellow
    Write-Host " SIMULACION: se corregirian $corregidos envoltorio(s)" -ForegroundColor Yellow
    Write-Host " Si se ve bien, ejecuta sin -Simular" -ForegroundColor Yellow
    Write-Host "============================================================`n" -ForegroundColor Yellow
    exit 0
}

# ==================================================================
Titulo "Verificacion de integridad"

$despues = Get-ChildItem -LiteralPath $Raiz -Recurse -File -Force -ErrorAction SilentlyContinue |
           Where-Object { $_.FullName -notmatch "\\\.git\\" }
$despuesN = ($despues | Measure-Object).Count
$despuesB = ($despues | Measure-Object Length -Sum).Sum

Write-Host ("    antes:   {0,6} archivo(s)  {1,10:N1} MB" -f $antesN, ($antesB / 1MB))
Write-Host ("    despues: {0,6} archivo(s)  {1,10:N1} MB" -f $despuesN, ($despuesB / 1MB))

if ($despuesN -eq $antesN -and $despuesB -eq $antesB) {
    Ok "integridad correcta: no se perdio nada"
} else {
    Malo "LA CUENTA NO CUADRA. Revisa antes de hacer commit."
}

if ($conflictos) {
    Titulo "Conflictos (no se sobrescribio nada)"
    $conflictos | Select-Object -First 10 | ForEach-Object {
        Write-Host "      $($_.Replace($Raiz, '.'))" -ForegroundColor Red
    }
}

# Segunda pasada de comprobacion
$quedan = @()
Get-ChildItem -LiteralPath $Raiz -Directory -Recurse -Force -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch "\\\.git\\" } |
    ForEach-Object {
        if (Test-Path -LiteralPath (Join-Path $_.FullName $_.Name)) { $quedan += $_.FullName }
    }

if ($quedan) {
    Titulo "Todavia quedan $($quedan.Count) envoltorio(s)"
    Info "Vuelve a ejecutar el script; los casos encadenados requieren varias pasadas."
} else {
    Ok "no queda ningun envoltorio"
}

# ==================================================================
Titulo "Como quedo Dellinger"

$dell = Join-Path $Raiz "Dellinger"
if (Test-Path -LiteralPath $dell) {
    Get-ChildItem -LiteralPath $dell -Force | ForEach-Object {
        if ($_.PSIsContainer) {
            $n = @(Get-ChildItem -LiteralPath $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue).Count
            "      [dir] {0,-20} {1,5} archivo(s)" -f $_.Name, $n | Write-Host
        } else {
            "            {0,-20} {1,8:N1} KB" -f $_.Name, ($_.Length / 1KB) | Write-Host -ForegroundColor DarkGray
        }
    }
}

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " $corregidos envoltorio(s) corregido(s)" -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Green
