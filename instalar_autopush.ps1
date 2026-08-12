<#
.SYNOPSIS
    Crea el repositorio git, lo conecta a GitHub y registra una tarea
    programada que sube los cambios cada N minutos.

.DESCRIPCION
    Funciona SIN permisos de administrador. Si GitHub CLI (gh) no esta
    disponible, pide crear el repositorio a mano en github.com y pasar la
    URL con -RemoteUrl.

    Es idempotente: se puede volver a ejecutar sin problema si fallo antes.

.EJEMPLO
    # Con gh disponible (crea el repo solo)
    .\instalar_autopush.ps1 -RepoName "semillero-tornillo-arquimedes"

    # Sin gh (repo creado antes en github.com)
    .\instalar_autopush.ps1 -RemoteUrl "https://github.com/usuario/semillero-tornillo-arquimedes.git"
#>

[CmdletBinding()]
param(
    [string]$RepoPath  = $PSScriptRoot,
    [string]$RepoName  = "semillero-tornillo-arquimedes",
    [string]$RemoteUrl = "",
    [int]   $Minutos   = 15,
    [string]$Branch    = "main",
    [string]$TaskName  = "AutoPush-Tornillo"
)

$ErrorActionPreference = "Stop"

# Si el script se ejecuta de forma que $PSScriptRoot quede vacio,
# se usa la carpeta actual como raiz.
if (-not $RepoPath) { $RepoPath = (Get-Location).Path }
$RepoPath = (Resolve-Path $RepoPath).Path

function Paso  { param($t) Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok    { param($t) Write-Host "    OK  $t" -ForegroundColor Green }
function Aviso { param($t) Write-Host "    !!  $t" -ForegroundColor Yellow }

<#
    IMPORTANTE
    git escribe avisos normales en stderr (por ejemplo el de CRLF/LF).
    Con $ErrorActionPreference = "Stop", PowerShell convierte eso en un
    NativeCommandError y aborta el script aunque git haya funcionado bien.
    Este envoltorio aisla ese comportamiento: baja la preferencia mientras
    corre git y decide el exito por el codigo de salida, no por stderr.
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

# ------------------------------------------------------------------
Paso "Comprobando requisitos"

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "`nFalta git." -ForegroundColor Red
    Write-Host "Si tu cuenta NO es administrador (error 5, acceso denegado), usa:" -ForegroundColor Red
    Write-Host "    .\instalar_git_sin_admin.ps1" -ForegroundColor Red
    exit 1
}
Ok (Invoke-Git --version).Texto

$hayGh = [bool](Get-Command gh -ErrorAction SilentlyContinue)
if ($hayGh) { Ok "gh disponible" } else { Aviso "gh no disponible; hara falta -RemoteUrl" }

# ------------------------------------------------------------------
Paso "Identidad de git"

$nombre = (Invoke-Git config --global user.name).Texto
$correo = (Invoke-Git config --global user.email).Texto

if (-not $nombre) {
    $nombre = Read-Host "    Tu nombre para los commits"
    Invoke-Git config --global user.name $nombre | Out-Null
}
if (-not $correo) {
    $correo = Read-Host "    Tu correo de GitHub"
    Invoke-Git config --global user.email $correo | Out-Null
}
Ok "$nombre <$correo>"

# ------------------------------------------------------------------
Paso "Preparando la carpeta $RepoPath"

if (-not (Test-Path $RepoPath)) { throw "No existe: $RepoPath" }
Set-Location $RepoPath

$here = Split-Path -Parent $MyInvocation.MyCommand.Path

foreach ($f in @(".gitignore", ".gitattributes", "autopush.ps1")) {
    $origen  = Join-Path $here $f
    $destino = Join-Path $RepoPath $f

    if (-not (Test-Path $origen)) { continue }

    # Si el script ya vive en la raiz del repositorio, origen y destino son
    # el mismo archivo y Copy-Item falla con "no se puede sobrescribir el
    # elemento consigo mismo". No hay nada que copiar.
    $rutaOrigen  = (Resolve-Path $origen).Path
    $rutaDestino = if (Test-Path $destino) { (Resolve-Path $destino).Path } else { $destino }

    if ($rutaOrigen -eq $rutaDestino) {
        Ok "$f ya esta en su sitio"
        continue
    }

    if ((Test-Path $destino) -and $f -eq ".gitignore") {
        Aviso "ya existe .gitignore; se conserva el tuyo"
        continue
    }

    Copy-Item $origen $destino -Force
    Ok "$f instalado"
}

# ------------------------------------------------------------------
Paso "Inicializando el repositorio"

if (-not (Test-Path (Join-Path $RepoPath ".git"))) {
    Invoke-Git init | Out-Null
    Invoke-Git branch -M $Branch | Out-Null
    Ok "repositorio creado en la rama $Branch"
} else {
    Ok "ya era un repositorio git"
}

# Sin conversion de fin de linea: evita reescribir los .out de Fluent
# y silencia el aviso "LF will be replaced by CRLF".
Invoke-Git config core.autocrlf false | Out-Null
Invoke-Git config core.safecrlf false | Out-Null
Ok "conversion de fin de linea desactivada"

# ------------------------------------------------------------------
Paso "Revisando archivos que GitHub rechazaria"

