#!/bin/bash

# WireGuard VPN Server Auto-Installation Script
# Supports: Ubuntu, Debian, CentOS, Fedora, RHEL

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== WireGuard VPN Server Installation Script ===${NC}\n"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}" 
   exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION_ID=$VERSION_ID
else
    echo -e "${RED}Cannot detect OS. Exiting.${NC}"
    exit 1
fi

echo -e "${YELLOW}Detected OS: $OS $VERSION_ID${NC}\n"

# Install WireGuard based on OS
echo -e "${GREEN}Installing WireGuard...${NC}"
case $OS in
    ubuntu|debian)
        apt-get update
        apt-get install -y wireguard wireguard-tools qrencode iptables
        ;;
    centos|rhel|fedora)
        if [[ "$OS" == "centos" || "$OS" == "rhel" ]]; then
            yum install -y epel-release elrepo-release
            yum install -y kmod-wireguard wireguard-tools qrencode iptables
        else
            dnf install -y wireguard-tools qrencode iptables
        fi
        ;;
    *)
        echo -e "${RED}Unsupported OS: $OS${NC}"
        exit 1
        ;;
esac

# Configuration
WG_DIR="/etc/wireguard"
WG_CONF="$WG_DIR/wg0.conf"
SERVER_PRIVKEY="$WG_DIR/server_private.key"
SERVER_PUBKEY="$WG_DIR/server_public.key"
CLIENT_DIR="$WG_DIR/clients"

# Create directories
mkdir -p $CLIENT_DIR

# Get server's public IP
echo -e "\n${GREEN}Detecting server IP address...${NC}"
SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || curl -s ipecho.net/plain)
if [ -z "$SERVER_IP" ]; then
    echo -e "${RED}Could not detect public IP. Please enter manually:${NC}"
    read -p "Server public IP: " SERVER_IP
fi
echo -e "Server IP: ${YELLOW}$SERVER_IP${NC}"

# Get network interface
DEFAULT_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
read -p "Network interface [$DEFAULT_IFACE]: " NET_IFACE
NET_IFACE=${NET_IFACE:-$DEFAULT_IFACE}

# WireGuard port
read -p "WireGuard UDP port [51820]: " WG_PORT
WG_PORT=${WG_PORT:-51820}

# Generate server keys
echo -e "\n${GREEN}Generating server keys...${NC}"
wg genkey | tee $SERVER_PRIVKEY | wg pubkey > $SERVER_PUBKEY
chmod 600 $SERVER_PRIVKEY

SERVER_PRIV=$(cat $SERVER_PRIVKEY)
SERVER_PUB=$(cat $SERVER_PUBKEY)

# Create server configuration
echo -e "${GREEN}Creating server configuration...${NC}"
cat > $WG_CONF <<EOF
[Interface]
Address = 10.8.0.1/24
ListenPort = $WG_PORT
PrivateKey = $SERVER_PRIV
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $NET_IFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $NET_IFACE -j MASQUERADE

EOF

chmod 600 $WG_CONF

# Enable IP forwarding
echo -e "${GREEN}Enabling IP forwarding...${NC}"
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

# Start and enable WireGuard
echo -e "${GREEN}Starting WireGuard service...${NC}"
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0

# Function to create a client
create_client() {
    CLIENT_NAME=$1
    CLIENT_NUM=$2
    CLIENT_IP="10.8.0.$((CLIENT_NUM + 1))"
    
    CLIENT_PRIVKEY="$CLIENT_DIR/${CLIENT_NAME}_private.key"
    CLIENT_PUBKEY="$CLIENT_DIR/${CLIENT_NAME}_public.key"
    CLIENT_CONF="$CLIENT_DIR/${CLIENT_NAME}.conf"
    
    # Generate client keys
    wg genkey | tee $CLIENT_PRIVKEY | wg pubkey > $CLIENT_PUBKEY
    chmod 600 $CLIENT_PRIVKEY
    
    CLIENT_PRIV=$(cat $CLIENT_PRIVKEY)
    CLIENT_PUB=$(cat $CLIENT_PUBKEY)
    
    # Create client config
    cat > $CLIENT_CONF <<EOF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = $CLIENT_IP/32
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $SERVER_IP:$WG_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
    
    # Add client to server config
    cat >> $WG_CONF <<EOF

[Peer]
# $CLIENT_NAME
PublicKey = $CLIENT_PUB
AllowedIPs = $CLIENT_IP/32
EOF
    
    # Generate QR code
    qrencode -t ansiutf8 < $CLIENT_CONF
    
    echo -e "\n${GREEN}Client configuration saved to: $CLIENT_CONF${NC}"
    echo -e "${GREEN}QR code generated above${NC}\n"
}

# Create first client
echo -e "\n${GREEN}Creating first client configuration...${NC}"
read -p "Enter client name [client1]: " CLIENT_NAME
CLIENT_NAME=${CLIENT_NAME:-client1}
create_client $CLIENT_NAME 1

# Restart WireGuard to apply changes
systemctl restart wg-quick@wg0

echo -e "\n${GREEN}=== Installation Complete ===${NC}"
echo -e "${YELLOW}Server Public Key:${NC} $SERVER_PUB"
echo -e "${YELLOW}Server Endpoint:${NC} $SERVER_IP:$WG_PORT"
echo -e "${YELLOW}Client Config:${NC} $CLIENT_DIR/${CLIENT_NAME}.conf"
echo -e "\n${GREEN}To add more clients, run:${NC}"
echo -e "  wg genkey | tee client_private.key | wg pubkey > client_public.key"
echo -e "  # Then manually edit $WG_CONF and restart service"
echo -e "\n${GREEN}Check WireGuard status:${NC} wg show"
echo -e "${GREEN}Restart WireGuard:${NC} systemctl restart wg-quick@wg0"
