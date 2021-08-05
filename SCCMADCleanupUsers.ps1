# Specify your Site Code
$SiteCode = "001" 

# Specify your Site Server
$ProviderMachineName = "AUWGSCCM-01.services.local" 

# Change this to $true, if the Script should invoke the removal of any orphaned users.
# You will be prompted to confirm the deletion of every device!
# If you know what you're doing, you can add the "-Force" Parameter to the "Remove-CMUser" Command below.
$deleteOrphanedUsers = $false

#########################################################################

# Check for ConfigMgr PoSh Module
If (!(Test-Path "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1")) {
    throw "Configuration Manager PowerShell Module not found"
    Exit
}

# Check for AD PoSh Module
If (!(Get-Module -ListAvailable | Where-Object {$_.Name -eq "ActiveDirectory"})) {
    throw "Active Directory PowerShell Module not found"
}

# Import the ConfigurationManager.psd1 module 
If (!(Get-Module ConfigurationManager)) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
}

# Import the ActiveDirectory module
If (!(Get-Module ActiveDirectory)) {
    Import-Module ActiveDirectory
}

# Set the current location to be the site code.
Set-Location "$($SiteCode):\"

# Get all Users from ConfigManager
$cmUsers = Get-CMUser | Select-Object SMSID

$counter = 100 / $cmUsers.Count
$i = 0
$orphanedUserCounter = 0
foreach ($cmUser in $cmUsers) {
   Write-Progress -Activity "Processing Users" -CurrentOperation $cmUser.SMSID -PercentComplete $i

    # Remove leading Domain name including back slash "Domain\"
    $userSam = $cmUser.SMSID.Split("\")[1]
    
    # Try to find user in Actice Directory
    Try {
        $ErrorActionPreference = "Stop"
        Get-ADUser -Identity $userSam | Out-Null
    }
    Catch {
        Write-Warning "User '$($cmUser.SMSID)' not found in Active Directory"

        # Remove user from ConfigMgr if options is enabled
        If ($deleteOrphanedUsers -eq $true) {
            # Remove device from ConfigMgr
            Remove-CMUser -Name $cmUser.SMSID
            
            # Verify removal
            If (!(Get-CMUser -Name $cmUser.SMSID)) {
                Write-Host "User '$($cmUser.SMSID)' deleted from Configuration Manager" -ForegroundColor Green
            }
            Else {
                Write-Host "User '$($cmUser.SMSID)' still exists in Configuration Manager" -ForegroundColor Red
            }
        }

        $orphanedUserCounter++
    }

    $i = $i + $counter
}

Write-Output "$orphanedUserCounter/$($cmUsers.Count) Users were discovered as orphaned."