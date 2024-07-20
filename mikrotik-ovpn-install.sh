#!/bin/bash
#
# https://github.com/alvin-kiveu/openvpn-mikrotik.git
#
# Copyright (c) 2013 Nyr. Released under the MIT License.


# Detect Debian users running the script with "sh" instead of bash
if readlink /proc/$$/exe | grep -q "dash"; then
    echo 'This installer needs to be run with "bash", not "sh".'
    exit
fi

# Discard stdin. Needed when running from an one-liner which includes a newline
read -N 999999 -t 0.001

# Detect OpenVZ 6
if [[ $(uname -r | cut -d "." -f 1) -eq 2 ]]; then
    echo "The system is running an old kernel, which is incompatible with this installer."
    exit
fi

# Detect OS
# $os_version variables aren't always in use, but are kept here for convenience
if grep -qs "ubuntu" /etc/os-release; then
    os="ubuntu"
    os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
    group_name="nogroup"
elif [[ -e /etc/debian_version ]]; then
    os="debian"
    os_version=$(grep -oE '[0-9]+' /etc/debian_version | head -1)
    group_name="nogroup"
elif [[ -e /etc/almalinux-release || -e /etc/rocky-release || -e /etc/centos-release ]]; then
    os="centos"
    os_version=$(grep -shoE '[0-9]+' /etc/almalinux-release /etc/rocky-release /etc/centos-release | head -1)
    group_name="nobody"
elif [[ -e /etc/fedora-release ]]; then
    os="fedora"
    os_version=$(grep -oE '[0-9]+' /etc/fedora-release | head -1)
    group_name="nobody"
else
    echo "This installer seems to be running on an unsupported distribution.
Supported distros are Ubuntu, Debian, AlmaLinux, Rocky Linux, CentOS and Fedora."
    exit
fi

if [[ "$os" == "ubuntu" && "$os_version" -lt 1804 ]]; then
    echo "Ubuntu 18.04 or higher is required to use this installer.
This version of Ubuntu is too old and unsupported."
    exit
fi

if [[ "$os" == "debian" && "$os_version" -lt 9 ]]; then
    echo "Debian 9 or higher is required to use this installer.
This version of Debian is too old and unsupported."
    exit
fi

if [[ "$os" == "centos" && "$os_version" -lt 7 ]]; then
    echo "CentOS 7 or higher is required to use this installer.
This version of CentOS is too old and unsupported."
    exit
fi

# Detect environments where $PATH does not include the sbin directories
if ! grep -q sbin <<< "$PATH"; then
    echo '$PATH does not include sbin. Try using "su -" instead of "su".'
    exit
fi

if [[ "$EUID" -ne 0 ]]; then
    echo "This installer needs to be run with superuser privileges."
    exit
fi

if [[ ! -e /dev/net/tun ]] || ! ( exec 7<>/dev/net/tun ) 2>/dev/null; then
    echo "The system does not have the TUN device available.
TUN needs to be enabled before running this installer."
    exit
fi

# Function to create a new user with username and password
new_client () {
    echo
    echo "Enter a username for the new client:"
    read -p "Username: " username
    until [[ -n "$username" ]]; do
        echo "Username cannot be empty."
        read -p "Username: " username
    done

    echo
    echo "Enter a password for the new client:"
    read -s -p "Password: " password
    echo
    until [[ -n "$password" ]]; do
        echo "Password cannot be empty."
        read -s -p "Password: " password
        echo
    done

    echo "$username $password" >> /etc/openvpn/server/credentials.txt
}

