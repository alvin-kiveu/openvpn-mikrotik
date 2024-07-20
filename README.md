# Ubuntu OpenVPN Server + MikroTik OVPN Client 

This is a guide to setup an OpenVPN server on an Ubuntu machine and connect to it from a MikroTik router.

## OpenVPN Server

### Install OpenVPN

```bash
sudo apt-get update
```

Create a New Folder name OpenVPN

```bash
mkdir OpenVPN
```

```bash
cd OpenVPN
```

```bash
wget https://git.io/vpn -O openvpn-install.sh
```

```bash
chmod +x openvpn-install.sh
```

```bash
sudo ./openvpn-install.sh
```



Remaove 

apt-get install -y wget






