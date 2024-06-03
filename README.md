### Ubuntu OpenVPN Server + MikroTik OVPN Client + Policy-Based Routing Guide

Step 1: Ubuntu OpenVPN Server Installation

Update System and Install OpenVPN and Easy-RSA:


```bash
sudo apt-get update

sudo apt-get install openvpn easy-rsa

```

Setup Easy-RSA:

```bash
make-cadir ~/openvpn-ca
cd ~/openvpn-ca
```


Configure Easy-RSA Variables:

```bash
nano vars
Edit the following variables (set your own values for KEY_COUNTRY, KEY_PROVINCE, KEY_CITY, KEY_ORG, KEY_EMAIL, KEY_OU):
```

```bash
export KEY_COUNTRY="US"
export KEY_PROVINCE="CA"
export KEY_CITY="SanFrancisco"
export KEY_ORG="MyOrg"
export KEY_EMAIL="email@example.com"
export KEY_OU="MyOrgUnit"
export KEY_NAME="server"
```

Build CA and Server Certificates:

```bash
./clean-all
./build-ca
./build-key-server server
./build-dh
./build-key client
```


Create OpenVPN Server Configuration:

```bash
sudo cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn/
sudo gunzip /etc/openvpn/server.conf.gz
sudo nano /etc/openvpn/server.conf
Edit /etc/openvpn/server.conf

```

```plaintext
port 1194
proto tcp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh2048.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
comp-lzo
user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
log openvpn.log
verb 3

```


Copy and Adjust Certificates:

```bash
sudo cp ~/openvpn-ca/keys/{ca.crt,server.crt,server.key,dh2048.pem} /etc/openvpn/
```

Start OpenVPN Service and Enable Autostart:

```bash
sudo systemctl start openvpn@server
sudo systemctl enable openvpn@server
```

Enable IP Forwarding:

```bash
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

Configure UFW (Uncomplicated Firewall):

```bash
sudo ufw allow 1194/tcp
sudo ufw allow OpenSSH
sudo ufw enable
sudo ufw status
```

Edit /etc/ufw/before.rules and add these lines at the top:

```plaintext
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s 10.8.0.0/8 -o eth0 -j MASQUERADE

```

COMMIT
Restart UFW:

```bash
sudo ufw disable
sudo ufw enable

```

Summary
Your Ubuntu OpenVPN server and MikroTik client with policy-based routing are now configured. This setup ensures that specified traffic is routed through the VPN, bypassing any ISP restrictions.

Happy networking!