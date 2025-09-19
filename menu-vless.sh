#!/bin/bash

# Colors
green='\033[0;32m'
NC='\033[0m'

# Generate VLESS URL
generate_vless_url() {
    local domain=$1
    local remarks=$2
    local uuid=$3
    local network=$4
    local path=$5
    local tls=$6
    local port=$7

    local json_config=$(jq -n \
        --arg v "2" \
        --arg ps "$remarks" \
        --arg add "$domain" \
        --arg port "$port" \
        --arg id "$uuid" \
        --arg net "$network" \
        --arg path "$path" \
        --arg type "none" \
        --arg host "$domain" \
        --arg tls "$tls" \
        '{"v": $v, "ps": $ps, "add": $add, "port": $port, "id": $id, "aid": "0", "net": $net, "path": $path, "type": $type, "host": $host, "tls": $tls}')

    local base64_config=$(echo -n "$json_config" | base64 -w 0)
    echo "vless://$base64_config"
}

# Add VLess User
add_vless_user() {
    local port=443
    local network="tcp"
    local path="/vless"
    local tls="tls"

    read -p "Enter username: " remarks
    read -p "Enter limit IP: " max_ips
    read -p "Enter limit quota (in GB): " quota
    read -p "Enter masa aktif: " exp_days
    read -p "Enter UUID (kosongkan untuk random): " uuid

    local expiration_date=$(date -d "+${exp_days} days" +%Y-%m-%d)

    config_file="/usr/local/etc/xray/config.json"
    jq --arg uuid "$uuid" '.inbounds[0].settings.clients += [{"id": $uuid}]' $config_file > temp.json && mv temp.json $config_file

    echo "$uuid $max_ips $quota $remarks $expiration_date" >> /etc/xray/users/vless_users.txt
    systemctl restart xray

    local domain=$(cat /etc/xray/domain)

    echo -e "[ ${green}INFO$NC ] ACCOUNT CREATED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔹 Remarks: $remarks"
    echo "🔹 Domain: $domain"
    echo "🔹 Port TLS: 443"
    echo "🔹 Port HTTP: 80"
    echo "🔹 UUID: $uuid"
    echo "🔹 Security: Auto"
    echo "🔹 Network: TCP"
    echo "🔹 Path: $path"
    echo "🔹 Max IPs Allowed: $max_ips"
    echo "🔹 Quota: $quota GB"
    echo "🔹 Expired Until: $expiration_date"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 TLS VLESS Url:"
    echo "$(generate_vless_url $domain $remarks $uuid $network $path $tls $port)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 HTTP VLESS Url:"
    echo "$(generate_vless_url $domain $remarks $uuid $network $path "none" 80)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 GRPC VLESS Url:"
    echo "$(generate_vless_url $domain $remarks $uuid "grpc" "vless" $tls $port)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Trial VLess User
trial_vless_user() {
    local port=443
    local network="tcp"
    local path="/vless"
    local tls="tls"
    local uuid=$(cat /proc/sys/kernel/random/uuid)
    local max_ips=3
    local quota=1
    local remarks="trialX-$(date +%s)"

    # Input menit trial
    read -p "Masukkan durasi trial (menit): " exp_minutes
    local expiration_date=$(date -d "+${exp_minutes} minutes" +%Y-%m-%d\ %H:%M:%S)

    config_file="/usr/local/etc/xray/config.json"
    jq --arg uuid "$uuid" '.inbounds[0].settings.clients += [{"id": $uuid}]' \
        $config_file > $config_file.tmp && mv $config_file.tmp $config_file

    echo "$uuid $max_ips $quota $remarks $expiration_date" >> /etc/xray/users/vless_users.txt

    local domain=$(cat /etc/xray/domain)

    echo -e "[ ${green}INFO$NC ] TRIAL ACCOUNT CREATED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔹 Remarks: $remarks"
    echo "🔹 Domain: $domain"
    echo "🔹 Port TLS: 443"
    echo "🔹 Port HTTP: 80"
    echo "🔹 UUID: $uuid"
    echo "🔹 Security: Auto"
    echo "🔹 Network: TCP"
    echo "🔹 Path: $path"
    echo "🔹 Max IPs Allowed: $max_ips"
    echo "🔹 Quota: $quota GB"
    echo "🔹 Expired At: $expiration_date"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 TLS VLESS Url:"
    echo "$(generate_vless_url $domain $remarks $uuid $network $path $tls $port)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 HTTP VLESS Url:"
    echo "$(generate_vless_url $domain $remarks $uuid $network $path "none" 80)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 GRPC VLESS Url:"
    echo "$(generate_vless_url $domain $remarks $uuid "grpc" "vless" $tls $port)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # === Jadwalkan auto hapus pakai at ===
    echo "jq --arg uuid \"$uuid\" \
        'del(.inbounds[0].settings.clients[] | select(.id == \$uuid))' \
        $config_file > $config_file.tmp && mv $config_file.tmp $config_file && \
        sed -i \"/$uuid/d\" /etc/xray/users/vless_users.txt && \
        xray api reload --server=127.0.0.1:10085 > /dev/null 2>&1" \
    | at now + $exp_minutes minutes
}

# Check VLess Users
check_vless_users() {
    echo "Checking VLess users..."
    cat /etc/xray/users/vless_users.txt
}

# Delete VLess User
delete_vless_user() {
    read -p "Enter UUID of VLess user to delete: " uuid

    config_file="/usr/local/etc/xray/config.json"
    jq --arg uuid "$uuid" 'del(.inbounds[0].settings.clients[] | select(.id == $uuid))' $config_file > temp.json && mv temp.json $config_file

    sed -i "/$uuid/d" /etc/xray/users/vless_users.txt
    systemctl restart xray
}

# VLess Menu
vless_menu() {
    while true; do
        echo -e "[ ${green}INFO$NC ] VLess Management Menu"
        echo "1. Add VLess User"
        echo "2. Trial VLess User"
        echo "3. Check VLess Users"
        echo "4. Delete VLess User"
        echo "5. Back to Main Menu"
        read -p "Choose an option: " option

        case $option in
            1)
               clear ; add_vless_user
                ;;
            2)
               clear ; trial_vless_user
                ;;
            3)
               clear ; check_vless_users
                ;;
            4)
               clear ; delete_vless_user
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

# Run VLess Menu
vless_menu