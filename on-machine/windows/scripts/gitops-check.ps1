# gitops-check.ps1
Start-Sleep -Seconds 10

$repoName = "NIRaspberryJam/nirj-infra"
$branch = "main"
$remoteVersionUrl = "https://raw.githubusercontent.com/NIRaspberryJam/nirj-infra/refs/heads/main/windows/version.txt"
$localPath = "C:\JamGitOps"
$localVersionPath = "$localPath\version.txt"
$zipPath = "$env:TEMP\repo.zip"
$extractPath = "$env:TEMP\repo-extract"

# Ensure local GitOps folder exists
try {
    $null = Get-Item -Path $localPath -ErrorAction Stop
    Write-Host "Folder exists: $localPath"
} catch {
    Write-Host "Folder does not exist or is corrupted. Recreating..."
    New-Item -ItemType Directory -Path $localPath -Force | Out-Null
}


# Get remote version
try {
    $remoteVersion = Invoke-RestMethod $remoteVersionUrl
} catch {
    Write-Host "Could not retrieve remote version"
    exit 1
}

if (-not (Test-Path $localVersionPath)) {
    Write-Host "Local version file not found. Assuming update is needed."
    $localVersion = ""
} else {
    $localVersion = Get-Content $localVersionPath -Raw
}

Write-Host "Remote Version = $remoteVersion"
Write-Host "Local Version = $localVersion"

# Compare with local version
if (-not (Test-Path $localVersionPath) -or (Get-Content $localVersionPath -Raw).Trim() -ne $remoteVersion.Trim()) {
    Write-Host "Update detected. Downloading repo ZIP..."

    # Download repo as ZIP
    $repoZipUrl = "https://github.com/$repoName/archive/refs/heads/$branch.zip"
    Invoke-WebRequest $repoZipUrl -OutFile $zipPath

    # Extract
    Expand-Archive $zipPath -DestinationPath $extractPath -Force

    # Repo content will be in: $extractPath\$repoName-$branch\windows\
    $sourcePath = Join-Path $extractPath "$($repoName.Split('/')[1])-$branch\windows"

    # Replace local GitOps folder
    Remove-Item $localPath -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $localPath -Force | Out-Null

    Get-ChildItem -Path $sourcePath -Recurse | ForEach-Object {
        $target = Join-Path $localPath ($_.FullName.Substring($sourcePath.Length + 1))
        if ($_.PSIsContainer) {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
        } else {
            Copy-Item -Path $_.FullName -Destination $target -Force
        }
    }

    # Run main.ps1
    & "$localPath\main.ps1"

    # Clean up
    Remove-Item $zipPath -Force
    Remove-Item $extractPath -Recurse -Force
} else {
    Write-Host "No update needed. Local version is up to date."
}