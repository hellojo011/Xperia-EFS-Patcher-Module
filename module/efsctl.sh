#!/system/bin/sh
# EFS carrier profile controller (called by the WebUI and action.sh).
#
#   efsctl.sh info                 key=value device/config summary
#   efsctl.sh save SIM1 SIM2 NAME UA NV VOLTE [MCFG1 MCFG2 [AUTO [AUTOSIM]]]
#   efsctl.sh preview              print generated ims_user_agent strings
#   efsctl.sh start apply|probe|restore [tx]
#   efsctl.sh status               state + log tail
#   efsctl.sh list                 past transactions
#   efsctl.sh check                read-only: carrier profile held per slot,
#                                  match with the last patch, UA/MBN, IMS
#   efsctl.sh export               copy the partition backup to /sdcard
#   efsctl.sh action-target        carriers the action button would apply
#   efsctl.sh quickapply           apply those carriers in the foreground
#   efsctl.sh pack-channel [stable|lab]  show or set the update channel
#   efsctl.sh pack-check [stable|lab]    newest EFS pack release on GitHub
#   efsctl.sh pack-update [tag]    download, verify and install that pack
#   efsctl.sh pack-remove          go back to the pack bundled in the module
#   efsctl.sh integrate on|off     (app only) lock settings to the companion app
#   efsctl.sh autoapply            boot hook (service.sh): apply the profile of
#                                  a newly inserted SIM carrier, replay the last
#                                  patch when the modem EFS no longer holds it
#   efsctl.sh ack                  clear the automatic patch notice (WebUI toast)
#
# With /sdcard/.efstestmode present, apply pushes raw files from
# /sdcard/efsinject/SIM1 and SIM2 instead of the bundled carrier profiles.

MODDIR=${0%/*}
[ "$MODDIR" = "$0" ] && MODDIR=.
MODDIR=$(cd "$MODDIR" && pwd)
STATE=/data/adb/efsprofile
RUNDIR=/data/local/tmp/efsprofile
CONFIG=$STATE/config
LOG=$STATE/last.log
LOCK=$STATE/lock
UA_PREFIX="TTA-VoLTE/3.0"
MCFG_ITEM=/nv/item_files/mcfg/mcfg_autoselect_by_uim
# Stock mcfg_autoselect_by_uim value read from XQ-FS44 (1 byte, 0x05).
MCFG_STOCK='\005'

# Test mode: /sdcard/.efstestmode switches apply to raw files from
# /sdcard/efsinject/SIM1 and SIM2. Read through /data/media/0 (the backing
# directory of /sdcard for user 0) so root never depends on FUSE views.
if [ -d /data/media/0 ]; then SDCARD=/data/media/0; else SDCARD=/sdcard; fi
TEST_FLAG=$SDCARD/.efstestmode
INJECT_DIR=$SDCARD/efsinject
FAILED_LOG=$SDCARD/efsprofile_failed.log

mkdir -p "$STATE/tx"
chmod 700 "$STATE"

SIM1=NONE
SIM2=NONE
NAME=
UA=1
NV=0
VOLTE=1
MCFG1=keep
MCFG2=keep
AUTO=0
AUTOSIM=0
TAB=$(printf '\t')

# Modem reset check: exact copy of the last successful patch, replayed at boot
# when the modem EFS no longer holds it.
APPLIED_DIR=$STATE/applied
AUTO_GUARD=$STATE/auto_repatched
AUTO_GAVEUP=$STATE/auto_gaveup
AUTO_NOTICE=$STATE/auto_notice
AUTO_LAST=$STATE/auto_last
AUTO_LOG=$STATE/auto.log
MARKER_PATH=/efsprofile_kr/applied
MSG_REPATCH_OK="모뎀 파티션의 변경이 감지되어 다시 패치를 성공하였습니다. 10초 뒤 기기를 재시작하세요."
MSG_REPATCH_FAIL="모뎀 파티션의 변경이 감지되어 패치를 시도하였으나 실패하였습니다. /sdcard/efsprofile_failed.log 로그를 확인하세요."
# SIM carrier detection: target (SIM1 SIM2) of a failed automatic apply, so it
# is not retried on every boot.
AUTOSIM_FAILED=$STATE/autosim_failed
SIMWATCH_PID=$STATE/simwatch.pid
MSG_SIM_FAIL="SIM 통신사 변경이 감지되어 패치를 시도하였으나 실패하였습니다. /sdcard/efsprofile_failed.log 로그를 확인하세요."
# Read-only status check result (dropped by every successful write).
CHECK_OUT=$STATE/check.out
# Companion app (LSPosed Settings page / standalone app). "integrated" lives in
# the module folder so reinstalling the module clears it.
APP_PKG=com.digiwb.efsprofile
INTEGRATED_FLAG=$MODDIR/integrated
EXPORT_DIR=$SDCARD/efsprofile_backup

# EFS profile pack: the one bundled in the module (profiles/) or a release
# downloaded from GitHub into $PACK_DIR, whichever has the newer version
# (versions are yymmdd-hhmm, so they sort as strings). On the same version the
# download wins (it may be a fixed re-release). Tag names are never compared,
# so a release can use any tag.
PACK_REPO=hellojo011/Xperia_KR_EFS_REPO
PACK_DIR=$STATE/pack
prop_of() { sed -n "s/^$2=//p" "$1/info.prop" 2>/dev/null | head -n 1; }
pack_key() { echo "$(prop_of "$1" version) $(prop_of "$1" tag)"; }
# True when version "$1" sorts at or after "$2".
key_ge() { [ "$1" = "$2" ] || [ "$(printf '%s\n%s\n' "$1" "$2" | sort | tail -n 1)" = "$1" ]; }
select_profiles() {
  PROFILES=$MODDIR/profiles
  PROFILES_FROM=bundled
  if [ -f "$PACK_DIR/info.prop" ] && key_ge "$(prop_of "$PACK_DIR" version)" "$(prop_of "$MODDIR/profiles" version)"; then
    PROFILES=$PACK_DIR
    PROFILES_FROM=pack
  fi
}
select_profiles

load_config() {
  local file=${1:-$CONFIG}
  [ -f "$file" ] || return 0
  while IFS='=' read -r key value; do
    case "$key" in
      SIM1|SIM2) case "$value" in SKT|KT|LGU|NONE) eval "$key=\$value" ;; esac ;;
      NAME) NAME=$value ;;
      UA|NV|VOLTE|AUTO|AUTOSIM) case "$value" in 0|1) eval "$key=\$value" ;; esac ;;
      MCFG1|MCFG2) case "$value" in keep|lock|unlock) eval "$key=\$value" ;; esac ;;
      # v0.1.3 stored one MCFG value for both slots.
      MCFG) case "$value" in keep|lock|unlock) MCFG1=$value; MCFG2=$value ;; esac ;;
    esac
  done < "$file"
}

default_name() {
  local model
  model=$(getprop ro.product.model)
  case "$model" in
    XQ-FS*) echo "Xperia 1 VII" ;;
    *)
      local market
      market=$(getprop ro.product.marketname)
      [ -n "$market" ] && echo "$market" || echo "$model"
      ;;
  esac
}

build_id() { getprop ro.build.id; }


device_name() { [ -n "$NAME" ] && echo "$NAME" || default_name; }

ua_string() {
  echo "$UA_PREFIX $(device_name)/$(build_id) Device_Type/Android_Phone $1"
}

valid_name() {
  case "$1" in
    *[!A-Za-z0-9\ ._+\(\)-]*) return 1 ;;
  esac
  [ ${#1} -le 64 ]
}

is_busy() { [ -d "$LOCK" ] && kill -0 "$(cat "$LOCK/pid" 2>/dev/null)" 2>/dev/null; }

test_mode() { [ -f "$TEST_FLAG" ]; }

# Prints the ims_user_agent file of an inject folder ($1) for slot $2.
# SIM2 accepts both names since either one lands on the _Subscription01 item.
find_test_ua() {
  local d=$1/nv/item_files/ims f
  for f in "$d"/ims_user_agent "$d"/ims_user_agent__*; do
    [ -f "$f" ] && { echo "$f"; return 0; }
  done
  if [ "$2" = 2 ]; then
    for f in "$d"/ims_user_agent_Subscription01 "$d"/ims_user_agent_Subscription01__*; do
      [ -f "$f" ] && { echo "$f"; return 0; }
    done
  fi
  return 1
}

# UA file content as one printable line (NUL padding dropped).
ua_text() { tr -d '\000' < "$1" | tr '\r\n\t' '   ' | head -c 512; }

# Version info of the EFS profile pack in use (info.prop: version, source, tag).
efs_info() { prop_of "$PROFILES" "$1"; }

app_installed() {
  local d
  for d in /data/app/*/"$APP_PKG"-*; do
    [ -d "$d" ] && return 0
  done
  return 1
}

