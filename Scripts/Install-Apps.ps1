# =========================================================
# Core Apps Installer — MDT post-imaging payload (sanitized)
# Runs as the final task-sequence step: system policy, then
# the full corporate app stack, silent + logged.
# =========================================================

$ErrorActionPreference = "Continue"

$Base = Split-Path -Parent $MyInvocation.MyCommand.Path
$Log  = "$env:TEMP\CoreAppsInstall.log"
Start-Transcript -Path $Log -Append

function Log {
    param ($Message)
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $Message"
}

function Run-Exe {
    param ($Exe, $Args)

    if (-not (Test-Path $Exe)) {
        Log "SKIP (EXE not found): $Exe"
        return
    }

    Log "RUN EXE: $Exe $Args"
    try {
        $p = Start-Process -FilePath $Exe -ArgumentList $Args -Wait -NoNewWindow -PassThru
        Log "EXIT CODE: $($p.ExitCode)"
    }
    catch {
        Log "FAILED EXE: $Exe"
    }
}

function Run-MSI {
    param ($Msi, $Args)

    if (-not (Test-Path $Msi)) {
        Log "SKIP (MSI not found): $Msi"
        return
    }

    Log "RUN MSI: $Msi"
    try {
        $p = Start-Process -FilePath "msiexec.exe" `
            -ArgumentList "/i `"$Msi`" $Args" `
            -Wait -NoNewWindow -PassThru
        Log "EXIT CODE: $($p.ExitCode)"
    }
    catch {
        Log "FAILED MSI: $Msi"
    }
}

# ---------------------------------------------------------
# SYSTEM SETTINGS (RUN FIRST)
# ---------------------------------------------------------

Log "Applying system power settings"

# Disable sleep & screen timeout (AC + Battery)
powercfg -change -monitor-timeout-ac 0
powercfg -change -monitor-timeout-dc 0
powercfg -change -standby-timeout-ac 0
powercfg -change -standby-timeout-dc 0

# Lid close action = Do nothing when plugged in
powercfg -setacvalueindex SCHEME_CURRENT SUB_BUTTONS LIDACTION 0
powercfg -SetActive SCHEME_CURRENT

# Disable hibernation
powercfg -hibernate off

# ---------------------------------------------------------
# ENABLE .NET FRAMEWORK 3.5
# ---------------------------------------------------------

Log "Enabling .NET Framework 3.5"
DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart

# ---------------------------------------------------------
# NETWORK LOGIC (ETHERNET FIRST, WIFI PROFILE ONLY)
# ---------------------------------------------------------

Log "Checking network adapters"

$EthernetUp = Get-NetAdapter |
    Where-Object {
        $_.Status -eq "Up" -and
        $_.Name -notmatch "Wi-Fi|Wireless"
    }

if ($EthernetUp) {
    Log "Ethernet detected. Skipping Wi-Fi."
}
else {
    $WifiProfile = "$Base\WiFi-Corp.xml"

    if (Test-Path $WifiProfile) {
        Log "Importing Wi-Fi profile (no forced connection)"
        netsh wlan add profile filename="$WifiProfile" user=all | Out-Null
    }
    else {
        Log "Wi-Fi profile XML not found. Skipping."
    }
}

# ---------------------------------------------------------
# APPLICATION INSTALLS (SEQUENTIAL)
# ---------------------------------------------------------

# PDF Reader
Run-MSI "$Base\Adobe Reader\AcroRead.msi" "/qn /norestart EULA_ACCEPT=YES"

# Google Chrome Enterprise
Run-MSI "$Base\Google Chrome Enterprise\googlechromestandaloneenterprise64.msi" "/qn /norestart"

# Office / Outlook (ODT)
Run-Exe "$Base\Office365\setup.exe" "/configure configuration-Office365-x64.xml"

# Endpoint protection agent
Run-Exe "$Base\AV\endpoint_agent_setup_online.exe" "/silent /norestart"

# Citrix Workspace
Run-Exe "$Base\Citrix\CitrixWorkspaceFullInstaller.exe" `
"/silent /noreboot /includeSSON ENABLE_SSON=Yes /AutoUpdateCheck=disabled EnableCEIP=false"

# Clinical dictation client
Run-MSI "$Base\Dictation\DictationClient.msi" "/qn /norestart"

# Vendor hardware support agent
Run-Exe "$Base\Dell Support Assistant Business\SupportAssistBusinessInstaller.exe" "/S"

# VPN client
Run-MSI "$Base\VPN\GlobalProtect64.msi" "/qn /norestart"

# OneDrive (machine-wide)
Run-Exe "$Base\OneDrive\OneDriveSetup.exe" "/allusers /silent"

# Secure-email Outlook plugin
Run-Exe "$Base\Outlook Send Secure Plugin\Send_Secure_Outlook_Plugin_Setup.exe" "/S"

# Zoom
Run-MSI "$Base\Zoom\ZoomInstallerFull.msi" `
"/qn /norestart ZConfig=`"AutoUpdate=true`" ZoomAutoUpdate=`"true`""

# Point and Print Registry (printer deployment under modern Windows hardening)
$RegFile = "$Base\Registration Entries\PointAndPrint.reg"
if (Test-Path $RegFile) {
    Log "Importing Point and Print registry settings"
    reg import "`"$RegFile`"" | Out-Null
}
else {
    Log "PointAndPrint.reg not found. Skipping."
}

# ---------------------------------------------------------
# FINISH
# ---------------------------------------------------------

Log "Core Apps Installer completed successfully"
Stop-Transcript