if [[ ! -e /etc/openvpn/server/server.conf ]]; then
    # Detect some Debian minimal setups where neither wget nor curl are installed
    if ! hash wget 2>/dev/null && ! hash curl 2>/dev/null; then
        echo "Wget is required to use this installer."
        read -n1 -r -p "Press any key to install Wget and continue..."
        apt-get update
        apt-get install -y wget
    fi
    clear
    echo 'Welcome to this OpenVPN road warrior installer!'
    # If system has a single IPv4, it is selected automatically. Else, ask the user
    if [[ $(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}') -eq 1 ]]; then
        ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}')
    else
        number_of_ip=$(ip -4 addr | grep inet | grep -vEc '127(\.[0-9]{1,3}){3}')
        echo
        echo "Which IPv4 address should be used?"
        ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | nl -s ') '
        read -p "IPv4 address [1]: " ip_number
        until [[ -z "$ip_number" || "$ip_number" =~ ^[0-9]+$ && "$ip_number" -le "$number_of_ip" ]]; do
            echo "$ip_number: invalid selection."
            read -p "IPv4 address [1]: " ip_number
        done
        [[ -z "$ip_number" ]] && ip_number="1"
        ip=$(ip -4 addr | grep inet | grep -vE '127(\.[0-9]{1,3}){3}' | cut -d '/' -f 1 | grep -oE '[0-9]{1,3}(\.[0-9]{1,3}){3}' | sed -n "$ip_number"p)
    fi
    # If $ip is a private IP address, the server must be behind NAT
    if echo "$ip" | grep -qE '^(10\.|172\.1[6789]\.|172\.2[0-9]\.|172\.3[01]\.|192\.168)'; then
        echo
        echo "This server is behind NAT. What is the public IPv4 address or hostname?"
        # Get public IP and sanitize with grep
        get_public_ip=$(grep -m 1 -oE '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' <<< "$(wget -T 10 -t 1 -4qO- "http://ip1.dynupdate.no-ip.com/" || curl -m 10 -4Ls "http://ip1.dynupdate.no-ip.com/")")
        read -p "Public IPv4 address / hostname [$get_public_ip]: " public_ip
        # If the checkip service is unavailable and user didn't provide input, ask again
        until [[ -n "$get_public_ip" || -n "$public_ip" ]]; do
            echo "Invalid input."
            read -p "Public IPv4 address / hostname: " public_ip
        done
        [[ -z "$public_ip" ]] && public_ip="$get_public_ip"
    fi
    # If system has a single IPv6, it is selected automatically
    if [[ $(ip -6 addr | grep -c 'inet6 [23]') -eq 1 ]]; then
        ip6=$(ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}')
    fi
    # If system has multiple IPv6, ask the user to select one
    if [[ $(ip -6 addr | grep -c 'inet6 [23]') -gt 1 ]]; then
        number_of_ip6=$(ip -6 addr | grep -c 'inet6 [23]')
        echo
        echo "Which IPv6 address should be used?"
        ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}' | nl -s ') '
        read -p "IPv6 address [1]: " ip6_number
        until [[ -z "$ip6_number" || "$ip6_number" =~ ^[0-9]+$ && "$ip6_number" -le "$number_of_ip6" ]]; do
            echo "$ip6_number: invalid selection."
            read -p "IPv6 address [1]: " ip6_number
        done
        [[ -z "$ip6_number" ]] && ip6_number="1"
        ip6=$(ip -6 addr | grep 'inet6 [23]' | cut -d '/' -f 1 | grep -oE '([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}' | sed -n "$ip6_number"p)
    fi
    echo
    echo "What protocol should OpenVPN use?"
    echo "   1) UDP"
    echo "   2) TCP"
    read -p "Protocol [1]: " protocol_number
    until [[ -z "$protocol_number" || "$protocol_number" =~ ^[1-2]$ ]]; do
        echo "$protocol_number: invalid selection."
        read -p "Protocol [1]: " protocol_number
    done
    [[ -z "$protocol_number" ]] && protocol_number="1"
    protocol=$([[ "$protocol_number" == "1" ]] && echo "udp" || echo "tcp")
    echo
    echo "What port should OpenVPN listen to?"
    read -p "Port [1194]: " port
    until [[ -z "$port" || "$port" =~ ^[0-9]+$ && "$port" -le 65535 ]]; do
        echo "$port: invalid port."
        read -p "Port [1194]: " port
    done
    [[ -z "$port" ]] && port="1194"
    echo
    echo "What DNS do you want to use with the VPN?"
    echo "   1) Current system resolvers"
    echo "   2) Google"
    echo "   3) OpenDNS"
    echo "   4) Cloudflare"
    read -p "DNS [1]: " dns
    until [[ -z "$dns" || "$dns" =~ ^[1-4]$ ]]; do
        echo "$dns: invalid selection."
        read -p "DNS [1]: " dns
    done
    case "$dns" in
        2)
            dns1="8.8.8.8"
            dns2="8.8.4.4"
            ;;
        3)
            dns1="208.67.222.222"
            dns2="208.67.220.220"
            ;;
        4)
            dns1="1.1.1.1"
            dns2="1.0.0.1"
            ;;
        *)
            dns1=$(awk '/^nameserver/ { print $2; exit }' /etc/resolv.conf)
            dns2=$(awk '/^nameserver/ { print $2; exit }' /etc/resolv.conf | sed -n 2p)
            ;;
    esac
    echo
    echo "Enable IPv6 support? (y/n)"
    read -p "Enable IPv6 support [n]: " ipv6
    until [[ -z "$ipv6" || "$ipv6" =~ ^[yn]$ ]]; do
        echo "$ipv6: invalid selection."
        read -p "Enable IPv6 support [n]: " ipv6
    done
    [[ -z "$ipv6" ]] && ipv6="n"
    ipv6=$([[ "$ipv6" == "y" ]] && echo "true" || echo "false")
    echo
    echo "Choose a client name:"
    read -p "Client name: " client
    until [[ -n "$client" ]]; do
        echo "Client name cannot be empty."
        read -p "Client name: " client
    done
    echo
    echo "Enter a username for the new client:"
    read -p "Username: " username
    until [[ -n "$username" ]]; do
        echo "Username cannot be empty."
        read -p "Username: " username
    done

    echo
    echo "Enter a password for the new client:"
    read -s -p "Password: " password
    echo
    until [[ -n "$password" ]]; do
        echo "Password cannot be empty."
        read -s -p "Password: " password
        echo
    done

    # Install required packages
    if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
        apt-get update
        apt-get install -y openvpn iptables openssl ca-certificates wget curl
    elif [[ "$os" == "centos" || "$os" == "fedora" ]]; then
        yum install -y epel-release
        yum install -y openvpn iptables openssl ca-certificates wget curl
    fi

    # Configure OpenVPN server
    mkdir -p /etc/openvpn/server
    cp /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz /etc/openvpn/server/
    gunzip /etc/openvpn/server/server.conf.gz

    # Edit OpenVPN server configuration to use username/password authentication
    sed -i '/^auth-user-pass-verify/d' /etc/openvpn/server/server.conf
    sed -i '/^username-as-common-name/d' /etc/openvpn/server/server.conf
    echo "auth SHA256" >> /etc/openvpn/server/server.conf
    echo "auth-user-pass-verify /etc/openvpn/server/verify.sh via-file" >> /etc/openvpn/server/server.conf
    echo "username-as-common-name" >> /etc/openvpn/server/server.conf

    # Create script to verify username and password
    echo "#!/bin/bash
    # Verify username and password
    while IFS=: read -r user pass; do
        if [[ \"\$username\" == \"\$user\" && \"\$password\" == \"\$pass\" ]]; then
            exit 0
        fi
    done < /etc/openvpn/server/credentials.txt
    exit 1" > /etc/openvpn/server/verify.sh
    chmod +x /etc/openvpn/server/verify.sh

    # Update the firewall and enable IP forwarding
    if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
        ufw allow $port/$protocol
        ufw allow OpenSSH
        echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        sysctl -p
        ufw enable
    elif [[ "$os" == "centos" || "$os" == "fedora" ]]; then
        firewall-cmd --add-port=$port/$protocol
        firewall-cmd --add-service=ssh
        firewall-cmd --permanent --add-port=$port/$protocol
        firewall-cmd --permanent --add-service=ssh
        echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
        sysctl -p
        systemctl start firewalld
        systemctl enable firewalld
    fi

    # Start and enable OpenVPN
    systemctl start openvpn-server@server
    systemctl enable openvpn-server@server

    # Create client configuration
    mkdir -p /etc/openvpn/clients
    echo "client
    dev tun
    proto $protocol
    remote $public_ip $port
    resolv-retry infinite
    nobind
    persist-key
    persist-tun
    remote-cert-tls server
    auth SHA256
    auth-user-pass
    verb 3" > /etc/openvpn/clients/"$client".ovpn

    echo
    echo "OpenVPN server setup is complete."
    echo "Client configuration is available at /etc/openvpn/clients/$client.ovpn"
    echo "Add the following lines to your OpenVPN client configuration file to use username and password authentication:"
    echo "auth-user-pass"
		exit
fi


# Run the client creation function
new_client