integrated() { [ -f "$INTEGRATED_FLAG" ]; }

# While integrated, only the companion app (EFS_CLIENT=app) may change settings.
locked() { integrated && [ "$EFS_CLIENT" != app ]; }

cmd_integrate() {
  if [ "$EFS_CLIENT" != app ]; then
    echo "ERROR only the companion app can change integration"
    return 1
  fi
  case "$1" in
    on) : > "$INTEGRATED_FLAG" || return 1 ;;
    off) rm -f "$INTEGRATED_FLAG" ;;
    "") ;;
    *) echo "ERROR usage: integrate on|off"; return 1 ;;
  esac
  echo "INTEGRATED=$(integrated && echo 1 || echo 0)"
}

efstrigger_active() {
  [ -d /data/adb/modules/efstrigger ] && [ ! -f /data/adb/modules/efstrigger/disable ]
}

cmd_info() {
  load_config
  echo "MODEL=$(getprop ro.product.model)"
  echo "BUILD=$(build_id)"
  echo "PLATFORM=$(getprop ro.board.platform)"
  echo "DEFAULT_NAME=$(default_name)"
  echo "EFS_VERSION=$(efs_info version)"
  echo "EFS_SOURCE=$(efs_info source)"
  echo "EFS_TAG=$(efs_info tag)"
  echo "EFS_FROM=$PROFILES_FROM"
  echo "EFS_BUNDLED=$(pack_key "$MODDIR/profiles")"
  echo "PACK_REPO=$PACK_REPO"
  echo "PACK_CHANNEL=$(pack_channel)"
  echo "SIM1=$SIM1"
  echo "SIM2=$SIM2"
  echo "NAME=$NAME"
  echo "UA=$UA"
  echo "NV=$NV"
  echo "VOLTE=$VOLTE"
  echo "MCFG1=$MCFG1"
  echo "MCFG2=$MCFG2"
  echo "AUTO=$AUTO"
  echo "AUTO_ARMED=$([ -f "$APPLIED_DIR/plan.tsv" ] && echo 1 || echo 0)"
  echo "AUTO_ARMED_AT=$(cat "$APPLIED_DIR/time" 2>/dev/null)"
  echo "AUTO_GAVEUP=$([ -f "$AUTO_GAVEUP" ] && echo 1 || echo 0)"
  echo "AUTO_NOTICE=$(cat "$AUTO_NOTICE" 2>/dev/null)"
  echo "AUTO_LAST=$(cat "$AUTO_LAST" 2>/dev/null)"
  echo "AUTOSIM=$AUTOSIM"
  echo "SIMWATCH=$(sim_watching && echo 1 || echo 0)"
  for slot in 1 2; do
    echo "SIM_DETECT$slot=$(detected_carrier "$slot")|$(sim_field gsm.sim.operator.numeric "$slot")|$(sim_field gsm.sim.state "$slot")|$(sim_field gsm.sim.operator.alpha "$slot")"
  done
  echo "TESTMODE=$(test_mode && echo 1 || echo 0)"
  echo "TEST_SIM1=$([ -d "$INJECT_DIR/SIM1" ] && echo 1 || echo 0)"
  echo "TEST_SIM2=$([ -d "$INJECT_DIR/SIM2" ] && echo 1 || echo 0)"
  local slot ua
  for slot in 1 2; do
    ua=$(find_test_ua "$INJECT_DIR/SIM$slot" "$slot")
    echo "TEST_UA$slot=$([ -n "$ua" ] && echo 1 || echo 0)"
    [ -n "$ua" ] && echo "TEST_UA${slot}_TEXT=$(ua_text "$ua")"
  done
  echo "LIBDIAG=$([ -f /vendor/lib64/libdiag.so ] && echo 1 || echo 0)"
  echo "EFSTRIGGER=$(efstrigger_active && echo 1 || echo 0)"
  echo "APP_LINKED=$(app_installed && echo 1 || echo 0)"
  echo "INTEGRATED=$(integrated && echo 1 || echo 0)"
  echo "PARTITION_BACKUP=$(ls "$STATE/partitions" 2>/dev/null | tr '\n' ' ')"
  echo "LAST_TX=$(cat "$STATE/last_tx" 2>/dev/null)"
  echo "LAST_RESULT=$(cat "$STATE/last_result" 2>/dev/null)"
  echo "BUSY=$(is_busy && echo 1 || echo 0)"
  echo "EXPORT_AT=$(cat "$STATE/export_at" 2>/dev/null)"
  # Last status check (if any) and the live IMS registration.
  cat "$CHECK_OUT" 2>/dev/null
  ims_status
}

cmd_save() {
  for v in "$1" "$2"; do
    case "$v" in SKT|KT|LGU|NONE) ;; *) echo "ERROR invalid carrier: $v"; return 1 ;; esac
  done
  if [ -n "$3" ] && ! valid_name "$3"; then
    echo "ERROR device name may only use letters, digits, space and ._+()-"
    return 1
  fi
  for v in "$4" "$5" "$6"; do
    case "$v" in 0|1) ;; *) echo "ERROR invalid flag: $v"; return 1 ;; esac
  done
  for v in "${7:-keep}" "${8:-keep}"; do
    case "$v" in keep|lock|unlock) ;; *) echo "ERROR invalid mcfg mode: $v"; return 1 ;; esac
  done
  case "${9:-0}" in 0|1) ;; *) echo "ERROR invalid auto flag: $9"; return 1 ;; esac
  case "${10:-0}" in 0|1) ;; *) echo "ERROR invalid autosim flag: ${10}"; return 1 ;; esac
  {
    echo "SIM1=$1"
    echo "SIM2=$2"
    echo "NAME=$3"
    echo "UA=$4"
    echo "NV=$5"
    echo "VOLTE=$6"
    echo "MCFG1=${7:-keep}"
    echo "MCFG2=${8:-keep}"
    echo "AUTO=${9:-0}"
    echo "AUTOSIM=${10:-0}"
  } > "$CONFIG"
  echo "SAVED"
}

cmd_preview() {
  load_config
  [ "$SIM1" != NONE ] && echo "SIM1_UA=$(ua_string "$SIM1")"
  [ "$SIM2" != NONE ] && echo "SIM2_UA=$(ua_string "$SIM2")"
  return 0
}

# Writes the ims_user_agent payload: string NUL-padded to 1024 bytes.
make_ua_file() {
  printf '%s' "$(ua_string "$1")" > "$2"
  truncate -s 1024 "$2"
}

# MBN auto-select by UIM, chosen per slot independently of the carrier:
# an empty item pins the current carrier profile.
emit_mcfg() {
  local slot=$1 tx=$2 mcfg remote
  eval "mcfg=\$MCFG$slot"
  [ "$mcfg" = keep ] && return 0
  if [ "$slot" = 1 ]; then remote=$MCFG_ITEM
  else remote=${MCFG_ITEM}_Subscription01; fi
  if [ "$mcfg" = lock ]; then
    : > "$tx/mcfg_sim$slot.bin"
  else
    printf "$MCFG_STOCK" > "$tx/mcfg_sim$slot.bin"
  fi
  printf 'E\t%s\t%s\n' "$remote" "$tx/mcfg_sim$slot.bin"
}

# Emits plan lines for every file under $1, mapped like EfsTools uploadDirectory
# (path relative to $1, name cut at "__", NvItem__<id> as NV items).
#   $2=1  append _Subscription01 to names that do not end with it already
#   $3=1  leave out ims_user_agent files (generated separately)
emit_dir() {
  local src=$1 add_sub=$2 skip_ua=$3 f rel name dir base id
  find "$src" -type f | sort | while read -r f; do
    rel=${f#$src}
    name=${rel##*/}
    dir=${rel%/*}
    case "$name" in
      *.bak) continue ;;
      NvItem__*)
        [ "$NV" = 1 ] || continue
        id=$(echo "${name#NvItem__}" | sed 's/^0*//')
        printf 'N\t%s\t%s\n' "${id:-0}" "$f"
        continue
        ;;
      ims_user_agent|ims_user_agent_Subscription01)
        [ "$skip_ua" = 1 ] && continue
        ;;
    esac
    base=${name%%__*}
    if [ "$add_sub" = 1 ]; then
      case "$base" in
        *_Subscription01) ;;
        *) base=${base}_Subscription01 ;;
      esac
    fi
    printf 'E\t%s\t%s\n' "$dir/$base" "$f"
  done
}

