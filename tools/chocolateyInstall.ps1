﻿
$ErrorActionPreference = 'Stop'; # stop on all errors
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. "$toolsDir\helper.ps1"
Test-DockerdConflict

$url = "https://download.docker.com/win/static/stable/x86_64/docker-$($env:ChocolateyPackageVersion).zip" # download url, HTTPS preferred

$pp = Get-PackageParameters

If ( !$pp.DockerGroup ) {
    $pp.DockerGroup = "docker-users"
}

$dockerdPath = Join-Path $toolsDir "docker\dockerd.exe"
$groupUser = $env:USER_NAME

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = "$env:ProgramFiles\docker"
  url           = $url

  # You can also use checksum.exe (choco install checksum) and use it
  # e.g. checksum -t sha256 -f path\to\file
  checksum      = 'A287DB87CE6CA557CB6FECC0C0761B8CDA7A1DF9612AC2C2BF4635BCF4C8DA7B'
  checksumType  = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs # https://chocolatey.org/docs/helpers-install-chocolatey-zip-package

# Set up user group for non admin usage
If (net localgroup | Select-String $($pp.DockerGroup) -Quiet) {
  Write-Host "$($pp.DockerGroup) group already exists"
} Else {
  net localgroup $($pp.DockerGroup) /add /comment:"Users of Docker"
}
If ( !$pp.noAddGroupUser ) {
  If (net localgroup $($pp.DockerGroup) | Select-String $groupUser -Quiet) {
  Write-Host "$groupUser already in $($pp.DockerGroup) group"
  } Else {
  Write-Host "Adding $groupUser to $($pp.DockerGroup) group, you will need to log out and in to take effect"
  net localgroup $($pp.DockerGroup) $groupUser /add
  }
}

# Write config
$daemonConfig = @{"group"=$($pp.DockerGroup)}
$daemonFolder = "C:\ProgramData\docker\config\"
$daemonFile = Join-Path $daemonFolder "daemon.json"
If (Test-Path $daemonFile) {
  Write-Host "Config file '$daemonFile' already exists, not overwriting"
} Else {
  If (-not (Test-Path $daemonFolder)) {
    New-Item -ItemType Directory -Path $daemonFolder
  }
  $jsonContent = $daemonConfig | ConvertTo-Json -Depth 10
  $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
  [IO.File]::WriteAllLines($daemonFile, $jsonContent, $Utf8NoBomEncoding)
}

# Install service if not already there, conflict check at start also means no others.
If (-not (Test-OurDockerd)) {
  $scArgs = "create docker binpath= `"$dockerdPath --run-service`" start= auto displayname= `"$($env:ChocolateyPackageTitle)`""
  Start-ChocolateyProcessAsAdmin -Statements "$scArgs" "C:\Windows\System32\sc.exe"
  Write-Host "$($env:ChocolateyPackageTitle) service created, start with: `sc start docker` "
}
