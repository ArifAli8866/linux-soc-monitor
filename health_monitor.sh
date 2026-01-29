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

mkdir -p $REPORT_DIR

DATE=$(date +"%Y-%m-%d")
TIME=$(date +"%H:%M:%S")
REPORT_FILE="$REPORT_DIR/report_$DATE.txt"

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
echo "[$(date)] $1" >> $LOG_FILE
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
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print 100-$8}')
echo -e "${GREEN}CPU Usage: $CPU%${RESET}"
echo "CPU: $CPU%" >> $REPORT_FILE

if (( ${CPU%.*} > CPU_LIMIT )); then
  echo -e "${RED}⚠ CPU threshold exceeded!${RESET}"
  log_event "High CPU usage"
  send_alert "High CPU usage detected: $CPU%"
fi
}

# ---------------- MEMORY ----------------
memory_check() {
MEM=$(free | awk '/Mem/ {printf("%.0f"), $3/$2 * 100}')
echo -e "${BLUE}Memory Usage: $MEM%${RESET}"
echo "Memory: $MEM%" >> $REPORT_FILE

if (( MEM > MEM_LIMIT )); then
  echo -e "${RED}⚠ Memory threshold exceeded!${RESET}"
  log_event "High memory usage"
  send_alert "High memory usage detected: $MEM%"
fi
}

# ---------------- DISK ----------------
disk_check() {
DISK=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
echo -e "${YELLOW}Disk Usage: $DISK%${RESET}"
echo "Disk: $DISK%" >> $REPORT_FILE

if (( DISK > DISK_LIMIT )); then
  echo -e "${RED}⚠ Disk threshold exceeded!${RESET}"
  log_event "Disk usage critical"
  send_alert "Disk usage critical: $DISK%"
fi
}

# ---------------- INTERNET ----------------
internet_check() {
ping -c 1 google.com &>/dev/null
if [ $? -eq 0 ]; then
  echo -e "${GREEN}Internet: Connected${RESET}"
else
  echo -e "${RED}Internet: Disconnected${RESET}"
  log_event "Internet disconnected"
fi
}

# ---------------- LOGIN ATTACK CHECK ----------------
login_monitor() {
FAILED=$(grep "Failed password" /var/log/auth.log 2>/dev/null | wc -l)
echo -e "${MAGENTA}Failed Login Attempts: $FAILED${RESET}"
echo "Failed Logins: $FAILED" >> $REPORT_FILE

if (( FAILED > 5 )); then
  echo -e "${RED}⚠ Possible brute-force attack!${RESET}"
  log_event "Suspicious login activity"
  send_alert "Suspicious login activity detected ($FAILED failed attempts)"
fi
}

# ---------------- PROCESSES ----------------
top_processes() {
echo -e "${WHITE}Top CPU Processes:${RESET}"
ps -eo pid,comm,%cpu --sort=-%cpu | head -6
ps -eo pid,comm,%cpu --sort=-%cpu | head -6 >> $REPORT_FILE
}

# ---------------- FULL SCAN ----------------
full_scan() {
echo "===== SECURITY REPORT ($DATE $TIME) =====" >> $REPORT_FILE
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