# A path written twice keeps the later (SIM2) content, as with EfsTools.
dedupe_plan() {
  awk -F'\t' '{ key = $1 FS $2; last[key] = NR; line[NR] = $0; k[NR] = key }
    END { for (i = 1; i <= NR; i++) if (last[k[i]] == i) print line[i] }'
}

emit_generated_ua() {
  local slot=$1 carrier=$2 tx=$3 remote
  if [ "$slot" = 1 ]; then remote=/nv/item_files/ims/ims_user_agent
  else remote=/nv/item_files/ims/ims_user_agent_Subscription01; fi
  make_ua_file "$carrier" "$tx/ua_sim$slot.bin"
  printf 'E\t%s\t%s\n' "$remote" "$tx/ua_sim$slot.bin"
}

# Test mode: raw files from the snapshot of /sdcard/efsinject/SIM1|SIM2.
# A folder without an ims_user_agent gets a generated one when UA is on and
# a carrier is chosen for that slot.
build_test_plan() {
  local tx=$1 slot carrier
  for slot in 1 2; do
    emit_mcfg "$slot" "$tx"
    [ -d "$tx/inject/SIM$slot" ] || continue
    emit_dir "$tx/inject/SIM$slot" "$([ "$slot" = 2 ] && echo 1 || echo 0)" 0
    eval "carrier=\$SIM$slot"
    if [ "$UA" = 1 ] && [ "$carrier" != NONE ] && ! find_test_ua "$tx/inject/SIM$slot" "$slot" > /dev/null; then
      emit_generated_ua "$slot" "$carrier" "$tx"
    fi
  done | dedupe_plan
}

# Mirrors EfsTools uploadDirectory: SIM1 folder first, then SIM2 folder.
build_plan() {
  local tx=$1 slot carrier
  for slot in 1 2; do
    eval "carrier=\$SIM$slot"
    if [ "$carrier" != NONE ] && [ ! -d "$PROFILES/$carrier/sim$slot" ]; then
      echo "ERROR missing profile $PROFILES/$carrier/sim$slot" >&2
      return 1
    fi
  done
  for slot in 1 2; do
    emit_mcfg "$slot" "$tx"
    eval "carrier=\$SIM$slot"
    [ "$carrier" = NONE ] && continue
    emit_dir "$PROFILES/$carrier/sim$slot" 0 "$UA"
    [ "$UA" = 1 ] && emit_generated_ua "$slot" "$carrier" "$tx"
  done | dedupe_plan
}

prepare_runtime() {
  # /data/local/tmp maps to the "unrestricted" linker namespace, so the
  # binary can dlopen /vendor/lib64/libdiag.so with its vendor deps.
  mkdir -p "$RUNDIR"
  chmod 700 "$RUNDIR"
  cp -f "$MODDIR/bin/efsdiag" "$RUNDIR/efsdiag" && chmod 700 "$RUNDIR/efsdiag"
}

set_volte_props() {
  for p in ims_avail_ovr volte_avail_ovr vt_avail_ovr wfc_avail_ovr; do
    setprop "persist.dbg.$p" 1
  done
  echo "VoLTE override props set (persist.dbg.*_avail_ovr=1)"
}

run_apply() {
  load_config
  local tx slot carrier ua
  tx=$STATE/tx/$(date +%Y%m%d-%H%M%S)
  mkdir -p "$tx"
  cp "$CONFIG" "$tx/config" 2>/dev/null
  if test_mode; then
    echo "TEST MODE ($TEST_FLAG) NV=$NV VOLTE=$VOLTE MCFG1=$MCFG1 MCFG2=$MCFG2"
    # Snapshot the inject folders so the backup/plan match what was written.
    mkdir -p "$tx/inject"
    for slot in 1 2; do
      if [ -d "$INJECT_DIR/SIM$slot" ]; then
        cp -r "$INJECT_DIR/SIM$slot" "$tx/inject/SIM$slot"
        echo "SIM$slot: $(find "$tx/inject/SIM$slot" -type f | wc -l) files from $INJECT_DIR/SIM$slot"
        ua=$(find_test_ua "$tx/inject/SIM$slot" "$slot")
        eval "carrier=\$SIM$slot"
        if [ -n "$ua" ]; then
          echo "SIM${slot}_UA (inject)=$(ua_text "$ua")"
        elif [ "$UA" = 1 ] && [ "$carrier" != NONE ]; then
          echo "SIM${slot}_UA (generated)=$(ua_string "$carrier")"
        else
          echo "SIM${slot}_UA: none in folder, not generated"
        fi
      else
        echo "SIM$slot: $INJECT_DIR/SIM$slot not found, skipped"
      fi
    done
    build_test_plan "$tx" > "$tx/plan.tsv" || return 1
  else
    echo "SIM1=$SIM1 SIM2=$SIM2 UA=$UA NV=$NV VOLTE=$VOLTE MCFG1=$MCFG1 MCFG2=$MCFG2"
    echo "EFS profiles: version=$(efs_info version) tag=$(efs_info tag) from=$PROFILES_FROM source=$(efs_info source)"
    [ "$UA" = 1 ] && cmd_preview
    build_plan "$tx" > "$tx/plan.tsv" || return 1
  fi
  if [ ! -s "$tx/plan.tsv" ]; then
    echo "ERROR nothing to apply"
    return 1
  fi
  # Marker written last: no carrier MBN owns this path, so it only disappears
  # when the modem EFS itself is reset.
  printf 'efsprofile_kr %s\n' "${tx##*/}" > "$tx/marker.bin"
  printf 'E\t%s\t%s\n' "$MARKER_PATH" "$tx/marker.bin" >> "$tx/plan.tsv"
  echo "PLAN $(grep -c '^E' "$tx/plan.tsv") EFS files, $(grep -c '^N' "$tx/plan.tsv") NV items"
  run_plan "$tx" record
}

# Writes $1/plan.tsv with efsdiag; on success sets the VoLTE props and, with
# $2=record, keeps a copy of what was written for the modem reset check.
run_plan() {
  local tx=$1 rc result
  echo "$tx" > "$STATE/last_tx"
  { "$RUNDIR/efsdiag" apply "$tx/plan.tsv" "$tx"; echo $? > "$tx/rc"; } | tee "$tx/efsdiag.log"
  rc=$(cat "$tx/rc")
  result=$(grep -o 'RESULT=.*' "$tx/efsdiag.log" | tail -n 1)
  echo "${result#RESULT=}" > "$STATE/last_result"
  if [ $rc -eq 0 ]; then
    rm -f "$CHECK_OUT"
    [ "$VOLTE" = 1 ] && set_volte_props
    [ "$2" = record ] && record_applied "$tx"
    echo "Done. Wait about 10 seconds for the modem to sync EFS, then reboot."
  fi
  return $rc
}

# Keeps an exact copy of the written plan in $APPLIED_DIR (test mode included),
# so a boot check can tell whether the modem EFS was reset and replay it.
record_applied() {
  local tx=$1 new=$STATE/applied.new i=0 kind target src
  rm -rf "$new"
  mkdir -p "$new" || return 1
  while IFS="$TAB" read -r kind target src; do
    [ -n "$kind" ] || continue
    i=$((i + 1))
    if ! cp "$src" "$new/$i.bin"; then
      rm -rf "$new"
      echo "WARN could not keep a copy of the patch; auto re-patch keeps the previous one"
      return 1
    fi
    printf '%s\t%s\t%s\n' "$kind" "$target" "$APPLIED_DIR/$i.bin" >> "$new/plan.tsv"
  done < "$tx/plan.tsv"
  cp "$tx/config" "$new/config" 2>/dev/null
  date '+%Y-%m-%d %H:%M' > "$new/time"
  build_id > "$new/build"
  # SIM carrier detection must never replace a test mode patch.
  [ -d "$tx/inject" ] && : > "$new/testmode"
  rm -rf "$APPLIED_DIR"
  mv "$new" "$APPLIED_DIR"
  rm -f "$AUTO_GUARD" "$AUTO_GAVEUP" "$AUTOSIM_FAILED"
}

# A restore puts the EFS back on purpose; stop the boot check from undoing it.
disarm_applied() {
  rm -rf "$APPLIED_DIR"
  rm -f "$AUTO_GUARD" "$AUTO_GAVEUP"
  echo "Auto re-patch disarmed until the next apply."
}

