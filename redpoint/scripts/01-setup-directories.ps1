# -----------------------------------------------------------------------------------------------------------------------
# 01-setup-directories.ps1
# 
# Purpose:  This script is responsible for replicating the required folder structure expected for today's RPDM environment.
#           Script is restricted to the dedicated RPDM drive only per variable $INSTALL_DIR.
# -----------------------------------------------------------------------------------------------------------------------

# Dedicated RPDM drive for processing
$INSTALL_DRIVE = "E"

# Prior RPDM server host
$PRIOR_SERVER = "PAZRPDMUAT01"

# array of directories to process
$ROOT_DIRS = 'archive', `
  'cdp\10_mars', 'cdp\11_imet', 'cdp\12_ccntr', 'cdp\13_ftnt', 'cdp\15_actpr', `
  'cdp\16_ims', 'cdp\17_ssp', 'cdp\18_wist', 'cdp\19_sdoh', `
  'cdp\20_prsna', 'cdp\21_incontact', 'cdp\22_snwflk', 'cdp\23_trustarc', 'cdp\24_luxsci', `
  'cdp\agg_work', 'cdp\keyfiles', 'cdp\match', 'cdp\RPIDataProjects'



# --NO MODIFICATION REQUIRED BELOW-------------------------------------------------
$INSTALL = "${INSTALL_DRIVE}:"

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

"Creating folder structure... on ${INSTALL}"
$ROOT_DIRS | ForEach-Object -Process {CreateBaseFolder $_}

$ROOT_DIRS | ForEach-Object -Process `
  {Write-Output "Initiating mass copy process.."} `
  {Write-Output "Folder: $_   ------------------------------------------"} `
  {RecursiveCopySourceFolder $_} `
  {Write-Output "Completed: $_   ---------------------------------------"} `
  {Write-Output "Mass copy process completed."}

#security ownership: RPI Developers and RPDM_UAT_USER
"Adding AccessControls to ${INSTALL}\cdp"
$acl = Get-Acl -Path "\\${PRIOR_SERVER}\${INSTALL_DRIVE}$\cdp"
Set-Acl -Path "${INSTALL}\cdp" -AclObject $acl

Write-Output "Processing \quarantine ....."
CreateBaseFolder('quarantine')
RecursiveCopySourceFolder 'quarantine'
"Adding AccessControls to ${INSTALL}\quarantine"
$acl = Get-Acl -Path "\\${PRIOR_SERVER}\${INSTALL_DRIVE}$\quarantine"
Set-Acl -Path "${INSTALL}\quarantine" -AclObject $acl


CreateBaseFolder('Java')
New-Item -Path ${INSTALL}'\rpdm_temp' -ItemType "directory"

"Creating local software repository: ${INSTALL}\Software"
CreateBaseFolder('Software')
Get-ChildItem "\\${PRIOR_SERVER}\${INSTALL_DRIVE}$\Software" | Copy-Item -Recurse -Destination ${INSTALL}\Software -Force

CreateBaseFolder('Temp')