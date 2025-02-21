
$ErrorActionPreference = 'Stop'; # stop on all errors
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. "$toolsDir\helper.ps1"
Test-DockerdConflict

$url = "https://download.docker.com/win/static/stable/x86_64/docker-28.0.0.zip" # download url, HTTPS preferred

$pp = Get-PackageParameters

If ( !$pp.DockerGroup ) {
    $pp.DockerGroup = "docker-users"
}

$dockerdPath = Join-Path $env:ProgramFiles "docker\dockerd.exe"
$groupUser = $env:USER_NAME

$packageArgs = @{
    PackageName   = $env:ChocolateyPackageName
    UnzipLocation = $env:ProgramFiles
    Url           = $url

    # You can also use checksum.exe (choco install checksum) and use it
    # e.g. checksum -t sha256 -f path\to\file
    Checksum      = 'FF38CDF943AF967A288FA594D8091B054BE8E622164FFB0CDE4F681DCA4733C4'
    ChecksumType  = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs # https://chocolatey.org/docs/helpers-install-chocolatey-zip-package

Install-BinFile -Name "docker" -Path "$env:ProgramFiles\docker\docker.exe"

# Set up user group for non admin usage
If (net localgroup | Select-String $($pp.DockerGroup) -Quiet) {
    Write-Host "$($pp.DockerGroup) group already exists"
}
Else {
    net localgroup $($pp.DockerGroup) /add /comment:"Users of Docker"
}
If ( !$pp.noAddGroupUser ) {
    If (net localgroup $($pp.DockerGroup) | Select-String $groupUser -Quiet) {
        Write-Host "$groupUser already in $($pp.DockerGroup) group"
    }
    Else {
        Write-Host "Adding $groupUser to $($pp.DockerGroup) group, you will need to log out and in to take effect"
        net localgroup $($pp.DockerGroup) $groupUser /add
    }
}

# Write config
$daemonConfig = @{"group" = $($pp.DockerGroup) }
$daemonFolder = "$env:ProgramData\docker\config\"
$daemonFile = Join-Path $daemonFolder "daemon.json"
If (Test-Path $daemonFile) {
    Write-Host "Config file '$daemonFile' already exists, not overwriting"
}
Else {
    If (-not (Test-Path $daemonFolder)) {
        New-Item -ItemType Directory -Path $daemonFolder
    }
    $jsonContent = $daemonConfig | ConvertTo-Json -Depth 10
    $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [IO.File]::WriteAllLines($daemonFile, $jsonContent, $Utf8NoBomEncoding)
}

# From v23 the package is now installed in Program Files. So clean up old files/service from tools
If (Test-Path "$toolsDir\docker") {
    Write-output "Cleaning up old docker files..."
    Remove-Item "$toolsDir\docker" -Recurse -Force
}
If (Test-OurOldDockerd) {
    Write-output "Unregistering old docker service..."
    Start-ChocolateyProcessAsAdmin -Statements "delete docker" "C:\Windows\System32\sc.exe"
}

# Install service if not already there, conflict check at start also means no others.
If (-not (Test-OurDockerd)) {
    $scArgs = "create docker binpath= `"$dockerdPath --run-service`" start= auto displayname= `"$($env:ChocolateyPackageTitle)`""
    Start-ChocolateyProcessAsAdmin -Statements "$scArgs" "C:\Windows\System32\sc.exe"
}

If (!$pp.StartService) {
    Write-Host "$($env:ChocolateyPackageTitle) service created, start with: `sc start docker` "
}
Else {
    Write-output "Starting docker service..."
    Start-ChocolateyProcessAsAdmin -Statements "start docker" "C:\Windows\System32\sc.exe"
}
