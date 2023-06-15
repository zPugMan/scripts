# Utility Scripts
A miscellaneous collection of utility scripts to support the day-to-day.

## CryptoSecrets
This powershell script provides encryption and decryption capabilities. It was modelled after Mulesoft's, java-based Secure Properties tool. Use of this script allows for the encryption of secrets with a shared decryption key.

### Usage
* Generate a key for encrypting / decrypting
    `.\CryptoSecrets.ps1 -action GenerateKey`

* Encrypt a secret
    `.\CryptoSecrets.ps1 -action Encrypt`

    This command will then provide a series of prompts. 
    * A request for an encryption key. 
    * Secret to encrypt using that shared encryption key.
    * (optional) the next secret to encrypt using that same key. If no value is provided, the program will exit.

* Decrypt a secret
    `.\CryptoSecrets.ps1 -action Encrypt`

    This command will then provide a series of prompts.
    * A request for an encryption key. 
    * Encypted string to decrypt using that shared encryption key.
    * (optional) the next encrypted string to decrypt using that same key. If no value is provided, the program will exit.