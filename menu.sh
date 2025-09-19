#!/bin/bash
clear

# Warna
RED='\033[0;31m'
WHITE='\033[1;37m'
CYAN='\033[36m'        # Cyan untuk garis
BGCYAN='\033[46;37m'   # Background cyan + teks putih
BOLD='\033[1m'
NC='\033[0m'           # Reset warna

# Garis fixed panjang 47 karakter
LINE="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Fungsi ambil info VPS
get_vps_info() {
    HOSTNAME=$(hostname)
    OS=$(lsb_release -d 2>/dev/null | awk -F"\t" '{print $2}')
    [[ -z "$OS" ]] && OS=$(cat /etc/*release | grep PRETTY_NAME | cut -d= -f2 | tr -d '"')
    UPTIME=$(uptime -p | cut -d " " -f2-)
    CPU_LOAD=$(top -bn1 | grep "load average:" | awk '{print $(NF-2),$(NF-1),$NF}')
    RAM_USED=$(free -m | awk 'NR==2{print $3}')
    RAM_TOTAL=$(free -m | awk 'NR==2{print $2}')
    IP=$(curl -s ifconfig.me)
}

# Fungsi cek akun aktif
get_accounts() {
    VMESS=$(grep -c '"id"' /etc/xray/vmess.json 2>/dev/null)
    VLESS=$(grep -c '"id"' /etc/xray/vless.json 2>/dev/null)
    TROJAN=$(grep -c '"password"' /etc/xray/trojan.json 2>/dev/null)

    # fallback kalau semua gabung di config.json
    if [[ $VMESS -eq 0 && -f /etc/xray/config.json ]]; then
        VMESS=$(grep -c '"id"' /etc/xray/config.json)
    fi
    if [[ $VLESS -eq 0 && -f /etc/xray/config.json ]]; then
        VLESS=$(grep -c '"id"' /etc/xray/config.json)
    fi
    if [[ $TROJAN -eq 0 && -f /etc/xray/config.json ]]; then
        TROJAN=$(grep -c '"password"' /etc/xray/config.json)
    fi
}

# Fungsi menu
vmess_menu() { bash /usr/bin/menu-vmess; }
vless_menu() { bash /usr/bin/menu-vless; }
trojan_menu() { bash /usr/bin/menu-trojan; }

# Menu utama
main_menu() {
    while true; do
        clear
        get_vps_info
        get_accounts

        echo -e "${CYAN}${LINE}${NC}"
        echo -e "${BGCYAN}${BOLD}               XRAY FREETUNNEL                 ${NC}"
        echo -e "${CYAN}${LINE}${NC}"
        echo ""
        echo -e " Hostname   : ${WHITE}$HOSTNAME${NC}"
        echo -e " OS         : ${WHITE}$OS${NC}"
        echo -e " Uptime     : ${WHITE}$UPTIME${NC}"
        echo -e " CPU Load   : ${WHITE}$CPU_LOAD${NC}"
        echo -e " RAM Usage  : ${WHITE}${RAM_USED}MB / ${RAM_TOTAL}MB${NC}"
        echo -e " IP Address : ${WHITE}$IP${NC}"
        echo -e "${CYAN}${LINE}${NC}"
        echo -e " 1. VMess Management   (${WHITE}${VMESS} aktif${NC})"
        echo -e " 2. VLess Management   (${WHITE}${VLESS} aktif${NC})"
        echo -e " 3. Trojan Management  (${WHITE}${TROJAN} aktif${NC})"
        echo -e " 4. Exit"
        echo -e "${CYAN}${LINE}${NC}"
        read -p " Choose an option [1-4]: " option
        echo -e "${CYAN}${LINE}${NC}"

        case $option in
            1|01) clear ; vmess_menu ;;
            2|02) clear ; vless_menu ;;
            3|03) clear ; trojan_menu ;;
            4|04) echo -e "${RED}Exiting...${NC}" ; sleep 1 ; exit 0 ;;
            *) echo -e "${RED}Invalid option!${NC}" ; sleep 1 ;;
        esac
    done
}

# Jalankan menu utama
main_menu