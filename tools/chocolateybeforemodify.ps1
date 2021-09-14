# This runs in 0.9.10+ before upgrade and uninstall.
# Use this file to do things like stop services prior to upgrade or uninstall.
# NOTE: It is an anti-pattern to call chocolateyUninstall.ps1 from here. If you
#  need to uninstall an MSI prior to upgrade, put the functionality in this
#  file without calling the uninstall script. Make it idempotent in the
#  uninstall script so that it doesn't fail when it is already uninstalled.
# NOTE: For upgrades - like the uninstall script, this script always runs from
#  the currently installed version, not from the new upgraded package version.

$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
# Helper will exit if there is already a dockerd service that is not ours
. "$toolsDir\helper.ps1"

If ($DockerServiceInstanceExistsAndIsOurs -AND (sc.exe query docker | Select-String 'RUNNING' -Quiet))
{
  #Shutdown and unregister service for upgrade
  Write-output "Stopping docker service..."
  Start-ChocolateyProcessAsAdmin -Statements "stop docker" "C:\Windows\System32\sc.exe"
  Start-Sleep -seconds 3
  If (-not (sc.exe query docker | Select-String 'STOPPED' -Quiet))
  {
    Throw "Could not stop the docker service, please stop manually and retry this package."
  }
}

If ($DockerServiceInstanceExistsAndIsOurs)
{
  Write-output "Unregistering docker service..."
  Start-ChocolateyProcessAsAdmin -Statements "delete docker" "C:\Windows\System32\sc.exe"
}
