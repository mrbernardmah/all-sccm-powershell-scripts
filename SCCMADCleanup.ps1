$SiteCode = "001"
$SiteServer = "AUWGSCCM-01.services.local"
$EmailRecipient = "bernard.mah@navitas.com"
$EmailSender = "services.smtp@navitas.com"
$SMTPServer = "smtp.office365.com"
 
#region Functions
 
# Function to check with the computer account is disabled
function Get-IsComputerAccountDisabled
{
  param($Computername)
 
  $root = [ADSI]''
  $searcher = New-Object -TypeName System.DirectoryServices.DirectorySearcher -ArgumentList ($root)
  $searcher.filter = "(&(objectClass=Computer)(Name=$Computername))"
  $Result = $searcher.findall()
  If ($Result.Count -ne 0)
  {
    $Result | ForEach-Object {
        $Computer = $_.GetDirectoryEntry()
        [pscustomobject]@{
            ComputerName = $Computername
            IsDisabled = $Computer.PsBase.InvokeGet("AccountDisabled")
        }
    }
  }
  Else
  {
      [pscustomobject]@{
      ComputerName = $Computername
      IsDisabled = "Not found in AD"
      }
  }
}
 
# Function to remove the device record from SCCM via WMI
function Remove-CMRecord
{
    [CmdletBinding()]
 
    Param
    (
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName = $True)] [string] $Computername,
        [Parameter(Mandatory = $True)] [string] $SiteCode,
        [Parameter(Mandatory = $True)] [string] $SiteServer,
        [Parameter(Mandatory = $True)] [string] $DeviceStatus
 
    )
 
    Begin
    {
        $ErrorAction = 'Stop'
    }
 
    Process
    {
 
        # Check if the system exists in SCCM
        Try
        {
            $Computer = [wmi] (Get-WmiObject -ComputerName $SiteServer -Namespace "root\sms\site_$SiteCode" -Class sms_r_system -Filter "Name = `'$Computername`'" -ErrorAction Stop).__PATH
        }
        Catch
        {
            $Result = $_
            Continue
        }
 
        # Delete it
        Try
        {
            $Computer.psbase.delete()
        }
        Catch
        {
            $Result = $_
            Continue
        }
 
        # Check that the delete worked
        Try
        {
            $Computer = [wmi] (Get-WmiObject -ComputerName $SiteServer -Namespace "root\sms\site_$SiteCode" -Class sms_r_system -Filter "Name = `'$Computername`'" -ErrorAction Stop).__PATH
        }
        Catch
        {
 
        }
 
        # Report result
        If ($Computer.PSComputerName)
        {
            $Result = "Tried to delete but record still exists"
        }
        Else
        {
            $Result = "Successfully deleted"
        }
    }
 
    End
    {
        [pscustomobject]@{
        DeviceName = $Computername
        IsDisabled = $DeviceStatus
        Result = $Result
        }
    }
}
 
#endregion
 
# Let's get the list of inactive systems, or systems with no SCCM client, from WMI
try
{
    $DevicesToCheck = Get-WmiObject -ComputerName $SiteServer -Namespace root\SMS\Site_$SiteCode -Query "SELECT SMS_R_System.Name FROM SMS_R_System left join SMS_G_System_CH_ClientSummary on SMS_G_System_CH_ClientSummary.ResourceID = SMS_R_System.ResourceID where (SMS_G_System_CH_ClientSummary.ClientActiveStatus = 0 or SMS_R_System.Active = 0 or SMS_R_System.Active is null)" -ErrorAction Stop |
        Select -ExpandProperty Name |
        Sort
}
Catch
{
    $_
}
 
# Now let's filter those systems whose AD account is disabled or not present
$NotEnabledDevices = ($DevicesToCheck | foreach {
    Get-IsComputerAccountDisabled  -Computername $_
}) | where {$_.IsDisabled -ne $False}
 
# Then we will delete each record from SCCM using WMI
$DeletedRecords = New-Object System.Collections.ArrayList
$Output = $NotEnabledDevices| foreach {
    Remove-CMRecord -Computername $_.ComputerName -DeviceStatus $_.IsDisabled -SiteCode $SiteCode -SiteServer $SiteServer
    }
$DeletedRecords.AddRange(@($Output))
 
# Finally we will send the list of affected systems to the administrator
$style = @"
<style>
body {
    color:#333333;
    font-family: ""Trebuchet MS"", Arial, Helvetica, sans-serif;}
}
h1 {
    text-align:center;
}
table {
    border-collapse: collapse;
    font-family: ""Trebuchet MS"", Arial, Helvetica, sans-serif;
}
th {
    font-size: 10pt;
    text-align: left;
    padding-top: 5px;
    padding-bottom: 4px;
    background-color: #1FE093;
    color: #ffffff;
}
td {
    font-size: 8pt;
    border: 1px solid #1FE093;
    padding: 3px 7px 2px 7px;
}
</style>
 
"@
If ($DeletedRecords.Count -ne 0)
{
    $Body = $DeletedRecords | ConvertTo-Html -Head $style -Body "
<h2>The following systems are either disabled or not present in active directory and have been deleted from SCCM</h2>
" | Out-String
    Send-MailMessage -To $EmailRecipient -From $EmailSender  -Subject "Disabled Computer Accounts Deleted from SCCM ($(Get-Date -format 'yyyy-MMM-dd'))" -SmtpServer $SMTPServer -Body $body -BodyAsHtml
}