# WireGuard VPN Server Auto-Installer

A simple, automated bash script to install and configure WireGuard VPN server on Linux with just one command.

## Features

- 🚀 One-command installation
- 🐧 Multi-distro support (Ubuntu, Debian, CentOS, Fedora, RHEL)
- 🔐 Automatic key generation
- 🌐 Auto-detection of server IP and network interface
- 📱 QR code generation for easy mobile setup
- 🔥 Automatic firewall and NAT configuration
- ⚡ IPv4 forwarding enabled automatically
- 🎯 Creates first client config automatically

## Requirements

- Linux server (Ubuntu 18.04+, Debian 10+, CentOS 7+, Fedora, RHEL)
- Root or sudo access
- Public IP address
- UDP port access (default: 51820)

## Quick Start

### Installation

```bash
# Download the script
wget https://raw.githubusercontent.com/AltRepoYT/wg-easy/refs/heads/main/wg-easy.sh

# Make it executable
chmod +x wg-easy.sh

# Run as root
sudo ./wg-easy.sh
```

### What It Does

1. Detects your operating system
2. Installs WireGuard and required dependencies
3. Generates server encryption keys
4. Detects your public IP address
5. Configures firewall rules (iptables)
6. Enables IP forwarding
7. Creates your first client configuration
8. Generates a QR code for mobile devices
9. Starts and enables WireGuard service

### Interactive Setup

During installation, you'll be prompted for:

- **Network Interface**: Auto-detected (usually `eth0` or `ens3`)
- **UDP Port**: Default is `51820`
- **Client Name**: Name for your first client config

## Usage

### Check VPN Status

```bash
sudo wg show
```

### View Active Connections

```bash
sudo wg show wg0
```

### Restart WireGuard

```bash
sudo systemctl restart wg-quick@wg0
```

### Stop WireGuard

```bash
sudo systemctl stop wg-quick@wg0
```

## Client Setup

### Desktop/Laptop

1. Install WireGuard client from [wireguard.com](https://www.wireguard.com/install/)
2. Import the configuration file located at:
   ```
   /etc/wireguard/clients/client1.conf
   ```
3. Connect!

### Mobile (iOS/Android)

1. Install WireGuard app from App Store or Google Play
2. Scan the QR code displayed during installation
3. Connect!

### Manual Client Configuration

The client configuration file includes:

```ini
[Interface]
PrivateKey = <client_private_key>
Address = 10.8.0.2/32
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = <server_public_key>
Endpoint = <server_ip>:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

## Adding Additional Clients

### Method 1: Manual

```bash
# Generate client keys
cd /etc/wireguard/clients
wg genkey | tee client2_private.key | wg pubkey > client2_public.key

# Create client config
nano client2.conf
```

Add to client config:
```ini
[Interface]
PrivateKey = <contents_of_client2_private.key>
Address = 10.8.0.3/32
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = <server_public_key_from_/etc/wireguard/server_public.key>
Endpoint = <your_server_ip>:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
```

Add to server config (`/etc/wireguard/wg0.conf`):
```ini
[Peer]
# client2
PublicKey = <contents_of_client2_public.key>
AllowedIPs = 10.8.0.3/32
```

Restart WireGuard:
```bash
sudo systemctl restart wg-quick@wg0
```

### Method 2: Using the Script Function

Edit the script and run the `create_client` function for additional clients.

## Configuration Files

| File | Description |
|------|-------------|
| `/etc/wireguard/wg0.conf` | Server configuration |
| `/etc/wireguard/server_private.key` | Server private key |
| `/etc/wireguard/server_public.key` | Server public key |
| `/etc/wireguard/clients/` | Directory containing client configs |

## Firewall Configuration

The script automatically configures iptables rules:

```bash
# Allow forwarding through WireGuard interface
iptables -A FORWARD -i wg0 -j ACCEPT
iptables -A FORWARD -o wg0 -j ACCEPT

# NAT for internet access
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

### External Firewall

If you use an external firewall (UFW, firewalld, cloud provider security groups), ensure UDP port 51820 is open:

**UFW:**
```bash
sudo ufw allow 51820/udp
```

**firewalld:**
```bash
sudo firewall-cmd --permanent --add-port=51820/udp
sudo firewall-cmd --reload
```

**Cloud Providers:**
- AWS: Add inbound rule for UDP 51820 in Security Group
- Google Cloud: Add firewall rule for UDP 51820
- Azure: Add inbound security rule for UDP 51820

## Troubleshooting

### VPN Connects but No Internet

Check IP forwarding:
```bash
sysctl net.ipv4.ip_forward
# Should return: net.ipv4.ip_forward = 1
```

Check iptables rules:
```bash
sudo iptables -t nat -L -n -v
```

### Connection Timeout

- Verify firewall allows UDP port 51820
- Check server IP is correct
- Ensure server is running: `sudo systemctl status wg-quick@wg0`

### Can't Connect Multiple Devices

Each client needs a unique IP address (10.8.0.2, 10.8.0.3, etc.) and unique keys.

### Check Logs

```bash
sudo journalctl -u wg-quick@wg0 -f
```

## Security Considerations

- 🔒 All keys are stored in `/etc/wireguard/` with `600` permissions
- 🔑 Each client has unique encryption keys
- 🌐 DNS set to Cloudflare (1.1.1.1) and Google (8.8.8.8)
- 🛡️ NAT configured for secure internet access
- 🔐 Modern cryptography: Curve25519, ChaCha20, Poly1305

## Uninstallation

```bash
# Stop and disable service
sudo systemctl stop wg-quick@wg0
sudo systemctl disable wg-quick@wg0

# Remove WireGuard
sudo apt remove --purge wireguard wireguard-tools  # Ubuntu/Debian
sudo yum remove wireguard-tools kmod-wireguard      # CentOS/RHEL

# Remove configuration
sudo rm -rf /etc/wireguard

# Remove iptables rules (optional)
# Check current rules first: sudo iptables -L -n -v
```

## Performance

WireGuard is extremely fast and lightweight:
- Minimal CPU usage
- Low latency
- High throughput
- Small codebase (~4,000 lines vs OpenVPN's 100,000+)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - feel free to use this script for personal or commercial projects.

## Support

If you encounter issues:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review WireGuard logs: `sudo journalctl -u wg-quick@wg0`
3. Open an issue on GitHub

## Credits

Built with ❤️ for the WireGuard community.

## Disclaimer

This script is provided as-is. Always review scripts before running them with root privileges. The authors are not responsible for any damage or security issues.

---

**⭐ If this helped you, please star the repo!**
