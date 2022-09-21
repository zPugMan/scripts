# -----------------------------------------------------------------------------------------------------------------------
# 04-setup-tomcat.ps1
# 
# Purpose:  This script is responsible for setting up the Tomcat server for RPDM oapi interface
#           
#           
# -----------------------------------------------------------------------------------------------------------------------
# Dedicated RPDM drive for processing
$INSTALL_DRIVE = "E"

# Tomcat binary path
$TOMCAT_SRC_PATH = "${INSTALL_DRIVE}:\Software\oapi"
$OAPI_WAR = "oapi.war"

Write-Output "Setup of Tomcat initiated"

$service = Get-Service -Name Tomcat9
if($null -eq $service){
  Write-Error -Message "Tomcat windows sevice not found" -Category ObjectNotFound
}
else {
  Write-Output "Confirmed Tomcat9 service exists on host"
}

if($service.CanStop)
{
  try {
    Write-Output "Stopping Tomcat service.."
    $service.Stop()
  }
  catch {
    Write-Error "Tomcat service cannot be stopped"
    Write-Error $_
  }
}

if(!(Test-Path -Path ${TOMCAT_SRC_PATH}\${OAPI_WAR})){
  Write-Error "$OAPI_WAR file not found.. cannot deploy artifact" -Category ObjectNotFound
  throw "$OAPI_WAR file not found in: $TOMCAT_SRC_PATH"
}

Write-Output "Copying $OAPI_WAR to \webapps"
try {
  Copy-Item -Path $TOMCAT_SRC_PATH\$OAPI_WAR -Destination "${INSTALL_DRIVE}:\Program Files\Apache Software Foundation\Tomcat 9.0\webapps\openapi.war"
}
catch {
  Write-Error "Failed top copy $OAPI_WAR for deployment" -Category WriteError
  throw $_
}

Write-Output "Starting Tomcat service"
$service.Start()

$maxRepeat = 30
do {
  $count = if($service.Status -eq "Running") { 1 } else {0}
  $maxRepeat--
  Start-Sleep -Milliseconds 600
  Write-Debug "Service not running, waiting.."
} while ($count -eq 1 -or $maxRepeat -eq 0)

if(!($service.Status -eq "Running")) {
  Write-Warning "Tomcat service failed to start in allocated time.. "
} else {
  $web = Invoke-WebRequest -Uri "http://localhost:8080/openapi/"
  if($web.StatusCode -eq 200) {
    Write-Output "Successfully connected to deployed OAPI"
  } else {
    Write-Warning "Received status: $web.StatusCode when connecting to deployed OAPI"
  }
}

Set-Service -Name Tomcat9 -StartupType Automatic

Write-Output "Setup complete."