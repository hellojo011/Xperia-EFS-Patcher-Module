#!/system/bin/sh
# Installer hook (KernelSU / Magisk).

STATE=/data/adb/efsprofile

ui_print "- EFS Carrier Profile (KR VoLTE)"

if [ "$ARCH" != "arm64" ]; then
  abort "! arm64 only"
fi
if [ ! -f /vendor/lib64/libdiag.so ]; then
  abort "! /vendor/lib64/libdiag.so not found (Qualcomm diag required)"
fi

set_perm "$MODPATH/bin/efsdiag" 0 0 0755
set_perm "$MODPATH/efsctl.sh" 0 0 0755
set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755

mkdir -p "$STATE/partitions" "$STATE/tx"
chmod 700 "$STATE"

# One-time raw backup of the modem EFS partitions (restore with dd if needed).
for p in modemst1 modemst2 fsg fsc; do
  src=/dev/block/by-name/$p
  dst=$STATE/partitions/$p.img
  [ -e "$src" ] || continue
  if [ -s "$dst" ]; then
    ui_print "- $p backup already exists"
  elif dd if="$src" of="$dst" bs=1M 2>/dev/null; then
    ui_print "- Backed up $p -> $dst"
  else
    rm -f "$dst"
    ui_print "! Failed to back up $p"
  fi
done

if [ -d /data/adb/modules/efstrigger ] && [ ! -f /data/adb/modules/efstrigger/disable ]; then
  ui_print "! efstrigger module is active."
  ui_print "! Disable it so the two tools never talk to diag at once."
fi

ui_print "- Open this module's WebUI to choose carriers and apply."
ui_print "- Without a WebUI (stock Magisk), use the module's action button."
