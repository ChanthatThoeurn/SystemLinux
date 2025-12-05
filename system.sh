#!/usr/bin/env bash
# ============================================================
#   SYSTEM TOOL – USER FRIENDLY SERVER MANAGEMENT TOOL
#   Features:
#     ✔ System Information Report
#     ✔ Firewall Management (ufw)
#     ✔ SSH Management (install, start, connect, key)
#     ✔ Easy interactive menu (user-friendly)
# ============================================================

# COLORS
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# -------- HEADER UI ----------
header() {
    clear
    echo -e "${BLUE}"
    echo "============================================================"
    echo "                   SYSTEM TOOL MENU"
    echo "============================================================"
    echo -e "${RESET}"
}

pause() {
    echo ""
    read -p "Press Enter to continue... " dummy
}

# ---------- SYSTEM REPORT ----------
system_report() {
    header
    echo -e "${GREEN}>>> SYSTEM INFORMATION REPORT <<<${RESET}"
    echo ""
    echo "[CPU INFO]"
    lscpu | grep -E 'Model name|CPU MHz|Vendor ID'

    echo ""
    echo "[MEMORY INFO]"
    free -h

    echo ""
    echo "[STORAGE INFO]"
    df -hT | grep -v tmpfs

    echo ""
    echo "[TOP PROCESSES]"
    ps aux --sort=-%cpu | head -n 10

    echo ""
    echo "[RUNNING SERVICES]"
    systemctl list-units --type=service --state=running --no-pager | head -n 10

    echo ""
    echo -e "${GREEN}>>> END REPORT <<<${RESET}"
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
        header
        echo -e "${GREEN}>>> FIREWALL (UFW) MENU <<<${RESET}"
        echo "1) Check Firewall Status"
        echo "2) Enable Firewall"
        echo "3) Disable Firewall"
        echo "4) Allow Port"
        echo "5) Deny Port"
        echo "6) Back"
        echo ""
        read -p "option > " choice

        case $choice in
            1) ufw_check; sudo ufw status verbose; pause ;;
            2) ufw_check; sudo ufw --force enable; echo "UFW Enabled."; pause ;;
            3) ufw_check; sudo ufw --force disable; echo "UFW Disabled."; pause ;;
            4)
                read -p "Enter port number > " port
                ufw_check
                sudo ufw allow "$port"
                echo "Port $port allowed."
                pause
                ;;
            5)
                read -p "Enter port number > " port
                ufw_check
                sudo ufw deny "$port"
                echo "Port $port denied."
                pause
                ;;
            6) break ;;
            *) echo -e "${RED}Invalid option!${RESET}"; sleep 1 ;;
        esac
    done
}

# ---------- SSH MANAGEMENT ----------
ssh_menu() {
    while true; do
        header
        echo -e "${GREEN}>>> SSH MANAGEMENT <<<${RESET}"
        echo "1) Install SSH Server"
        echo "2) Start SSH Service"
        echo "3) Stop SSH Service"
        echo "4) Generate SSH Key"
        echo "5) Connect to Remote Server"
        echo "6) Back"
        echo ""
        read -p "option > " choice

        case $choice in
            1)
                sudo apt install -y openssh-server
                sudo systemctl enable --now ssh
                echo "SSH installed and started."
                pause
                ;;
            2) sudo systemctl start ssh; echo "SSH started."; pause ;;
            3) sudo systemctl stop ssh; echo "SSH stopped."; pause ;;
            4)
                read -p "Save key at (default: ~/.ssh/id_rsa) > " path
                path=${path:-~/.ssh/id_rsa}
                ssh-keygen -t rsa -b 4096 -f "$path"
                echo "Key generated at $path"
                pause
                ;;
            5)
                read -p "Enter: user@host > " host
                read -p "Port (default 22) > " port
                port=${port:-22}
                ssh -p "$port" "$host"
                pause
                ;;
            6) break ;;
            *) echo -e "${RED}Invalid option!${RESET}"; sleep 1 ;;
        esac
    done
}

# -------- MAIN MENU ----------
main_menu() {
    while true; do
        header
        echo "1) System Information Report"
        echo "2) Firewall Management"
        echo "3) SSH Management"
        echo "4) Exit"
        echo ""
        read -p "option > " option

        case $option in
            1) system_report ;;
            2) ufw_menu ;;
            3) ssh_menu ;;
            4) echo -e "${GREEN}Goodbye!${RESET}"; exit 0 ;;
            *) echo -e "${RED}Invalid option!${RESET}"; sleep 1 ;;
        esac
    done
}

main_menu
