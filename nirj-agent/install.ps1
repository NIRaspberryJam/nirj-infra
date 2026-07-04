#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$AssetId,

    [ValidateSet("lpt-win")]
    [string]$DeviceType = "lpt-win",

    [ValidatePattern("^[A-Za-z0-9._/-]+$")]
    [string]$Branch = "main",

    [string]$RepoUrl = "https://github.com/NIRaspberryJam/nirj-agent.git",

    [string]$InstallDir = "$env:ProgramData\nirj"
)

$ErrorActionPreference = "Stop"

$repoDir = Join-Path $InstallDir "agent-repo"
$venvDir = Join-Path $InstallDir "agent-venv"
$runner = Join-Path $InstallDir "run-agent.ps1"
$config = Join-Path $InstallDir "config\config.yaml"
$venvPython = Join-Path $venvDir "Scripts\python.exe"
$agent = Join-Path $venvDir "Scripts\nirj-agent.exe"
$taskName = "nirj-agent"

function Invoke-Native {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [string[]]$ArgumentList = @()
    )

    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $ArgumentList"
    }
}

function Update-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

function Install-WingetPackage {
    param([Parameter(Mandatory)][string]$Id)

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "winget is required to install missing prerequisite $Id"
    }

    Invoke-Native -FilePath $winget.Source -ArgumentList @(
        "install",
        "--id", $Id,
        "--exact",
        "--silent",
        "--scope", "machine",
        "--accept-package-agreements",
        "--accept-source-agreements"
    )
    Update-ProcessPath
}

if ([string]::IsNullOrWhiteSpace($AssetId)) {
    throw "AssetId must not be empty"
}

if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
    Install-WingetPackage -Id "Git.Git"
}

$pythonLauncher = Get-Command py.exe -ErrorAction SilentlyContinue
if ($pythonLauncher) {
    & $pythonLauncher.Source -3 -c `
        "import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)"
}
if (-not $pythonLauncher -or $LASTEXITCODE -ne 0) {
    Install-WingetPackage -Id "Python.Python.3.13"
    $pythonLauncher = Get-Command py.exe -ErrorAction SilentlyContinue
}
if (-not $pythonLauncher) {
    throw "Python launcher py.exe was not found after installing Python 3.13"
}

$git = (Get-Command git.exe -ErrorAction Stop).Source
$python = $pythonLauncher.Source

Invoke-Native -FilePath $python -ArgumentList @(
    "-3", "-c",
    "import sys; raise SystemExit(0 if sys.version_info >= (3, 11) else 1)"
)

foreach ($directory in @(
    $InstallDir,
    (Join-Path $InstallDir "config"),
    (Join-Path $InstallDir "state"),
    (Join-Path $InstallDir "logs"),
    (Join-Path $InstallDir "cache")
)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

if (Test-Path (Join-Path $repoDir ".git")) {
    Write-Host "Using existing repository at $repoDir"
    Invoke-Native -FilePath $git -ArgumentList @(
        "-C", $repoDir, "fetch", "origin", $Branch
    )

    & $git -C $repoDir show-ref --verify --quiet "refs/heads/$Branch"
    if ($LASTEXITCODE -eq 0) {
        Invoke-Native -FilePath $git -ArgumentList @(
            "-C", $repoDir, "checkout", $Branch
        )
    }
    else {
        Invoke-Native -FilePath $git -ArgumentList @(
            "-C", $repoDir, "checkout", "--track", "-b", $Branch,
            "origin/$Branch"
        )
    }

    Invoke-Native -FilePath $git -ArgumentList @(
        "-C", $repoDir, "merge", "--ff-only", "origin/$Branch"
    )
}
elseif (Test-Path $repoDir) {
    throw "$repoDir exists but is not a Git repository"
}
else {
    Invoke-Native -FilePath $git -ArgumentList @(
        "clone", "--branch", $Branch, "--single-branch", $RepoUrl, $repoDir
    )
}

Invoke-Native -FilePath $python -ArgumentList @(
    "-3", "-m", "venv", $venvDir
)
Invoke-Native -FilePath $venvPython -ArgumentList @(
    "-m", "pip", "install", "--upgrade", "pip", "setuptools"
)
Invoke-Native -FilePath $venvPython -ArgumentList @(
    "-m", "pip", "install", "--upgrade", $repoDir
)

Copy-Item -Path (Join-Path $repoDir "scripts\run-agent.ps1") `
    -Destination $runner -Force

$env:NIRJ_AGENT_INSTALL_DIR = $InstallDir
[Environment]::SetEnvironmentVariable(
    "NIRJ_AGENT_INSTALL_DIR",
    $InstallDir,
    "Machine"
)

if (-not (Test-Path $config)) {
    Invoke-Native -FilePath $agent -ArgumentList @(
        "setup", "--asset-id", $AssetId, "--device-type", $DeviceType
    )
}
else {
    Write-Host "Preserving existing $config"
}

$scriptsDir = Join-Path $venvDir "Scripts"
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$pathEntries = $machinePath -split ";" | Where-Object { $_ }
if ($scriptsDir -notin $pathEntries) {
    [Environment]::SetEnvironmentVariable(
        "Path",
        (($pathEntries + $scriptsDir) -join ";"),
        "Machine"
    )
    Update-ProcessPath
}

$powerShellPath = (Get-Process -Id $PID).Path
$taskArguments = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", ('"{0}"' -f $runner),
    "-InstallDir", ('"{0}"' -f $InstallDir),
    "-Branch", ('"{0}"' -f $Branch)
) -join " "

$action = New-ScheduledTaskAction `
    -Execute $powerShellPath `
    -Argument $taskArguments `
    -WorkingDirectory $repoDir
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet `
    -RestartCount 10 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -StartWhenAvailable

$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
}

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Force | Out-Null

Start-ScheduledTask -TaskName $taskName

Write-Host "nirj-agent installed and started"
Get-ScheduledTask -TaskName $taskName | Format-List `
    TaskName, State, TaskPath
