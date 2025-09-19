#!/bin/bash
# Check root
if [ "$(id -u)" != "0" ]; then
  echo -e "${RED}Error: Script harus dijalankan sebagai root.${NC}" 1>&2
  exit 1
fi
# Install dependencies
apt update
apt install -y curl socat cron jq uuid-runtime
apt-get install at -y
systemctl enable --now atd
# Repository URL
REPO_URL="https://raw.githubusercontent.com/freetunnel/xray6/main"

# Colors
green='\033[0;32m'
NC='\033[0m'

# Install Xray
install_xray() {
    sleep 0.5
    echo -e "[ ${green}INFO$NC ] Downloading & Installing Xray Core v1.6.1"
    domainSock_dir="/run/xray"
    ! [ -d $domainSock_dir ] && mkdir $domainSock_dir
    chown www-data.www-data $domainSock_dir

    # Make Folder XRay
    mkdir -p /var/log/xray
    mkdir -p /etc/xray
    chown www-data.www-data /var/log/xray
    chmod +x /var/log/xray
    touch /var/log/xray/access.log
    touch /var/log/xray/error.log
    touch /var/log/xray/access2.log
    touch /var/log/xray/error2.log

bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data --version 1.6.1
}

# Issue SSL certificate using acme.sh
issue_ssl_certificate() {
    read -p "Enter your domain: " domain
    echo "$domain" > /etc/xray/domain
    
    systemctl stop nginx
    mkdir /root/.acme.sh
    curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    /root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
    /root/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
}

function ddos() {
# Instal DDOS Flate
if [ -d '/usr/local/ddos' ]; then
	rm -rf /usr/local/ddos
else
	mkdir /usr/local/ddos
fi
clear
echo; echo 'Installing DOS-Deflate 0.6'; echo
echo; echo -n 'Downloading source files...'
wget --no-check-certificate -q -O /usr/local/ddos/ddos.conf http://www.inetbase.com/scripts/ddos/ddos.conf
echo -n '.'
wget --no-check-certificate -q -O /usr/local/ddos/LICENSE http://www.inetbase.com/scripts/ddos/LICENSE
echo -n '.'
wget --no-check-certificate -q -O /usr/local/ddos/ignore.ip.list http://www.inetbase.com/scripts/ddos/ignore.ip.list
echo -n '.'
wget --no-check-certificate -q -O /usr/local/ddos/ddos.sh http://www.inetbase.com/scripts/ddos/ddos.sh
chmod 0755 /usr/local/ddos/ddos.sh
cp -s /usr/local/ddos/ddos.sh /usr/local/sbin/ddos
echo '...done'
echo; echo -n 'Creating cron to run script every minute.....(Default setting)'
/usr/local/ddos/ddos.sh --cron > /dev/null 2>&1
echo '.....done'
echo; echo 'Installation has completed.'
echo 'Config file is at /usr/local/ddos/ddos.conf'
echo 'Please send in your comments and/or suggestions to zaf@vsnl.com'
}

function torent() {
# blockir torrent & smtp port
iptables -A INPUT -p tcp --dport 25 -j DROP
iptables -A INPUT -p tcp --dport 465 -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP
iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
iptables -A FORWARD -m string --algo bm --string "torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce" -j DROP
iptables -A FORWARD -m string --algo bm --string "info_hash" -j DROP
iptables -A FORWARD -m string --algo bm --string "/default.ida?" -j DROP
iptables -A FORWARD -m string --algo bm --string ".exe?/c+dir" -j DROP
iptables -A FORWARD -m string --algo bm --string ".exe?/c_tftp" -j DROP
iptables -A FORWARD -m string --string "peer_id" --algo kmp -j DROP
iptables -A FORWARD -m string --string "BitTorrent" --algo kmp -j DROP
iptables -A FORWARD -m string --string "BitTorrent protocol" --algo kmp -j DROP
iptables -A FORWARD -m string --string "bittorrent-announce" --algo kmp -j DROP
iptables -A FORWARD -m string --string "announce.php?passkey=" --algo kmp -j DROP
iptables -A FORWARD -m string --string "find_node" --algo kmp -j DROP
iptables -A FORWARD -m string --string "info_hash" --algo kmp -j DROP
iptables -A FORWARD -m string --string "get_peers" --algo kmp -j DROP
iptables -A FORWARD -m string --string "announce" --algo kmp -j DROP
iptables -A FORWARD -m string --string "announce_peers" --algo kmp -j DROP
iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload
}

