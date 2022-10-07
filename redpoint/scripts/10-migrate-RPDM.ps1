# -----------------------------------------------------------------------------------------------------------------------
# 10-migrate-RPDM.ps1
# 
# Purpose:  This script is responsible for migrating RPDM from one host to another. The script will stop
#           running services, copy required files, and then restart services on the new host.
# -----------------------------------------------------------------------------------------------------------------------

# Dedicated RPDM drive for processing
$INSTALL_DRIVE = "E"

# Prior RPDM server host
$PRIOR_SERVER = Read-Host -Prompt "Prior RPDM hostname?"
$NEW_SERVER = $env:COMPUTERNAME

# array of directories to process
$ROOT_DIRS = 'archive', `
  'cdp\10_mars', 'cdp\11_imet', 'cdp\12_ccntr', 'cdp\13_ftnt', 'cdp\15_actpr', `
  'cdp\16_ims', 'cdp\17_ssp', 'cdp\18_wist', 'cdp\19_sdoh', `
  'cdp\20_prsna', 'cdp\21_incontact', 'cdp\22_snwflk', 'cdp\23_trustarc', 'cdp\24_luxsci', `
  'cdp\agg_work', 'cdp\keyfiles', 'cdp\match', 'cdp\RPIDataProjects'



# --NO MODIFICATION REQUIRED BELOW-------------------------------------------------
$INSTALL = "${INSTALL_DRIVE}:"
$RPDM_SRVC_LIST = 'RedPointDM9_SiteService','RedPointDM9_ExecutionService','RedPointDM9_WebProxyService'


function RecursiveCopySourceFolder([String]$folderName) {
  Get-ChildItem \\${PRIOR_SERVER}\${INSTALL_DRIVE}$\$folderName -depth 0 | 
  ForEach-Object -Process {Write-Output "Starting copy of folder: $folderName"} `
    {Write-Output "Copying folder: $_"} `
    {Copy-Item -Path "\\${PRIOR_SERVER}\${INSTALL_DRIVE}$\$folderName\$_" -Destination ${INSTALL}\$folderName\$_ -Recurse -Force} `
    {Write-Output "Copy completed."}
}

function CreateBaseFolder([String]$folderName){
  if(!(Test-Path -path "${INSTALL}\$folderName")) {  
    Write-Output "adding folder: $folderName"
    New-Item -Path ${INSTALL}\$folderName -ItemType "directory"
  }
}

function StopStartAll([String]$hostServer,[String]$action){
  $RPDM_SRVC_LIST | ForEach-Object `
    -Begin {Write-Output "Stopping Redpoint RPDM services"} `
    -Process {
      Write-Output "Finding service $_ on $hostServer"
      $service = Get-Service -ComputerName $hostServer -Name $_
      if($null -eq $service){
        Write-Output "Service $_ not found on $hostServer... aborting"
        throw "Issue finding service $_ on $hostServer"
      }
      
      if($action -eq "Start"){
        try {
          $service.Start()
        }
        catch {
          Write-Error -Message "Error in starting service. $_"
        }
      }
      else {
        if($service.CanStop){
          try{
            $service.Stop()
          } catch {
            Write-Error -Message "Error in stopping service. $_"
          }
        }
      }
    } `
    -End {Write-Output "Redpoint RPDM services stopped on host $PRIOR_SERVER"}
}

Write-Output "Initiating Redpoint DM code transfer.."
StopStartAll $PRIOR_SERVER "Stop"
StopStartAll $NEW_SERVER "Stop"

Write-Output "Waiting 60seconds for lock files to be cleared..."
Start-Sleep -Seconds 60

$lockFileList = "repository.s3db-shm","repository.s3db-wal"
$lockFileList | ForEach-Object `
  -Begin {Write-Output "Checking for repository lock files on $PRIOR_SERVER.."} `
  -Process {
    $file = "\\${PRIOR_SERVER}\${INSTALL_DRIVE}$\Program Files\RedPointDM9\repository\$_"
    Write-Output "Searching for file: $file"
    if(Test-Path $file){
      Write-Error -Message "Found repository lock file: $file"
      throw "Repository must not be in use before continuing.. exiting"
    }
  } `
  -End {Write-Output "No lock files detected."}

$lockFileList | ForEach-Object `
  -Begin {Write-Output "Checking for repository lock files on $NEW_SERVER.."} `
  -Process {
    $file = "${INSTALL_DRIVE}:\Program Files\RedPointDM9\repository\$_"
    Write-Output "Searching for file: $file"
    if(Test-Path $file){
      Write-Error -Message "Found repository lock file: $file"
      throw "Repository must not be in use before continuing.. exiting"
    }
  } `
  -End {Write-Output "No lock files detected."}

$ROOT_DIRS | ForEach-Object -Process `
  {Write-Output "Initiating mass copy process.."} `
  {Write-Output "Folder: $_   ------------------------------------------"} `
  {RecursiveCopySourceFolder $_} `
  {Write-Output "Completed: $_   ---------------------------------------"} `
  {Write-Output "Mass copy process completed."}

#security ownership: RPI Developers and RPDM_UAT_USER
"Re-Applying AccessControls to ${INSTALL}\cdp"
$acl = Get-Acl -Path "\\${PRIOR_SERVER}\${INSTALL_DRIVE}$\cdp"
Set-Acl -Path "${INSTALL}\cdp" -AclObject $acl

Write-Output "Processing \quarantine ....."
RecursiveCopySourceFolder 'quarantine'
"Adding AccessControls to ${INSTALL}\quarantine"
$acl = Get-Acl -Path "\\${PRIOR_SERVER}\${INSTALL_DRIVE}$\quarantine"
Set-Acl -Path "${INSTALL}\quarantine" -AclObject $acl

Write-Output "Renaming default repository on $NEW_SERVER"
try {
  $suffix = Get-Date -Format "yyyyMMdd"
  Move-Item -Path "${INSTALL_DRIVE}:\Program Files\RedPointDM9\repository" -Destination "${INSTALL_DRIVE}:\Program Files\RedPointDM9\repository-$suffix" -Force
}
catch {
  throw "Failed to move default repository on $NEW_SERVER"
}

RecursiveCopySourceFolder "Program Files\RedPointDM9\repository"
if(!(Test-Path -Path "${INSTALL_DRIVE}:\Program Files\RedPointDM9\repository")){
  Write-Error -Message "Recursive copy of repository suspect.. stopping script"
  throw "Missing \repository subdirectory on $NEW_SERVER"
}

Write-Output "Enabling advanced security mode"
try {
  $coreConfig = "${INSTALL_DRIVE}:\Program Files\RedPointDM9\CoreCfg.properties"
  ((Get-Content -path $coreConfig -Raw) -replace "enable_advanced_security=false","enable_advanced_security=true") | Set-Content -Path $coreConfig
}
catch {
  Write-Error -Message "Failed to enable security mode. Please confirm 'enable_advanced_security' setting in $coreConfig"
}

Write-Output "Restarting $NEW_SERVER"
StopStartAll $NEW_SERVER "Start"

Write-Output "License key may require re-installation. Connect to the new server via the RPDM client to confirm."
Write-Output "Migration complete."