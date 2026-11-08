#!/system/bin/sh
# Runs when the module is removed. The modem EFS keeps the patch, and
# /data/adb/efsprofile keeps the partition images, the per-apply backups, the
# config and the last patch record, so a reinstall can undo or resume it.
STATE=/data/adb/efsprofile

# Stop the SIM watcher if it is still running in this boot.
pid=$(cat "$STATE/simwatch.pid" 2>/dev/null)
if [ -n "$pid" ] && tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null | grep -q simwatch; then
  for child in $(pgrep -P "$pid"); do kill "$child" 2>/dev/null; done
  kill "$pid" 2>/dev/null
fi

# Runtime leftovers only.
rm -f "$STATE/simwatch.pid" "$STATE/auto_notice" "$STATE/check.out" "$STATE/quick_rc" \
      "$STATE/auto_verify.out" "$STATE/repatch_plan.tsv"
rm -rf "$STATE/lock" "$STATE/applied.new" "$STATE/check" /data/local/tmp/efsprofile