# Writes the recorded entries listed in $1 (a subset of the recorded plan).
run_reapply() {
  local plan=$1 tx
  if [ ! -f "$APPLIED_DIR/plan.tsv" ] || [ ! -s "$plan" ]; then
    echo "ERROR nothing to re-patch"
    return 1
  fi
  load_config "$APPLIED_DIR/config"
  tx=$STATE/tx/$(date +%Y%m%d-%H%M%S)
  mkdir -p "$tx"
  cp "$APPLIED_DIR/config" "$tx/config" 2>/dev/null
  cp "$plan" "$tx/plan.tsv"
  echo "RE-PATCH of $(cat "$APPLIED_DIR/time" 2>/dev/null): $(grep -c '^E' "$tx/plan.tsv") EFS files, $(grep -c '^N' "$tx/plan.tsv") NV items"
  run_plan "$tx"
}

# Firmware update: recorded ims_user_agent entries that carry the build id of
# the time they were written get the current one. Prints the count.
bump_ua_build() {
  local old=$1 new=$2 n=0 kind target src text size len
  while IFS="$TAB" read -r kind target src; do
    case "$target" in */ims_user_agent|*/ims_user_agent_Subscription01) ;; *) continue ;; esac
    text=$(tr -d '\000' < "$src")
    case "$text" in *"/$old "*) ;; *) continue ;; esac
    size=$(wc -c < "$src")
    printf '%s' "${text%%"/$old "*}/$new ${text#*"/$old "}" > "$src.new"
    len=$(wc -c < "$src.new")
    [ "$len" -gt "$size" ] && size=$len
    truncate -s "$size" "$src.new" && mv "$src.new" "$src" && n=$((n + 1))
  done < "$APPLIED_DIR/plan.tsv"
  echo $n
}

auto_log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$AUTO_LOG"; }

# Best-effort status bar notification. "cmd notification post" refuses uid 0,
# so drop to the shell uid first.
notify() {
  local title="EFS Carrier Profile" tag=efsprofile_kr
  su 2000 -c "cmd notification post -S bigtext -t '$title' $tag '$1'" > /dev/null 2>&1 && return 0
  su -lp 2000 -c "cmd notification post -S bigtext -t '$title' $tag '$1'" > /dev/null 2>&1 && return 0
  cmd notification post -S bigtext -t "$title" "$tag" "$1" > /dev/null 2>&1
}

write_failed_log() {
  {
    echo "EFS Carrier Profile automatic patch failed: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "model: $(getprop ro.product.model)  build: $(build_id)"
    echo
    echo "--- auto.log (last 60 lines)"
    tail -n 60 "$AUTO_LOG" 2>/dev/null
    echo
    echo "--- last run"
    cat "$LOG" 2>/dev/null
  } > "$FAILED_LOG"
  chown 1023:1023 "$FAILED_LOG" 2>/dev/null
  chmod 664 "$FAILED_LOG" 2>/dev/null
}

# Result of an automatic patch: notification now, toast when the WebUI opens.
#   $1  ok | fail | sim_ok | sim_fail      $2  message
auto_notice() {
  echo "$2" > "$AUTO_NOTICE"
  echo "$(date '+%Y-%m-%d %H:%M') $1" > "$AUTO_LAST"
  case "$1" in *fail) write_failed_log ;; esac
  notify "$2"
}

# --- SIM carrier detection -------------------------------------------------

# Field $2 (1-based slot) of a comma separated per-slot property.
sim_field() { getprop "$1" | cut -d, -f"$2"; }

# Carrier of a Korean home SIM by MCC+MNC (MVNOs use their host's code).
# Anything else (foreign or unknown) prints nothing.
carrier_of_plmn() {
  case "$1" in
    45005) echo SKT ;;
    45002|45004|45008) echo KT ;;
    45006) echo LGU ;;
  esac
}

# Carrier of the SIM in slot $1, or nothing when absent/not ready/unknown.
# Uses the SIM's own code, not the serving network, so roaming changes nothing.
detected_carrier() {
  [ "$(sim_field gsm.sim.state "$1")" = LOADED ] || return 0
  carrier_of_plmn "$(sim_field gsm.sim.operator.numeric "$1")"
}

carrier_label() {
  case "$1" in LGU) echo "LG U+" ;; NONE) echo "없음" ;; *) echo "$1" ;; esac
}

# Waits up to 2 minutes for every slot to leave NOT_READY/UNKNOWN.
wait_sim_ready() {
  local i=0 s
  while [ $i -lt 24 ]; do
    s=$(getprop gsm.sim.state)
    case ",$s," in
      ,,|*,NOT_READY,*|*,UNKNOWN,*|*,,*) ;;
      *) return 0 ;;
    esac
    sleep 5
    i=$((i + 1))
  done
  return 1
}

# Applies the profile of the carriers found in the SIM slots when they differ
# from the last successful apply. A slot without a known Korean SIM keeps its
# last value; every other option comes from the last apply as well.
# Returns 0 when it ran an apply this boot (whatever the result).
auto_sim() {
  local base slot det old changed=0 keep_auto=$AUTO keep_autosim=$AUTOSIM target from rc
  if test_mode; then
    auto_log "sim: test mode is on, skipped"
    return 1
  fi
  if [ -f "$APPLIED_DIR/testmode" ]; then
    auto_log "sim: the last apply was a test mode patch, skipped until the next carrier apply"
    return 1
  fi
  wait_sim_ready || auto_log "sim: SIM state not settled ($(getprop gsm.sim.state)), using what is known"
  base=$CONFIG
  [ -f "$APPLIED_DIR/config" ] && base=$APPLIED_DIR/config
  load_config "$base"
  AUTO=$keep_auto
  AUTOSIM=$keep_autosim
  from="$SIM1/$SIM2"
  for slot in 1 2; do
    det=$(detected_carrier "$slot")
    eval "old=\$SIM$slot"
    if [ -n "$det" ] && [ "$det" != "$old" ]; then
      eval "SIM$slot=\$det"
      changed=1
    fi
  done
  if [ $changed = 0 ]; then
    auto_log "sim: $(getprop gsm.sim.operator.numeric) [$(getprop gsm.sim.state)] matches the last apply ($from)"
    return 1
  fi
  target="$SIM1 $SIM2"
  if [ "$(cat "$AUTOSIM_FAILED" 2>/dev/null)" = "$target" ]; then
    auto_log "sim: apply for $target already failed; not retrying until the next successful apply"
    return 1
  fi
  auto_log "sim: carriers changed $from -> $SIM1/$SIM2 ($(getprop gsm.sim.operator.numeric))"
  cmd_save "$SIM1" "$SIM2" "$NAME" "$UA" "$NV" "$VOLTE" "$MCFG1" "$MCFG2" "$AUTO" "$AUTOSIM" > /dev/null
  while is_busy; do sleep 10; done
  rm -rf "$LOCK"
  : > "$LOG"
  echo "=== automatic apply: SIM carriers changed $from -> $SIM1/$SIM2" >> "$LOG"
  sh "$MODDIR/efsctl.sh" run apply >> "$LOG" 2>&1 < /dev/null
  rc=$?
  auto_log "sim: apply rc=$rc result=$(cat "$STATE/last_result" 2>/dev/null)"
  if [ $rc -eq 0 ]; then
    auto_notice sim_ok "SIM 통신사 변경이 감지되어 패치를 적용하였습니다 (SIM1 $(carrier_label "$SIM1"), SIM2 $(carrier_label "$SIM2")). 10초 뒤 기기를 재시작하세요."
  else
    echo "$target" > "$AUTOSIM_FAILED"
    auto_notice sim_fail "$MSG_SIM_FAIL"
  fi
  return 0
}

# --- boot hook ---------------------------------------------------------------

cmd_autoapply() {
  load_config
  [ "$AUTO" = 1 ] || [ "$AUTOSIM" = 1 ] || return 0
  until [ "$(getprop sys.boot_completed)" = 1 ]; do sleep 5; done
  # Let the modem, diag-router and SIM state settle after boot.
  sleep 60
  # A fresh apply this boot already is the newest patch; skip the reset check.
  if [ "$AUTOSIM" = 1 ] && auto_sim; then
    :
  elif [ "$AUTO" = 1 ]; then
    auto_repatch
  fi
  load_config
  # Keep watching for SIM swaps while the phone stays on. exec so the process
  # is recognisable as the watcher (see sim_watching).
  if [ "$AUTOSIM" = 1 ] && ! sim_watching; then
    exec sh "$MODDIR/efsctl.sh" simwatch boot
  fi
  return 0
}