# Configure Xray
configure_xray() {
    # Configure Xray with domain
    cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "api": {
    "services": ["HandlerService", "LoggerService", "StatsService"]
  },
  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    }
  },
  "stats": {},
  "inbounds": [
    {
      "protocol": "vmess",
      "port": 443,
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/xray/xray.crt",
              "keyFile": "/etc/xray/xray.key"
            }
          ]
        }
      }
    },
    {
      "protocol": "vless",
      "port": 443,
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/xray/xray.crt",
              "keyFile": "/etc/xray/xray.key"
            }
          ]
        }
      }
    },
    {
      "protocol": "trojan",
      "port": 443,
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/xray/xray.crt",
              "keyFile": "/etc/xray/xray.key"
            }
          ]
        }
      }
    },
    {
      "protocol": "vmess",
      "port": 80,
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess"
        }
      }
    },
    {
      "protocol": "vless",
      "port": 80,
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vless"
        }
      }
    },
    {
      "protocol": "trojan",
      "port": 80,
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/trojan"
        }
      }
    },
    {
      "protocol": "vmess",
      "port": 443,
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "vmess"
        }
      }
    },
    {
      "protocol": "vless",
      "port": 443,
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "vless"
        }
      }
    },
    {
      "protocol": "trojan",
      "port": 443,
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "trojan"
        }
      }
    },
    {
      "tag": "api",
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
    systemctl restart xray
}

# Initialize directories and files
initialize_directories() {
    mkdir -p /etc/xray/users
    touch /etc/xray/users/vmess_users.txt
    touch /etc/xray/users/vless_users.txt
    touch /etc/xray/users/trojan_users.txt
}

# Download and save menu scripts to /usr/bin
download_menu_scripts() {
    wget -O /usr/bin/menu-vmess ${REPO_URL}/menu-vmess.sh
    wget -O /usr/bin/menu-vless ${REPO_URL}/menu-vless.sh
    wget -O /usr/bin/menu-trojan ${REPO_URL}/menu-trojan.sh
    wget -O /usr/bin/menu ${REPO_URL}/menu.sh
    wget -O /usr/bin/monitor ${REPO_URL}/monitor.sh

    chmod +x /usr/bin/menu-vmess
    chmod +x /usr/bin/menu-vless
    chmod +x /usr/bin/menu-trojan
    chmod +x /usr/bin/menu
    chmod +x /usr/bin/monitor
}

# Create systemd service for monitoring
create_systemd_service() {
    cat <<EOF > /etc/systemd/system/monitor.service
[Unit]
Description=Xray Connection Monitor
After=network.target xray.service

[Service]
ExecStart=/usr/bin/monitor
Restart=always
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable monitor.service
    sudo systemctl start monitor.service
}

# Configure automatic login to menu.sh
configure_automatic_login() {
 cat> /root/.profile << END
if [ "$BASH" ]; then
if [ -f ~/.bashrc ]; then
. ~/.bashrc
fi
fi
mesg n || true
clear
menu
END
}
xray_serv() {
# Enable and start Xray
# Enable and start Xray
systemctl enable xray
systemctl start xray

# Create log files
mkdir -p /var/log/xray
touch /var/log/xray/access.log
touch /var/log/xray/error.log
chown -R nobody:nogroup /var/log/xray

}
BBR() {
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
}
function FTP2(){
cd
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
clear
start=$(date +%s)
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
apt install git curl -y >/dev/null 2>&1
apt install python -y >/dev/null 2>&1
}
# Main function for installation
main() {
    FTP2
    initialize_directories
    install_xray
    issue_ssl_certificate
    configure_xray
    download_menu_scripts
    create_systemd_service
    xray_serv
    configure_automatic_login
    ddos
    torent
    BBR
    echo -e "[ ${green}INFO$NC ] Xray installation and configuration completed successfully."
}

# Run the main function
main
