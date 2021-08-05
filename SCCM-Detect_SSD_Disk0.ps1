 $tsenv = New-Object -ComObject Microsoft.SMS.TSEnvironment
 $SSD = $tsenv.value("SSD")

 $IsSSD = (Get-PhysicalDisk | Where-Object {$_.DeviceID -eq 0}).MediaType
 If ($IsSSD -eq "SSD")
 {$tsenv.value("SSD") = "Yes"}
 Else
 {$tsenv.value("SSD") = "No"}