# --- SIM swap watcher (phone on) ---------------------------------------------

# "states/codes". Not "|": mksh does not strip ${x%%|*} like bash does.
sim_signature() { echo "$(getprop gsm.sim.state)/$(getprop gsm.sim.operator.numeric)"; }

sim_watching() {
  local pid
  pid=$(cat "$SIMWATCH_PID" 2>/dev/null)
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && grep -q simwatch "/proc/$pid/cmdline" 2>/dev/null
}

# Watches for SIM swaps while the option stays on. No polling: efsdiag
# propwait sleeps in the kernel until telephony sets gsm.sim.state again, so
# nothing runs between swaps. Once the state has stayed put for 15 s the SIM
# set is compared with the last apply; the modem loads a new profile on the
# next reboot.
#   $1=boot  the current SIMs were just handled by the boot pass
#   other    started from the WebUI: check the current SIMs once first
cmd_simwatch() {
  local seen= now first=1 rc t0 n waiter="$MODDIR/bin/efsdiag"
  sim_watching && return 0
  echo $$ > "$SIMWATCH_PID"
  if [ "$1" = boot ]; then
    seen=$(sim_signature)
    first=0
  fi
  auto_log "sim watch: started (${1:-webui})"
  while :; do
    if [ $first = 1 ]; then
      first=0
    else
      # Wake every 6 h anyway to re-read the option.
      t0=$(date +%s)
      "$waiter" propwait gsm.sim.state 21600 > /dev/null 2>&1
      rc=$?
      # 0 changed, 1 timeout. Any other code, or a "timeout" that came back
      # at once, means the waiter does not work here: fall back to a slow poll.
      if [ $rc -gt 1 ] || { [ $rc -eq 1 ] && [ $(($(date +%s) - t0)) -lt 60 ]; }; then
        sleep 10
      fi
    fi
    load_config
    [ "$AUTOSIM" = 1 ] || break
    # Let the swap finish: wait until the state stays put for 15 s (at most
    # 20 rounds, so a waiter that keeps returning "changed" cannot spin).
    n=0
    while [ $n -lt 20 ] && "$waiter" propwait gsm.sim.state 15 > /dev/null 2>&1; do
      n=$((n + 1))
    done
    now=$(sim_signature)
    [ "$now" = "$seen" ] && continue
    # Still being read; the next state change wakes us again.
    case ",${now%%/*}," in ,,|*,NOT_READY,*|*,UNKNOWN,*) continue ;; esac
    seen=$now
    auto_log "sim watch: SIM set is now [$now]"
    auto_sim
  done
  auto_log "sim watch: stopped (option turned off)"
  rm -f "$SIMWATCH_PID"
}

# From the WebUI when the option is switched on.
cmd_simwatch_start() {
  load_config
  [ "$AUTOSIM" = 1 ] || return 0
  sim_watching && { echo "WATCHING"; return 0; }
  setsid sh "$MODDIR/efsctl.sh" simwatch > /dev/null 2>&1 < /dev/null &
  echo "STARTED"
}

# From the WebUI when the option is switched off: the watcher may be asleep
# for hours, so end it (and its waiting propwait) now.
cmd_simwatch_stop() {
  local pid kids
  if sim_watching; then
    pid=$(cat "$SIMWATCH_PID")
    kids=$(pgrep -P "$pid" 2>/dev/null)
    kill "$pid" 2>/dev/null
    [ -n "$kids" ] && kill $kids 2>/dev/null
    auto_log "sim watch: stopped (option turned off)"
  fi
  rm -f "$SIMWATCH_PID"
  echo "STOPPED"
}

# Modem reset check. Reads the last patch back from the modem and decides:
#   marker missing             modem EFS was reset      -> write back what differs
#   build id changed           firmware update          -> new build id into the UA,
#                                                          write back what differs
#   marker kept, same build    the modem changed files itself (MBN switch for
#                              another SIM, ...)        -> leave it, log only
# A reset that comes back right after a re-patch is not retried.
auto_repatch() {
  local i rc out=$STATE/auto_verify.out plan=$STATE/repatch_plan.tsv cur old fw=0 reason n
  [ -f "$APPLIED_DIR/plan.tsv" ] || return 0
  [ -f "$AUTO_GAVEUP" ] && return 0
  cur=$(build_id)
  old=$(cat "$APPLIED_DIR/build" 2>/dev/null)
  if [ -n "$old" ] && [ -n "$cur" ] && [ "$old" != "$cur" ]; then
    fw=1
    n=$(bump_ua_build "$old" "$cur")
    [ "$n" -gt 0 ] && auto_log "firmware build $old -> $cur: build id updated in $n recorded UA entries"
  fi
  for i in 1 2 3; do
    while is_busy; do sleep 10; done
    rm -rf "$LOCK"
    sh "$MODDIR/efsctl.sh" run verify > "$out" 2>&1 < /dev/null
    rc=$?
    [ $rc -eq 0 ] || [ $rc -eq 2 ] && break
    [ $i -lt 3 ] && sleep 30
  done
  case $rc in
    0)
      auto_log "check: modem EFS matches the last patch (build $cur)"
      [ -n "$cur" ] && echo "$cur" > "$APPLIED_DIR/build"
      rm -f "$AUTO_GUARD"
      return 0
      ;;
    2) ;;
    *)
      auto_log "check: diag unavailable (rc=$rc), skipped this boot"
      return 0
      ;;
  esac
  n=$(grep -cE '^(DIFF|MISSING) ' "$out")
  if grep -q "^DIFF $MARKER_PATH " "$out"; then
    # The modem holds a patch other than the recorded one (the record of a
    # later apply was lost); replaying the record would roll that apply back.
    auto_log "check: the modem holds a different patch than the recorded one; left alone until the next apply"
    return 0
  fi
  if grep -qx "MISSING $MARKER_PATH" "$out"; then
    reason=reset
  elif [ $fw = 1 ]; then
    reason=firmware
  else
    auto_log "check: $n files differ but the marker is intact and the build is the same; changed by the modem itself (e.g. MBN switch for another SIM), left alone"
    grep -E '^(DIFF|MISSING) ' "$out" | head -n 20 | while read -r line; do auto_log "  $line"; done
    return 0
  fi
  auto_log "check: $reason, $n files differ from the last patch"
  grep -E '^(DIFF|MISSING) ' "$out" | head -n 20 | while read -r line; do auto_log "  $line"; done
  : > "$LOG"
  echo "=== auto re-patch ($reason): modem EFS differs from the last patch" >> "$LOG"
  grep -E '^(DIFF|MISSING|ERROR read|CHECKED)' "$out" >> "$LOG"
  if [ -f "$AUTO_GUARD" ] && [ $reason = reset ]; then
    auto_log "re-patched on the previous boot and lost again; not retrying"
    echo "Re-patched on the previous boot and lost again; not retrying." >> "$LOG"
    touch "$AUTO_GAVEUP"
    auto_notice fail "$MSG_REPATCH_FAIL"
    return 0
  fi
  # Only what differs; NV items are not read back, so they go along on a reset.
  awk -F'\t' -v reset="$([ $reason = reset ] && echo 1 || echo 0)" '
    NR == FNR {
      split($0, a, " ")
      if ($0 ~ /^(DIFF|MISSING) /) want[a[2]] = 1
      else if ($0 ~ /^ERROR read /) want[a[3]] = 1
      next
    }
    ($1 == "E" && ($2 in want)) || ($1 == "N" && reset == 1)
  ' "$out" "$APPLIED_DIR/plan.tsv" > "$plan"
  for i in 1 2; do
    while is_busy; do sleep 10; done
    rm -rf "$LOCK"
    sh "$MODDIR/efsctl.sh" run reapply "$plan" >> "$LOG" 2>&1 < /dev/null
    rc=$?
    auto_log "re-patch attempt $i: rc=$rc result=$(cat "$STATE/last_result" 2>/dev/null)"
    [ $rc -eq 0 ] && break
    case "$(cat "$STATE/last_result" 2>/dev/null)" in FAILED_RESTORE_INCOMPLETE*) break ;; esac
    [ $i -lt 2 ] && sleep 30
  done
  if [ $rc -eq 0 ]; then
    [ -n "$cur" ] && echo "$cur" > "$APPLIED_DIR/build"
    # Only a reset that comes back right away means the patch does not hold.
    if [ $reason = reset ]; then touch "$AUTO_GUARD"; else rm -f "$AUTO_GUARD"; fi
    auto_notice ok "$MSG_REPATCH_OK"
  else
    touch "$AUTO_GAVEUP"
    auto_notice fail "$MSG_REPATCH_FAIL"
  fi
}

