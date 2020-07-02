<#
.Synopsis
   Schedules a job to run in RES Automation Manager.
.DESCRIPTION
   Schedules Module, Project or RunBook to run in RES Automation Manager
   using the REST api (must be enabled on a dispatcher). After the job
   has been scheduled the progress will be monitored and shown in the
   MDT progress window.
   Requires the RESAM module and the following custom Task Sequence variables:

   RESAMDispatcher  : Name of a dispatcher with a running WebAPI
   RESAMDBServer    : Name of the RES AM database server (SQL)
   RESAMDBName      : Name of the RES AM database
   RESAMDBUser      : SQL User with read right to the database
   RESAMDBPassword  : Password of the DB user (Base64 encoded)
   RESAMAPIUser     : RES AM account with the right to schedule jobs
   RESAMAPIPassword : Password of the API user (Base64 encoded)
.PARAMETER AgentName
   Name of the agent the job will be scheduled on. When omitted the local computername
   will be used to schedule Modules and Projects. Runbooks will be scheduled regardless
   of this parameter.
.NOTES
   Author: Michaja van der Zouwen
   Date  : 13-01-2016
.EXAMPLE
   Run-RESAMJob -ProjectName 'PostJob MDT' -Parameters 'Param1 = Value 1,Param 2 = Value 2'
   Start the RES AM project "Postjob MDT" on the local agent. Parameter 'Param1' will be set
   to value 'Value 1' and parameter 'Param 2' will be set to 'Value 2'.
#>
[CmdletBinding()]
Param (

    [Parameter()]
    [string]
    $AgentName,

    [Parameter(ParameterSetName='Module')]
    [string]
    $ModuleName,

    [Parameter(ParameterSetName='Project')]
    [string]
    $ProjectName,

    [Parameter(ParameterSetName='RunBook')]
    [string]
    $RunBookName,

    #Parameters for the scheduled job
    [string]
    $Parameters,

    [switch]
    $ShowProgress = $true
)

#region Variables

$Dispatcher = $TSENV:RESAMDispatcher
$DBServer = $TSENV:RESAMDBServer
$DBName = $TSENV:RESAMDBName
$DBUser = $TSENV:RESAMDBUser
$DBPwd = $TSENV:RESAMDBPassword
$APIUser = $TSENV:RESAMAPIUser
$APIPwd = $TSENV:RESAMAPIPassword
If (Test-Path D:\MININT)
{
    $File = "D:\MININT\RESAM.txt"
}
elseif (Test-Path C:\MININT)
{
    $File = "C:\MININT\RESAM.txt"
}

#endregion Variables

#region functions

function ConvertFrom-Base64($EncodedString)
{
    $bytesfrom  = [System.Convert]::FromBase64String($EncodedString);
    [System.Text.Encoding]::UTF8.GetString($bytesfrom)
}

function Refresh-SQLConnection
{
    Write-Host 'Error: Connection to SQL was lost! Trying to re-establish contact..'
    for ($i = 1; $i -lt 30; $i++)
    { 
        Connect-RESAMDatabase -DataSource $DBServer -DatabaseName $DBName -Credential $cred -ea 0
        If ($RESAM_DB_Connection.State -eq 'Open')
        {
            Write-Host 'Connection re-established.'
            Continue
        }
        else
        {
            sleep -s 2
        }
    }
    If ($RESAM_DB_Connection.State -ne 'Open')
    {
        Write-Error 'Unable to re-establish connection to SQL.' -ErrorAction Continue
        exit 1
    }
}

