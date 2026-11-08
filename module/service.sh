#!/system/bin/sh
# Late start: when the firmware changed since the last carrier apply,
# re-apply that config (efsctl.sh autoapply waits for boot_completed itself).
MODDIR=${0%/*}
sh "$MODDIR/efsctl.sh" autoapply > /dev/null 2>&1 &
