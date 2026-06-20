#!/usr/bin/env bash
# Reverse arm-netconsole-v01.sh — remove all targets and restore defaults. Run with sudo.
CFG=/sys/kernel/config/netconsole
for n in nas96 nas97 nas98; do
  d="$CFG/$n"
  if [ -d "$d" ]; then echo 0 > "$d/enabled" 2>/dev/null || true; rmdir "$d" 2>/dev/null && echo "removed $n"; fi
done
echo Y > /sys/module/printk/parameters/console_suspend 2>/dev/null || true
rmmod netconsole 2>/dev/null && echo "netconsole module unloaded" || echo "(netconsole module still loaded / in use)"
echo "disarmed; console_suspend restored to $(cat /sys/module/printk/parameters/console_suspend 2>/dev/null)"