function New-MonitorEvent
{
    Param(
        [Parameter(mandatory=$true)]
        [ValidateRange(41000,41050)]
        $EventID,

        [ValidateSet('Info','Warning','Error')]
        $Type = 'Info',
        
        [Parameter(mandatory=$true)]
        [string]
        $StepName,

        [Parameter(mandatory=$true)]
        [string]
        $Message
    )

    $Url = @(
        "uniqueID=$TSEnv:LTIGUID",
        "computerName=$ENV:COMPUTERNAME",
        "messageID=$EventID",
        "severity=LogType$Type",
        "stepName=$StepName",
        "currentStep=$TSEnv:_SMSTSNextInstructionPointer",
        "totalSteps=$TSEnv:_SMSTSInstructionTableSize",
        "id=$TSEnv:UUID,$((Get-ChildItem TSENV:MacAddress*).Value -join ',')",
        "message=$Message"
        "dartIP=$TSEnv:DartIP001",
        "dartPort=$TSEnv:DartPort001",
        "dartTicket=$TSEnv:DartTicket",
        "vmHost=$TSEnv:VMHost",
        "vmName=$TSEnv:VMName"
    ) -join '&'
    $XMLHTTPRequest = New-Object -ComObject Msxml2.ServerXMLHTTP
    #Set timeouts to infinite for name resolution, 60 seconds for connect, send, and receive
    $XMLHTTPRequest.setTimeouts(0,60000,60000,60000)
    try
    {
        #Ignore SSL errors (avoids having to deal with certificates)
        $XMLHTTPRequest.SetOption(2,13056)
    }
    catch{}
    try
    {
        $XMLHTTPRequest.open('GET',"$TSEnv:EVENTSERVICE/MDTMonitorEvent/PostEvent?$Url",$false,"$TSEnv:USERDOMAIN\$TSEnv:USERID",$TSenv:USERPASSWORD)
        $XMLHTTPRequest.send()
    }
    catch
    {
        Write-Host "Failed to send Monitoring event. Step is: $StepName."
    }
}

Function Telnet
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [Alias ('HostName','cn','Host','Computer')]
        [String]
        $ComputerName='localhost',

        [Parameter(Mandatory=$true,
            ValueFromPipeline=$true,
            ValueFromPipelineByPropertyName=$true)]
        [int32]
        $Port,

        [int32]
        $Timeout = 10000
    )

    Process 
    {
        Try 
        {
            $TCP = New-Object System.Net.Sockets.TcpClient
            $Connection = $TCP.BeginConnect($ComputerName, $Port, $null, $null)
            $Connection.AsyncWaitHandle.WaitOne($timeout,$false)  | Out-Null 
            return $TCP.Connected
        }
        Catch
        {
            Write-Error "Unknown Error: $_"
        }
    }
}

#endregion functions

#region Prerequisites
If (!$RunBookName -and !$AgentName)
{
    Write-Host "No agent name defined. Using local computer."
    $AgentName = $env:COMPUTERNAME
}
If ($AgentName -eq $env:COMPUTERNAME)
{
    Write-Host 'Checking RES AM agent service...'
    $Service = Get-Service RESWAS -ErrorAction Stop
    If ($Service.Status -eq 'Running')
    {
        Write-Host 'Service is running.'
    }
    else
    {
        Write-Host "Service not running!`nStarting service..."
        Start-Service RESWAS -ea Stop
        Write-Host 'Service started.'
    }
}
Import-Module RESAM -ea 1

Write-Host "Connecting to RES AM environment database '$DBName' on server '$DBServer'..."
$PW = ConvertFrom-Base64 $DBPwd
$password = $PW | ConvertTo-SecureString -AsPlainText -Force
$cred = New-Object -typename System.Management.Automation.PSCredential -argumentlist $DBUser, $password
Connect-RESAMDatabase -DataSource $DBServer -DatabaseName $DBName -Credential $cred -ea 1
Write-Host "Connection established."
$WarningPreference = 'SilentlyContinue'
If ($AgentName)
{
    Write-Host 'Retreiving Agent object...'
    for ($i = 0; $i -le 30; $i++)
    { 
        $Agent = Get-RESAMAgent -Name $AgentName -Full
        if ($Agent.count -gt 1)
        {
            Write "Multiple agents found. Checking status..."
            $Online = $Agent.Where{$_.Status -eq 'Online'}
            If ($Online.count -gt 1)
            {
                Write-Error "There are $($Agent.count) agents online named '$AgentName'." -ErrorAction Continue
                exit 1
            }
            elseif ($Online)
            {
                Write "Agent '$AgentName' is online."
                $Agent = $Online
                break
            }
            else
            {
                Write "Agent '$AgentName' is not online (yet). Waiting... (pass $i)"
            }
        }
        elseif ($Agent.Status -ne 'Online')
        {
            Write "Agent '$AgentName' is not online (yet). Waiting... (pass $i)"
        }
        elseif ($Agent)
        {
            Write "Agent '$AgentName' is online."
            break
        }
        else
        {
            Write "Agent '$AgentName' not found. Waiting... (pass $i)"
        }
        sleep -s 2
    }

    if ($Agent -and $Agent.Status -ne 'Online')
    {
        Write-Host "Agent '$AgentName' is still offline.`nRestarting agent service..."
        Restart-Service RESWAS -ErrorAction stop
        Write-Host 'Service restarted. Waiting 10 seconds'
        Start-Sleep -Seconds 10
        $Agent = Get-RESAMAgent -Name $AgentName
        If ($Agent.Status -ne 'Online')
        {
            Write-Error "Agent '$AgentName' is still offline. Exiting script." -ErrorAction Continue
            exit 1
        }
    }
    elseif (!$Agent)
    {
        Write-Error "Agent '$AgentName' is not present." -ErrorAction Continue
        exit 1
    }
}

