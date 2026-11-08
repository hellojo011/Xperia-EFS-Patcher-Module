#!/system/bin/sh
# Action button (Magisk / KernelSU / APatch). Works without the WebUI, so it is
# the way to use the module on stock Magisk:
#   1. read-only status check of the modem EFS and IMS registration
#   2. optional apply of the SIM carriers (or the saved choice), confirmed with
#      the volume keys; nothing is written without Volume Up.
MODDIR=${0%/*}
STATE=/data/adb/efsprofile
CTL="sh $MODDIR/efsctl.sh"
mkdir -p "$STATE"

kv() { sed -n "s/^$1=//p" "$2" | head -n 1; }
label() { case "$1" in LGU) echo "LG U+" ;; NONE|"") echo "없음" ;; *) echo "$1" ;; esac; }

# Prints up | down | none; waits up to $1 seconds for a volume key press.
wait_key() {
  local end ev
  end=$(( $(date +%s) + $1 ))
  while [ "$(date +%s)" -lt "$end" ]; do
    ev=$(timeout 3 getevent -lqc 1 2>/dev/null)
    case "$ev" in
      *KEY_VOLUMEUP*DOWN*) echo up; return 0 ;;
      *KEY_VOLUMEDOWN*DOWN*) echo down; return 0 ;;
    esac
  done
  echo none
}

slot_text() {
  local c=$1 m=$2 n=$3
  if [ -z "$c" ]; then echo "판단할 수 없음"
  elif [ "$m" = "$n" ]; then echo "$(label "$c") 프로필과 일치 ($m/$n)"
  elif [ $((m * 2)) -lt "$n" ]; then echo "어느 통신사 프로필과도 맞지 않음 (가장 가까운 $(label "$c") $m/$n)"
  else echo "$(label "$c") 프로필에 가까움 ($m/$n 일치)"
  fi
}

ims_text() { case "$1" in true) echo "등록됨" ;; false) echo "등록 안 됨" ;; *) echo "알 수 없음" ;; esac; }

info=$STATE/action.info
chk=$STATE/action.check
tgt=$STATE/action.target

echo "EFS Carrier Profile (KR VoLTE) $(sed -n 's/^version=//p' "$MODDIR/module.prop")"
$CTL info > "$info"
echo "모델 $(kv MODEL "$info") · 빌드 $(kv BUILD "$info")"
echo "EFS 프로필 버전 $(kv EFS_VERSION "$info")"
echo
echo "모뎀 EFS를 읽는 중입니다 (읽기 전용, 몇 초 걸립니다)..."
$CTL check > "$chk" 2>&1
case "$(kv CHECK_RESULT "$chk")" in
  OK)
    for s in 1 2; do
      echo "SIM$s EFS: $(slot_text "$(kv SLOT${s}_CARRIER "$chk")" "$(kv SLOT${s}_MATCH "$chk")" "$(kv SLOT${s}_TOTAL "$chk")")"
      echo "      IMS: $(ims_text "$(kv IMS$s "$chk")")"
    done
    if [ "$(kv APPLIED_TOTAL "$chk")" -gt 0 ] 2>/dev/null; then
      if [ "$(kv APPLIED_MATCH "$chk")" = "$(kv APPLIED_TOTAL "$chk")" ]; then
        echo "마지막 적용: 그대로 유지됨"
      elif [ -z "$(kv MARKER "$chk")" ]; then
        echo "마지막 적용: 사라짐 (모뎀 EFS 초기화로 보입니다)"
      else
        echo "마지막 적용: $(kv APPLIED_MATCH "$chk")/$(kv APPLIED_TOTAL "$chk") 파일 일치 (모뎀이 일부를 바꿨습니다)"
      fi
    fi
    ;;
  BUSY) echo "다른 작업이 실행 중이라 상태를 확인하지 못했습니다." ;;
  *) echo "diag에 연결하지 못해 상태를 확인하지 못했습니다." ;;
esac
echo

if [ -f "$MODDIR/integrated" ]; then
  echo "앱과 통합되어 있어 여기서는 적용할 수 없습니다."
  echo "설정 > SIM > EFS 통신사 프로필(또는 앱)에서 적용하세요."
  exit 0
fi

$CTL action-target > "$tgt"
if [ "$(kv TESTMODE "$tgt")" = 1 ]; then
  echo "테스트 모드: /sdcard/efsinject 의 파일을 씁니다."
else
  t1=$(kv TARGET1 "$tgt")
  t2=$(kv TARGET2 "$tgt")
  if [ "$t1" = NONE ] && [ "$t2" = NONE ]; then
    echo "적용할 통신사가 없습니다. SIM을 감지하지 못했고 저장된 선택도 없습니다."
    rm -f "$info" "$chk" "$tgt"
    exit 0
  fi
  from() { [ "$1" = sim ] && echo "SIM 감지" || echo "저장된 선택"; }
  echo "적용 대상: SIM1 $(label "$t1") ($(from "$(kv TARGET1_FROM "$tgt")")) · SIM2 $(label "$t2") ($(from "$(kv TARGET2_FROM "$tgt")"))"
fi
echo
echo "볼륨 업: 적용   볼륨 다운: 취소"
echo "(10초 동안 누르지 않으면 취소됩니다)"
key=$(wait_key 10)
rm -f "$info" "$chk" "$tgt"
if [ "$key" != up ]; then
  echo
  echo "취소했습니다. 아무것도 쓰지 않았습니다."
  exit 0
fi
echo
echo "적용을 시작합니다."
if $CTL quickapply; then
  echo
  echo "적용 완료. 10초 뒤 기기를 재시작하세요."
else
  echo
  echo "적용하지 못했습니다. 위 로그를 확인하세요."
fi