# --- status check (read-only) --------------------------------------------------

# IMS registration per slot (IMS1=true|false), read from the phone process.
ims_status() {
  dumpsys activity service com.android.phone 2>/dev/null | awk '
    /mPhoneId=/ { split($0, a, "="); p = a[2] + 0 }
    /mImsRegistered=/ { split($0, b, "="); if (!(p in s)) { s[p] = b[2]; print "IMS" p + 1 "=" b[2] } }'
}

# Entries of carrier $1 slot $2 that only that slot owns: SIM2 paths end in
# _Subscription01; SIM1 paths also written by a SIM2 folder are left out
# (the SIM2 folder is written last and wins).
check_entries() {
  if [ "$2" = 2 ]; then
    awk -F'\t' '$2 ~ /_Subscription01$/' "$3/$1$2.all"
  else
    awk -F'\t' 'NR == FNR { shared[$0] = 1; next } !($2 in shared)' "$3/sim2.paths" "$3/$1$2.all"
  fi
}

# Reads the modem EFS once and reports, per slot, which carrier profile it
# holds, whether it still matches the last patch, the UA and MBN auto-select
# in EFS, and IMS registration. Writes nothing to the modem.
cmd_check() {
  local work=$STATE/check c slot n m k t l best bestm bestn scores f v
  load_config
  NV=0
  mkdir "$LOCK" 2>/dev/null || { echo "CHECK_RESULT=BUSY"; return 1; }
  echo $$ > "$LOCK/pid"
  trap 'rm -rf "$LOCK"' EXIT
  prepare_runtime
  rm -rf "$work"
  mkdir -p "$work/efs"
  for c in SKT KT LGU; do
    for slot in 1 2; do
      [ -d "$PROFILES/$c/sim$slot" ] && emit_dir "$PROFILES/$c/sim$slot" 0 1 > "$work/$c$slot.all"
    done
  done
  cat "$work"/*2.all 2>/dev/null | cut -f2 | sort -u > "$work/sim2.paths"
  {
    cat "$work"/*.all 2>/dev/null | cut -f2
    [ -f "$APPLIED_DIR/plan.tsv" ] && awk -F'\t' '$1 == "E" { print $2 }' "$APPLIED_DIR/plan.tsv"
    echo "$MARKER_PATH"
    echo /nv/item_files/ims/ims_user_agent
    echo /nv/item_files/ims/ims_user_agent_Subscription01
    echo "$MCFG_ITEM"
    echo "${MCFG_ITEM}_Subscription01"
  } | sort -u > "$work/pull.list"
  if ! "$RUNDIR/efsdiag" pull "$work/pull.list" "$work/efs" > "$work/pull.log" 2>&1; then
    echo "CHECK_RESULT=UNAVAILABLE"
    rm -rf "$work"
    return 1
  fi
  {
    echo "CHECK_RESULT=OK"
    echo "CHECK_AT=$(date '+%Y-%m-%d %H:%M')"
    echo "CHECK_ERRORS=$(grep -c '^ERROR read' "$work/pull.log")"
    for slot in 1 2; do
      best=; bestm=0; bestn=1; scores=
      for c in SKT KT LGU; do
        [ -f "$work/$c$slot.all" ] || continue
        n=0; m=0
        check_entries "$c" "$slot" "$work" > "$work/$c$slot.chk"
        while IFS="$TAB" read -r k t l; do
          n=$((n + 1))
          cmp -s "$l" "$work/efs$t" && m=$((m + 1))
        done < "$work/$c$slot.chk"
        [ $n -gt 0 ] || continue
        scores="$scores $c:$m/$n"
        if [ -z "$best" ] || [ $((m * bestn)) -gt $((bestm * n)) ]; then
          best=$c; bestm=$m; bestn=$n
        fi
      done
      echo "SLOT${slot}_CARRIER=$best"
      echo "SLOT${slot}_MATCH=$bestm"
      echo "SLOT${slot}_TOTAL=$bestn"
      echo "SLOT${slot}_SCORES=${scores# }"
    done
    f=$work/efs$MARKER_PATH
    if [ -f "$f" ]; then echo "MARKER=$(head -n 1 "$f" | cut -d' ' -f2)"; else echo "MARKER="; fi
    if [ -f "$APPLIED_DIR/plan.tsv" ]; then
      n=0; m=0
      : > "$work/applied.diff"
      while IFS="$TAB" read -r k t l; do
        [ "$k" = E ] || continue
        n=$((n + 1))
        if [ ! -f "$work/efs$t" ]; then echo "$t" >> "$work/applied.diff"
        elif cmp -s "$l" "$work/efs$t"; then m=$((m + 1))
        else echo "$t" >> "$work/applied.diff"; fi
      done < "$APPLIED_DIR/plan.tsv"
      echo "APPLIED_MATCH=$m"
      echo "APPLIED_TOTAL=$n"
      echo "APPLIED_DIFF=$(head -n 40 "$work/applied.diff" | tr '\n' ' ')"
    else
      echo "APPLIED_TOTAL=0"
    fi
    for slot in 1 2; do
      f=$work/efs/nv/item_files/ims/ims_user_agent
      [ "$slot" = 2 ] && f=${f}_Subscription01
      if [ -f "$f" ]; then echo "UA_EFS$slot=$(ua_text "$f")"; else echo "UA_EFS$slot="; fi
      f=$work/efs$MCFG_ITEM
      [ "$slot" = 2 ] && f=${f}_Subscription01
      if [ ! -f "$f" ]; then v=none
      elif [ ! -s "$f" ]; then v=lock
      else
        v=$(od -An -tx1 "$f" | tr -d ' \n' | cut -c1-16)
        [ "$v" = 05 ] && v=unlock || v="other:$v"
      fi
      echo "MCFG_EFS$slot=$v"
    done
  } > "$CHECK_OUT.new"
  mv "$CHECK_OUT.new" "$CHECK_OUT"
  rm -rf "$work"
  cat "$CHECK_OUT"
  ims_status
}

# --- partition backup export ----------------------------------------------------

# Copies the install-time modem partition images to shared storage (they live
# in /data, which a factory reset wipes) and checks the copies by SHA-256.
cmd_export() {
  local f n=0 shown=/sdcard/${EXPORT_DIR#$SDCARD/}
  if ! ls "$STATE/partitions"/*.img > /dev/null 2>&1; then
    echo "ERROR no partition backup in $STATE/partitions"
    return 1
  fi
  mkdir -p "$EXPORT_DIR" || { echo "ERROR cannot create $shown"; return 1; }
  for f in "$STATE/partitions"/*.img; do
    cp -f "$f" "$EXPORT_DIR/" || { echo "ERROR copy ${f##*/}"; return 1; }
    n=$((n + 1))
  done
  (cd "$STATE/partitions" && sha256sum *.img) > "$EXPORT_DIR/SHA256SUMS"
  if ! (cd "$EXPORT_DIR" && sha256sum -c SHA256SUMS > /dev/null 2>&1); then
    echo "ERROR the copies do not match the originals"
    return 1
  fi
  {
    echo "EFS Carrier Profile - modem partition backup"
    echo "model: $(getprop ro.product.model)"
    echo "build: $(build_id)"
    for f in "$STATE/partitions"/*.img; do
      echo "backed up: $(date -r "$f" '+%Y-%m-%d %H:%M' 2>/dev/null) (at module install)"
      break
    done
    echo "exported: $(date '+%Y-%m-%d %H:%M')"
    echo
    echo "These images hold device-unique data (IMEI and others). Keep them private."
    echo "이 파일에는 IMEI 등 기기 고유 정보가 들어 있습니다. 다른 사람과 공유하지 마세요."
    echo "Check: sha256sum -c SHA256SUMS"
  } > "$EXPORT_DIR/README.txt"
  chown -R 1023:1023 "$EXPORT_DIR" 2>/dev/null
  chmod 775 "$EXPORT_DIR"
  chmod 664 "$EXPORT_DIR"/* 2>/dev/null
  date '+%Y-%m-%d %H:%M' > "$STATE/export_at"
  echo "EXPORTED=$n $shown"
}

# --- action button ---------------------------------------------------------------

# Carriers the action button applies: a known Korean SIM per slot, otherwise
# the saved choice for that slot.
cmd_action_target() {
  local slot det src
  load_config
  for slot in 1 2; do
    det=$(detected_carrier "$slot")
    src=config
    if [ -n "$det" ]; then
      eval "SIM$slot=\$det"
      src=sim
    fi
    eval "echo \"TARGET$slot=\$SIM$slot\""
    echo "TARGET${slot}_FROM=$src"
  done
  echo "TESTMODE=$(test_mode && echo 1 || echo 0)"
}

# Saves the action button target (other options unchanged) and applies it in
# the foreground; output goes to stdout and the WebUI log.
cmd_quickapply() {
  local slot det
  load_config
  if ! test_mode; then
    for slot in 1 2; do
      det=$(detected_carrier "$slot")
      [ -n "$det" ] && eval "SIM$slot=\$det"
    done
    if [ "$SIM1" = NONE ] && [ "$SIM2" = NONE ]; then
      echo "ERROR no carrier to apply"
      return 1
    fi
    cmd_save "$SIM1" "$SIM2" "$NAME" "$UA" "$NV" "$VOLTE" "$MCFG1" "$MCFG2" "$AUTO" "$AUTOSIM" > /dev/null || return 1
  fi
  if is_busy; then
    echo "ERROR another operation is running"
    return 1
  fi
  rm -rf "$LOCK"
  : > "$LOG"
  { sh "$MODDIR/efsctl.sh" run apply < /dev/null 2>&1; echo $? > "$STATE/quick_rc"; } | tee -a "$LOG"
  return "$(cat "$STATE/quick_rc" 2>/dev/null || echo 1)"
}

# --- EFS pack from GitHub releases --------------------------------------------------

gh_api() {
  curl -fsSL --max-time 30 -H 'Accept: application/vnd.github+json' -H 'User-Agent: efsprofile_kr' \
    "https://api.github.com/repos/$PACK_REPO/$1"
}
# First string field $1 of the JSON on stdin (pretty-printed or minified;
# GitHub minifies for non-curl user agents). The release object's own
# tag_name/name/published_at come before any nested object that has them.
json_top() { tr -d '\n' | grep -o "\"$1\": *\"[^\"]*\"" | head -n 1 | sed 's/^[^:]*: *"//; s/"$//'; }
# blob id<TAB>path for every file of a git tree JSON on stdin.
tree_blobs() {
  tr -d '\n' | sed 's/^.*"tree": *\[//' | awk 'BEGIN { RS = "}" }
    function field(name,   v) {
      if (!match($0, "\"" name "\": *\"[^\"]*\"")) return ""
      v = substr($0, RSTART, RLENGTH); sub(/^[^:]*: *"/, "", v); sub(/"$/, "", v); return v
    }
    { p = field("path"); t = field("type"); s = field("sha")
      if (t == "blob" && p != "" && s != "") print s "\t" p }'
}
# Field $1 of info.json on stdin (also the loose form with unquoted keys).
info_field() { sed -nE "s/.*\"?$1\"?[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p" | head -n 1; }
valid_tag() { case "$1" in ""|*[!A-Za-z0-9._-]*) return 1 ;; esac; return 0; }

# Update channel: stable (tags without -LAB) or lab (every release, -LAB
# experimental ones included, so a lab user still gets a newer stable one).
PACK_CHANNEL_FILE=$STATE/pack_channel
pack_channel() { [ "$(cat "$PACK_CHANNEL_FILE" 2>/dev/null)" = lab ] && echo lab || echo stable; }
is_lab_tag() { case "$1" in *-LAB) return 0 ;; esac; return 1; }

# "newest stable tag<TAB>newest -LAB tag" by published_at (the release list
# itself is not in publishing order); either may be empty.
release_tags() {
  gh_api "releases?per_page=100" | tr -d '\n' |
    grep -oE '"(tag_name|published_at)": *"[^"]*"' |
    awk -F'"' '/^"tag_name"/ { t = $4; next } /^"published_at"/ { if (t != "") print $4 "\t" t; t = "" }' |
    sort -r |
    awk -F'\t' '{ if ($2 ~ /-LAB$/) { if (l == "") l = $2 } else if (s == "") s = $2 }
      END { print s "\t" l }'
}
release_version() {
  curl -fsSL --max-time 30 "https://raw.githubusercontent.com/$PACK_REPO/$1/info.json" 2>/dev/null | info_field version
}

# Release to offer on channel $1. Sets TARGET_TAG, and LAB_NONE=1 when the lab
# channel has no -LAB release whose version is newer than the newest stable
# one (then the stable release is the target).
channel_target() {
  local tags s l sv lv
  TARGET_TAG=
  LAB_NONE=0
  tags=$(release_tags)
  s=$(echo "$tags" | cut -f1)
  l=$(echo "$tags" | cut -f2)
  TARGET_TAG=$s
  [ "$1" = lab ] || return 0
  if [ -z "$l" ]; then LAB_NONE=1; return 0; fi
  if [ -z "$s" ]; then TARGET_TAG=$l; return 0; fi
  lv=$(release_version "$l")
  sv=$(release_version "$s")
  if [ -n "$lv" ] && ! key_ge "$sv" "$lv"; then TARGET_TAG=$l; else LAB_NONE=1; fi
}

cmd_pack_channel() {
  case "$1" in
    stable|lab) echo "$1" > "$PACK_CHANNEL_FILE"; echo "PACK_CHANNEL=$1" ;;
    "") echo "PACK_CHANNEL=$(pack_channel)" ;;
    *) echo "ERROR channel must be stable or lab"; return 1 ;;
  esac
}

# Newest release of the channel ($1, default: the saved one) against the pack
# in use. Network only, no install.
cmd_pack_check() {
  local ch=${1:-$(pack_channel)} rel tag info ver cur
  channel_target "$ch"
  tag=$TARGET_TAG
  valid_tag "$tag" || { echo "PACK_CHECK=FAILED"; return 1; }
  rel=$(gh_api "releases/tags/$tag") || { echo "PACK_CHECK=FAILED"; return 1; }
  info=$(curl -fsSL --max-time 30 "https://raw.githubusercontent.com/$PACK_REPO/$tag/info.json") ||
    { echo "PACK_CHECK=FAILED"; return 1; }
  ver=$(echo "$info" | info_field version)
  cur=$(efs_info tag)
  echo "PACK_CHECK=OK"
  echo "PACK_CHANNEL=$ch"
  echo "REMOTE_TAG=$tag"
  echo "REMOTE_LAB=$(is_lab_tag "$tag" && echo 1 || echo 0)"
  echo "LAB_NONE=$LAB_NONE"
  echo "REMOTE_NAME=$(echo "$rel" | json_top name)"
  echo "REMOTE_DATE=$(echo "$rel" | json_top published_at | cut -c1-10)"
  echo "REMOTE_VERSION=$ver"
  echo "REMOTE_SOURCE=$(echo "$info" | info_field source)"
  echo "CURRENT_VERSION=$(efs_info version)"
  echo "CURRENT_TAG=$(efs_info tag)"
  echo "CURRENT_FROM=$PROFILES_FROM"
  echo "CURRENT_LAB=$(is_lab_tag "$cur" && echo 1 || echo 0)"
  # The channel's newest release is newer by definition unless it is the one
  # in use or carries an older version than the pack in use (e.g. a newer
  # bundled pack). Going back from a -LAB pack to stable is always offered.
  if [ "$tag" = "$cur" ]; then
    echo "PACK_UPDATE=0"
  elif [ "$ch" = stable ] && is_lab_tag "$cur"; then
    echo "PACK_UPDATE=1"
    echo "PACK_SWITCH=1"
  elif key_ge "$ver" "$(efs_info version)"; then
    echo "PACK_UPDATE=1"
  else
    echo "PACK_UPDATE=0"
    echo "PACK_OLDER=1"
  fi
}

# Downloads release $1 (default: latest) and installs it as the profile pack.
# Every file is checked against the git blob ids of the tagged tree from the
# GitHub API: nothing missing, nothing changed, nothing extra. Writes nothing
# to the modem; the next apply uses the new pack.
cmd_pack_update() {
  local tag=$1 work=$STATE/pack.dl root sha path f got n=0 bad=0 total ver src c s
  mkdir "$LOCK" 2>/dev/null || { echo "ERROR another operation is running"; echo "PACK_RESULT=BUSY"; return 1; }
  echo $$ > "$LOCK/pid"
  trap 'rm -rf "$LOCK" "$STATE/pack.dl" "$STATE/pack.new"' EXIT
  rm -rf "$work"
  mkdir -p "$work/x"
  if [ -z "$tag" ]; then
    channel_target "$(pack_channel)"
    tag=$TARGET_TAG
  fi
  if ! valid_tag "$tag"; then
    echo "ERROR cannot read the latest release of $PACK_REPO"
    echo "PACK_RESULT=FAILED"
    return 1
  fi
  echo "Release $PACK_REPO $tag"
  if ! curl -fsSL --max-time 120 -H 'User-Agent: efsprofile_kr' -o "$work/pack.zip" \
      "https://api.github.com/repos/$PACK_REPO/zipball/$tag"; then
    echo "ERROR download failed"
    echo "PACK_RESULT=FAILED"
    return 1
  fi
  if ! gh_api "git/trees/$tag?recursive=1" > "$work/tree.json" || ! grep -qE '"truncated": *false' "$work/tree.json"; then
    echo "ERROR cannot read the file list of $tag"
    echo "PACK_RESULT=FAILED"
    return 1
  fi
  tree_blobs < "$work/tree.json" > "$work/blobs.tsv"
  total=$(wc -l < "$work/blobs.tsv")
  if [ "$total" -lt 1 ] || grep -qE '(^|/)\.\.(/|$)|\\' "$work/blobs.tsv"; then
    echo "ERROR unexpected file list"
    echo "PACK_RESULT=FAILED"
    return 1
  fi
  if ! unzip -q "$work/pack.zip" -d "$work/x" > /dev/null 2>&1 || [ "$(ls "$work/x" | wc -l)" != 1 ]; then
    echo "ERROR the archive cannot be unpacked"
    echo "PACK_RESULT=FAILED"
    return 1
  fi
  root=$work/x/$(ls "$work/x")
  while IFS="$TAB" read -r sha path; do
    f=$root/$path
    if [ ! -f "$f" ]; then
      echo "MISSING $path"
      bad=$((bad + 1))
      continue
    fi
    got=$({ printf 'blob %d\0' "$(($(wc -c < "$f")))"; cat "$f"; } | sha1sum | cut -d' ' -f1)
    if [ "$got" = "$sha" ]; then n=$((n + 1)); else echo "MISMATCH $path"; bad=$((bad + 1)); fi
  done < "$work/blobs.tsv"
  if [ "$(find "$root" -type f | wc -l)" != "$total" ]; then
    echo "EXTRA files in the archive that are not in the release"
    bad=$((bad + 1))
  fi
  echo "VERIFIED $n/$total files"
  if [ $bad -gt 0 ]; then
    echo "ERROR the download does not match the release"
    echo "PACK_RESULT=FAILED"
    return 1
  fi
  for c in SKT KT LGU; do
    for s in 1 2; do
      if [ -z "$(find "$root/$c/sim$s" -type f 2>/dev/null | head -n 1)" ]; then
        echo "ERROR the release has no $c/sim$s"
        echo "PACK_RESULT=FAILED"
        return 1
      fi
    done
  done
  ver=$(info_field version < "$root/info.json" 2>/dev/null)
  src=$(info_field source < "$root/info.json" 2>/dev/null)
  if [ -z "$ver" ]; then
    echo "ERROR info.json has no version"
    echo "PACK_RESULT=FAILED"
    return 1
  fi
  rm -rf "$STATE/pack.new"
  mkdir -p "$STATE/pack.new"
  for c in SKT KT LGU; do cp -r "$root/$c" "$STATE/pack.new/$c" || { echo "PACK_RESULT=FAILED"; return 1; }; done
  {
    echo "version=$ver"
    echo "source=$src"
    echo "tag=$tag"
    echo "downloaded=$(date '+%Y-%m-%d %H:%M')"
  } > "$STATE/pack.new/info.prop"
  rm -rf "$STATE/pack.old"
  [ -d "$PACK_DIR" ] && mv "$PACK_DIR" "$STATE/pack.old"
  mv "$STATE/pack.new" "$PACK_DIR"
  rm -rf "$STATE/pack.old"
  # The status check compares against the pack, so its result is stale now.
  rm -f "$CHECK_OUT"
  select_profiles
  echo "Installed $tag (version $ver). In use: $([ "$PROFILES_FROM" = pack ] && echo "this download" || echo "the newer pack bundled in the module")."
  echo "PACK_RESULT=OK $tag $ver"
}

cmd_pack_remove() {
  if is_busy; then echo "PACK_RESULT=BUSY"; return 1; fi
  rm -rf "$PACK_DIR"
  rm -f "$CHECK_OUT"
  echo "PACK_RESULT=REMOVED"
}

run_restore() {
  local tx=${1:-$(cat "$STATE/last_tx" 2>/dev/null)}
  case "$tx" in
    "$STATE"/tx/*) ;;
    *) tx=$STATE/tx/$tx ;;
  esac
  if [ ! -f "$tx/manifest.tsv" ]; then
    echo "ERROR no restorable transaction: $tx"
    return 1
  fi
  echo "Restoring $tx"
  "$RUNDIR/efsdiag" restore "$tx"
  local rc=$?
  echo "RESTORED_FROM ${tx##*/}" > "$STATE/last_result"
  if [ $rc -eq 0 ]; then
    rm -f "$CHECK_OUT"
    disarm_applied
    echo "Done. Reboot to reload the restored profile."
  fi
  return $rc
}

