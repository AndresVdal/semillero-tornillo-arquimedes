<#
.SYNOPSIS
    Sube automaticamente a GitHub los archivos nuevos/modificados de un
    proyecto Ansys, ignorando binarios pesados y archivos aun en escritura.

.NOTES
    Semillero SIIM - UPB Bucaramanga
    Pensado para ejecutarse cada N minutos desde el Programador de tareas.
#>

[CmdletBinding()]
param(
    # Carpeta del repositorio git
    [string]$RepoPath = $PSScriptRoot,

    # Segundos que un archivo debe llevar SIN modificarse para considerarse
    # estable. Evita subir un .out que Fluent esta escribiendo justo ahora.
    [int]$QuietSeconds = 90,

    # Tamano maximo por archivo en MB (GitHub rechaza >100 MB)
    [int]$MaxFileMB = 95,

    # Rama destino
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

# Si el script se ejecuta de forma que $PSScriptRoot quede vacio,
# se usa la carpeta actual como raiz.
if (-not $RepoPath) { $RepoPath = (Get-Location).Path }
$RepoPath = (Resolve-Path $RepoPath).Path
$logFile = Join-Path $RepoPath "autopush.log"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Write-Host $line
    Add-Content -Path $logFile -Value $line -Encoding UTF8
}

<#
    git escribe avisos normales en stderr. Con $ErrorActionPreference =
    "Stop", PowerShell los convierte en NativeCommandError y aborta el
    script aunque git haya funcionado. Este envoltorio decide el exito por
    el codigo de salida, no por stderr.
#>
function Invoke-Git {
    # SIN bloque param a proposito.
    #
    # Con param([string[]]$Argumentos), PowerShell interpreta "git add -A"
    # como si -A fuera una abreviatura del parametro -Argumentos, y falla
    # con "Falta un argumento para el parametro Argumentos".
    #
    # Al no declarar parametros, todo llega crudo en $args y se reenvia
    # tal cual a git.

    $previo = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $salida = & git @args 2>&1
    $codigo = $LASTEXITCODE
    $ErrorActionPreference = $previo

    [pscustomobject]@{
        Texto  = ($salida | Out-String).Trim()
        Codigo = $codigo
        Ok     = ($codigo -eq 0)
    }
}

try {
    if (-not (Test-Path $RepoPath)) {
        throw "No existe la carpeta: $RepoPath"
    }
    Set-Location $RepoPath

    if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
        throw "$RepoPath no es un repositorio git. Ejecuta primero instalar_autopush.ps1"
    }

    # --- 1. Evitar que dos ejecuciones se pisen ---------------------------
    $lockFile = Join-Path $RepoPath ".autopush.lock"
    if (Test-Path $lockFile) {
        $age = (Get-Date) - (Get-Item $lockFile).LastWriteTime
        if ($age.TotalMinutes -lt 30) {
            Write-Log "Otra ejecucion sigue activa. Se omite este ciclo." "WARN"
            exit 0
        }
        Write-Log "Lock viejo (>30 min). Se descarta." "WARN"
    }
    New-Item -Path $lockFile -ItemType File -Force | Out-Null

    # --- 2. Preparar todos los cambios ------------------------------------
    $r = Invoke-Git add -A
    if (-not $r.Ok) { throw "git add fallo: $($r.Texto)" }

    $staged = (Invoke-Git diff --cached --name-only).Texto
    if (-not $staged) {
        Write-Log "Sin cambios que subir."
        Remove-Item $lockFile -Force
        exit 0
    }
    $lista = $staged -split "`n" | Where-Object { $_ }

    # --- 3. Quitar archivos aun en escritura ------------------------------
    $cutoff  = (Get-Date).AddSeconds(-$QuietSeconds)
    $skipped = 0
    foreach ($f in $lista) {
        $full = Join-Path $RepoPath $f
        if (Test-Path $full) {
            if ((Get-Item $full).LastWriteTime -gt $cutoff) {
                Invoke-Git restore --staged -- $f | Out-Null
                $skipped++
            }
        }
    }
    if ($skipped -gt 0) {
        Write-Log "$skipped archivo(s) aun en escritura. Se subiran en el proximo ciclo."
    }

    # --- 4. Quitar archivos demasiado grandes -----------------------------
    $limit  = $MaxFileMB * 1MB
    $tooBig = @()
    $lista2 = (Invoke-Git diff --cached --name-only).Texto -split "`n" | Where-Object { $_ }
    foreach ($f in $lista2) {
        $full = Join-Path $RepoPath $f
        if (Test-Path $full) {
            $item = Get-Item $full
            if ($item.Length -gt $limit) {
                Invoke-Git restore --staged -- $f | Out-Null
                $tooBig += ("{0} ({1:N1} MB)" -f $f, ($item.Length / 1MB))
            }
        }
    }
    foreach ($b in $tooBig) {
        Write-Log "EXCLUIDO por tamano: $b  -> agregalo al .gitignore" "WARN"
    }

    # --- 5. Confirmar y enviar --------------------------------------------
    $final = (Invoke-Git diff --cached --name-only).Texto -split "`n" | Where-Object { $_ }
    if (-not $final) {
        Write-Log "Nada estable que subir en este ciclo."
        Remove-Item $lockFile -Force
        exit 0
    }

    $count = ($final | Measure-Object).Count
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm"
    $msg   = "Auto: $count archivo(s) - $stamp"

    $r = Invoke-Git commit -m $msg
    if (-not $r.Ok) { throw "git commit fallo: $($r.Texto)" }

    Write-Log "Commit hecho: $msg"
    foreach ($f in $final) { Write-Log "   + $f" }

    $r = Invoke-Git push origin $Branch
    if ($r.Ok) {
        Write-Log "Push a origin/$Branch correcto."
    } else {
        Write-Log "Fallo el push. El commit quedo local; se reintentara. $($r.Texto)" "ERROR"
    }

    Remove-Item $lockFile -Force
}
catch {
    Write-Log $_.Exception.Message "ERROR"
    $lockFile = Join-Path $RepoPath ".autopush.lock"
    if (Test-Path $lockFile) { Remove-Item $lockFile -Force }
    exit 1
}
