#!/usr/bin/env bash
# ==========================================================
#  CyberSec Linux Health & Threat Monitor - Installer
#  Author : Arif Ali
# ==========================================================

set -e

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

echo -e "${CYAN}${BOLD}"
echo "╔════════════════════════════════════════════════════╗"
echo "║   CyberSec Linux Health & Threat Monitor Setup     ║"
echo "╚════════════════════════════════════════════════════╝"
echo -e "${RESET}"

# Require root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Please run this installer as root or with sudo.${RESET}"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_TARGET="/usr/local/bin/cybersecmon"
SERVICE_TARGET="/etc/systemd/system/cybersecmon.service"
CONFIG_TARGET="/etc/cybersec_monitor.conf"

echo -e "${CYAN}==> Detecting package manager & installing dependencies...${RESET}"
if command -v apt-get &>/dev/null; then
  apt-get update -y
  apt-get install -y mailutils iputils-ping procps iproute2 gawk sed coreutils
elif command -v dnf &>/dev/null; then
  dnf install -y mailx iputils procps-ng iproute gawk sed coreutils
elif command -v yum &>/dev/null; then
  yum install -y mailx iputils procps-ng iproute gawk sed coreutils
elif command -v pacman &>/dev/null; then
  pacman -Sy --noconfirm s-nail iputils procps-ng iproute2 gawk sed coreutils
elif command -v zypper &>/dev/null; then
  zypper install -y mailx iputils procps iproute2 gawk sed coreutils
else
  echo -e "${YELLOW}Warning: Unrecognized package manager. Please ensure ping, ss/netstat, mail, and awk are installed.${RESET}"
fi

echo -e "${CYAN}==> Installing cybersecmon binary to ${BIN_TARGET}...${RESET}"
chmod +x "$SCRIPT_DIR/health_monitor.sh"
cp "$SCRIPT_DIR/health_monitor.sh" "$BIN_TARGET"
ln -sf "$BIN_TARGET" "/usr/local/bin/health_monitor"

echo -e "${CYAN}==> Setting up default configuration at ${CONFIG_TARGET}...${RESET}"
if [ ! -f "$CONFIG_TARGET" ]; then
  cat <<EOF > "$CONFIG_TARGET"
# System-wide CyberSec Monitor Configuration
EMAIL_ALERT=""
CPU_LIMIT=80
MEM_LIMIT=80
DISK_LIMIT=85
LOGIN_FAIL_LIMIT=5
REPORT_DIR="/var/log/cybersecmon"
LOG_FILE="/var/log/cybersecmon/security.log"
EOF
  mkdir -p /var/log/cybersecmon
  chmod 750 /var/log/cybersecmon
fi

if [ -f "$SCRIPT_DIR/cybersecmon.service" ]; then
  echo -e "${CYAN}==> Installing systemd service to ${SERVICE_TARGET}...${RESET}"
  cp "$SCRIPT_DIR/cybersecmon.service" "$SERVICE_TARGET"
  systemctl daemon-reload || true
fi

echo -e "\n${GREEN}${BOLD}✔ CyberSec Monitor installation completed successfully!${RESET}"
echo -e "You can now run: ${CYAN}cybersecmon${RESET} or ${CYAN}cybersecmon --help${RESET}"
echo -e "To start background service: ${CYAN}systemctl enable --now cybersecmon${RESET}\n"
