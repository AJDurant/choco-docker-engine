
$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
. "$toolsDir\helper.ps1"
Test-DockerdConflict

If (Test-OurDockerd)
{
  Write-output "Unregistering docker service..."
  Start-ChocolateyProcessAsAdmin -Statements "delete docker" "C:\Windows\System32\sc.exe"
}

Uninstall-BinFile -Name "docker"
Uninstall-ChocolateyZipPackage $env:ChocolateyPackageName "docker-$($env:ChocolateyPackageVersion).zip"
