
$ErrorActionPreference = 'Stop'; # stop on all errors
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. "$toolsDir\helper.ps1"
Test-DockerdConflict

$url = "https://download.docker.com/win/static/stable/x86_64/docker-$($env:ChocolateyPackageVersion).zip" # download url, HTTPS preferred

$dockerdPath = Join-Path $toolsDir "docker\dockerd.exe"
$dockerGroup = "docker-users"
$groupUser = $env:USER_NAME

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = $toolsDir
  url           = $url

  # You can also use checksum.exe (choco install checksum) and use it
  # e.g. checksum -t sha256 -f path\to\file
  checksum      = 'BD3775ADA72492AA1F3C2EDB3E81663BD128B9D4F6752EF75953A6AF7C219C81'
  checksumType  = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs # https://chocolatey.org/docs/helpers-install-chocolatey-zip-package

# Set up user group for non admin usage
If (net localgroup | Select-String $dockerGroup -Quiet) {
  Write-Host "$dockerGroup group already exists"
} Else {
  net localgroup $dockerGroup /add /comment:"Users of Docker"
}
If (net localgroup $dockerGroup | Select-String $groupUser -Quiet) {
  Write-Host "$groupUser already in $dockerGroup group"
} Else {
  Write-Host "Adding $groupUser to $dockerGroup group, you will need to log out and in to take effect"
  net localgroup $dockerGroup $groupUser /add
}

# Write config
$daemonConfig = @{"group"=$dockerGroup}
$daemonFolder = "C:\ProgramData\docker\config\"
$daemonFile = Join-Path $daemonFolder "daemon.json"
If (Test-Path $daemonFile) {
  Write-Host "Config file '$daemonFile' already exists, not overwriting"
} Else {
  If (-not (Test-Path daemonFolder)) {
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
