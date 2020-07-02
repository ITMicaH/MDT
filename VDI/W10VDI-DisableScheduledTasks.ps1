<#
.Synopsis
   Disable unnecessary scheduled tasks
.DESCRIPTION
   This script disables scheduled tasks that are unnecessary for use in a non-persistent VDI image. Run this script on the online image.
.NOTES
   Author: Michaja van der Zouwen
   Date  : 13-01-2016
   Tested: 1809,1909
#>

Write-Host "Disabling Scheduled Tasks..."
$TaskPaths = @(
    "\"
    "\Microsoft\Windows\Application Experience\"
    "\Microsoft\Windows\AppID\"
    "\Microsoft\Windows\Autochk\"
    "\Microsoft\Windows\Customer Experience Improvement Program\"
    "\Microsoft\Windows\Bluetooth\"
    "\Microsoft\Windows\ApplicationData\"
    "\Microsoft\Windows\CHKDSK\"
    "\Microsoft\Windows\Diagnosis\"
    "\Microsoft\Windows\DiskDiagnostic\"
    "\Microsoft\Windows\Defrag\"
    "\Microsoft\Windows\FileHistory\"
    "\Microsoft\Windows\Maintenance\"
    "\Microsoft\Windows\Power Efficiency Diagnostics\"
    "\Microsoft\Windows\RecoveryEnvironment\"
    "\Microsoft\Windows\Registry\"
    "\Microsoft\Windows\Mobile Broadband Accounts\"
    "\Microsoft\Windows\RAS\"
    "\Microsoft\Windows\WDI\"
    "\Microsoft\Windows\Shell\"
    "\Microsoft\XblGameSave\"
    "\Microsoft\Windows\Maps\"
    "\Microsoft\Windows\MemoryDiagnostic\"
    "\Microsoft\Windows\Location\"
    "\Microsoft\Windows\Active Directory Rights Management Services Client\"
    "\Microsoft\Windows\Windows Error Reporting\"
    "\Microsoft\Windows\Offline Files\"
    "\Microsoft\Windows\WindowsUpdate\"
    "\Microsoft\Windows\Speech\"
    "\Microsoft\Windows\Windows Filtering Platform\"
    "\Microsoft\Windows\SystemRestore\"
    "\Microsoft\Windows\Servicing\"
    "\Microsoft\Windows\Windows Media Sharing\"
)
$Tasks2Disable = Get-ScheduledTask -TaskPath $TaskPaths | where TaskName -NotMatch 'CreateObjectTask|SyspartRepair'
for ($i = 0; $i -lt $Tasks2Disable.count; $i++)
{ 
    Write-Progress -Activity 'Disabling Scheduled jobs' -Status "Processing: $($Tasks2Disable[$i].TaskName)" -PercentComplete ($i/$Tasks2Disable.count*100)
    Disable-ScheduledTask -InputObject $Tasks2Disable[$i]
}
