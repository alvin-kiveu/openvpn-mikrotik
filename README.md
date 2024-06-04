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
./easyrsa build-client-full client1 nopass
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

How to Export the Client Certificate and Key Pair that you will use on the MikroTik Router:

```bash
cd /etc/openvpn/easy-rsa/pki
```

```bash
cp ca.crt /etc/openvpn/client/
cp issued/client1.crt /etc/openvpn/client/
cp private/client1.key /etc/openvpn/client/
```

Update the OpenVPN server configuration file to reflect the changes:

```bash
nano /etc/openvpn/server.conf
```

Add the following lines to the server.conf file:

```bash
ca /etc/openvpn/client/ca.crt
cert /etc/openvpn/client/client1.crt
key /etc/openvpn/client/client1.key
```

Save the file and exit the editor.


Restart the OpenVPN service:

```bash
service openvpn restart
```


## Step 2: MikroTik OVPN Client Configuration

Login to your MikroTik router and navigate to the System menu and click on the Certificates option.

Click on the Import button and import the CA certificate, client certificate, and client key.

Navigate to the PPP menu and click on the Interface tab.

Click on the OVPN Client button and add a new OVPN client.



Fill in the required information:

Name: Name of the OVPN client <Client1>

Connect To: Public IP address of the OpenVPN server <Public IP Address>

Port: 1194 (default)

Mode: ip (default)

User: Username (if required)

Password: Password (if required)

Certificate: Client certificate imported in the MikroTik router

Auth: sha1 (default)

Cipher: aes256 (default)




Add a new route to the OVPN client:

1. After creating the OVPN client interface, select it from the list of interfaces.

2. Click on the "Routes" button.

3. Add a new route with the following information:

Dst. Address:

4. Leave the Gateway field blank.

5. Leave "Check Gateway" unchecked.

6. Leave "Routing Mark" blank.

7. Keep the Distance as default (1).

8. Click on the "OK" button to save the route.

9. Repeat these steps to add additional routes if needed.


## Step 3: Policy-Based Routing Configuration

Navigate to the IP menu and click on the Firewall tab.

Click on the Mangle button and add a new rule.

Fill in the required information:

Chain: prerouting

Src. Address: IP address of the device you want to route through the OpenVPN server

Action: mark routing

New Routing Mark: ovpn

Click on the "OK" button to save the rule.

Navigate to the IP menu and click on the Routes tab.


Click on the "+" button to add a new route.

Fill in the required information:

Dst. Address:

Gateway: IP address of the OpenVPN server

Routing Mark: ovpn

Click on the "OK" button to save the route.

Repeat these steps to add additional routes if needed.












