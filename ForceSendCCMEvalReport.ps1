New-ItemProperty -Path "HKLM:\Software\Microsoft\CCM\CcmEval" -Name 'SendAlways' -Value "TRUE" -Force -ErrorAction Stop

        Write-Verbose "Triggering CM Health Evaluation task"
        Invoke-Command -ScriptBlock { schtasks /Run /TN "Microsoft\Configuration Manager\Configuration Manager Health Evaluation" /I }
 
        Write-Verbose "Waiting for ccmeval to finish"
        do {} while (Get-process -Name ccmeval -ErrorAction SilentlyContinue)
 
        Write-Verbose "Disabling 'SendAlways' in registry"
        New-ItemProperty -Path "HKLM:\Software\Microsoft\CCM\CcmEval" -Name 'SendAlways' -Value "FALSE" -Force -ErrorAction Stop