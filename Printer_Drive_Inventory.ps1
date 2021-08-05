# https://social.technet.microsoft.com/Forums/en-US/c08c393d-1ea4-4f6b-8f07-affc0f743193/network-printer-inventory-in-system-centre-configuration-manager-sccm-2012?forum=configmanagergeneral#c08c393d-1ea4-4f6b-8f07-affc0f743193
# http://blogs.technet.com/b/breben/archive/2013/08/26/inventory-mapped-drives-in-configmgr-2012.aspx

#pause for 30 seconds just to allow drives and printers to connect
#Start-Sleep -s 30

# run with PowerShell.exe -NonInteractive -WindowStyle Hidden -noprofile -ExecutionPolicy Bypass -file .\NetworkPrinterInventory.ps1

$printers = Get-WMIObject -class Win32_Printer -ErrorAction SilentlyContinue|select-Object -Property ServerName,ShareName,Location,DriverName,PrintProcessor,PortName,Local |Where-Object {$_.Local -ne $true}|Where-Object {$_.ServerName.length -gt 2} -ErrorAction SilentlyContinue
$user = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name).Replace('\','-')

#Remove previous entries
Get-ChildItem -Path HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS\ -Recurse -Include $user* -ErrorAction SilentlyContinue | Remove-Item

ForEach($printer in $printers){
    $PServerName= $printer.ServerName -replace ('\\','')
    $PShareName = $printer.ShareName
    $PLocation = $printer.Location
    $PDriverName = $printer.DriverName
    $PPrintProcessor = $printer.PrintProcessor
    $PPortName = $printer.PortName

    if ((Test-Path HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS)) {
      #  if ((Test-Path "HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS\$PShareName on $PServerName")) {
      #      Remove-item "HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS\$PShareName on $PServerName" -Force -ErrorAction SilentlyContinue
      #  }
        if ((Test-Path "HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS\$user $PShareName on $PServerName")) {
            Remove-item "HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS\$user $PShareName on $PServerName" -Force -ErrorAction SilentlyContinue
        }
        New-item "HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS\$user $PShareName on $PServerName" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS\$user $PShareName on $PServerName" -Name "UserDomain" -Value $user.Split('-')[0] -PropertyType "String" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS\$user $PShareName on $PServerName" -Name "UserName" -Value $user.Split('-')[1] -PropertyType "String" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS\$user $PShareName on $PServerName" -Name "PrintServer" -Value $PServerName -PropertyType "String" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS\$user $PShareName on $PServerName" -Name "PrinterQueue" -Value $PShareName -PropertyType "String" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS\$user $PShareName on $PServerName" -Name "PrinterLocation" -Value $PLocation -PropertyType "String" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS\$user $PShareName on $PServerName" -Name "PrinterDriver" -Value $PDriverName -PropertyType "String" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS\$user $PShareName on $PServerName" -Name "PrintProcessor" -Value $PPrintProcessor -PropertyType "String" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS\$user $PShareName on $PServerName" -Name "PrinterPortName" -Value $PPortName -PropertyType "String" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\NETWORKPRINTERS\$user $PShareName on $PServerName" -Name "DateInventoried" -Value $(get-date) -PropertyType "String" -ErrorAction SilentlyContinue
    }
}


#now inventory drives
$drives = Get-WMIObject -class Win32_MappedLogicalDisk -ErrorAction SilentlyContinue|select-Object -Property Caption,Name,FreeSpace,ProviderName,Size,SystemName,FileSystem |Where-Object {$_.Local -ne $true}|Where-Object {$_.ProviderName.length -gt 3} -ErrorAction SilentlyContinue

#Remove previous entries
Get-ChildItem -Path HKLM:\SOFTWARE\SCCMINVENTORY\MAPPEDDRIVES\ -Recurse -Include $user* -ErrorAction SilentlyContinue | Remove-Item

ForEach($drive in $drives){
    $DShareName = $drive.ProviderName -Replace ('\\','\')
    $DName = $drive.Name
    #convert to GB
    $DSize = $drive.Size/1000000000
    $DFreeSpace = $drive.FreeSpace/1000000000
    $DSystem = $drive.SystemName
    $DFileSystem = $drive.FileSystem

    if ((Test-Path HKLM:\SOFTWARE\SCCMINVENTORY\MAPPEDDRIVES)) {
        if ((Test-Path "HKLM:\SOFTWARE\SCCMINVENTORY\MAPPEDDRIVES\$user $DName")) {
            Remove-item "HKLM:\SOFTWARE\SCCMINVENTORY\MAPPEDDRIVES\$user $DName" -Force -ErrorAction SilentlyContinue
        }
        New-item "HKLM:\SOFTWARE\SCCMINVENTORY\MAPPEDDRIVES\$user $DName" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\MAPPEDDRIVES\$user $DName" -Name "UserDomain" -Value $user.Split('-')[0] -PropertyType "String" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\MAPPEDDRIVES\$user $DName" -Name "UserName" -Value $user.Split('-')[1] -PropertyType "String" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\MAPPEDDRIVES\$user $DName" -Name "ShareName" -Value $DShareName -PropertyType "String" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\MAPPEDDRIVES\$user $DName" -Name "DriveLetter" -Value $DName -PropertyType "String" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\MAPPEDDRIVES\$user $DName" -Name "Size" -Value $DSize -PropertyType "DWord" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\MAPPEDDRIVES\$user $DName" -Name "FreeSpace" -Value $DFreeSpace -PropertyType "DWord" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\MAPPEDDRIVES\$user $DName" -Name "System" -Value $DSystem -PropertyType "String" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\MAPPEDDRIVES\$user $DName" -Name "FileSystem" -Value $DFileSystem -PropertyType "String" -ErrorAction SilentlyContinue
        New-ItemProperty "HKLM:\SOFTWARE\SCCMINVENTORY\MAPPEDDRIVES\$user $DName" -Name "DateInventoried" -Value $(get-date) -PropertyType "String" -ErrorAction SilentlyContinue
    }
}
