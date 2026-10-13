#!/bin/bash

# ==========================================================
#  CyberSec Linux Health & Threat Monitor
#  Author  : Arif Ali
#  Version : 4.0 (Auto-Install + User Config)
# ==========================================================

# ---------------- COLORS ----------------
RED="\e[31m"; GREEN="\e[32m"; YELLOW="\e[33m"
BLUE="\e[34m"; MAGENTA="\e[35m"; CYAN="\e[36m"
WHITE="\e[97m"; BOLD="\e[1m"; RESET="\e[0m"

# ---------------- LIMITS ----------------
CPU_LIMIT=80
MEM_LIMIT=80
DISK_LIMIT=85

# ---------------- FILES ----------------
REPORT_DIR="reports"
LOG_FILE="security.log"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/cybersec_monitor"
CONFIG_FILE="$CONFIG_DIR/cybersec_monitor.conf"

DATE=""
TIME=""
REPORT_FILE=""

refresh_timestamps() {
  DATE=$(date +"%Y-%m-%d")
  TIME=$(date +"%H:%M:%S")
  mkdir -p "$REPORT_DIR"
  REPORT_FILE="$REPORT_DIR/report_$DATE.txt"
}

# ---------------- AUTO INSTALL ----------------
auto_install() {
  REQUIRED_CMDS=("mail" "acpi" "ping" "awk" "grep")

  echo -e "${CYAN}🔧 Checking required tools...${RESET}"
  for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v $cmd &>/dev/null; then
      echo -e "${YELLOW}Installing missing dependency: $cmd${RESET}"
      sudo apt update -y &>/dev/null
      sudo apt install -y mailutils acpi &>/dev/null
      break
    fi
  done
}

# ---------------- LOADING ----------------
loading() {
echo -ne "${CYAN}Initializing CyberSec Monitor"
for i in {1..6}; do
  echo -ne "."
  sleep 0.25
done
echo -e "${RESET}\n"
}

