<#
The purpose of this program is to run a series of health checks on a server.
This Health Check queries the following and outputs to a formatted HTML file in C:\HealthCheck\"Server Name":
    System Information - Name, OS, Build Number, Major Service Pack Level, and Last Boot Time
    Disk Information - ID, Volumn Name, Size in Gb, Free Space in Gb, and % Free
    Application Log Information - Warnings & Errors in the Application Log since last boot
    System Log Information - Warnings & Errors in the System Log since last boot
    Services Information - Sorted by Start Up Type and running or not.  Displays Display Name, Name, StartMode, State
    HotFix information - Hotfixes installed since last boot.  Displays HotFix ID, Caption (Web site), and Installed on.
        Date works but not time.
#>
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Variable Declarations >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>#
###############################HTml Report Content############################
$Style = "
<style>
    BODY{background-color:#b0c4de;}
    TABLE{border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
    TH{border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color:#778899}
    TD{border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
    tr:nth-child(odd) { background-color:#d3d3d3;} 
    tr:nth-child(even) { background-color:white;} 
</style>
"
$StatusColor = @{Stopped = ' bgcolor="Red">Stopped<';Running = ' bgcolor="Green">Running<';}
$EventColor = @{Error = ' bgcolor="Red">Error<';Warning = ' bgcolor="Yellow">Warning<';}
# Path = C:\psscripts
$ReportHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H1>System Health Check</H1>' |Out-String 
$UserHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Current Logged On User</H2>'|Out-String 
$OSHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>System Information</H2>'|Out-String  
$DiskHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Disk Information</H2>'|Out-String 
$AppLogHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Application Log Information</H2>'|Out-String
$SysLogHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>System Log Information</H2>'|Out-String
$ServHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Services Information</H2>'|Out-String
$HotFixHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Hotfix Information</H2>'|Out-String
$InstalledAppsHead = ConvertTo-HTML -AS Table -Fragment -PreContent '<H2>Installed Programs Information</H2>'|Out-String

$TimestampAtBoot = Get-CimInstance Win32_PerfRawData_PerfOS_System |
     Select-Object -ExpandProperty systemuptime
$CurrentTimestamp = Get-CimInstance Win32_PerfRawData_PerfOS_System |
     Select-Object -ExpandProperty Timestamp_Object
$Frequency = Get-CimInstance Win32_PerfRawData_PerfOS_System |
     Select-Object -ExpandProperty Frequency_Object
$UptimeInSec = ($CurrentTimestamp - $TimestampAtBoot)/$Frequency
$Time = (Get-Date) - (New-TimeSpan -seconds $UptimeInSec) 
$CurrentDate = Get-Date
$CurrentDate = $CurrentDate.ToString('MM-dd-yyyy')
$Date = (Get-Date) - (New-TimeSpan -Day 1)
$CurrentUser = (Get-WmiObject -Class Win32_Process -Filter 'Name="explorer.exe"').GetOwner().User

Function Get-RemoteProgram {
<#
.Synopsis
Generates a list of installed programs on a computer

.DESCRIPTION
This function generates a list by querying the registry and returning the installed programs of a local or remote computer.

.PARAMETER ComputerName
The computer to which connectivity will be checked

.PARAMETER Property
Additional values to be loaded from the registry. Can contain a string or an array of string that will be attempted to retrieve from the registry for each program entry

.PARAMETER ExcludeSimilar
This will filter out similar programnames, the default value is to filter on the first 3 words in a program name. If a program only consists of less words it is excluded and it will not be filtered. For example if you Visual Studio 2015 installed it will list all the components individually, using -ExcludeSimilar will only display the first entry.

.PARAMETER SimilarWord
This parameter only works when ExcludeSimilar is specified, it changes the default of first 3 words to any desired value.

.EXAMPLE
Get-RemoteProgram

Description:
Will generate a list of installed programs on local machine

.EXAMPLE
Get-RemoteProgram -ComputerName server01,server02

Description:
Will generate a list of installed programs on server01 and server02

.EXAMPLE
Get-RemoteProgram -ComputerName Server01 -Property DisplayVersion,VersionMajor

Description:
Will gather the list of programs from Server01 and attempts to retrieve the displayversion and versionmajor subkeys from the registry for each installed program

.EXAMPLE
'server01','server02' | Get-RemoteProgram -Property Uninstallstring

Description
Will retrieve the installed programs on server01/02 that are passed on to the function through the pipeline and also retrieves the uninstall string for each program

.EXAMPLE
'server01','server02' | Get-RemoteProgram -Property Uninstallstring -ExcludeSimilar -SimilarWord 4

Description
Will retrieve the installed programs on server01/02 that are passed on to the function through the pipeline and also retrieves the uninstall string for each program. Will only display a single entry of a program of which the first four words are identical.
#>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(ValueFromPipeline              =$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0
        )]
        [string[]]
            $ComputerName = $env:COMPUTERNAME,
        [Parameter(Position=0)]
        [string[]]
            $Property,
        [switch]
            $ExcludeSimilar,
        [int]
            $SimilarWord
    )

    begin {
        $RegistryLocation = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\',
                            'SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\'
        $HashProperty = @{}
        $SelectProperty = @('ProgramName','ComputerName')
        if ($Property) {
            $SelectProperty += $Property
        }
    }

    process {
        foreach ($Computer in $ComputerName) {
            $RegBase = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$Computer)
            $RegistryLocation | ForEach-Object {
                $CurrentReg = $_
                if ($RegBase) {
                    $CurrentRegKey = $RegBase.OpenSubKey($CurrentReg)
                    if ($CurrentRegKey) {
                        $CurrentRegKey.GetSubKeyNames() | ForEach-Object {
                            if ($Property) {
                                foreach ($CurrentProperty in $Property) {
                                    $HashProperty.$CurrentProperty = ($RegBase.OpenSubKey("$CurrentReg$_")).GetValue($CurrentProperty)
                                }
                            }
                            $HashProperty.ComputerName = $Computer
                            $HashProperty.ProgramName = ($DisplayName = ($RegBase.OpenSubKey("$CurrentReg$_")).GetValue('DisplayName'))
                            if ($DisplayName) {
                                New-Object -TypeName PSCustomObject -Property $HashProperty |
                                Select-Object -Property $SelectProperty
                            } 
                        }
                    }
                }
            } | ForEach-Object -Begin {
                if ($SimilarWord) {
                    $Regex = [regex]"(^(.+?\s){$SimilarWord}).*$|(.*)"
                } else {
                    $Regex = [regex]"(^(.+?\s){3}).*$|(.*)"
                }
                [System.Collections.ArrayList]$Array = @()
            } -Process {
                if ($ExcludeSimilar) {
                    $null = $Array.Add($_)
                } else {
                    $_
                }
            } -End {
                if ($ExcludeSimilar) {
                    $Array | Select-Object -Property *,@{
                        name       = 'GroupedName'
                        expression = {
                            ($_.ProgramName -split $Regex)[1]
                        }
                    } |
                    Group-Object -Property 'GroupedName' | ForEach-Object {
                        $_.Group[0] | Select-Object -Property * -ExcludeProperty GroupedName
                    }
                }
            }
        }
    }
}
#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Input >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>#
$computer = $env:COMPUTERNAME

#<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< Directory Creation for Health Checks >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>#
# New-Item -path C:\HealthCheck\$computer -type Directory -ErrorAction Ignore

#Retrieves current Disk Space Status
$Freespace = 
@{
  Expression = {[int]($_.Freespace/1GB)}
  Name = 'Free Space (GB)'
}
$Size = 
@{
  Expression = {[int]($_.Size/1GB)}
  Name = 'Size (GB)'
}
$PercentFree = 
@{
  Expression = {[int]($_.Freespace*100/$_.Size)}
  Name = 'Free (%)'
}

# Gathers information for System Name, Operating System, Microsoft Build Number, Major Service Pack Installed, and the last time the system was booted
$OS = Get-CimInstance -class Win32_OperatingSystem |  Select-Object -property CSName,Caption,BuildNumber,ServicePackMajorVersion,@{n='LastBootUpTime';e={get-date $_.LastBootUpTime -f "dd MM yyyy HH:mm:ss" }} | ConvertTo-HTML -Fragment

# Gathers information for Device ID, Volume Name, Size in Gb, Free Space in Gb, and Percent of Frree Space on each storage device that the system sees
$Disk = Get-CimInstance -Class Win32_LogicalDisk | Select-Object -Property DeviceID, VolumeName, $Size, $Freespace, $PercentFree | ConvertTo-HTML -Fragment

# Gathers Warning and Errors out of the Application event log.  Displays Event ID, Event Type, Source of event, Time the event was generated, and the message of the event.
$AppEvent = Get-EventLog -LogName Application -EntryType "Error","Warning"-after $Time | Select-Object -property EventID, EntryType, Source, TimeGenerated, Message | ConvertTo-HTML -Fragment

# Gathers Warning and Errors out of the System event log.  Displays Event ID, Event Type, Source of event, Time the event was generated, and the message of the event.
$SysEvent = Get-EventLog -LogName System -EntryType "Error","Warning" -After $Time | Select-Object -property EventID, EntryType, Source, TimeGenerated, Message |  ConvertTo-HTML -Fragment

# Gathers information on Services.  Displays the service name, System name of the Service, Start Mode, and State.  Sorted by Start Mode and then State.
$Service = Get-CimInstance win32_service | Select-Object DisplayName, Name, StartMode, State | sort StartMode, State, DisplayName | ConvertTo-HTML -Fragment 

# Gathers information about Installed Applications on the Machine.
$InstalledApps = Get-RemoteProgram | Select-Object ProgramName | sort ProgramName | ConvertTo-Html -Fragment

# Gathers information about Installed Hotfixes on the Machine.
$Hotfix = gwmi Win32_QuickFixEngineering | ? {$_.InstalledOn} | where { (Get-date($_.Installedon)) -gt $Time } | Select-Object HotFixID, Caption, InstalledOn | sort InstalledOn, HotFixID | ConvertTo-HTML -Fragment 

# Applies color coding based on cell value
$StatusColor.Keys | foreach { $Service = $Service -replace ">$_<",($StatusColor.$_) }
$EventColor.Keys | foreach { $AppEvent = $AppEvent -replace ">$_<",($EventColor.$_) }
$EventColor.Keys | foreach { $SysEvent = $SysEvent -replace ">$_<",($EventColor.$_) }

# Builds the HTML report for output to C:\HealthCheck\(System Name)
$HTML = ConvertTo-HTML -Head $Style -PostContent "$ReportHead $UserHead $CurrentUser $OSHead $OS $DiskHead $Disk $AppLogHead $AppEvent $SysLogHead $SysEvent $ServHead $Service $InstalledAppsHead $InstalledApps $HotFixHead $HotFix" -Title "System Health Check Report" | Out-String

$secpasswd = ConvertTo-SecureString "hj*7&8op@2p" -AsPlainText -Force
$creds = New-Object System.Management.Automation.PSCredential("script.notifications@navitas.com", $secpasswd)

$Props = @{
    To          = "gary.smith@navitas.com"
    Subject     = "System Health Check Report: $Computer"
    Body        = $HTML.ToString()
    From        = "script.notifications@navitas.com"
    SmtpServer  = "smtp.office365.com"
    Port        = 587
    Credential  = $Creds
}

Send-MailMessage @Props -UseSsl -BodyAsHtml