#endregion Prerequisites

#region Scheduling

If (Test-Path $File) #Check for running RES AM Job
{
    Write-Host "Reboot complete"
    Write-Host "RES AM job GUID is now: '$TSEnv:RESAMJob'."
    $TSenv:RESAMJob = Get-Content $File
    Write-Host "Running RES AM job detected with GUID '$TSEnv:RESAMJob'."
}
else # Schedule new RES AM Job
{
    Write-Host "Starting script with Project/Runbook value '$ProjectName$RunBookName' and Parameters '$Parameters'..."
    Write-Progress -Activity "Running RES Automation Manager job" -Status "Scheduling job: '$ProjectName$RunBookName'" -percentComplete 0
    
    If ($ModuleName)
    {
        $Module = Get-RESAMModule -Name $ModuleName
        If (!$Module)
        {
            Write-Error "Unable to find module '$ModuleName'." -ErrorAction Continue
            exit 1
        }
        If ($Module.count -gt 1)
        {
            Write-Error "There are $($Module.count) modules named '$ModuleName'" -ErrorAction Continue
            exit 1
        }
        $JobDescription = "$ModuleName (initiated by MDT)"
        $Message = "Scheduling RES AM module '$ModuleName' using dispatcher $Dispatcher..."
    }
    ElseIf ($ProjectName)
    {
        $Project = Get-RESAMProject -Name $ProjectName
        If (!$Project)
        {
            Write-Error "Unable to find project '$ProjectName'." -ErrorAction Continue
            exit 1
        }
        If ($Project.count -gt 1)
        {
            Write-Error "There are $($Project.count) projects named '$ProjectName'" -ErrorAction Continue
            exit 1
        }
        $JobDescription = "$ProjectName (initiated by MDT)"
        $Message = "Scheduling RES AM project '$ProjectName' using dispatcher $Dispatcher..."
    }
    elseif ($RunBookName)
    {
        $Runbook = Get-RESAMRunBook -Name $RunBookName -Full
        If (!$Runbook)
        {
            Write-Error "Unable to find runbook '$RunbookName'." -ErrorAction Continue
            exit 1
        }
        If ($Runbook.count -gt 1)
        {
            Write-Error "There are $($Runbook.count) runbooks named '$RunBookName'" -ErrorAction Continue
            exit 1
        }
        If (!$Agent -and 
            $Runbook.Properties.properties.jobs.job.properties.whoname -contains '' -and
            $Runbook.Properties.properties.jobs.job.properties.use_runbookparam -eq 'no')
        {
            Write-Error "Runbook '$RunBookName' requires an agent." -ErrorAction 1
            exit 1
        }
        $JobDescription = "$RunBookName (initiated by MDT)"
        $Message = "Scheduling RES AM runbook '$RunBookName' using dispatcher $Dispatcher..."
    }
    Write-Host 'Objects received.'

    Write-Host $Message

    #Convert parameters to hashtable
    If ($Parameters)
    {
        $ParamHash = ConvertFrom-StringData ($Parameters.Split(',') | Out-String)
    }
    else
    {
        $ParamHash = $null
    }
    #Creating credential object for REST API
    $PW = ConvertFrom-Base64 $APIPwd
    $password = $PW | ConvertTo-SecureString -AsPlainText -Force
    $ApiCred = New-Object -typename System.Management.Automation.PSCredential -argumentlist $APIUser, $password
    
    #Schedule the job
    If ($ModuleName)
    {
        try
        {
            $Job = New-RESAMJob -Dispatcher $Dispatcher -Credential $ApiCred -Who $Agent -Module $Module -Parameters $ParamHash -Description $JobDescription -ea 1
        }
        catch
        {
            Write-Error "Unable to schedule job. Error: $($_.exception)"
            exit 1
        }
    }
    elseif ($ProjectName)
    {
        try
        {
            $Job = New-RESAMJob -Dispatcher $Dispatcher -Credential $ApiCred -Who $Agent -Project $Project -Parameters $ParamHash -Description $JobDescription -ea 1
        }
        catch
        {
            Write-Error "Unable to schedule job. Error: $($_.exception)"
            exit 1
        }
    }
    elseif ($RunbookName)
    {
        try
        {
            $Job = New-RESAMJob -Dispatcher $Dispatcher -Credential $ApiCred -Who $Agent -RunBook $Runbook -Parameters $ParamHash -Description $JobDescription -ea 1
        }
        catch
        {
            Write-Error "Unable to schedule job. Error: $($_.exception)"
            exit 1
        }
    }
    
    #Save Job GUID in file
    $TSEnv:RESAMJob = $Job.MasterJobGUID
    If ($ShowProgress)
    {
        $TSEnv:RESAMJob | Out-File $File
    }
    Write-Host "Job scheduled with GUID '$TSEnv:RESAMJob'."
}

