# hw-ssh-tunnels
## Use Yubikeys (in PIV mode) to anchor SSH tunnels between servers

Requirements `sudo apt install yubico-piv-tool opensc opensc-pkcs11`

`yubikey_ssh_provision.sh` is a script to provision a Yubikey with a SSH key (in PIV mode) with an RSA key for SSH authentication.

`yubi_read.sh` is a file to read and obtain the current public key of a yubikey provisioned with `yubikey_ssh_provision.sh` (which you should copy to authorized_hosts file on the remote bastion machine)

`autossh-tunnel.service` is a systemd service file that demonstrates setting up an autossh tunnel that is hardware anchored to the yubikey.   The following variables (in ansible template syntax) are available:
- `{{ ssh_connect_port }}` : Loopback port of the SSH tunnel, on the remote-side (bastion)
- `{{ tunnel_username }}` : Username that the SSH session is to use for authorization
- `{{ ssh_bastion_host }}` : Hostname of the SSH server you intend to connect out to