$grandes = Get-ChildItem -Path $RepoPath -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Length -gt 95MB -and $_.FullName -notmatch "\\\.git\\" }

if ($grandes) {
    $totalGB = [math]::Round((($grandes | Measure-Object Length -Sum).Sum / 1GB), 2)
    Aviso "$($grandes.Count) archivo(s) superan 95 MB ($totalGB GB en total)"
    $grandes | Sort-Object Length -Descending | Select-Object -First 10 | ForEach-Object {
        "      {0,8:N1} MB  {1}" -f ($_.Length / 1MB), $_.FullName.Replace($RepoPath, ".")
    } | Write-Host -ForegroundColor DarkGray

    # Verificacion real: preguntarle a git si estan ignorados
    $noIgnorados = @()
    foreach ($g in $grandes) {
        $rel = $g.FullName.Replace("$RepoPath\", "")
        if (-not (Invoke-Git check-ignore -q -- $rel).Ok) { $noIgnorados += $rel }
    }

    if ($noIgnorados) {
        Write-Host "`n    PELIGRO: estos NO estan ignorados y romperian el push:" -ForegroundColor Red
        $noIgnorados | ForEach-Object { Write-Host "      $_" -ForegroundColor Red }
        Write-Host "    Agregalos al .gitignore antes de continuar.`n" -ForegroundColor Red
        exit 1
    }
    Ok "todos estan correctamente excluidos por el .gitignore"
} else {
    Ok "ningun archivo supera el limite"
}

# ------------------------------------------------------------------
Paso "Primer commit"

$r = Invoke-Git add -A
if (-not $r.Ok) { throw "git add fallo:`n$($r.Texto)" }

$staged = (Invoke-Git diff --cached --name-only).Texto
if ($staged) {
    $n = ($staged -split "`n" | Where-Object { $_ }).Count
    $r = Invoke-Git commit -m "Commit inicial: turbina de tornillo de Arquimedes"
    if ($r.Ok) { Ok "$n archivo(s) confirmados" }
    else       { throw "git commit fallo:`n$($r.Texto)" }
} else {
    Aviso "no habia nada que confirmar (quiza ya se hizo el commit)"
}

# ------------------------------------------------------------------
Paso "Conectando con GitHub"

$remoto = Invoke-Git remote get-url origin

if ($remoto.Ok) {
    Ok "ya existe un remoto: $($remoto.Texto)"
    $r = Invoke-Git push -u origin $Branch
    if ($r.Ok) { Ok "contenido subido" } else { Aviso "el push fallo:`n$($r.Texto)" }
}
elseif ($RemoteUrl) {
    Invoke-Git remote add origin $RemoteUrl | Out-Null
    Ok "remoto agregado: $RemoteUrl"
    Write-Host "    Se abrira el navegador para autenticarte (Git Credential Manager)." -ForegroundColor DarkGray
    $r = Invoke-Git push -u origin $Branch
    if ($r.Ok) { Ok "contenido subido" } else { Aviso "el push fallo:`n$($r.Texto)" }
}
elseif ($hayGh) {
    $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
    & gh auth status 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Aviso "sin sesion de GitHub; se abrira el navegador"
        & gh auth login --web --git-protocol https
    }
    & gh repo create $RepoName --private --source=. --remote=origin --push
    $ErrorActionPreference = $prev
    Ok "repositorio '$RepoName' creado y subido"
}
else {
    Write-Host "`n------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host " FALTA CONECTAR EL REPOSITORIO REMOTO" -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host " 1. Entra a https://github.com/new"
    Write-Host " 2. Nombre: $RepoName    Visibilidad: Private"
    Write-Host " 3. NO marques 'Add a README file'"
    Write-Host " 4. Copia la URL y vuelve a ejecutar:"
    Write-Host "      .\instalar_autopush.ps1 -RemoteUrl 'https://github.com/TU_USUARIO/$RepoName.git'" -ForegroundColor Cyan
    Write-Host "`n El commit local ya quedo hecho, no se pierde nada.`n"
    exit 0
}

# ------------------------------------------------------------------
Paso "Registrando la tarea programada (cada $Minutos minutos)"

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$script = Join-Path $RepoPath "autopush.ps1"
$accion = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`" -RepoPath `"$RepoPath`" -Branch $Branch"

$disparador = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
    -RepetitionInterval (New-TimeSpan -Minutes $Minutos)

$opciones = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 20)

Register-ScheduledTask -TaskName $TaskName -Action $accion -Trigger $disparador `
    -Settings $opciones -Description "Sube automaticamente los resultados CFD a GitHub" | Out-Null
Ok "tarea '$TaskName' registrada"

# ------------------------------------------------------------------
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " LISTO" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Repositorio : $((Invoke-Git remote get-url origin).Texto)"
Write-Host " Carpeta     : $RepoPath"
Write-Host " Frecuencia  : cada $Minutos minutos"
Write-Host " Registro    : $RepoPath\autopush.log"
Write-Host "`n Comandos utiles:"
Write-Host "   Subir ahora     : Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "   Ver el registro : Get-Content '$RepoPath\autopush.log' -Tail 20"
Write-Host "   Pausar          : Disable-ScheduledTask -TaskName '$TaskName'"
Write-Host "   Reanudar        : Enable-ScheduledTask -TaskName '$TaskName'"
Write-Host "   Desinstalar     : Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false`n"