#endregion Scheduling

#region Monitoring
If ($ShowProgress)
{
    Write-Host 'Monitoring progress...'
    try
    {
        $MasterJob = Get-RESAMMasterJob -MasterJobGUID $TSEnv:RESAMJob -Full -ErrorAction Stop
    }
    catch
    {
        If ($_.Exception.Message -match 'error occurred while establishing a connection to SQL Server')
        {
            
            Refresh-SQLConnection
            $MasterJob = Get-RESAMMasterJob -MasterJobGUID $TSEnv:RESAMJob -Full -ErrorAction Stop
        }
        else
        {
            Write-Error "Unable to retreive masterjob with guid $TSEnv:RESAMJob. $_" -ErrorAction Continue
            exit 1
        }
    }
    If ($MasterJob.IsProject)
    {
        Write-Host 'Job is a Project.'

        #Get project tasks
        $Enabled = $MasterJob.Tasks.tasks.task | ?{$_.properties.enabled -eq 'yes'}
        try
        {
            $Modules = $MasterJob.Tasks.tasks.task.moduleinfo | ?{$_.name} | Get-RESAMModule -Full -ErrorAction Stop
        }
        catch
        {
            If ($_.Exception.Message -match 'error occurred while establishing a connection to SQL Server')
            {
                Refresh-SQLConnection
                $Modules = $MasterJob.Tasks.tasks.task.moduleinfo | ?{$_.name} | Get-RESAMModule -Full
            }
            else
            {
                Write-Error "Unable to retreive modules for masterjob. $_" -ErrorAction Continue
                exit 1
            }
        }
        $TaskGUIDs = $Enabled.properties.guid

        #Assign percentage to each task
        $TaskProgress = for ($i = 1; $i -le $TaskGUIDs.count; $i++)
        { 
            [pscustomobject]@{
                Percent = 100/$TaskGUIDs.count * $i
                GUID = $TaskGUIDs[($i-1)]
            }
        }

        #Check progress until job finished or reboot request
        Do
        {
            Try
            {
                $Job = $MasterJob | Get-RESAMJob -ErrorAction Stop
                If ($Job.CurrentTaskGUID)
                {
                    $CurrentTaskGuid = "{$($Job.CurrentTaskGUID.Guid)}"
                    $CurrentModule = $Modules | ?{$_.Tasks.tasks.task.properties.guid -match $CurrentTaskGuid}
                    $Task = $TaskProgress | ?{$_.GUID -eq $CurrentTaskGuid} | sort percent | select -First 1
                    If ($Task)
                    {
                        $TaskProgress = $TaskProgress | ?{$_.percent -gt $Task.percent}
                        Write-Host "Processing Module: $($CurrentModule.Name) - Project at $($Task.percent -as [int])% completion."
                        #$tsenv:_SMSTSCurrentActionName = $CurrentModule.Name
                        Write-Progress -Activity "Running RES Automation Manager job" -Status "Processing Module: $($CurrentModule.Name)" -percentComplete $Task.Percent
                        If ($TSEnv:EventService)
                        {
                            If (Telnet -ComputerName $TSEnv:EventService.Split(':')[1].TrimStart('//') -Port $TSEnv:EventService.Split(':')[2] -Timeout 1000 -ErrorAction SilentlyContinue)
                            {
                                New-MonitorEvent -EventID 41000 -Type Info -StepName $CurrentModule.Name -Message "Processing Module: $($CurrentModule.Name)"
                            }
                            else
                            {
                                Write-Host "Failed to contact Monitoring service at server [$($TSEnv:EventService.Split(':')[1].TrimStart('//'))] on port [$($TSEnv:EventService.Split(':')[2])]"
                            }
                        }
                    }
                }
                sleep -Seconds 3
                $MasterJob = Get-RESAMMasterJob -MasterJobGUID $MasterJob.MasterJobGUID -ErrorAction Stop
            }
            catch
            {
                If ($_.Exception.Message -match 'error occurred while establishing a connection to SQL Server')
                {
                    Refresh-SQLConnection
                }
                elseif (!$Job)
                {
                    Write-Error "Unable to retreive jobs from masterjob. $_" -ErrorAction Continue
                    exit 1
                }
                elseif (!$MasterJob)
                {
                    Write-Error "Unable to retreive masterjob with guid $($MasterJob.MasterJobGUID). $_" -ErrorAction Continue
                    exit 1
                }
            }
        }
        Until ($TSenv:SMSTSRebootRequested -or $MasterJob.Status -notmatch 'Active|Scheduled')
    }
    ElseIf ($MasterJob.IsRunBook)
    {
        Write-Host 'Job is a RunBook.'

        #Get Runbook tasks
        $Enabled = $MasterJob.Tasks.jobs.job | ?{$_.properties.enabled -eq 'yes'}
        $What = $Enabled.Properties.What
        $RBModules = @()
        foreach ($Item in $What)
        {
            switch ($Item.type)
            {
                project {
                            $Project = Get-RESAMProject -GUID $Item.'#text'
                            $PModules = $Project.Modules | ?{$_.Enabled} | sort Order | Get-RESAMModule -Full
                            $RBModules += [pscustomobject]@{ParentGUID = $Project.GUID;Modules = $PModules}
                        }
                module  {
                            $Module = Get-RESAMModule -GUID $Item.'#text' -Full
                            $RBModules += [pscustomobject]@{ParentGUID = $Module.GUID;Modules = $Module}
                        }
            }
        }
        $Modules = $RBModules.Modules
        $TaskGUIDs = foreach ($SchedJob in $RBModules)
        {
            $enabledTasks = $SchedJob.Modules.tasks.tasks.task.properties | ?{$_.enabled -eq 'yes'}
            $enabledTasks  | %{
                [pscustomobject]@{
                    ParentGUID = $SchedJob.ParentGUID
                    Task = $_.guid
                }
            }
        }

        #Assign percentage to each task
        $TaskProgress = for ($i = 1; $i -le $TaskGUIDs.count; $i++)
        { 
            [pscustomobject]@{
                Percent = 100/$TaskGUIDs.count * $i
                GUID = $TaskGUIDs.Task[($i-1)]
                ParentGUID = "{$($TaskGUIDs.ParentGUID[($i-1)])}"
            }
        }

        #Check progress until job finished or reboot request
        Do
        {
            $MasterJob = Get-RESAMMasterJob -MasterJobGUID $MasterJob.MasterJobGUID -Full
            $ActiveMasterJob = $MasterJob.Tasks.jobs.job | where Status -eq 1 | Foreach {
                Get-RESAMMasterJob -MasterJobGUID $_.masterjobguid -InvokedByRunbook -Full}
            If ($ActiveMasterJob.IsProject)
            {
                $ParentGUID = $ActiveMasterJob.Tasks.Tasks.task.projectinfo.guid
            }
            else
            {
                $ParentGUID = $ActiveMasterJob.Tasks.Tasks.task.moduleinfo.guid
            }
            $ActiveJob = $ActiveMasterJob | Get-RESAMJob
            IF ($ActiveJob.CurrentTaskGUID)
            {
                $CurrentTaskGuid = "{$($ActiveJob.CurrentTaskGUID.Guid)}"
                $CurrentModule = $Modules | ?{$_.Tasks.tasks.task.properties.guid -match $CurrentTaskGuid} | select -First 1
                $Task = $TaskProgress | ?{$_.GUID -eq $CurrentTaskGuid -and $ParentGUID -eq $_.ParentGUID} | sort percent | select -First 1
                If ($Task)
                {
                    $TaskProgress = $TaskProgress | ?{$_.percent -gt $Task.percent}
                    Write-Host "Processing Module: $($CurrentModule.Name) - Runbook at $($Task.percent -as [int])% completion."
                    Write-Progress -Activity "Running RES Automation Manager job" -Status "Processing Module: $($CurrentModule.Name)" -percentComplete $Task.Percent
                    New-MonitorEvent -EventID 41000 -Type Info -StepName $CurrentModule.Name -Message "Processing Module: $($CurrentModule.Name)"
                }
            }
            sleep -Seconds 3
        }
        Until ($TSenv:SMSTSRebootRequested -or $MasterJob.Status -notmatch 'Active|Scheduled')
    }
    else
    {
        Write-Host 'Job is a Module.'

        #Get module tasks
        $Enabled = $MasterJob.Tasks.tasks.task | ?{$_.properties.enabled -eq 'yes'}
        $Module = $MasterJob.Tasks.tasks.task.moduleinfo | ?{$_.name}
        $TaskGUIDs = $Enabled.properties.guid

        #Assign percentage to each task
        $TaskProgress = for ($i = 1; $i -le $TaskGUIDs.count; $i++)
        { 
            [pscustomobject]@{
                Percent = 100/$TaskGUIDs.count * $i
                GUID = $TaskGUIDs[($i-1)]
            }
        }

        #Check progress until job finished or reboot request
        Do
        {
            $Job = $MasterJob | Get-RESAMJob
            If ($Job.CurrentTaskGUID)
            {
                $CurrentTaskGuid = "{$(($MasterJob | Get-RESAMJob).CurrentTaskGUID.Guid)}"
                $Task = $TaskProgress | ?{$_.GUID -eq $CurrentTaskGuid} | sort percent | select -First 1
                If ($Task)
                {
                    $TaskProgress = $TaskProgress | ?{$_.percent -ne $Task.percent}
                    Write-Host "Processing Module: $($Module.Name) - Module at $($Task.percent -as [int])% completion."
                    Write-Progress -Activity "Running RES Automation Manager job" -Status "Processing Module: $($Module.Name). Task: $($Job.CurrentActivity)" -percentComplete $Task.Percent
                    New-MonitorEvent -EventID 41000 -Type Info -StepName $Module.Name -Message "Processing Module: $($Module.Name)"
                }
            }
            sleep -Seconds 3
            $MasterJob = Get-RESAMMasterJob -MasterJobGUID $MasterJob.MasterJobGUID
        }
        Until ($TSenv:SMSTSRebootRequested -or $MasterJob.Status -notmatch 'Active|Scheduled')
    }
    If ($TSenv:SMSTSRebootRequested)
    {
        Write-Host "Continue after reboot."
    }
    else
    {
        If (Test-Path $File)
        {
            Remove-Item $File
        }
        $MasterJobInfo = Get-RESAMMasterJob -MasterJobGUID $MasterJob.MasterJobGUID
        $Description = $MasterJobInfo.Description
        switch ($MasterJobInfo.Status)
        {
            'Completed'             {Write-host "RES AM Job '$Description' completed successfully."}
            'Completed with Errors' {Write-host "RES AM Job '$Description' completed successfully, but with some errors."}
            'Failed'                {Disconnect-RESAMDatabase;Write-Error "RES AM Job '$Description' failed. Please check job results." -ErrorAction Continue;exit 1}
        }
    }
}
Disconnect-RESAMDatabase

#endregion Monitoring
