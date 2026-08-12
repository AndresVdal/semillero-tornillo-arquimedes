<#
.SYNOPSIS
    Instala Git y GitHub CLI SIN permisos de administrador.

.DESCRIPCION
    En equipos institucionales la cuenta de usuario no puede escribir en
    C:\Program Files, y el instalador normal de Git falla con "Error 5:
    Acceso denegado".

    Este script usa las versiones portables, que se descomprimen dentro de
    tu propia carpeta de usuario (%LOCALAPPDATA%\Programs) y no tocan
    C:\Program Files ni el registro de la maquina.

.EJEMPLO
    .\instalar_git_sin_admin.ps1
#>

[CmdletBinding()]
param(
    [string]$Destino = "$env:LOCALAPPDATA\Programs",
    [switch]$SoloGit
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Titulo { param($t) Write-Host "`n=== $t" -ForegroundColor Cyan }
function Ok     { param($t) Write-Host "    OK   $t" -ForegroundColor Green }
function Info   { param($t) Write-Host "    ..   $t" -ForegroundColor DarkGray }
function Aviso  { param($t) Write-Host "    !!   $t" -ForegroundColor Yellow }

$gitDir = Join-Path $Destino "Git"
$ghDir  = Join-Path $Destino "gh"
$temp   = $env:TEMP

if (-not (Test-Path $Destino)) { New-Item -Path $Destino -ItemType Directory -Force | Out-Null }

# ==================================================================
Titulo "1. Comprobando si Git ya esta disponible"

$gitYa = Get-Command git -ErrorAction SilentlyContinue
if ($gitYa) {
    Ok "Git ya esta en el PATH: $(& git --version)"
    Info "Ubicacion: $($gitYa.Source)"
    $instalarGit = $false
} else {
    # El log del instalador fallido mencionaba C:\Program Files\Git.
    # Puede haber quedado una instalacion parcial que aun sirva.
    $candidatos = @(
        "C:\Program Files\Git\cmd\git.exe",
        "C:\Program Files (x86)\Git\cmd\git.exe",
        (Join-Path $gitDir "cmd\git.exe")
    )
    $encontrado = $candidatos | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($encontrado) {
        Aviso "Git existe pero no esta en el PATH: $encontrado"
        try {
            $v = & $encontrado --version
            Ok "Funciona: $v  -> solo hay que agregarlo al PATH"
            $gitDir = Split-Path (Split-Path $encontrado -Parent) -Parent
            $instalarGit = $false
        } catch {
            Aviso "Esa copia esta rota (instalacion a medias). Se instalara la portable."
            $instalarGit = $true
        }
    } else {
        Info "Git no esta instalado"
        $instalarGit = $true
    }
}

# ==================================================================
if ($instalarGit) {
    Titulo "2. Descargando Git portable"

    Info "Consultando la ultima version..."
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/git-for-windows/git/releases/latest" `
                             -Headers @{ "User-Agent" = "PowerShell" }

    $asset = $rel.assets |
        Where-Object { $_.name -like "PortableGit-*-64-bit.7z.exe" } |
        Select-Object -First 1

    if (-not $asset) { throw "No se encontro el paquete PortableGit en la ultima version." }

    $mb = [math]::Round($asset.size / 1MB, 1)
    Ok "$($asset.name)  ($mb MB)"

    $exe = Join-Path $temp $asset.name
    Info "Descargando... (puede tardar unos minutos)"
    $anterior = $ProgressPreference
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $exe
    $ProgressPreference = $anterior
    Ok "Descarga completa"

    Titulo "3. Extrayendo en tu carpeta de usuario"
    if (Test-Path $gitDir) {
        Aviso "Ya existe $gitDir, se sobrescribe"
    }
    Info "Destino: $gitDir"

    # El paquete es un autoextraible 7-Zip: -o destino, -y sin preguntar
    & $exe -o"$gitDir" -y | Out-Null

    if (-not (Test-Path (Join-Path $gitDir "cmd\git.exe"))) {
        throw "La extraccion no produjo cmd\git.exe. Revisa $gitDir"
    }
    Ok "Git extraido"
    Remove-Item $exe -Force -ErrorAction SilentlyContinue
}

# ==================================================================
if (-not $SoloGit) {
    Titulo "4. GitHub CLI (opcional, automatiza crear el repositorio)"

    if (Get-Command gh -ErrorAction SilentlyContinue) {
        Ok "gh ya esta disponible"
    } else {
        try {
            $relGh = Invoke-RestMethod -Uri "https://api.github.com/repos/cli/cli/releases/latest" `
                                       -Headers @{ "User-Agent" = "PowerShell" }
            $assetGh = $relGh.assets |
                Where-Object { $_.name -like "gh_*_windows_amd64.zip" } |
                Select-Object -First 1

            if ($assetGh) {
                $zip = Join-Path $temp $assetGh.name
                Info "Descargando $($assetGh.name)..."
                $anterior = $ProgressPreference
                $ProgressPreference = "SilentlyContinue"
                Invoke-WebRequest -Uri $assetGh.browser_download_url -OutFile $zip
                $ProgressPreference = $anterior

                $tmpDir = Join-Path $temp "gh_extract"
                if (Test-Path $tmpDir) { Remove-Item $tmpDir -Recurse -Force }
                Expand-Archive -Path $zip -DestinationPath $tmpDir -Force

                $interior = Get-ChildItem -Path $tmpDir -Directory | Select-Object -First 1
                if (Test-Path $ghDir) { Remove-Item $ghDir -Recurse -Force }
                Move-Item -Path $interior.FullName -Destination $ghDir

                Remove-Item $zip, $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
                Ok "GitHub CLI instalado en $ghDir"
            }
        } catch {
            Aviso "No se pudo instalar gh: $($_.Exception.Message)"
            Aviso "No es grave: podras crear el repositorio desde github.com"
        }
    }
}

# ==================================================================
Titulo "5. Agregando al PATH de tu usuario"

$rutas = @()
if (Test-Path (Join-Path $gitDir "cmd"))  { $rutas += (Join-Path $gitDir "cmd") }
if (Test-Path (Join-Path $ghDir "bin"))   { $rutas += (Join-Path $ghDir "bin") }

$pathUsuario = [Environment]::GetEnvironmentVariable("Path", "User")
if (-not $pathUsuario) { $pathUsuario = "" }
$actuales = $pathUsuario -split ";" | Where-Object { $_ }

$agregadas = 0
foreach ($r in $rutas) {
    if ($actuales -notcontains $r) {
        $pathUsuario = if ($pathUsuario) { "$pathUsuario;$r" } else { $r }
        $agregadas++
        Ok "agregada: $r"
    } else {
        Info "ya estaba: $r"
    }
}

if ($agregadas -gt 0) {
    # "User" no requiere permisos de administrador
    [Environment]::SetEnvironmentVariable("Path", $pathUsuario, "User")
    Ok "PATH de usuario actualizado"
}

# Disponible ya en esta misma sesion
foreach ($r in $rutas) {
    if ($env:Path -notlike "*$r*") { $env:Path = "$env:Path;$r" }
}

# ==================================================================
Titulo "6. Verificacion"

$okGit = $false
try {
    $v = & git --version
    Ok "git  -> $v"
    $okGit = $true
} catch {
    Aviso "git no responde todavia. Cierra y vuelve a abrir PowerShell."
}

try {
    $v = (& gh --version | Select-Object -First 1)
    Ok "gh   -> $v"
} catch {
    Info "gh no disponible (opcional)"
}

# ==================================================================
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " INSTALACION SIN ADMINISTRADOR COMPLETA" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host " Git : $gitDir"
if (Test-Path $ghDir) { Write-Host " gh  : $ghDir" }
Write-Host "`n Nada se instalo en C:\Program Files ni se toco el registro"
Write-Host " de la maquina. Todo vive en tu perfil de usuario."

if ($okGit) {
    Write-Host "`n Siguiente paso:" -ForegroundColor Cyan
    Write-Host "   cd `$HOME\Documents\Semillero"
    Write-Host "   .\reorganizar.ps1 -Simular"
} else {
    Write-Host "`n IMPORTANTE: cierra y vuelve a abrir PowerShell antes de seguir." -ForegroundColor Yellow
}
Write-Host ""
