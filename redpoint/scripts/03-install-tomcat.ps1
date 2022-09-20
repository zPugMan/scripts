# -----------------------------------------------------------------------------------------------------------------------
# 03-install-tomcat.ps1
# 
# Purpose:  This script is responsible for installing the Tomcat9 and Java for use by Tomcat
#           
#           List of available config.ini settings available here: https://github.com/apache/tomcat/blob/3bdd80293fb2b88a8b3df50692a93047261bd082/res/tomcat.nsi#L473
#           
# -----------------------------------------------------------------------------------------------------------------------
# Dedicated RPDM drive for processing
$INSTALL_DRIVE = "E"

# Prior RPDM server host
$PRIOR_SERVER = "PAZRPDMUAT01"

# Tomcat binary path
$TOMCAT_BINARY = "apache-tomcat-9.0.63.exe"
$TOMCAT_SRC_PATH = "${INSTALL_DRIVE}:\Software\oapi"

Write-Output "Installation of Tomcat initiated"

$tomcatPassword = Read-Host -Prompt "Tomcat admin password?" -AsSecureString

if(!(Test-Path -Path ${INSTALL_DRIVE}:\Java)) {
  New-Item -Path ${INSTALL_DRIVE}:\Java -ItemType Directory
}

Write-Output "Mass copy of Java from prior server $PRIOR_SERVER"
try {
  Copy-Item -Path "\\$PRIOR_SERVER\$INSTALL_DRIVE$\Java" -Destination ${INSTALL_DRIVE}:\ -Recurse -Force
}
catch {
  Write-Error -Message "Failed to copy Java binaries" -Category WriteError
  throw "Stopping install process due to Java install failure"
}

Write-Output "Installing Tomcat"
if(!(Test-Path -Path $TOMCAT_SRC_PATH\$TOMCAT_BINARY)) {
  Write-Error -Message "Tomcat source binary not found at $TOMCAT_SRC_PATH" -Category ObjectNotFound
  throw "Stopping install process due to Tomcat source binary being unavailable"
}

#inject password
$Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($tomcatPassword)
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
[System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)
try {
  ((Get-Content -path $TOMCAT_SRC_PATH\config.setup.ini -Raw) -replace "TomcatAdminPassword=","TomcatAdminPassword=$password") | Set-Content -Path $TOMCAT_SRC_PATH\config.ini
}
catch {
  Write-Error -Message "Failed to generate config.ini"
}

if(!(Test-Path -Path $TOMCAT_SRC_PATH\config.ini)) {
  Write-Error -Message "Tomcat install config.ini not found" -Category ObjectNotFound
  throw "Stopping install process due to Tomcat config.ini being unavailable"
}

$installArgs = `"/S /C=${TOMCAT_SRC_PATH}\config.ini /D=${INSTALL_DRIVE}:\Program Files\Apache Software Foundation\Tomcat 9.0`"

try {
  Start-Process -FilePath $TOMCAT_SRC_PATH\$TOMCAT_BINARY -Wait -ArgumentList $installArgs
  Write-Output "Install completed, confirming..."
}
catch {
  Write-Error $_ -Category NotInstalled
  throw "Installation failed."
}

if(!(Test-Path -Path ${INSTALL_DRIVE}:\Program Files\Apache Software Foundation\Tomcat 9.0\conf\server.xml)){
  Write-Error -Message "Tomcat server.xml not found in expected location" -Category ObjectNotFound
}

$service = Get-Service -Name Tomcat9
if($null -eq $service){
  Write-Error -Message "Tomcat windows sevice not found" -Category ObjectNotFound
}

Remove-Item -Path $TOMCAT_SRC_PATH\config.ini -Force

Write-Output "Installation complete."