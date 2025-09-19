#!/bin/bash

# Colors
green='\033[0;32m'
NC='\033[0m'

# Generate VMESS URL
generate_vmess_url() {
    local domain=$1
    local remarks=$2
    local uuid=$3
    local alter_id=$4
    local network=$5
    local path=$6
    local tls=$7
    local port=$8

    local json_config=$(jq -n \
        --arg v "2" \
        --arg ps "$remarks" \
        --arg add "$domain" \
        --arg port "$port" \
        --arg id "$uuid" \
        --arg aid "$alter_id" \
        --arg net "$network" \
        --arg path "$path" \
        --arg type "none" \
        --arg host "$domain" \
        --arg tls "$tls" \
        '{"v": $v, "ps": $ps, "add": $add, "port": $port, "id": $id, "aid": $aid, "net": $net, "path": $path, "type": $type, "host": $host, "tls": $tls}')

    local base64_config=$(echo -n "$json_config" | base64 -w 0)
    echo "vmess://$base64_config"
}

# Add VMess User
add_vmess_user() {
    local port=443
    local alter_id=0
    local network="ws"
    local path="/vmess"
    local tls="tls"

    read -p "Enter username: " remarks
    read -p "Enter limit IP: " max_ips
    read -p "Enter limit quota (in GB): " quota
    read -p "Enter masa aktif: " exp_days
    read -p "Enter UUID (kosongkan untuk random): " uuid
    if [ -z "$uuid" ]; then
        uuid=$(cat /proc/sys/kernel/random/uuid)
    fi

    local expiration_date=$(date -d "+${exp_days} days" +%Y-%m-%d)

    config_file="/usr/local/etc/xray/config.json"
    jq --arg uuid "$uuid" '.inbounds[3].settings.clients += [{"id": $uuid}]' $config_file > temp.json && mv temp.json $config_file

    echo "$uuid $max_ips $quota $remarks $expiration_date" >> /etc/xray/users/vmess_users.txt
    systemctl restart xray

    local domain=$(cat /etc/xray/domain)
  # generate links (asumsi fungsi ada)
    vmesslink1="$(generate_vmess_url $domain $remarks $uuid $alter_id $network $path $tls $port)"
    vmesslink2="$(generate_vmess_url $domain $remarks $uuid $alter_id $network $path "none" 80)"
    vmesslink3="$(generate_vmess_url $domain $remarks $uuid $alter_id "grpc" "vmess" $tls $port)"
    
    echo -e "[ ${green}INFO$NC ] ACCOUNT CREATED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔹 Remarks: $remarks"
    echo "🔹 Domain: $domain"
    echo "🔹 Port TLS: 443"
    echo "🔹 Port HTTP: 80"
    echo "🔹 UUID: $uuid"
    echo "🔹 Alter ID: $alter_id"
    echo "🔹 Security: Auto"
    echo "🔹 Network: Websocket (WS)"
    echo "🔹 Path: $path"
    echo "🔹 Max IPs Allowed: $max_ips"
    echo "🔹 Quota: $quota GB"
    echo "🔹 Expired Until: $expiration_date"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 TLS VMESS Url:"
    echo "$(vmesslink1)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 HTTP VMESS Url:"
    echo "$(vmesslink2)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 GRPC VMESS Url:"
    echo "$(vmesslink3)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Trial VMess User
trial_vmess_user() {
    local port=443
    local alter_id=0
    local network="ws"
    local path="/vmess"
    local tls="tls"
    local uuid=$(cat /proc/sys/kernel/random/uuid)
    local max_ips=3
    local quota=1
    local remarks="trialX-$(date +%s)"
    
    # Input menit trial
    read -p "Masukkan durasi trial (menit): " exp_minutes
    local expiration_date=$(date -d "+${exp_minutes} minutes" +%Y-%m-%d\ %H:%M:%S)

    config_file="/usr/local/etc/xray/config.json"

    # Tambahkan user trial ke config
    jq --arg uuid "$uuid" '.inbounds[3].settings.clients += [{"id": $uuid}]' \
        "$config_file" > "$config_file.tmp" && mv "$config_file.tmp" "$config_file"

    # Simpan info user trial
    echo "$uuid $max_ips $quota $remarks $expiration_date" >> /etc/xray/users/vmess_users.txt

    local domain=$(cat /etc/xray/domain)

    echo -e "[ ${green}INFO$NC ] TRIAL ACCOUNT CREATED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔹 Remarks: $remarks"
    echo "🔹 Domain: $domain"
    echo "🔹 Port TLS: 443"
    echo "🔹 Port HTTP: 80"
    echo "🔹 UUID: $uuid"
    echo "🔹 Alter ID: $alter_id"
    echo "🔹 Security: Auto"
    echo "🔹 Network: Websocket (WS)"
    echo "🔹 Path: $path"
    echo "🔹 Max IPs Allowed: $max_ips"
    echo "🔹 Quota: $quota GB"
    echo "🔹 Expired At: $expiration_date"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 TLS VMESS Url:"
    echo "$(generate_vmess_url $domain $remarks $uuid $alter_id $network $path $tls $port)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 HTTP VMESS Url:"
    echo "$(generate_vmess_url $domain $remarks $uuid $alter_id $network $path "none" 80)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 GRPC VMESS Url:"
    echo "$(generate_vmess_url $domain $remarks $uuid $alter_id "grpc" "vmess" $tls $port)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # ====== Jadwalkan hapus user otomatis pakai at ======
    echo "jq --arg uuid \"$uuid\" \
        'del(.inbounds[3].settings.clients[] | select(.id == \$uuid))' \
        $config_file > $config_file.tmp && mv $config_file.tmp $config_file && \
        sed -i \"/$uuid/d\" /etc/xray/users/vmess_users.txt && \
        xray api reload --server=127.0.0.1:10085 > /dev/null 2>&1" \
    | at now + $exp_minutes minutes
}

# Check VMess Users
check_vmess_users() {
    echo "Checking VMess users..."
    cat /etc/xray/users/vmess_users.txt
}

# Delete VMess User
delete_vmess_user() {
    read -p "Enter UUID of VMess user to delete: " uuid

    config_file="/usr/local/etc/xray/config.json"
    jq --arg uuid "$uuid" 'del(.inbounds[3].settings.clients[] | select(.id == $uuid))' $config_file > temp.json && mv temp.json $config_file

    sed -i "/$uuid/d" /etc/xray/users/vmess_users.txt
    systemctl restart xray
}

# VMess Menu
vmess_menu() {
    while true; do
        echo -e "[ ${green}INFO$NC ] VMess Management Menu"
        echo "1. Add VMess User"
        echo "2. Trial VMess User"
        echo "3. Check VMess Users"
        echo "4. Delete VMess User"
        echo "5. Back to Main Menu"
        read -p "Choose an option: " option

        case $option in
            1)
               clear ; add_vmess_user
                ;;
            2)
               clear ; trial_vmess_user
                ;;
            3)
               clear ; check_vmess_users
                ;;
            4)
               clear ; delete_vmess_user
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

# Run VMess Menu
vmess_menu