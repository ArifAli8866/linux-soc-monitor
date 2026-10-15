#!/usr/bin/env bash
# ==========================================================
#  CyberSec Linux Health & Threat Monitor - Uninstaller
#  Author : Arif Ali
#  this is a basic project no production level project so consider it as local use
# ==========================================================

set -e

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

echo -e "${YELLOW}${BOLD}CyberSec Monitor Uninstaller${RESET}"

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Please run this uninstaller as root or with sudo.${RESET}"
  exit 1
fi

echo -e "${CYAN}==> Stopping and disabling systemd service (if active)...${RESET}"
if systemctl is-active --quiet cybersecmon.service 2>/dev/null; then
  systemctl stop cybersecmon.service || true
fi

if systemctl is-enabled --quiet cybersecmon.service 2>/dev/null; then
  systemctl disable cybersecmon.service || true
fi

rm -f /etc/systemd/system/cybersecmon.service
systemctl daemon-reload || true

echo -e "${CYAN}==> Removing installed binaries...${RESET}"
rm -f /usr/local/bin/cybersecmon
rm -f /usr/local/bin/health_monitor

echo -e "${GREEN}${BOLD}✔ CyberSec Monitor has been successfully uninstalled.${RESET}"
echo -e "${YELLOW}Note: Configuration files at /etc/cybersec_monitor.conf and reports were preserved.${RESET}"