# ---------------- CONFIG ----------------
init_config() {
  if [ -f "$HOME/.cybersec_monitor.conf" ] && [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="$HOME/.cybersec_monitor.conf"
  else
    mkdir -p "$(dirname "$CONFIG_FILE")"
  fi

  if [ ! -f "$CONFIG_FILE" ]; then
    cat <<EOF > "$CONFIG_FILE"
# CyberSec Linux Health & Threat Monitor Config
EMAIL_ALERT=""
CPU_LIMIT=80
MEM_LIMIT=80
DISK_LIMIT=85
LOGIN_FAIL_LIMIT=5
REPORT_DIR="reports"
LOG_FILE="security.log"
EOF
  fi

  # shellcheck disable=SC1090
  source "$CONFIG_FILE"

  # Ensure default values if unset in config
  CPU_LIMIT=${CPU_LIMIT:-80}
  MEM_LIMIT=${MEM_LIMIT:-80}
  DISK_LIMIT=${DISK_LIMIT:-85}
  LOGIN_FAIL_LIMIT=${LOGIN_FAIL_LIMIT:-5}
  REPORT_DIR=${REPORT_DIR:-"reports"}
  LOG_FILE=${LOG_FILE:-"security.log"}
}

save_config() {
  mkdir -p "$(dirname "$CONFIG_FILE")"
  cat <<EOF > "$CONFIG_FILE"
# CyberSec Linux Health & Threat Monitor Config
EMAIL_ALERT="$EMAIL_ALERT"
CPU_LIMIT=$CPU_LIMIT
MEM_LIMIT=$MEM_LIMIT
DISK_LIMIT=$DISK_LIMIT
LOGIN_FAIL_LIMIT=$LOGIN_FAIL_LIMIT
REPORT_DIR="$REPORT_DIR"
LOG_FILE="$LOG_FILE"
EOF
  echo -e "${GREEN}✔ Configuration saved to $CONFIG_FILE${RESET}"
}

# ---------------- SETTINGS ----------------
configure_settings() {
  echo -e "\n${CYAN}${BOLD}=== Monitor Configuration ===${RESET}"
  echo "1. Alert Email        : ${EMAIL_ALERT:-[Not Set]}"
  echo "2. CPU Alert Limit   : ${CPU_LIMIT}%"
  echo "3. RAM Alert Limit   : ${MEM_LIMIT}%"
  echo "4. Disk Alert Limit  : ${DISK_LIMIT}%"
  echo "5. Login Fail Limit  : ${LOGIN_FAIL_LIMIT} attempts"
  echo "----------------------------------------"

  read -p "Enter Alert Email [current: ${EMAIL_ALERT:-none}]: " new_email
  if [ -n "$new_email" ]; then EMAIL_ALERT="$new_email"; fi

  read -p "Enter CPU Limit % [current: ${CPU_LIMIT}]: " new_cpu
  if [[ "$new_cpu" =~ ^[0-9]+$ ]]; then CPU_LIMIT="$new_cpu"; fi

  read -p "Enter Memory Limit % [current: ${MEM_LIMIT}]: " new_mem
  if [[ "$new_mem" =~ ^[0-9]+$ ]]; then MEM_LIMIT="$new_mem"; fi

  read -p "Enter Disk Limit % [current: ${DISK_LIMIT}]: " new_disk
  if [[ "$new_disk" =~ ^[0-9]+$ ]]; then DISK_LIMIT="$new_disk"; fi

  read -p "Enter Failed Login Limit [current: ${LOGIN_FAIL_LIMIT}]: " new_lgn
  if [[ "$new_lgn" =~ ^[0-9]+$ ]]; then LOGIN_FAIL_LIMIT="$new_lgn"; fi

  save_config
  sleep 1
}

# ---------------- BANNER ----------------
banner() {
  clear
  echo -e "${CYAN}${BOLD}"
  echo "╔════════════════════════════════════════════════════╗"
  echo "║   CYBERSEC LINUX HEALTH & THREAT MONITOR            ║"
  echo "║           Created by Arif Ali                       ║"
  echo "╚════════════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

# ---------------- LOG ----------------
log_event() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ---------------- EMAIL ALERT ----------------
send_alert() {
  if [ -z "$EMAIL_ALERT" ]; then
    return
  fi
  echo "$1" | mail -s "⚠ CyberSec System Alert" "$EMAIL_ALERT"
}

# ---------------- CPU ----------------
cpu_check() {
  refresh_timestamps
  local cpu_idle
  cpu_idle=$(LC_ALL=C top -bn1 | awk -F',' '/Cpu\(s\)/ {for(i=1;i<=NF;i++) if($i ~ /id/) {gsub(/[^0-9.]/,"",$i); print $i; exit}}')
  if [ -z "$cpu_idle" ]; then
    cpu_idle=$(LC_ALL=C top -bn1 | grep "Cpu(s)" | awk '{print $8}')
  fi
  local cpu_usage
  cpu_usage=$(awk "BEGIN {printf \"%.1f\", 100 - ${cpu_idle:-0}}")
  local cpu_int=${cpu_usage%.*}

  echo -e "${GREEN}CPU Usage: ${cpu_usage}%${RESET}"
  echo "CPU: ${cpu_usage}%" >> "$REPORT_FILE"

  if [ "${cpu_int:-0}" -gt "$CPU_LIMIT" ]; then
    echo -e "${RED}⚠ CPU threshold exceeded (${cpu_usage}% > ${CPU_LIMIT}%)!${RESET}"
    log_event "High CPU usage: ${cpu_usage}%"
    send_alert "High CPU usage detected: ${cpu_usage}% (Threshold: ${CPU_LIMIT}%)"
  fi
}

# ---------------- MEMORY ----------------
memory_check() {
  refresh_timestamps
  local mem_usage
  mem_usage=$(free | awk '/Mem:/ {if ($2 > 0) printf("%.0f", ($3/$2) * 100); else print 0}')
  echo -e "${BLUE}Memory Usage: ${mem_usage}%${RESET}"
  echo "Memory: ${mem_usage}%" >> "$REPORT_FILE"

  if [ "${mem_usage:-0}" -gt "$MEM_LIMIT" ]; then
    echo -e "${RED}⚠ Memory threshold exceeded (${mem_usage}% > ${MEM_LIMIT}%)!${RESET}"
    log_event "High memory usage: ${mem_usage}%"
    send_alert "High memory usage detected: ${mem_usage}% (Threshold: ${MEM_LIMIT}%)"
  fi
}

# ---------------- DISK ----------------
disk_check() {
  refresh_timestamps
  local disk_usage
  disk_usage=$(df -P / | tail -1 | awk '{print $5}' | tr -d '%')
  echo -e "${YELLOW}Disk Usage: ${disk_usage}%${RESET}"
  echo "Disk: ${disk_usage}%" >> "$REPORT_FILE"

  if [ "${disk_usage:-0}" -gt "$DISK_LIMIT" ]; then
    echo -e "${RED}⚠ Disk threshold exceeded (${disk_usage}% > ${DISK_LIMIT}%)!${RESET}"
    log_event "Disk usage critical: ${disk_usage}%"
    send_alert "Disk usage critical: ${disk_usage}% (Threshold: ${DISK_LIMIT}%)"
  fi
}

# ---------------- INTERNET ----------------
internet_check() {
  if ping -c 1 -W 2 1.1.1.1 &>/dev/null || ping -c 1 -W 2 google.com &>/dev/null; then
    echo -e "${GREEN}Internet: Connected${RESET}"
  else
    echo -e "${RED}Internet: Disconnected${RESET}"
    log_event "Internet disconnected"
  fi
}

# ---------------- LOGIN ATTACK CHECK ----------------
login_monitor() {
  refresh_timestamps
  local failed=0
  local auth_log=""

  if [ -r "/var/log/auth.log" ]; then
    auth_log="/var/log/auth.log"
  elif [ -r "/var/log/secure" ]; then
    auth_log="/var/log/secure"
  fi

  if [ -n "$auth_log" ]; then
    failed=$(grep -E -i "(failed password|authentication failure)" "$auth_log" 2>/dev/null | wc -l)
  elif command -v journalctl &>/dev/null; then
    failed=$(journalctl -u ssh -u sshd --since "24 hours ago" 2>/dev/null | grep -E -i "(failed password|authentication failure)" | wc -l)
  else
    echo -e "${YELLOW}Notice: Auth logs require elevated privileges (run with sudo)${RESET}"
  fi

  echo -e "${MAGENTA}Failed Login Attempts: ${failed}${RESET}"
  echo "Failed Logins: ${failed}" >> "$REPORT_FILE"

  if [ "${failed:-0}" -gt "$LOGIN_FAIL_LIMIT" ]; then
    echo -e "${RED}⚠ Possible brute-force attack! (${failed} failed attempts > ${LOGIN_FAIL_LIMIT})${RESET}"
    log_event "Suspicious login activity: ${failed} failed attempts"
    send_alert "Suspicious login activity detected (${failed} failed attempts)"
  fi
}

# ---------------- PROCESSES ----------------
top_processes() {
  refresh_timestamps
  echo -e "${WHITE}Top CPU Processes:${RESET}"
  ps -eo pid,comm,%cpu --sort=-%cpu | head -6
  ps -eo pid,comm,%cpu --sort=-%cpu | head -6 >> "$REPORT_FILE"
}

# ---------------- OPEN PORTS & SOCKETS ----------------
network_ports_check() {
  refresh_timestamps
  echo -e "${CYAN}--- Active Listening Ports & Sockets ---${RESET}"
  echo "===== LISTENING PORTS ($DATE $TIME) =====" >> "$REPORT_FILE"

  local port_cmd=""
  if command -v ss &>/dev/null; then
    port_cmd="ss -tuln"
  elif command -v netstat &>/dev/null; then
    port_cmd="netstat -tuln"
  fi

  if [ -z "$port_cmd" ]; then
    echo -e "${YELLOW}Warning: Neither 'ss' nor 'netstat' is available.${RESET}"
    return
  fi

  local total_ports
  total_ports=$($port_cmd | awk 'NR>1 {print $1, $5}' | grep -c -v '^$' || true)

  echo -e "${GREEN}Total Listening Services: ${total_ports}${RESET}"
  echo "Total Listening Services: ${total_ports}" >> "$REPORT_FILE"

  $port_cmd | head -n 15
  $port_cmd >> "$REPORT_FILE"

  local risky_patterns="(:21|:23|:3306|:5432|:6379|:27017)"
  local exposed_risks
  exposed_risks=$($port_cmd | grep -E "(0\.0\.0\.0|\*|\[::\])$risky_patterns" || true)

  if [ -n "$exposed_risks" ]; then
    echo -e "\n${RED}⚠ WARNING: Sensitive or unencrypted ports exposed publicly!${RESET}"
    echo "$exposed_risks" | while read -r line; do
      echo -e "${RED}  -> $line${RESET}"
    done
    log_event "Alert: Sensitive service port exposed on public interface"
    send_alert "Security Alert: Sensitive service listening on public interface!"
  else
    echo -e "${GREEN}✔ No sensitive database or cleartext ports exposed on wildcard IP.${RESET}"
  fi
}

# ---------------- USER ACCOUNT & SESSION AUDIT ----------------
user_audit() {
  refresh_timestamps
  echo -e "${MAGENTA}--- User Accounts & Active Sessions Audit ---${RESET}"
  echo "===== USER AUDIT ($DATE $TIME) =====" >> "$REPORT_FILE"

  echo -e "${WHITE}Currently Logged In Users:${RESET}"
  local logged_users
  logged_users=$(who 2>/dev/null)
  if [ -n "$logged_users" ]; then
    echo "$logged_users"
    echo "$logged_users" >> "$REPORT_FILE"
  else
    echo "No interactive user sessions detected."
    echo "No interactive user sessions." >> "$REPORT_FILE"
  fi

  local uid_zero_users
  uid_zero_users=$(awk -F: '($3 == 0) {print $1}' /etc/passwd 2>/dev/null)
  local uid_zero_count
  uid_zero_count=$(echo "$uid_zero_users" | wc -w)

  echo -e "\n${WHITE}Accounts with UID 0 (Superuser):${RESET} $uid_zero_users"
  echo "UID 0 Accounts: $uid_zero_users" >> "$REPORT_FILE"

  if [ "${uid_zero_count:-0}" -gt 1 ]; then
    echo -e "${RED}⚠ CRITICAL ALERT: Multiple accounts have UID 0 root privilege! ($uid_zero_users)${RESET}"
    log_event "CRITICAL: Multiple UID 0 accounts detected: $uid_zero_users"
    send_alert "CRITICAL: Multiple UID 0 superuser accounts detected on system!"
  else
    echo -e "${GREEN}✔ Root account configuration normal.${RESET}"
  fi

  local shell_accounts
  shell_accounts=$(grep -E "(/bash|/sh|/zsh)$" /etc/passwd 2>/dev/null | awk -F: '{print $1}' | paste -sd, -)
  echo -e "${CYAN}Accounts with interactive shell:${RESET} ${shell_accounts}"
  echo "Interactive shell users: ${shell_accounts}" >> "$REPORT_FILE"
}

# ---------------- SYSTEM INTEGRITY & SERVICES ----------------
system_integrity_check() {
  refresh_timestamps
  echo -e "${YELLOW}--- System Integrity & Service Status ---${RESET}"
  echo "===== SYSTEM INTEGRITY ($DATE $TIME) =====" >> "$REPORT_FILE"

  if command -v systemctl &>/dev/null; then
    local failed_services
    failed_services=$(systemctl --failed --no-legend --no-pager 2>/dev/null)
    local failed_count=0
    if [ -n "$failed_services" ]; then
      failed_count=$(echo "$failed_services" | grep -c -v '^$' || true)
    fi

    if [ "${failed_count:-0}" -gt 0 ]; then
      echo -e "${RED}⚠ Found ${failed_count} failed systemd service(s):${RESET}"
      echo "$failed_services" | head -n 10
      echo "$failed_services" >> "$REPORT_FILE"
      log_event "Warning: ${failed_count} systemd unit(s) in failed state"
      send_alert "Warning: ${failed_count} failed systemd services detected on system!"
    else
      echo -e "${GREEN}✔ All system services active without failures.${RESET}"
      echo "Systemd Services: All healthy" >> "$REPORT_FILE"
    fi
  fi

  echo -e "\n${WHITE}Firewall Status:${RESET}"
  if command -v ufw &>/dev/null; then
    local ufw_stat
    ufw_stat=$(ufw status 2>/dev/null || true)
    if [ -n "$ufw_stat" ]; then
      echo "$ufw_stat" | head -n 4
      echo "UFW Status: $ufw_stat" >> "$REPORT_FILE"
    else
      echo -e "${YELLOW}UFW installed (requires sudo to read status)${RESET}"
    fi
  elif command -v iptables &>/dev/null; then
    echo "iptables installed"
  else
    echo -e "${YELLOW}No standard firewall detected (ufw/iptables)${RESET}"
  fi

  echo -e "\n${WHITE}Scheduled Tasks (Cron) Audit:${RESET}"
  local user_cron
  user_cron=$(crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$' || true)
  if [ -n "$user_cron" ]; then
    echo -e "${CYAN}Current User Crontab Entries:${RESET}"
    echo "$user_cron"
    echo "User Crontab: $user_cron" >> "$REPORT_FILE"
  else
    echo "No custom user cron jobs active."
  fi

  local sys_cron_count
  sys_cron_count=$(ls -1 /etc/cron* 2>/dev/null | wc -l)
  echo "System Cron Definitions: ${sys_cron_count} items found in /etc/cron*"
  echo "System Cron Entries Count: ${sys_cron_count}" >> "$REPORT_FILE"
}

# ---------------- FULL SCAN ----------------
full_scan() {
  refresh_timestamps
  echo "===== SECURITY REPORT ($DATE $TIME) =====" >> "$REPORT_FILE"
  cpu_check
  memory_check
  disk_check
  internet_check
  login_monitor
  top_processes
  network_ports_check
  user_audit
  system_integrity_check

  echo -e "\n${GREEN}${BOLD}✔ Full security scan completed${RESET}"
  echo -e "${CYAN}Report saved: $REPORT_FILE${RESET}"
}

# ---------------- MENU ----------------
menu() {
echo -e "${BOLD}"
echo "1)  CPU Check"
echo "2)  Memory Check"
echo "3)  Disk Check"
echo "4)  Internet Status"
echo "5)  Login Attack Scan"
echo "6)  Top Processes"
echo "7)  Open Ports & Sockets Audit"
echo "8)  User Accounts & Sessions Audit"
echo "9)  System Integrity & Services Audit"
echo "10) Full Security Scan"
echo "11) Configure Settings & Thresholds"
echo "12) Exit"
echo -e "${RESET}"
}

# ---------------- MAIN ----------------
auto_install
init_config
loading

while true; do
  banner
  menu
  read -p "Choose option [1-12]: " ch

  case $ch in
    1) cpu_check ;;
    2) memory_check ;;
    3) disk_check ;;
    4) internet_check ;;
    5) login_monitor ;;
    6) top_processes ;;
    7) network_ports_check ;;
    8) user_audit ;;
    9) system_integrity_check ;;
    10) full_scan ;;
    11) configure_settings ;;
    12) echo -e "${RED}Exiting CyberSec Monitor...${RESET}"; exit 0 ;;
    *) echo -e "${RED}Invalid option${RESET}" ;;
  esac

  echo
  read -p "Press Enter to continue..."
done
