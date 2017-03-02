' // ***************************************************************************
' // 
' // Copyright (c) Microsoft Corporation.  All rights reserved.
' // 
' // Microsoft Deployment Toolkit Solution Accelerator
' //
' // File:      DeployWiz_WinUpdates.vbs
' // 
' // Version:   6.2.5019.0
' // 
' // Purpose:   Windows Updates wizard pane validation
' // 
' // ***************************************************************************

Option Explicit

'''''''''''''''''''''''''''''''''''''
'  Validate Windows Update pane
'
Function InitializeWindowsUpdate
	'Get values from CS.ini
	WSUSServer.Value = Property("WSUSServer")
	TargetGroup.Value = Property("TargetGroup")
	
	'Determine the default value
	If UCase(Property("WinUpdate")) = "YES" then
		If Property("WSUSServer") <> "" then
			WSUSUpdate.checked = true
		Else
			WinUpdates.checked = true
		End if
	Else
		NoUpdate.checked = true
	End if
		
	ValidateWindowsUpdate
	
	
End Function

Function ValidateWindowsUpdate

	Dim IsWSUS

	IsWSUS = WSUSUpdate.checked
	
	If not isWSUS then
	
		WSUSServer.disabled = true
		TargetGroup.disabled = true
		
	Else
	
		WSUSServer.disabled = false 
		TargetGroup.disabled = false
		
	End if
	
	If IsWSUS and WSUSServer.value = "" then
	
		ValidateWindowsUpdate = false
		ButtonNext.disabled = true
	
	Else
	
		ValidateWindowsUpdate = true
		ButtonNext.disabled = false
		
	End if
	
End Function

Function ValidateWindowsUpdate_Final

	If not WSUSUpdate.checked then
	
		 WSUSServer.Value = ""
		 TargetGroup.Value = ""
		 
	End if
	
	ValidateWindowsUpdate_Final = true
	
End Function
