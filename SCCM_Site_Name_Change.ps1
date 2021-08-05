###################################################################################################
# Project: Change Site Name
# Date: 20-05-2013
# By: Peter van der Woude
# Version: 1.0 Public
###################################################################################################

[CmdletBinding()]

param (
[string]$SiteCode,
[string]$SiteServer,
[string]$SiteName
)

function Change-SiteName {
    $Site = Get-WmiObject -Class SMS_SCI_SiteDefinition -Namespace root/SMS/site_$($SiteCode) -ComputerName $SiteServer | Where-Object -FilterScript {$_.SiteCode -eq $SiteCode}
    $Site.SiteName = $SiteName
    $Site.Put()
}

Change-SiteNam