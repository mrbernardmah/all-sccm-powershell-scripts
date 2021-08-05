## Uploads client logs files to Azure storage

$Logs = Get-ChildItem "$env:SystemRoot\CCM\Logs"
$Date = Get-date -Format "yyyy-MM-dd-HH-mm-ss"
$ContainerURL = "https://storagename.blob.core.windows.net/configmgrclientlogs"
$FolderPath = "ClientLogFiles/$($env:COMPUTERNAME)/$Date"
$SASToken = "?sv=2019-10-10&ss=b&srt=o&sp=cx&se=2020-06-11T14:00:00Z&st=2020-06-09T00:00:00Z&spr=https&sig=2iMlutYGCVqXofwz00QytzDki7lG4Y4YSaOD8zoZnkI%3D"

$Responses = New-Object System.Collections.ArrayList
$Stopwatch = New-object System.Diagnostics.Stopwatch
$Stopwatch.Start()

foreach ($Log in $Logs)
{
    $Body = Get-Content $($Log.FullName) -Raw
    $URI = "$ContainerURL/$FolderPath/$($Log.Name)$SASToken"
    $Headers = @{
        'x-ms-content-length' = $($Log.Length)
        'x-ms-blob-type' = 'BlockBlob'
    }
    $Response = Invoke-WebRequest -Uri $URI -Method PUT -Headers $Headers -Body $Body
    [void]$Responses.Add($Response)
}
$Stopwatch.Stop()
Write-host "$(($Responses | Where {$_.StatusCode -eq 201}).Count) log files uploaded in $([Math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds."