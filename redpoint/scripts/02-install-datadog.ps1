# -----------------------------------------------------------------------------------------------------------------------
# 02-install-datadog.ps1
# 
# Purpose:  This script is responsible for installing the DataDog agent and retrieve existing YAML configurations from
#           a $PRIOR_HOSTNAME as required for the agent's desired configuration.
#           
# -----------------------------------------------------------------------------------------------------------------------
$ENV = "uat"  # uat | prod
$MSI_PATH = "e:\Software\datadog"
$MSI = "${MSI_PATH}\datadog-agent-7-latest.amd64.msi"
$DD_DEFAULT_PATH = "c:\ProgramData\Datadog"
$TAGS = "application-name:Redpoint","environment:$ENV"
$PRIOR_HOSTNAME = "PAZRPDMUAT01"

#copy over relevant YAMLs
$yamlDirectories = 'windows_service.d','redpoint.d'

$APIKEY = Read-Host -Prompt "Datadog Agent API Key?"
$HOSTNAME = Get-WMIObject Win32_ComputerSystem | Select-Object -ExpandProperty Name

if(Test-Path -path $MSI) {
  $install_args = "/qn /i `"$MSI`" APIKEY=`"$APIKEY`" HOSTNAME=`"$HOSTNAME`" TAGS=`"$($TAGS -join ",")`""
  # $install_cmd = "c:\Windows\System32\msiexec.exe /qn /i `"$MSI`" APIKEY=`"$APIKEY`" HOSTNAME=`"$HOSTNAME`" TAGS=`"$($TAGS -join ",")`""
}
else {
  throw "Expected Agent MSI is missing. Not Found: $MSI"
}

#invoke installation
Write-Output "Starting DataDog agent install"
try {
  Start-Process -FilePath "c:\Windows\System32\msiexec.exe" -Wait -ArgumentList $install_args
  Write-Output "Install completed, confirming..."
}
catch {
  Write-Error $_ -Category NotInstalled
  throw "Installation failed."
}

#confirm agent location

if(Test-Path -path ${DD_DEFAULT_PATH}\datadog.yaml) {
  Write-Output "Confirmed. DataDog base yaml detected in %PROGRAMDATA%"
}
else {
  Write-Error -Message "Fail.  DataDog base yaml detected in %PROGRAMDATA%" -Category ObjectNotFound
}

$service_check
try {
  $service_check = Get-Service -Name datadogagent
  Write-Output "Confirmed. Found datadog agent service: $service_check.Name"
} 
catch {
  Write-Error -Message "Fail. DataDog agent service not found on inspection." -Category ObjectNotFound
}

#stop service & reset run-as on service
if( $null -ne $service_check )
{
  if($service_check.Status -eq "Running")
  {
    $service_check.Stop();
  }
  & sc.exe config $service_check.Name obj="LocalSystem"
  Write-Output "Updated ${service_check.Name} to LocalSystem account"
}


#copy over datadog YAMLs
function CopyYaml([String]$yamlDirectory){
  $subdir = $DD_DEFAULT_PATH -replace '^[a-zA-Z]:\\(.*)', '$1'
  $confd_path = "\\${PRIOR_HOSTNAME}\c$\${subdir}"

  if(Test-Path -Path "${confd_path}\$yamlDirectory\conf.yaml"){
    Copy-Item -Path "${confd_path}\$yamlDirectory\conf.yaml" -Destination "${DD_DEFAULT_PATH}\$yamlDirectory\conf.yaml" -Force
  }
}

$yamlDirectories | ForEach-Object -Process `
  {Write-Output "Initiating copy of YAML configs"} `
  {Write-Output "Copy: $_"} `
  {CopyYaml($_)} `
  {Write-Output "YAML config files copied from ${PRIOR_HOSTNAME}"}

Write-Output "DataDog install completed. Agent remains in state: ${service_check.Status}"