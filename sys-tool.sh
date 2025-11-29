#!/usr/bin/env bash
# Simple System Tool: system info, ufw management, ssh helper
# Usage: ./sys-tool.sh         (interactive menu)
#        ./sys-tool.sh --report
#        ./sys-tool.sh --ufw enable
#        ./sys-tool.sh --ufw allow 22
#        ./sys-tool.sh --ssh install
# Requires: sudo for actions that change system state

set -euo pipefail
IFS=$'\n\t'

### Helper functions ###
die() { echo "ERROR: $*" >&2; exit 1; }
need_sudo() { if [ "$EUID" -ne 0 ]; then echo "This action requires sudo privileges. Re-running with sudo..."; exec sudo bash "$0" "$@"; fi }

detect_pkg_manager() {
  if command -v apt-get >/dev/null; then echo "apt"; return; fi
  if command -v dnf >/dev/null; then echo "dnf"; return; fi
  if command -v yum >/dev/null; then echo "yum"; return; fi
  if command -v pacman >/dev/null; then echo "pacman"; return; fi
  echo "unknown"
}

prompt_continue() { read -r -p "Press Enter to continue..." || true; }

### System report ###
report_system_info() {
  echo "========== System Information Report =========="
  echo "Date: $(date -Is)"
  echo
  echo "Hostname: $(hostname)"
  echo "Uptime: $(uptime -p)"
  echo
  echo "-- CPU --"
  if [ -f /proc/cpuinfo ]; then
    lscpu 2>/dev/null || awk -F: '/model name|cpu MHz|vendor_id/ {print $1": "$2}' /proc/cpuinfo | sed '/^$/d'
  else
    echo "lscpu not available"
  fi
  echo
  echo "-- Memory --"
  free -h
  echo
  echo "-- Storage --"
  df -hT --total | sed '/tmpfs/d'
  echo
  echo "-- Top processes by CPU --"
  ps aux --sort=-%cpu | awk 'NR<=10{printf "%-8s %-6s %-4s %s\n",$1,$3,$4,$11}' 
  echo
  echo "-- Running services (systemctl) --"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl list-units --type=service --state=running --no-legend --no-pager \
      | awk '{printf "%-40s %s\n", $1, $4}'
  else
    echo "systemctl not found. Showing processes with systemd-like names:"
    ps -eo pid,cmd --sort=-%mem | head -n 15
  fi
  echo
  echo "========== End Report =========="
}

### UFW management ###
ensure_ufw_installed() {
  if ! command -v ufw >/dev/null 2>&1; then
    echo "ufw is not installed."
    read -r -p "Install ufw now? [Y/n] " ans
    ans=${ans:-Y}
    if [[ "$ans" =~ ^[Yy] ]]; then
      pm=$(detect_pkg_manager)
      case "$pm" in
        apt) sudo apt-get update && sudo apt-get install -y ufw ;;
        dnf) sudo dnf install -y ufw ;;
        yum) sudo yum install -y ufw ;;
        pacman) sudo pacman -Sy --noconfirm ufw ;;
        *) die "Unable to auto-install ufw: unknown package manager. Please install ufw manually." ;;
      esac
      echo "ufw installed."
    else
      die "ufw required for firewall actions."
    fi
  fi
}

ufw_status() { sudo ufw status verbose || echo "ufw not active or not installed."; }

ufw_enable() {
  ensure_ufw_installed
  sudo ufw --force enable
  echo "ufw enabled."
}

ufw_disable() {
  ensure_ufw_installed
  sudo ufw --force disable
  echo "ufw disabled."
}

ufw_allow_port() {
  ensure_ufw_installed
  port="$1"
  proto="${2:-tcp}"
  sudo ufw allow "$port"/"$proto"
  echo "Allowed $port/$proto through ufw."
}

ufw_deny_port() {
  ensure_ufw_installed
  port="$1"
  proto="${2:-tcp}"
  sudo ufw deny "$port"/"$proto"
  echo "Denied $port/$proto through ufw."
}

### SSH management ###
ssh_install_server() {
  pm=$(detect_pkg_manager)
  echo "Will install openssh-server if missing..."
  if command -v sshd >/dev/null 2>&1; then
    echo "openssh-server appears installed."
  else
    case "$pm" in
      apt) sudo apt-get update && sudo apt-get install -y openssh-server ;;
      dnf) sudo dnf install -y openssh-server ;;
      yum) sudo yum install -y openssh-server ;;
      pacman) sudo pacman -Sy --noconfirm openssh ;;
      *) die "Unable to auto-install openssh-server: unknown package manager. Please install manually." ;;
    esac
    echo "openssh-server installed (if package available)."
  fi
  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl enable --now ssh || sudo systemctl enable --now sshd || true
    echo "SSH service enabled and started (if available)."
  else
    echo "systemctl not found; please start sshd manually if required."
  fi
}

ssh_start_stop() {
  action="$1" # start|stop|restart|status
  if command -v systemctl >/dev/null 2>&1; then
    if sudo systemctl list-unit-files | grep -qE "ssh|sshd"; then
      sudo systemctl "$action" ssh || sudo systemctl "$action" sshd || echo "Tried service commands."
    else
      echo "SSH service unit not found; try 'ssh_install_server' first."
    fi
  else
    die "systemctl not available on this system."
  fi
}

