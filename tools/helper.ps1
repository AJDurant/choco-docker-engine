
$EditionId = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'EditionID').EditionId
$RunningOnNano = $False
If ($EditionId -ilike '*Nano*') {
    $RunningOnNano = $True
}

Function Test-ServicePath ($ServiceEXE, $FolderToCheck) {
    if ($RunningOnNano) {
        #The NANO TP5 Compatible Way:
        Return ([bool](@(wmic service | Where-Object { $_ -ilike "*$ServiceEXE*" }) -ilike "*$FolderToCheck*"))
    }
    Else {
        #The modern way:
        Return ([bool]((Get-WmiObject win32_service | Where-Object { $_.PathName -ilike "*$ServiceEXE*" } | Select-Object -expand PathName) -ilike "*$FolderToCheck*"))
    }
}

Function Test-OurDockerd {
    return (Test-ServicePath 'dockerd.exe' "$env:ProgramFiles") -Or (Test-ServicePath 'dockerd.exe' "$toolsDir")
}

Function Test-OurOldDockerd {
    return Test-ServicePath 'dockerd.exe' "$toolsDir"
}

Function Test-DockerdConflict {
    If (-not (Test-OurDockerd) -AND (sc.exe query docker | Select-String 'SERVICE_NAME: docker' -SimpleMatch -Quiet)) {
        $ExistingDockerInstancePath = Get-ItemProperty hklm:\system\currentcontrolset\services\* | Where-Object { ($_.ImagePath -ilike '*dockerd.exe*') } | Select-Object -expand ImagePath
        Throw "You have requested that the docker service be installed, but this system appears to have an instance of an docker service configured for another folder ($ExistingDockerInstancePath). You will need to remove that instance of Docker to use the one that comes with this package."
    }
}

Function Test-DockerdRunning {
    return [bool](C:\Windows\System32\sc.exe query docker | Select-String 'RUNNING' -SimpleMatch -Quiet)
}

Function Test-DockerdStopped {
    return [bool](C:\Windows\System32\sc.exe query docker | Select-String 'STOPPED' -SimpleMatch -Quiet)
}
