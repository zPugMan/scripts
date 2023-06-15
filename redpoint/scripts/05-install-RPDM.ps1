# -----------------------------------------------------------------------------------------------------------------------
# 05-install-RPDM.ps1
# 
# Purpose:  This script is responsible for installing RPDM
#           
# -----------------------------------------------------------------------------------------------------------------------
# Dedicated RPDM drive for processing
$INSTALL_DRIVE = "E"

# RPDM binary path
$RPDM_BINARY = "RedPointDM-ServerAndClient-9.4.4.2848-for-Windows.exe"
$RPDM_SRC_PATH = "${INSTALL_DRIVE}:\Software\RPDM"
$RPDM_INSTALL_OPTIONS = ".\05-RPDM-options.properties"
$RPDM_TEMP_OPTIONS = "rpdm.properties"

Write-Output "Installation of RPDM initiated"

$rpdmServiceAccount = Read-Host -Prompt "RPDM Service account (e.g. RPDM_UAT_USER@xyz.com)"
$rpdmServicePassword = Read-Host -Prompt "RPDM Service account password?" -AsSecureString

Write-Output "Installing RPDM"
if(!(Test-Path -Path $RPDM_SRC_PATH\$RPDM_BINARY)) {
  Write-Error -Message "RPDM source binary not found at $RPDM_SRC_PATH\$RPDM_BINARY" -Category ObjectNotFound
  throw "Stopping install process due to source binary being unavailable"
}

Write-Output "Creating local install options file"
if(!(Test-Path -Path $RPDM_INSTALL_OPTIONS)) {
  Write-Error -Message "Install options file template is missing. Expecting file: $RPDM_INSTALL_OPTIONS" -Category ObjectNotFound
  throw "Stopping install process due to missing template file"
}

try {
  Copy-Item -Path $RPDM_INSTALL_OPTIONS -Destination $RPDM_SRC_PATH\$RPDM_TEMP_OPTIONS -Force
  
  #inject password
  $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($rpdmServicePassword)
  $password = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
  [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)

  ((Get-Content -path $RPDM_SRC_PATH\$RPDM_TEMP_OPTIONS -Raw) -replace "service-login-password=","service-login-password=$password") | Set-Content -Path $RPDM_SRC_PATH\$RPDM_TEMP_OPTIONS
  ((Get-Content -path $RPDM_SRC_PATH\$RPDM_TEMP_OPTIONS -Raw) -replace "service-login-username=","service-login-username=$rpdmServiceAccount") | Set-Content -Path $RPDM_SRC_PATH\$RPDM_TEMP_OPTIONS
} catch {
  Write-Error $_
  Remove-Item -Path $RPDM_SRC_PATH\$RPDM_TEMP_OPTIONS
  throw "Copy of temporary options file for installation failed"
}

if(!(Test-Path -Path $RPDM_SRC_PATH\$RPDM_TEMP_OPTIONS)) {
  Write-Error -Message "RPDM install options file not found at $RPDM_SRC_PATH\$RPDM_TEMP_OPTIONS" -Category ObjectNotFound
  throw "Stopping install process due to options file being unavailable"
}

Write-Output "Local install options file created."
Set-Location $RPDM_SRC_PATH
$installArgs = "--optionfile .\$RPDM_TEMP_OPTIONS"

Write-Output "Proceeding with RPDM installation: $RPDM_SRC_PATH\$RPDM_BINARY $installArgs"
try {
  Start-Process -FilePath $RPDM_SRC_PATH\$RPDM_BINARY -Wait -ArgumentList $installArgs
  Write-Output "Install completed, confirming..."

  #TODO need a wait as the Start-Process returns before completed
}
catch {
  Write-Error $_ -Category NotInstalled
  Remove-Item -Path $RPDM_SRC_PATH\$RPDM_TEMP_OPTIONS -Force
  throw "Installation failed."
}

if(!(Test-Path -Path "${INSTALL_DRIVE}:\Program Files\RedPointDM9\program\Release\x64\rpdm_ExecutionServer.exe")){
  Write-Error -Message "RPDM rpdm_ExecutionServer.exe not found in expected location. Installation may be incomplete.." -Category ObjectNotFound
}

$service = Get-Service -Name RedPointDM9_ExecutionService
if($null -eq $service){
  Write-Error -Message "RedPointDM9_ExecutionService windows sevice not found" -Category ObjectNotFound
}

$service = Get-Service -Name RedPointDM9_SiteService
if($null -eq $service){
  Write-Error -Message "RedPointDM9_SiteService windows sevice not found" -Category ObjectNotFound
}

$service = Get-Service -Name RedPointDM9_WebProxyService
if($null -eq $service){
  Write-Error -Message "RedPointDM9_WebProxyService windows service not found" -Category ObjectNotFound
}

#destroy config.ini with secret
Remove-Item -Path $RPDM_SRC_PATH\$RPDM_TEMP_OPTIONS -Force

Write-Output "Installation complete."