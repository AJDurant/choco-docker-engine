
$ErrorActionPreference = 'Stop'; # stop on all errors
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"

$url        = 'https://download.docker.com/win/static/stable/x86_64/docker-20.10.8.zip' # download url, HTTPS preferred

$dockerdPath = Join-Path $toolsDir "docker\dockerd.exe"
$dockerGroup = "docker-users"

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = $toolsDir
  url           = $url

  # You can also use checksum.exe (choco install checksum) and use it
  # e.g. checksum -t sha256 -f path\to\file
  checksum      = 'D77503AE5D7BB2944019C4D521FAC4FDF6FC6E970865D93BE05007F2363C8144'
  checksumType  = 'sha256'

}

Function CheckServicePath ($ServiceEXE,$FolderToCheck)
{
  if ($RunningOnNano) {
    #The NANO TP5 Compatible Way:
    Return ([bool](@(wmic service | Where-Object {$_ -ilike "*$ServiceEXE*"}) -ilike "*$FolderToCheck*"))
  }
  Else
  {
    #The modern way:
    Return ([bool]((Get-WmiObject win32_service | Where-Object {$_.PathName -ilike "*$ServiceEXE*"} | Select-Object -expand PathName) -ilike "*$FolderToCheck*"))
  }
}

$DockerServiceInstanceExistsAndIsOurs = CheckServicePath 'dockerd.exe' "$toolsDir"

If ((!$DockerServiceInstanceExistsAndIsOurs) -AND (sc query docker | Select-String 'SERVICE_NAME: docker' -Quiet))
{
  $ExistingDockerInstancePath = Get-ItemProperty hklm:\system\currentcontrolset\services\* | Where-Object {($_.ImagePath -ilike '*dockerd.exe*')} | Select-Object -expand ImagePath
  Throw "You have requested that the docker service be installed, but this system appears to have an instance of an docker service configured for another folder ($ExistingDockerInstancePath). You will need to remove that instance of Docker to use the one that comes with this package."
}

Install-ChocolateyZipPackage @packageArgs # https://chocolatey.org/docs/helpers-install-chocolatey-zip-package

# Set up user group for non admin usage
If (net localgroup | Select-String $dockerGroup -Quiet) {
  Write-Host "$dockerGroup group already exists"
} Else {
  net localgroup $dockerGroup /add /comment:"Users of Docker"
}
$groupUser = $env:USER_NAME
If (net localgroup $dockerGroup | Select-String $groupUser -Quiet) {
  Write-Host "$groupUser already in $dockerGroup group"
} Else {
  Write-Host "Adding $groupUser to $dockerGroup group"
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

# Install service
Start-ChocolateyProcessAsAdmin -Statements 'create docker binpath= "C:\ProgramData\chocolatey\lib\docker-engine\tools\docker\dockerd.exe --run-service" start= auto displayname= "Docker Engine"' "sc.exe"
Write-Host "Docker Engine service created, start with: `sc start docker` "