ssh_generate_key() {
  keyfile="${1:-$HOME/.ssh/id_rsa}"
  read -r -p "Enter key comment (e.g. user@host) [${USER}@$(hostname)]: " comment
  comment=${comment:-${USER}@$(hostname)}
  ssh-keygen -t rsa -b 4096 -C "$comment" -f "$keyfile"
  echo "Public key:"
  echo "---------------------------------"
  cat "${keyfile}.pub"
  echo "---------------------------------"
}

ssh_connect() {
  host="$1"
  user="${2:-$USER}"
  port="${3:-22}"
  echo "Connecting to ${user}@${host} on port ${port}..."
  ssh -p "$port" "${user}@${host}"
}

### Interactive menus ###
show_main_menu() {
  cat <<'MENU'
Simple System Tool - Main Menu
1) System Information Report
2) Firewall (ufw) Management
3) SSH Management (install/start/generate key/connect)
4) Show Help / Usage
5) Exit
MENU
}

show_firewall_menu() {
  cat <<'MENU'
Firewall (ufw) Menu
1) Status
2) Enable ufw
3) Disable ufw
4) Allow port (e.g. 22 or 80/tcp)
5) Deny port
6) Back
MENU
}

show_ssh_menu() {
  cat <<'MENU'
SSH Menu
1) Install & start openssh-server
2) Start SSH service
3) Stop SSH service
4) Generate SSH key pair (default ~/.ssh/id_rsa)
5) Connect to remote host (ssh)
6) Back
MENU
}

interactive() {
  while true; do
    echo
    show_main_menu
    read -r -p "option > " opt
    case "$opt" in
      1) report_system_info; prompt_continue ;;
      2)
         while true; do
           show_firewall_menu
           read -r -p "option > " f
           case "$f" in
             1) ufw_status; prompt_continue ;;
             2) ufw_enable; prompt_continue ;;
             3) ufw_disable; prompt_continue ;;
             4) read -r -p "Port (e.g. 22 or 8080/tcp): " p; ufw_allow_port "$p"; prompt_continue ;;
             5) read -r -p "Port (e.g. 22 or 8080/tcp): " p; ufw_deny_port "$p"; prompt_continue ;;
             6) break ;;
             *) echo "Invalid";;
           esac
         done
         ;;
      3)
         while true; do
           show_ssh_menu
           read -r -p "option > " s
           case "$s" in
             1) ssh_install_server; prompt_continue ;;
             2) ssh_start_stop start; prompt_continue ;;
             3) ssh_start_stop stop; prompt_continue ;;
             4) read -r -p "Key file to write (default ~/.ssh/id_rsa): " kf; kf=${kf:-$HOME/.ssh/id_rsa}; ssh_generate_key "$kf"; prompt_continue ;;
             5) read -r -p "Remote host (host or user@host): " remote; 
                if [[ "$remote" == *@* ]]; then u="${remote%@*}"; h="${remote#*@}"; else u=""; h="$remote"; fi
                read -r -p "Port [22]: " p; p=${p:-22}
                if [ -n "$u" ]; then ssh_connect "$h" "$u" "$p"; else ssh_connect "$h" "" "$p"; fi
                prompt_continue ;;
             6) break ;;
             *) echo "Invalid";;
           esac
         done
         ;;
      4)
         echo "Usage examples:"
         echo "  ./sys-tool.sh --report"
         echo "  ./sys-tool.sh --ufw status"
         echo "  ./sys-tool.sh --ufw allow 8080"
         echo "  ./sys-tool.sh --ssh install"
         echo
         prompt_continue
         ;;
      5) echo "Goodbye."; exit 0 ;;
      *) echo "Invalid option." ;;
    esac
  done
}

### CLI argument parsing for non-interactive usage ###
if [ "${1:-}" = "--report" ]; then
  report_system_info
  exit 0
fi

if [ "${1:-}" = "--ufw" ]; then
  action="${2:-status}"
  case "$action" in
    status) ufw_status ;;
    enable) ufw_enable ;;
    disable) ufw_disable ;;
    allow)
      port="${3:-}"
      [ -z "$port" ] && die "Usage: $0 --ufw allow PORT[/proto]"
      ufw_allow_port "$port"
      ;;
    deny)
      port="${3:-}"
      [ -z "$port" ] && die "Usage: $0 --ufw deny PORT[/proto]"
      ufw_deny_port "$port"
      ;;
    *) die "Unknown ufw action: $action. Use status|enable|disable|allow|deny" ;;
  esac
  exit 0
fi

if [ "${1:-}" = "--ssh" ]; then
  action="${2:-help}"
  case "$action" in
    install) ssh_install_server ;;
    start) ssh_start_stop start ;;
    stop) ssh_start_stop stop ;;
    genkey) ssh_generate_key "${3:-}" ;;
    connect) ssh_connect "${3:?host}" "${4:-}" "${5:-22}" ;;
    *) echo "ssh actions: install|start|stop|genkey|connect"; exit 0 ;;
  esac
  exit 0
fi

# default -> interactive
interactive

