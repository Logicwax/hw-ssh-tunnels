#!/bin/bash

# Script to automate the provisioning of a new SSH certificate onto a yubikey device.
set -e
set -u
set -o pipefail

for path in "/usr/lib64/opensc-pkcs11.so" \
            "/usr/lib/opensc-pkcs11.so" \
            "/usr/local/lib/opensc-pkcs11.so" \
            "/opt/local/lib/opensc-pkcs11.so" \
            "/usr/local/Cellar/opensc/*/lib/opensc-pkcs11.so" \
	        "/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so"
do
    if [[ -f $path ]]
    then
        OPENSC_LIBS="$(dirname $path)"
        break
    fi
done

echo "[+] Make sure to remove any personal attached yubikeys as this script will factory reset!"
read -p "Press <ENTER> to continue."
echo "[+] Using ${OPENSC_LIBS} for PKCS11 smartcard support."

SLOT=${SLOT:-9e}
TDIR=$(mktemp -d)

# Attempt to detect yubico-piv-tool path
YPIV="$(which yubico-piv-tool)"

trap 'rm -rf ${TDIR}' EXIT

mgmt_key=$(dd if=/dev/random bs=1 count=24 2>/dev/null | hexdump -v -e '/1 "%02X"')

sudo killall ssh-agent gpg-agent pcscd 2> /dev/null || true
sudo killall ssh-agent gpg-agent pcscd 2> /dev/null || true

# Force the old PINs to be blocked.
echo "[+] Lock the security token by using the wrong pin."
for _ in $(seq 0 5)
do
    "$YPIV" -a verify-pin -P 000000 || true
    "$YPIV" -a change-puk -P 000000 -N 000001 || true
done
"$YPIV" -a reset

# Configure PINs
"$YPIV" -a set-mgm-key -n "${mgmt_key}"

# Generate self-signed certificate, later use the CA.
echo "[+] Generating new SSH certificate on the hardware token; this may take a moment."
"$YPIV" -a generate "--key=${mgmt_key}" -s "$SLOT" --touch-policy=never --pin-policy=never -o "${TDIR}/public.pem"
echo "[+] Self-signing generated certificate."
echo "[+]"
echo "[+]"
"$YPIV" -a selfsign-certificate -s "$SLOT" -S '/CN=SSH key/' -i "${TDIR}/public.pem" -o "${TDIR}/cert.pem"
echo "[+] Loading the self-signed certificate onto the hardware token."
"$YPIV" -a import-certificate "--key=${mgmt_key}" -s "$SLOT" -i "${TDIR}/cert.pem"

# Dump the authorized-keys header for the user
killall ssh-agent gpg-agent pcscd 2> /dev/null || :
ssh-agent -a /tmp/ssh-agent.socket
echo -e "123456\n" | DISPLAY=:0 SSH_ASKPASS=tee SSH_AUTH_SOCK=/tmp/ssh-agent.socket ssh-add -s "$OPENSC_LIBS/opensc-pkcs11.so"
rm -rf "Enter passphrase for PKCS#11: "
echo -e "\n\n[+] SSH Public key stored in file \"yubikey_ssh_pubkey.asc\""
echo "[+] SSH Public Key: "
SSH_AUTH_SOCK=/tmp/ssh-agent.socket ssh-add -L | tee yubikey_ssh_pubkey.asc
