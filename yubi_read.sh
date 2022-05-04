#!/bin/bash

# Script to read the current ssh pubkey located on the yubikey

set -e
set -u
set -o pipefail

for SCPATH in "/usr/lib64/opensc-pkcs11.so" \
            "/usr/lib/opensc-pkcs11.so" \
            "/usr/local/lib/opensc-pkcs11.so" \
            "/opt/local/lib/opensc-pkcs11.so" \
            "/usr/local/Cellar/opensc/*/lib/opensc-pkcs11.so" \
	        "/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so"

do
    if [[ -f $SCPATH ]]
    then
        break
    fi
done
# Dump the authorized-keys header for the user
killall ssh-agent gpg-agent pcscd 2> /dev/null || :
ssh-agent -a /tmp/ssh-agent.socket
echo -e "123456\n" | SSH_ASKPASS=tee SSH_AUTH_SOCK=/tmp/ssh-agent.socket ssh-add -s "$SCPATH" 
echo -e "\n\n[+] SSH Public key stored in file \"yubikey_ssh_pubkey.asc\""
echo "[+] SSH Public Key: "
SSH_AUTH_SOCK=/tmp/ssh-agent.socket ssh-add -L | tee yubikey_ssh_pubkey.asc
