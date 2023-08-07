# -----------------------------------------------------------------------------------------------------------------------
# NetshRPIServices-Check.ps1
# 
# Purpose:  RPI runs two separate web services. One service runs under IIS' application pool under the standard SSL port 443. The 
#           other service runs under port 8180.
#           When a certificate change occurs, this script will detect if the certificate hashes are not in agreement. When this occurs
#           the certificate being used for port 8180 must also be updated.
#
# -----------------------------------------------------------------------------------------------------------------------

$IIS_SSL_PORT = "443"
$NODE_MANAGER_PORT = "8180"
$InformationPreference = 'Continue'

function CertificateHashMatch($port1, $port2) {
    Write-Information "Retrieving current SSH bindings"

    $attrs = @('IP:port','Certificate Hash','Application ID','Certificate Store Name')

    $netshresult = Invoke-Command {netsh http show sslcert}
    $result = @{}

    $netObjResult = @()

    $netshresult = $netshresult | select-string : #break into chunks if colon  only
    $i = 0
    #load netsh results into a dict array structure for quick access
    while($i -lt $netshresult.length){
        $line = $netshresult[$i]
        $line = $line -split(" : ")

        # Write-Output "Processing line: $line"
        if($line.Count -ne 2){
            $i++
            continue
        }
        $line[0] = $line[0].trim()
        $line[1] = $line[1].trim()

        if($line[0] -in $attrs){
            $result.$($line[0]) = $($line[1])
        }

        if($result.Count -eq 4){
            $netObj = New-Object psobject -property @{
                IPandPort = $null
                CertificateHash = $null
                ApplicationID = $null
                CertificateStoreName = $null
            }

            $netObj.IPandPort = $result.'IP:port'
            $netObj.CertificateHash = $result.'Certificate Hash'
            $netObj.ApplicationID = $result.'Application ID'
            $netObj.CertificateStoreName = $result.'Certificate Store Name'
            $netObjResult += $netObj
            $result = @{}
        }

        $i++
    }

    $result1 = $netObjResult | Where-Object {$_.IPandPort -eq ('0.0.0.0:' + $port1) }
    $result2 = $netObjResult | Where-Object {$_.IPandPort -eq '0.0.0.0:' + $port2}

    if( $null -eq $result1){
        Write-Error "Port: $port1 not currently bound to anything"
        throw "Missing Port: $port1 binding"
    }

    if( $null -eq $result2){
        Write-Error "Port: $port2 not currently bound to anything"
        throw "Missing Port: $port2 binding"
    }


    if( $result1.CertificateHash -ne $result2.CertificateHash) {
        Write-Warning "Certificate hashes are not in agreement"
        return $false, @($result1, $result2)
    } else {
        Write-Information  "Certificate hashes agree. Nothing to do."
        return $true
    }
}

function UpdateCert($cert1, $cert2) {
    $deleteCmd = "netsh http delete sslcert ipport=" + $cert2.'IPandPort'
    Write-Information "Invoking request to delete existing cert: "
    Write-Information $deleteCmd
    $delete = Invoke-Command {$deleteCmd}
    Write-Information "result: $delete"

    $updateCmd = "netsh http add sslcert ipport=" + $cert2.'IPandPort'
    $updateCmd += " certstorename=" + $cert1.'CertificateStoreName'
    $updateCmd += " certhash=" + $cert1.'CertificateHash' 
    $updateCmd += " appid=" + $cert2.'ApplicationID'
    Write-Information "Invoking request to update ssl cert: "
    Write-Information $updateCmd
    $update = Invoke-Command {$updateCmd}
    Write-Information "result: $update"
}

$match, $hashMatchResults = CertificateHashMatch $IIS_SSL_PORT $NODE_MANAGER_PORT

if(!$match){
    Write-Information "Certificates do not match!.. updating"
    Write-Information $hashMatchResults

    UpdateCert $hashMatchResults[0] $hashMatchResults[1]

    Write-Information "Confirming results"
    $matchCheck, $hashMatchResults = CertificateHashMatch $IIS_SSL_PORT $NODE_MANAGER_PORT

    if($matchCheck){
        Write-Information "Certificates match.. a restart of services maybe required"
    } else {
        Write-Warning "Certificates still do not match. Contact the administrator."
    }

} else {
    Write-Information "Certificates match.. nothing to do."
}