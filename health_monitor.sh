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
CONFIG_FILE="$HOME/.cybersec_monitor.conf"

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
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "EMAIL_ALERT=" > "$CONFIG_FILE"
  fi
  source "$CONFIG_FILE"
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

# ---------------- SET EMAIL ----------------
set_email() {
  read -p "Enter your email for alerts (leave empty to disable): " email
  sed -i "s/^EMAIL_ALERT=.*/EMAIL_ALERT=$email/" "$CONFIG_FILE"
  echo -e "${GREEN}✔ Email configuration saved${RESET}"
  sleep 1
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

  if [ "${failed:-0}" -gt 5 ]; then
    echo -e "${RED}⚠ Possible brute-force attack! (${failed} failed attempts)${RESET}"
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

  echo -e "\n${GREEN}${BOLD}✔ Full security scan completed${RESET}"
  echo -e "${CYAN}Report saved: $REPORT_FILE${RESET}"
}

# ---------------- MENU ----------------
menu() {
echo -e "${BOLD}"
echo "1) CPU Check"
echo "2) Memory Check"
echo "3) Disk Check"
echo "4) Internet Status"
echo "5) Login Attack Scan"
echo "6) Top Processes"
echo "7) Full Security Scan"
echo "8) Configure Email Alerts"
echo "9) Exit"
echo -e "${RESET}"
}

# ---------------- MAIN ----------------
auto_install
init_config
loading

while true; do
  banner
  menu
  read -p "Choose option [1-9]: " ch

  case $ch in
    1) cpu_check ;;
    2) memory_check ;;
    3) disk_check ;;
    4) internet_check ;;
    5) login_monitor ;;
    6) top_processes ;;
    7) full_scan ;;
    8) set_email ;;
    9) echo -e "${RED}Exiting CyberSec Monitor...${RESET}"; exit 0 ;;
    *) echo -e "${RED}Invalid option${RESET}" ;;
  esac

  echo
  read -p "Press Enter to continue..."
done
