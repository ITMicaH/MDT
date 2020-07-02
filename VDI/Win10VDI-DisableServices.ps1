<#
.Synopsis
   Disable unnecessary services
.DESCRIPTION
   This script disables services that are unnecessary for use in a non-persistent VDI image. Run this script on the online image.
.NOTES
   Author: Michaja van der Zouwen
   Date  : 13-01-2016
#>

function Disable-Service
{
    Param([hashtable]$Services)

    for ($i = 0; $i -lt $Services.keys; $i++)
    {
        $ServiceName = $Services.Keys[$i]
        Write-Progress -Activity 'Disable unnecessary services' -Status "Processing $ServiceName" -PercentComplete ($i/$Services.Keys.Count*100)
        If ($ServiceName -eq 'swprv')
        {
            $StartupType = 'Manual'
        }
        else
        {
            $StartupType = 'Disabled'
        }
        If ($Service = Get-Service $ServiceName -ErrorAction SilentlyContinue)
        {
            Try
            {
                Set-Service $ServiceName -StartupType $StartupType -ErrorAction Stop
                Write-Host "Successfully disabled service: $($Service.DisplayName)"
            }
            catch
            {
                Write-Error "Failed to disable service: $($Service.DisplayName)"
            }
        }
        else
        {
            Write-Information "Service [$($Services[$ServiceName])] is not present on this system"
        }
    }
}

$Services = @{
    vmickvpexchange = 'Hyper-V Data Exchange Service'
    vmicguestinterface = 'Hyper-V Guest Service Interface'
    vmicshutdown = 'Hyper-V Guest Shutdown Service'
    vmicheartbeat = 'Hyper-V Heartbeat Service'
    vmicvmsession = 'Hyper-V PowerShell Direct Service'
    vmicrdv = 'Hyper-V Remote Desktop Virtualization Service'
    vmictimesync = 'Hyper-V Time Synchronization Service'
    vmicvss = 'Hyper-V Volume Shadow Copy Requestor'
    HvHost = 'Hyper-V Host Service'
    AJRouter = 'AllJoyn Router Service'
    ALG = 'Application Layer Gateway Service'
    AppMgmt = 'Application Management Service'
    BITS = 'Background Intelligent Transfer Service'
    BDESVC = 'Bitlocker Drive Encryption Service'
    wbengine = 'Block Level Backup Engine Service'
    BthHFSrv = 'Bluetooth Handsfree Service'
    bthserv = 'Bluetooth Support Service'
    BTAGService = 'Bluetooth Audio Gateway Service'
    PeerDistSvc = 'Branche Cache Service'
    Browser = 'Computer Browser Service'
    DsmSvc = 'Device Setup Manager Service'
    DoSvc = 'Delivery Optimization Service'
    DusmSvc = 'Data Usage'
    DPS = 'Diagnostic Policy Service'
    WdiServiceHost = 'Diagnostic Service Host Service'
    WdiSystemHost = 'Diagnostic System Host Service'
    DiagTrack = 'Diagnostics Tracking Service'
    TrkWks = 'Distributed Link Tracking Client'
    EFS = 'Encrypting File System Service'
    Eaphost = 'Extensible Authentication Protocol Service'
    Fax = 'Fax Service'
    fdPHost = 'Function Discovery Provider Host Service'
    FDResPub = 'Function Discovery Resource Publication Service'
    fhsvc = 'File History Service'
    lfsvc = 'Geolocation Service'
    HomeGroupListener = 'Home Group Listener Service'
    HomeGroupProvider = 'Home Group Provider Service'
    SharedAccess = 'Internet Connection Sharing (ICS) Service'
    irmon = 'Infrared Monitoring Service'
    wlidsvc = 'Microsoft Account Sign-in Assistant Service'
    MSiSCSI = 'Microsoft iSCSI Initiator Service'
    swprv = 'Microsoft Software Shadow Copy Provider Service'
    smphost = 'Microsoft Storage Spaces SMP Service'
    MapsBroker = 'Microsoft Maps Download Manager Service'
    NcaSvc = 'Microsoft Network Connectivity Service'
    CscService = 'Offline Files Service'
    CSC = 'Offline Files Service'
    defragsvc = 'Optimize drives Service'
    PhoneSvc = 'Phone Service'
    PcaSvc = 'Program Compatibility Assistant Service'
    SEMgrSvc = 'Payments and NFC/SE Manager Service'
    RmSvc = 'Radio Management Service'
    RetailDemo = 'Retail Demo Service'
    wscsvc = 'Security Service'
    SstpSvc = 'Secure Socket Tunneling Protocol Service'
    SensrSvc = 'Sensor Monitoring Service' 
    SensorService = 'Sensor Service' 
    ShellHWDetection = 'Shell Hardware Detection Service' 
    SNMPTRAP = 'SNMP Trap Service'
    SysMain = 'Superfetch'
    svsvc = 'Spot Verifier Service' 
    SSDPSRV = 'SSDP Discovery Service' 
    TapiSrv = 'Telephony Service' 
    upnphost = 'UPnP Device Host Service' 
    WFDSConMgrSvc = 'Wi-fi Direct Connect Manager Service' 
    wcncsvc = 'Windows Connect Now - Config Registrar Service' 
    WerSvc = 'Windows Error Reporting Service' 
    WMPNetworkSvc = 'Windows Media Player Network Sharing Service' 
    icssvc = 'Windows Mobile Hotspot Service' 
    wuauserv = 'Windows Update Service' 
    WlanSvc = 'WLAN AutoConfig Service' 
    WwanSvc = 'WWAN AutoConfig Service' 
    XboxGipSvc = 'Xbox Accessories Management Service' 
    XblAuthManager = 'Xbox Live Auth Manager Service' 
    XblGameSave = 'Xbox Live Game Save Service' 
    XboxNetApiSvc = 'Xbox Live Networking Service Service'
    BcastDVRUserService = 'GameDVR and Broadcast user service'
    MessagingService = 'MessagingService'
    WpcMonSvc = 'Parental Controls'
    VacSvc = 'Volumetric Audio Compositor Service'
    edgeupdate = 'Edge update service'
    edgeupdatem = 'Edge update service'
}

Disable-Service $Services
