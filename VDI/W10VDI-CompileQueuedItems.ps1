<#
.Synopsis
   Compile queued items with ngen
.DESCRIPTION
   This script forces .NET assembly updates in the queue to compile before the image is sealed.
   Progress is monitored from the log and displayed in the MDT progress bar.
   Run right before sealing the image (after installs and Windows updates).
.NOTES
   Author: Michaja van der Zouwen
   Date  : 13-01-2016
   Tested: 1809,1909
#>
#region Run ngen

Write-Progress -Activity 'Executing queued compilation jobs' -Status 'Running Ngen' -PercentComplete 0
$Items = (& 'C:\WINDOWS\Microsoft.NET\Framework64\v4.0.30319\ngen.exe' display) -match 'StatusPending'
$UniqueAssemblies = Invoke-Command {
    ($Items -notmatch ',').foreach({$_.Split('\')[-1].Split()[0]}) | select -Unique
    ($Items -match ',').foreach({$_.split(',')[0]}) | select -Unique
}
$TotalItems = $UniqueAssemblies.count
Write-Host "Running Ngen for execution of $TotalItems queued compilation jobs"
Start-Process 'C:\WINDOWS\Microsoft.NET\Framework64\v4.0.30319\ngen.exe' -ArgumentList executeQueuedItems -WindowStyle Hidden

#endregion Run ngen

#region Monitor Progress

$i = 0
$Assemblies = New-Object collections.arraylist
$Job = Start-Job -Name NGEN -ScriptBlock {Get-Content C:\WINDOWS\Microsoft.NET\Framework64\v4.0.30319\ngen.log -Tail 1 -Wait}
while (Get-Process ngen -ErrorAction SilentlyContinue)
{
    Receive-Job -Name NGEN | foreach {
        Switch -Regex ($_)
        {
            'compiling assembly \w\:\\.+\\(.+)\s\('         {$Assembly = $Matches[1]}
            'Compiling assembly ([^,]+),'                   {$Assembly = $Matches[1]}
            'Failed to load the runtime.+Assembly ([^,]+),' {$Assembly = $Matches[1]}
        }
        If ($Assembly)
        {
            Write-Progress -Activity 'NGEN' -Status "Compiling [$Assembly]" -PercentComplete ($i/$TotalItems*100)
            Write-Host "Compiling [$Assembly] (Progress: $([int]($i/$TotalItems*100))% - Count: $i)"
            If ($Assembly -notin $Assemblies -and $Assembly -in $UniqueAssemblies)
            {
                $null = $Assemblies.Add($Assembly)
                $i++
            }
            $Assembly = ''
        }
    }
    sleep -Seconds 1
}
$Job | Stop-Job -PassThru | Remove-Job

#endregion Monitor Progress

#region Check result

$ExpectedResult = 'All compilation targets are up to date.'
If ((& 'C:\WINDOWS\Microsoft.NET\Framework64\v4.0.30319\ngen.exe' executeQueuedItems)[-1] -eq $ExpectedResult)
{
    Write-Host $ExpectedResult
    $Host.SetShouldExit(0)
    exit
}
else
{
    Write-Error 'ngen failed to compile queued targets.' -Category InvalidResult
}

#endregion Check result
