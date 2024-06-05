# Ubuntu OpenVPN Server + MikroTik OVPN Client + Policy-Based Routing Guide

Step 1: Ubuntu OpenVPN Server Installation

Update System and Install OpenVPN and Easy-RSA:


```bash
sudo apt-get update

sudo apt-get install openvpn easy-rsa

```

### Navigate to the /etc/openvpn directory
  
  ```bash
cd /etc/openvpn
```

### Create a directory named easy-rsa

```bash
mkdir easy-rsa
```


### Copy the easy-rsa files to the /etc/openvpn/easy-rsa directory

```bash
cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
```


### Change the permissions of all files and directories within easy-rsa to make them executable

```bash
chmod -R 755 /etc/openvpn/easy-rsa/
```

## Create the vars file

### Navigate to the /etc/openvpn/easy-rsa directory

```bash
cd /etc/openvpn/easy-rsa
```

### Create the vars file

```bash
nano vars
```

Save the vars file empty and add the following lines buy hiting Ctrl+O and Ctrl+X


Then copy the vars.example file to the vars file

```bash
cp vars.example vars
```

Give the vars file the correct permissions

```bash
chmod 755 vars
```

Edit the vars file

```bash
nano vars
```

Find the following lines and change them to match the information below:

```bash
export KEY_COUNTRY="US"
export KEY_PROVINCE="CA"
export KEY_CITY="SanFrancisco"
export KEY_ORG="Fort-Funston"
export KEY_EMAIL="example@email.com"
export KEY_OU="MyOrganizationalUnit"
```

Create a CA Certificate and Key

```bash
./easyrsa init-pki
```

THE OUTPUT WILL BE SOMETHING LIKE THIS:

```bash
Notice
------
'init-pki' complete; you may now create a CA or requests.

Your newly created PKI dir is:
* /etc/openvpn/easy-rsa/pki

Using Easy-RSA configuration:
* /etc/openvpn/easy-rsa/vars

```

Build the Certificate Authority

```bash
./easyrsa build-ca
```

Fil the information as you want and hit enter

The certificate will be located in the


CA creation complete. Your new CA certificate is at:
* /etc/openvpn/easy-rsa/pki/ca.crt



# Create a certificate/key for the server:

```bash
./easyrsa build-server-full server nopass
```


A server certificate and key will be created in the /etc/openvpn/easy-rsa/pki/issued/server.crt



### Generating keys for encryption of SSL/TLS connections:

```bash
cd /etc/openvpn/easy-rsa/

./easyrsa gen-dh
```


### Create Keys for the Client:

```bash
./easyrsa build-client-full C001 nopass
```

Replace client with the name you want to use for your client. This command will generate a certificate and key pair for the client. The certificate will be located in the /etc/openvpn/easy-rsa/pki/issued/client.crt directory.


Create OpenVPN Server Configuration:

```bash
nano /etc/openvpn/server.conf
```

Add the following lines to the server.conf file:

```bash
port 1194
proto udp
dev tun
ca /etc/openvpn/easy-rsa/pki/ca.crt
cert /etc/openvpn/easy-rsa/pki/issued/server.crt
key /etc/openvpn/easy-rsa/pki/private/server.key
dh /etc/openvpn/easy-rsa/pki/dh.pem

server 10.0.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt

push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120

cipher AES-256-CBC

user nobody
group nogroup
persist-key
persist-tun
status openvpn-status.log
verb 3

explicit-exit-notify 1
```

Save the file and exit the editor.

Allow port 1194 through the firewall:

```bash
ufw allow 1194/udp
```

Enable IP Forwarding:

```bash
nano /etc/sysctl.conf
```

Find the following line and uncomment it:

```bash
net.ipv4.ip_forward=1
```


Save the file and exit the editor.

Install iptables-persistent:

```bash
apt-get install iptables-persistent
```

Apply the changes:

```bash
sysctl -p
```

Add rules into iptables /etc/iptables:

```bash
nano /etc/iptables/rules.v4
```

Add the following lines to the rules.v4 file:

```bash
# NAT table rules
*nat
:POSTROUTING ACCEPT [0:0]
# Allow traffic from OpenVPN client to eth0
-A POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE
COMMIT
```

Save the iptables Rules:

```bash
iptables-restore < /etc/iptables/rules.v4
```

Restart the OpenVPN service:

```bash
service openvpn restart
```


Save the file and exit the editor.


Now you can start the OpenVPN service:

```bash
service openvpn start
```

Enable the OpenVPN service to start on boot:

```bash
systemctl enable openvpn
```

Add openvpn service in autoload:

```bash
update-rc.d openvpn enable
```

Restart the OpenVPN service:

```bash
service openvpn restart
```

Check the status of the OpenVPN service:

```bash
service openvpn status
```

Get your CA certificate, client certificate, and client key from the /etc/openvpn/easy-rsa/pki/ directory. You will need these files to configure the OpenVPN client.

CA Certificate:

```bash
cat /etc/openvpn/easy-rsa/pki/ca.crt
```

Client Certificate:

```bash
cat /etc/openvpn/easy-rsa/pki/issued/C001.crt
```

Client Key:

```bash
cat /etc/openvpn/easy-rsa/pki/private/C001.key
```

Copy and both and save them in a safe place. 




The OpenVPN server is now installed and configured. The next step is to configure the MikroTik OVPN client.


### Step 1: MikroTik OVPN Client Configuration

1. Open the Winbox application and log in to your MikroTik router.

2. Click on the System menu and select the Certificates option.

3. Click on the Import button and import the CA certificate, client certificate, and client key that you saved from the OpenVPN server.

4. Click on Interfaces and select the OVPN Client option.

5. Click on the Add New button to create a new OVPN client.

6. Fill in the Name, Connect To, User, Password, Certificate, and Key fields with the appropriate information.

7. Click on the OK button to save the OVPN client configuration.

8. Click on the Enable button to enable the OVPN client.

9. The MikroTik OVPN client is now configured and connected to the OpenVPN server. You can now configure policy-based routing on the MikroTik router.


### Step 3: MikroTik Policy-Based Routing Configuration





