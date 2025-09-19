#!/bin/bash

# Function to clean up logs and temporary files
auto_cleaner() {
    echo "Running auto cleaner..."
    journalctl --vacuum-time=1d
    rm -f /etc/xray/temp.json
    echo "Auto cleaning completed."
}

# =============================
# VMess Checker
# =============================
check_vmess() {
    local config="/usr/local/etc/xray/config.json"
    local userfile="/etc/xray/users/vmess_users.txt"
    local current_ts=$(date +%s)

    [ ! -f "$userfile" ] && return

    while read -r uuid max_ips quota remarks expiration_date; do
        [ -z "$uuid" ] && continue
        exp_ts=$(date -d "$expiration_date" +%s)

        # Expired check
        if (( current_ts > exp_ts )); then
            echo "[VMess] Deleting expired user $uuid ($remarks)"
            jq --arg uuid "$uuid" 'del(.inbounds[3].settings.clients[] | select(.id == $uuid))' \
                "$config" > temp.json && mv temp.json "$config"
            sed -i "/$uuid/d" "$userfile"
            systemctl restart xray
            continue
        fi

        # IP limit check
        connected_ips=$(journalctl -u xray -S -5m | grep "$uuid" | grep -oP 'ip=\K[0-9\.]+' | sort -u)
        ip_count=$(echo "$connected_ips" | wc -l)

        if (( ip_count > max_ips )); then
            echo "[VMess] Locking $uuid ($remarks) — IPs $ip_count > $max_ips"
            jq --arg uuid "$uuid" 'del(.inbounds[3].settings.clients[] | select(.id == $uuid))' \
                "$config" > temp.json && mv temp.json "$config"
            systemctl restart xray
        fi
    done < "$userfile"
}

# =============================
# VLess Checker
# =============================
check_vless() {
    local config="/usr/local/etc/xray/config.json"
    local userfile="/etc/xray/users/vless_users.txt"
    local current_ts=$(date +%s)

    [ ! -f "$userfile" ] && return

    while read -r uuid max_ips quota remarks expiration_date; do
        [ -z "$uuid" ] && continue
        exp_ts=$(date -d "$expiration_date" +%s)

        if (( current_ts > exp_ts )); then
            echo "[VLess] Deleting expired user $uuid ($remarks)"
            jq --arg uuid "$uuid" 'del(.inbounds[0].settings.clients[] | select(.id == $uuid))' \
                "$config" > temp.json && mv temp.json "$config"
            sed -i "/$uuid/d" "$userfile"
            systemctl restart xray
            continue
        fi

        connected_ips=$(journalctl -u xray -S -5m | grep "$uuid" | grep -oP 'ip=\K[0-9\.]+' | sort -u)
        ip_count=$(echo "$connected_ips" | wc -l)

        if (( ip_count > max_ips )); then
            echo "[VLess] Locking $uuid ($remarks) — IPs $ip_count > $max_ips"
            jq --arg uuid "$uuid" 'del(.inbounds[0].settings.clients[] | select(.id == $uuid))' \
                "$config" > temp.json && mv temp.json "$config"
            systemctl restart xray
        fi
    done < "$userfile"
}

# =============================
# Trojan Checker
# =============================
check_trojan() {
    local config="/usr/local/etc/xray/config.json"
    local userfile="/etc/xray/users/trojan_users.txt"
    local current_ts=$(date +%s)

    [ ! -f "$userfile" ] && return

    while read -r password max_ips quota remarks expiration_date; do
        [ -z "$password" ] && continue
        exp_ts=$(date -d "$expiration_date" +%s)

        if (( current_ts > exp_ts )); then
            echo "[Trojan] Deleting expired user $password ($remarks)"
            jq --arg password "$password" 'del(.inbounds[2].settings.clients[] | select(.password == $password))' \
                "$config" > temp.json && mv temp.json "$config"
            sed -i "/$password/d" "$userfile"
            systemctl restart xray
            continue
        fi

        connected_ips=$(journalctl -u xray -S -5m | grep "$password" | grep -oP 'ip=\K[0-9\.]+' | sort -u)
        ip_count=$(echo "$connected_ips" | wc -l)

        if (( ip_count > max_ips )); then
            echo "[Trojan] Locking $password ($remarks) — IPs $ip_count > $max_ips"
            jq --arg password "$password" 'del(.inbounds[2].settings.clients[] | select(.password == $password))' \
                "$config" > temp.json && mv temp.json "$config"
            systemctl restart xray
        fi
    done < "$userfile"
}

# =============================
# Main Loop
# =============================
monitor_connections() {
    while true; do
        echo "=== Running check at $(date) ==="
        check_vmess
        check_vless
        check_trojan

        # Run auto cleaner at midnight
        current_hour=$(date +%H)
        if [ "$current_hour" -eq "0" ]; then
            auto_cleaner
        fi

        sleep 60
    done
}

monitor_connections