cmd_run() {
  local action=$1 rc
  mkdir "$LOCK" 2>/dev/null || { echo "ERROR another operation is running"; return 1; }
  echo $$ > "$LOCK/pid"
  trap 'rm -rf "$LOCK"' EXIT
  echo "=== $action $(date '+%Y-%m-%d %H:%M:%S')"
  if efstrigger_active; then
    echo "WARN efstrigger module is active; do not run it at the same time."
  fi
  prepare_runtime
  case "$action" in
    probe) "$RUNDIR/efsdiag" probe ;;
    apply) run_apply ;;
    restore) run_restore "$2" ;;
    verify) "$RUNDIR/efsdiag" verify "$APPLIED_DIR/plan.tsv" ;;
    reapply) run_reapply "$2" ;;
    *) echo "ERROR unknown action $action"; false ;;
  esac
  rc=$?
  echo "=== exit $rc"
  return $rc
}

cmd_start() {
  case "$1" in probe|apply|restore) ;; *) echo "ERROR unknown action"; return 1 ;; esac
  if is_busy; then
    echo "BUSY"
    return 1
  fi
  rm -rf "$LOCK"
  : > "$LOG"
  setsid sh "$MODDIR/efsctl.sh" run "$1" "$2" >> "$LOG" 2>&1 < /dev/null &
  echo "STARTED"
}

