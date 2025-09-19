#!/bin/bash

# Colors
green='\033[0;32m'
NC='\033[0m'

# Generate Trojan URL
generate_trojan_url() {
    local domain=$1
    local remarks=$2
    local password=$3
    local network=$4
    local path=$5
    local tls=$6
    local port=$7

    local url="trojan://$password@$domain:$port?security=$tls&path=$path&type=$network&sni=$domain#$remarks"
    echo "$url"
}

# Add Trojan User
add_trojan_user() {
    local port=443
    local network="tcp"
    local path="/trojan"
    local tls="tls"

    read -p "Enter username: " remarks
    read -p "Enter limit IP: " max_ips
    read -p "Enter limit quota (in GB): " quota
    read -p "Enter masa aktif: " exp_days
    read -p "Enter UUID (kosongkan untuk random): " password
    if [ -z "$password" ]; then
        password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    fi
    
    local expiration_date=$(date -d "+${exp_days} days" +%Y-%m-%d)

    config_file="/usr/local/etc/xray/config.json"
    jq --arg password "$password" '.inbounds[2].settings.clients += [{"password": $password}]' $config_file > temp.json && mv temp.json $config_file

    echo "$password $max_ips $quota $remarks $expiration_date" >> /etc/xray/users/trojan_users.txt
    systemctl restart xray

    local domain=$(cat /etc/xray/domain)

    echo -e "[ ${green}INFO$NC ] ACCOUNT CREATED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔹 Remarks: $remarks"
    echo "🔹 Domain: $domain"
    echo "🔹 Port TLS: 443"
    echo "🔹 Port HTTP: 80"
    echo "🔹 Password: $password"
    echo "🔹 Security: Auto"
    echo "🔹 Network: TCP"
    echo "🔹 Path: $path"
    echo "🔹 Max IPs Allowed: $max_ips"
    echo "🔹 Quota: $quota GB"
    echo "🔹 Expired Until: $expiration_date"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 TLS Trojan Url:"
    echo "$(generate_trojan_url $domain $remarks $password $network $path $tls $port)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 HTTP Trojan Url:"
    echo "$(generate_trojan_url $domain $remarks $password $network $path "none" 80)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 GRPC Trojan Url:"
    echo "$(generate_trojan_url $domain $remarks $password "grpc" "" $tls $port)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Trial Trojan User
trial_trojan_user() {
    local port=443
    local network="tcp"
    local path="/trojan"
    local tls="tls"
    local password=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
    local max_ips=3
    local quota=1
    local remarks="trialX-$(date +%s)"

    # Input menit trial
    read -p "Masukkan durasi trial (menit): " exp_minutes
    local expiration_date=$(date -d "+${exp_minutes} minutes" +%Y-%m-%d\ %H:%M:%S)

    config_file="/usr/local/etc/xray/config.json"
    jq --arg password "$password" '.inbounds[2].settings.clients += [{"password": $password}]' \
        $config_file > $config_file.tmp && mv $config_file.tmp $config_file

    echo "$password $max_ips $quota $remarks $expiration_date" >> /etc/xray/users/trojan_users.txt

    local domain=$(cat /etc/xray/domain)

    echo -e "[ ${green}INFO$NC ] TRIAL ACCOUNT CREATED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔹 Remarks: $remarks"
    echo "🔹 Domain: $domain"
    echo "🔹 Port TLS: 443"
    echo "🔹 Port HTTP: 80"
    echo "🔹 Password: $password"
    echo "🔹 Security: Auto"
    echo "🔹 Network: TCP"
    echo "🔹 Path: $path"
    echo "🔹 Max IPs Allowed: $max_ips"
    echo "🔹 Quota: $quota GB"
    echo "🔹 Expired At: $expiration_date"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 TLS Trojan Url:"
    echo "$(generate_trojan_url $domain $remarks $password $network $path $tls $port)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 HTTP Trojan Url:"
    echo "$(generate_trojan_url $domain $remarks $password $network $path "none" 80)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 GRPC Trojan Url:"
    echo "$(generate_trojan_url $domain $remarks $password "grpc" "" $tls $port)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # === Jadwalkan auto hapus pakai at ===
    echo "jq --arg password \"$password\" \
        'del(.inbounds[2].settings.clients[] | select(.password == \$password))' \
        $config_file > $config_file.tmp && mv $config_file.tmp $config_file && \
        sed -i \"/$password/d\" /etc/xray/users/trojan_users.txt && \
        xray api reload --server=127.0.0.1:10085 > /dev/null 2>&1" \
    | at now + $exp_minutes minutes
}

# Check Trojan Users
check_trojan_users() {
    echo "Checking Trojan users..."
    cat /etc/xray/users/trojan_users.txt
}

# Delete Trojan User
delete_trojan_user() {
    read -p "Enter password of Trojan user to delete: " password

    config_file="/usr/local/etc/xray/config.json"
    jq --arg password "$password" 'del(.inbounds[2].settings.clients[] | select(.password == $password))' $config_file > temp.json && mv temp.json $config_file

    sed -i "/$password/d" /etc/xray/users/trojan_users.txt
    systemctl restart xray
}

# Trojan Menu
trojan_menu() {
    while true; do
        echo -e "[ ${green}INFO$NC ] Trojan Management Menu"
        echo "1. Add Trojan User"
        echo "2. Trial Trojan User"
        echo "3. Check Trojan Users"
        echo "4. Delete Trojan User"
        echo "5. Back to Main Menu"
        read -p "Choose an option: " option

        case $option in
            1)
               clear ; add_trojan_user
                ;;
            2)
               clear ; trial_trojan_user
                ;;
            3)
               clear ; check_trojan_users
                ;;
            4)
               clear ; delete_trojan_user
                ;;
            5)
               clear ; menu
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}

# Run Trojan Menu
trojan_menu