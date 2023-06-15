# -----------------------------------------------------------------------------------------------------------------------
# CryptoSecrets.ps1
# 
# Purpose:  This script provides encryption and decryption utilities. It operates in a similar vane to Mulesoft's java-based 
#           Secure Properties Tool.
#
# Available Actions:
#   GenerateKey - Generates a key to use for encryption/decryption. Keep this safe!!
#   Encrypt - Encrypts one or more values using the provided key
#   Decrypt - Decrypts one or more values using the provided key
#           
# -----------------------------------------------------------------------------------------------------------------------
param(
    [Parameter(Mandatory=$true, HelpMessage="One of: GenerateKey | Encrypt | Decrypt")]
    [string]$action
)

function GetAesObject($key, $value) {
    $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
    $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
    $aesManaged.BlockSize = 128
    $aesManaged.KeySize = 256

    if($IV) {
        if($IV.GetType().Name -eq "string") {
            $aesManaged.IV = [System.Convert]::FromBase64String($IV)
        }
        else {
            $aesManaged.IV = $IV
        }
    }

    if($key) {
        if ($key.GetType().Name -eq "string") {
            $aesManaged.Key = [System.Convert]::FromBase64String($key)
        }
        else 
        {
            $aesManaged.Key = $key
        }
    }

    $aesManaged
}

function Encrypt-String($key, $plaintext) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($plaintext)
    $aesManaged = GetAesObject $key
    $encryptor = $aesManaged.CreateEncryptor()
    $encryptedData = $encryptor.TransformFinalBlock($bytes, 0, $bytes.Length);
    [byte[]] $fullData = $aesManaged.IV + $encryptedData
    return [System.Convert]::ToBase64String($fullData)
}

function Decrypt-String($key, $encryptedStringWithIV) {
    $bytes = [System.Convert]::FromBase64String($encryptedStringWithIV)
    $IV = $bytes[0..15]
    $aesManaged = GetAesObject $key $IV
    $decryptor = $aesManaged.CreateDecryptor();
    $unencryptedData = $decryptor.TransformFinalBlock($bytes, 16, $bytes.Length - 16);
    $aesManaged.Dispose()
    [System.Text.Encoding]::UTF8.GetString($unencryptedData).Trim([char]0)
}

if($action -eq 'GenerateKey') {
    Write-Output "Generating encryption key"
    $aes = New-Object "System.Security.Cryptography.AesManaged"
    $aes.GenerateKey()
    $secretKey = [System.Convert]::ToBase64String($aes.Key)
    Write-Output "Key: $secretKey"
}
elseif($action -eq 'Encrypt') {
    $key = Read-Host -Prompt "Encryption Key? " -AsSecureString
    if($key.Length -eq 0) {
        Write-Error "Encryption key is required."
        exit
    }
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($key)
    $keySecret = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)

    $repeat = $true
    while($repeat) {
        $value = Read-Host -Prompt "Value to Encrypt? " -AsSecureString
        if($value.Length -eq 0){
            $repeat = $false
            Write-Output "No value provided.. exiting"
            break
        }

        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($value)
        $secretValue = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)

        $encryptedString = Encrypt-String $keySecret $secretValue
        Write-Output "Encrypted value: $encryptedString"
    }
    
    
}
elseif($action -eq 'Decrypt') {
    $key = Read-Host -Prompt "Encryption Key? " -AsSecureString
    if($key.Length -eq 0) {
        Write-Error "Encryption key is required."
        exit
    }
    $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($key)
    $keySecret = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($Ptr)

    $repeat = $true
    While($repeat) {
        $value = Read-Host -Prompt "Encrypted value? "
        if($value.Length -eq 0) {
            $repeat = $false
            Write-Output "No value provided.. exiting"
            break
        }

        $unencrypted = Decrypt-String $keySecret $value
        Write-Output "Decrypted value: $unencrypted"
    }

}
else {
    Write-Output("Required parameters: 
        - Action: GenerateKey | Encrypt | Decrypt")
}


