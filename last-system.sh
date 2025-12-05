#!/usr/bin/env bash

# ============================================================
#   SYSTEM TOOL – INTERACTIVE SERVER MANAGEMENT TOOL
#   Arrow-key menu • Borders • Centered UI • Pure BASH
# ============================================================

# ---------- COLORS ----------
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
RESET="\e[0m"

# ---------- CENTER PRINT ----------
center() {
    term_width=$(tput cols)
    text="$1"
    printf "%*s\n" $(((${#text} + term_width) / 2)) "$text"
}

draw_border() {
    term_width=$(tput cols)
    printf "%*s\n" "$term_width" '' | tr ' ' '='
}

pause() {
    echo ""
    read -p "Press Enter to continue... " dummy
}

# ---------- ARROW KEY MENU ----------
menu() {
    local options=("$@")
    local index=0

    while true; do
        clear
        echo -e "${BLUE}"
        draw_border
        center "SYSTEM TOOL MENU"
        draw_border
        echo -e "${RESET}"

        for i in "${!options[@]}"; do
            if [[ $i == $index ]]; then
                echo -e "  ${CYAN}> ${options[$i]}${RESET}"
            else
                echo -e "    ${options[$i]}"
            fi
        done

        echo ""
        center "Use ARROW KEYS ↑ ↓ and ENTER"

        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            case "$key" in
                "[A") ((index--)) ;;   # up
                "[B") ((index++)) ;;   # down
            esac
        elif [[ $key == "" ]]; then
            return $index
        fi

        ((index < 0)) && index=$((${#options[@]} - 1))
        ((index >= ${#options[@]})) && index=0
    done
}

# ---------- SYSTEM REPORT ----------
system_report() {
    clear
    draw_border
    center "SYSTEM INFORMATION REPORT"
    draw_border
    echo ""

    echo -e "${GREEN}[CPU INFO]${RESET}"
    lscpu | grep -E "Model name|CPU MHz|Vendor ID"

    echo ""
    echo -e "${GREEN}[MEMORY INFO]${RESET}"
    free -h

    echo ""
    echo -e "${GREEN}[STORAGE INFO]${RESET}"
    df -hT | grep -v tmpfs

    echo ""
    echo -e "${GREEN}[TOP PROCESSES]${RESET}"
    ps aux --sort=-%cpu | head -n 10

    echo ""
    echo -e "${GREEN}[RUNNING SERVICES]${RESET}"
    systemctl list-units --type=service --state=running --no-pager | head -n 10

    pause
}

# ---------- FIREWALL (UFW) ----------
ufw_check() {
    if ! command -v ufw >/dev/null; then
        echo -e "${YELLOW}UFW not installed. Installing...${RESET}"
        sudo apt install -y ufw
    fi
}

ufw_menu() {
    while true; do
        clear
        draw_border
        center "FIREWALL (UFW) MENU"
        draw_border

        echo -e "${CYAN}"
        echo "1) Check Firewall Status"
        echo "2) Enable Firewall"
        echo "3) Disable Firewall"
        echo "4) Allow Port"
        echo "5) Deny Port"
        echo "6) Back"
        echo -e "${RESET}"

        read -p "option > " choice

        case $choice in
            1) ufw_check; sudo ufw status verbose; pause ;;
            2) ufw_check; sudo ufw --force enable; echo "UFW Enabled"; pause ;;
            3) ufw_check; sudo ufw --force disable; echo "UFW Disabled"; pause ;;
            4)
                read -p "Enter port > " port
                sudo ufw allow "$port"
                echo "Port allowed"
                pause ;;
            5)
                read -p "Enter port > " port
                sudo ufw deny "$port"
                echo "Port denied"
                pause ;;
            6) break ;;
            *) echo "Invalid"; sleep 1 ;;
        esac
    done
}

# ---------- SSH MENU ----------
ssh_menu() {
    while true; do
        clear
        draw_border
        center "SSH MANAGEMENT"
        draw_border

        echo -e "${CYAN}"
        echo "1) Install SSH Server"
        echo "2) Start SSH Service"
        echo "3) Stop SSH Service"
        echo "4) Generate SSH Key"
        echo "5) Connect to Remote Server"
        echo "6) Back"
        echo -e "${RESET}"

        read -p "option > " choice

        case $choice in
            1)
                sudo apt install -y openssh-server
                sudo systemctl enable --now ssh
                echo "SSH installed"
                pause ;;
            2)
                sudo systemctl start ssh
                echo "SSH started"
                pause ;;
            3)
                sudo systemctl stop ssh
                echo "SSH stopped"
                pause ;;
            4)
                read -p "Save key at (default ~/.ssh/id_rsa) > " path
                path=${path:-~/.ssh/id_rsa}
                ssh-keygen -t rsa -b 4096 -f "$path"
                pause ;;
            5)
                read -p "Enter user@host > " host
                read -p "Port (default 22) > " port
                port=${port:-22}
                ssh -p "$port" "$host"
                pause ;;
            6) break ;;
            *) echo "Invalid"; sleep 1 ;;
        esac
    done
}

# ---------- MAIN ----------
main_menu() {
    while true; do
        menu "System Information" "Firewall Management" "SSH Management" "Exit"
        choice=$?

        case $choice in
            0) system_report ;;
            1) ufw_menu ;;
            2) ssh_menu ;;
            3) clear; echo -e "${GREEN}Goodbye!${RESET}"; exit ;;
        esac
    done
}

main_menu
