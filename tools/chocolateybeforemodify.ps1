﻿# This runs in 0.9.10+ before upgrade and uninstall.
# Use this file to do things like stop services prior to upgrade or uninstall.
# NOTE: It is an anti-pattern to call chocolateyUninstall.ps1 from here. If you
#  need to uninstall an MSI prior to upgrade, put the functionality in this
#  file without calling the uninstall script. Make it idempotent in the
#  uninstall script so that it doesn't fail when it is already uninstalled.
# NOTE: For upgrades - like the uninstall script, this script always runs from
#  the currently installed version, not from the new upgraded package version.

$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$dockerdPath = Join-Path $toolsDir "docker\dockerd.exe"
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
  $ExistingDockerInstancePath = get-itemproperty hklm:\system\currentcontrolset\services\* | Where-Object {($_.ImagePath -ilike '*dockerd.exe*')} | Select-Object -expand ImagePath
  Throw "You have requested that the docker service be installed, but this system appears to have an instance of an docker service configured for another folder ($ExistingDockerInstancePath). You will need to remove that instance of Docker to use the one that comes with this package."
}

If ($DockerServiceInstanceExistsAndIsOurs -AND (sc query docker | Select-String 'RUNNING' -Quiet))
{
    #Shutdown and unregister service for upgrade
    Write-output "Stopping docker service..."
    Start-ChocolateyProcessAsAdmin -Statements "stop docker" "sc.exe"
    Start-Sleep -seconds 3
    If (-not (sc query docker | Select-String 'STOPPED' -Quiet))
    {
      Throw "Could not stop the docker service, please stop manually and retry this package."
    }

}

If ($DockerServiceInstanceExistsAndIsOurs)
{
  Write-output "Unregistering docker service..."
  Start-ChocolateyProcessAsAdmin -Statements "delete docker" "sc.exe"
}