cmd_status() {
  echo "BUSY=$(is_busy && echo 1 || echo 0)"
  echo "---"
  tail -n 300 "$LOG" 2>/dev/null
}

cmd_list() {
  for d in "$STATE"/tx/*; do
    [ -f "$d/manifest.tsv" ] && echo "${d##*/}"
  done
}

# Commands that change settings or the modem; read-only ones stay open.
case "$1" in
  save|quickapply|pack-update|pack-remove|simwatch-start|simwatch-stop) lock_check=1 ;;
  start) [ "$2" = probe ] || lock_check=1 ;;
  pack-channel) [ -n "$2" ] && lock_check=1 ;;
esac
if [ -n "$lock_check" ] && locked; then
  echo "LOCKED app integrated: change settings in the EFS 통신사 프로필 app"
  exit 75
fi

case "$1" in
  info) cmd_info ;;
  integrate) cmd_integrate "$2" ;;
  save) shift; cmd_save "$@" ;;
  preview) cmd_preview ;;
  start) shift; cmd_start "$@" ;;
  run) shift; cmd_run "$@" ;;
  status) cmd_status ;;
  list) cmd_list ;;
  autoapply) cmd_autoapply ;;
  simwatch) cmd_simwatch "$2" ;;
  simwatch-start) cmd_simwatch_start ;;
  simwatch-stop) cmd_simwatch_stop ;;
  ack) rm -f "$AUTO_NOTICE" ;;
  check) cmd_check ;;
  export) cmd_export ;;
  action-target) cmd_action_target ;;
  quickapply) cmd_quickapply ;;
  pack-check) cmd_pack_check "$2" ;;
  pack-channel) cmd_pack_channel "$2" ;;
  pack-update) cmd_pack_update "$2" ;;
  pack-remove) cmd_pack_remove ;;
  *) echo "usage: efsctl.sh info|save|preview|start|status|list|check|export|action-target|quickapply|pack-check|pack-update|pack-remove|integrate|autoapply|simwatch-start|ack"; exit 64 ;;
esac
