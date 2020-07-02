<#
.Synopsis
   Prepare custom image for sysprep
.DESCRIPTION
   Prepare a custom image for sysprep in which store apps (Appx) have been removed.

   https://support.microsoft.com/en-us/help/2769827/sysprep-fails-after-you-remove-or-update-windows-store-apps-that-inclu
.NOTES
   Author: Michaja van der Zouwen
   Date  : 02-07-2020
   Tested: 1909
#>

Write-Progress -Activity 'Preparing for sysprep' -Status 'Removing local user profiles' -PercentComplete 0
Get-CimInstance Win32_UserProfile -Filter "Special = $false AND Loaded = $false" | Remove-CimInstance

Write-Progress -Activity 'Preparing for sysprep' -Status 'Removing Appx packages for current profile' -PercentComplete 50
Get-AppxPackage -AllUsers | foreach {Remove-AppPackage $_.PackageFullName -ErrorAction SilentlyContinue}

Write-Progress -Activity 'Preparing for sysprep' -Completed
