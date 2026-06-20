#!/usr/bin/env bash
# Arm dynamic netconsole on the PC, streaming kernel log to the NAS over UDP.
# Three redundant targets (the NAS's three NICs). Run with sudo.
# Fully reversible: disarm-netconsole-v01.sh
set -e

DEV=enp130s0           # PC LAN interface
LOCAL_IP=<PC_LAN_IP> # PC IP
RPORT=6666             # must match the NAS listener port

modprobe configfs  2>/dev/null || true
modprobe netconsole 2>/dev/null || true
CFG=/sys/kernel/config/netconsole
[ -d "$CFG" ] || { echo "ERROR: netconsole configfs missing at $CFG"; exit 1; }

# CRITICAL: keep the console (and thus netconsole) alive across suspend/resume.
# Default kernel behaviour gags the console during suspend — exactly when we need it.
echo N > /sys/module/printk/parameters/console_suspend
# Max verbosity so the resume path's messages actually go out the wire.
echo 8 > /proc/sys/kernel/printk

add_target() {
  local name=$1 rip=$2 rmac=$3 d="$CFG/$1"
  if [ -d "$d" ]; then echo 0 > "$d/enabled" 2>/dev/null || true; rmdir "$d" 2>/dev/null || true; fi
  mkdir "$d"
  echo "$DEV"      > "$d/dev_name"
  echo "$LOCAL_IP" > "$d/local_ip"
  echo "$rip"      > "$d/remote_ip"
  echo "$rmac"     > "$d/remote_mac"
  echo "$RPORT"    > "$d/remote_port"
  echo 1           > "$d/enabled"
  echo "  armed: $name -> $rip ($rmac)"
}

echo "Arming netconsole on $DEV ($LOCAL_IP) -> NAS udp:$RPORT"
add_target nas96 <NAS_IP_A> <NAS_MAC_A>   # 2.5GbE static, primary
add_target nas97 <NAS_IP_B> <NAS_MAC_B>   # redundant
add_target nas98 <NAS_IP_C> <NAS_MAC_C>   # redundant
echo "console_suspend=$(cat /sys/module/printk/parameters/console_suspend)  printk=$(cat /proc/sys/kernel/printk | awk '{print $1}')"
echo "DONE. Smoke-test:  echo zel-netconsole-test-from-pc > /dev/kmsg"
