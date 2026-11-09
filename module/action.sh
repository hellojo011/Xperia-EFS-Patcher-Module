#!/system/bin/sh
# Action button (Magisk / KernelSU / APatch). Works without the WebUI, so it is
# the way to use the module on stock Magisk:
#   1. read-only status check of the modem EFS and IMS registration
#   2. optional apply of the SIM carriers (or the saved choice), confirmed with
#      the volume keys; nothing is written without Volume Up.
# Texts follow the system language (Korean, Russian, Chinese, else English).
MODDIR=${0%/*}
STATE=/data/adb/efsprofile
CTL="sh $MODDIR/efsctl.sh"
mkdir -p "$STATE"

kv() { sed -n "s/^$1=//p" "$2" | head -n 1; }

L=$(getprop persist.sys.locale)
[ -n "$L" ] || L=$(getprop ro.product.locale)
case "$L" in ko*) L=ko ;; ru*) L=ru ;; zh*) L=zh ;; *) L=en ;; esac

# m KEY [ARG...]: one line of text in language $L ($2, $3, ... fill in).
m() {
  local k=$1
  shift
  case "$L/$k" in
    ko/none) echo "없음" ;;
    ru/none) echo "нет" ;;
    zh/none) echo "无" ;;
    */none) echo "none" ;;
    ko/model) echo "모델 $1 · 빌드 $2" ;;
    ru/model) echo "Модель $1 · сборка $2" ;;
    zh/model) echo "型号 $1 · 版本号 $2" ;;
    */model) echo "Model $1 · build $2" ;;
    ko/efsver) echo "EFS 프로필 버전 $1" ;;
    ru/efsver) echo "Версия профилей EFS $1" ;;
    zh/efsver) echo "EFS 配置版本 $1" ;;
    */efsver) echo "EFS profile version $1" ;;
    ko/reading) echo "모뎀 EFS를 읽는 중입니다 (읽기 전용, 몇 초 걸립니다)..." ;;
    ru/reading) echo "Чтение EFS модема (только чтение, несколько секунд)..." ;;
    zh/reading) echo "正在读取调制解调器 EFS（只读，需要几秒钟）..." ;;
    */reading) echo "Reading the modem EFS (read-only, takes a few seconds)..." ;;
    ko/unknown) echo "판단할 수 없음" ;;
    ru/unknown) echo "не определить" ;;
    zh/unknown) echo "无法判断" ;;
    */unknown) echo "cannot tell" ;;
    ko/match) echo "$1 프로필과 일치 ($2/$3)" ;;
    ru/match) echo "совпадает с профилем $1 ($2/$3)" ;;
    zh/match) echo "与 $1 配置一致（$2/$3）" ;;
    */match) echo "matches the $1 profile ($2/$3)" ;;
    ko/nomatch) echo "어느 통신사 프로필과도 맞지 않음 (가장 가까운 $1 $2/$3)" ;;
    ru/nomatch) echo "не совпадает ни с одним профилем (ближе всего $1 $2/$3)" ;;
    zh/nomatch) echo "与任何运营商配置都不符（最接近 $1 $2/$3）" ;;
    */nomatch) echo "matches no carrier profile (closest $1 $2/$3)" ;;
    ko/near) echo "$1 프로필에 가까움 ($2/$3 일치)" ;;
    ru/near) echo "близко к профилю $1 (совпадает $2/$3)" ;;
    zh/near) echo "接近 $1 配置（$2/$3 一致）" ;;
    */near) echo "close to the $1 profile ($2/$3 match)" ;;
    ko/ims_true) echo "등록됨" ;;
    ru/ims_true) echo "зарегистрирован" ;;
    zh/ims_true) echo "已注册" ;;
    */ims_true) echo "registered" ;;
    ko/ims_false) echo "등록 안 됨" ;;
    ru/ims_false) echo "не зарегистрирован" ;;
    zh/ims_false) echo "未注册" ;;
    */ims_false) echo "not registered" ;;
    ko/ims_unknown) echo "알 수 없음" ;;
    ru/ims_unknown) echo "неизвестно" ;;
    zh/ims_unknown) echo "未知" ;;
    */ims_unknown) echo "unknown" ;;
    ko/applied_kept) echo "마지막 적용: 그대로 유지됨" ;;
    ru/applied_kept) echo "Последнее применение: сохраняется" ;;
    zh/applied_kept) echo "上次写入：保持不变" ;;
    */applied_kept) echo "Last apply: still in place" ;;
    ko/applied_gone) echo "마지막 적용: 사라짐 (모뎀 EFS 초기화로 보입니다)" ;;
    ru/applied_gone) echo "Последнее применение: пропало (похоже на сброс EFS модема)" ;;
    zh/applied_gone) echo "上次写入：已丢失（调制解调器 EFS 似乎已重置）" ;;
    */applied_gone) echo "Last apply: gone (the modem EFS looks reset)" ;;
    ko/applied_part) echo "마지막 적용: $1/$2 파일 일치 (모뎀이 일부를 바꿨습니다)" ;;
    ru/applied_part) echo "Последнее применение: совпадает $1/$2 файлов (модем изменил часть)" ;;
    zh/applied_part) echo "上次写入：$1/$2 个文件一致（调制解调器修改了部分文件）" ;;
    */applied_part) echo "Last apply: $1/$2 files match (the modem changed some)" ;;
    ko/busy) echo "다른 작업이 실행 중이라 상태를 확인하지 못했습니다." ;;
    ru/busy) echo "Выполняется другая операция, состояние не проверено." ;;
    zh/busy) echo "另一项操作正在运行，无法检查状态。" ;;
    */busy) echo "Another operation is running; the status was not checked." ;;
    ko/nodiag) echo "diag에 연결하지 못해 상태를 확인하지 못했습니다." ;;
    ru/nodiag) echo "Не удалось подключиться к diag, состояние не проверено." ;;
    zh/nodiag) echo "无法连接 diag，未能检查状态。" ;;
    */nodiag) echo "Could not connect to diag; the status was not checked." ;;
    ko/integrated) echo "앱과 통합되어 있어 여기서는 적용할 수 없습니다."; echo "설정 > SIM > EFS 통신사 프로필(또는 앱)에서 적용하세요." ;;
    ru/integrated) echo "Модуль интегрирован с приложением, применять здесь нельзя."; echo "Применяйте в Настройки > SIM > Профиль оператора EFS (или в приложении)." ;;
    zh/integrated) echo "已与应用整合，无法在此写入。"; echo "请在 设置 > SIM > EFS 运营商配置（或应用）中写入。" ;;
    */integrated) echo "Integrated with the app; nothing can be applied here."; echo "Apply in Settings > SIM > EFS Carrier Profile (or the app)." ;;
    ko/testmode) echo "테스트 모드: /sdcard/efsinject 의 파일을 씁니다." ;;
    ru/testmode) echo "Тестовый режим: записываются файлы из /sdcard/efsinject." ;;
    zh/testmode) echo "测试模式：写入 /sdcard/efsinject 中的文件。" ;;
    */testmode) echo "Test mode: writes the files in /sdcard/efsinject." ;;
    ko/notarget) echo "적용할 통신사가 없습니다. SIM을 감지하지 못했고 저장된 선택도 없습니다." ;;
    ru/notarget) echo "Нечего применять: SIM не обнаружены и сохранённого выбора нет." ;;
    zh/notarget) echo "没有可写入的运营商：未检测到 SIM，也没有已保存的选择。" ;;
    */notarget) echo "No carrier to apply: no SIM was detected and nothing was chosen before." ;;
    ko/from_sim) echo "SIM 감지" ;;
    ru/from_sim) echo "по SIM" ;;
    zh/from_sim) echo "检测到 SIM" ;;
    */from_sim) echo "detected SIM" ;;
    ko/from_config) echo "저장된 선택" ;;
    ru/from_config) echo "сохранённый выбор" ;;
    zh/from_config) echo "已保存的选择" ;;
    */from_config) echo "saved choice" ;;
    ko/target) echo "적용 대상: SIM1 $1 ($2) · SIM2 $3 ($4)" ;;
    ru/target) echo "Будет применено: SIM1 $1 ($2) · SIM2 $3 ($4)" ;;
    zh/target) echo "写入目标：SIM1 $1（$2）· SIM2 $3（$4）" ;;
    */target) echo "To apply: SIM1 $1 ($2) · SIM2 $3 ($4)" ;;
    ko/gband) echo "글로벌 통합 밴드셋: 사용" ;;
    ru/gband) echo "Глобальный набор диапазонов: вкл." ;;
    zh/gband) echo "全球通用频段集：开启" ;;
    */gband) echo "Global band set: on" ;;
    ko/keys) echo "볼륨 업: 적용   볼륨 다운: 취소"; echo "(10초 동안 누르지 않으면 취소됩니다)" ;;
    ru/keys) echo "Громкость вверх: применить   Громкость вниз: отмена"; echo "(без нажатия в течение 10 секунд — отмена)" ;;
    zh/keys) echo "音量加：写入   音量减：取消"; echo "（10 秒内未按键则取消）" ;;
    */keys) echo "Volume up: apply   Volume down: cancel"; echo "(cancelled if nothing is pressed for 10 seconds)" ;;
    ko/cancelled) echo "취소했습니다. 아무것도 쓰지 않았습니다." ;;
    ru/cancelled) echo "Отменено. Ничего не записано." ;;
    zh/cancelled) echo "已取消，未写入任何内容。" ;;
    */cancelled) echo "Cancelled. Nothing was written." ;;
    ko/starting) echo "적용을 시작합니다." ;;
    ru/starting) echo "Начинается применение." ;;
    zh/starting) echo "开始写入。" ;;
    */starting) echo "Applying." ;;
    ko/done) echo "적용 완료. 10초 뒤 기기를 재시작하세요." ;;
    ru/done) echo "Готово. Перезагрузите устройство через 10 секунд." ;;
    zh/done) echo "写入完成。请在 10 秒后重启设备。" ;;
    */done) echo "Applied. Reboot the device in 10 seconds." ;;
    ko/failed) echo "적용하지 못했습니다. 위 로그를 확인하세요." ;;
    ru/failed) echo "Не удалось применить. Смотрите журнал выше." ;;
    zh/failed) echo "写入失败，请查看上面的日志。" ;;
    */failed) echo "Could not apply. See the log above." ;;
  esac
}

label() { case "$1" in LGU) echo "LG U+" ;; NONE|"") m none ;; *) echo "$1" ;; esac; }

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
  local c=$1 n1=$2 n2=$3
  if [ -z "$c" ]; then m unknown
  elif [ "$n1" = "$n2" ]; then m match "$(label "$c")" "$n1" "$n2"
  elif [ $((n1 * 2)) -lt "$n2" ]; then m nomatch "$(label "$c")" "$n1" "$n2"
  else m near "$(label "$c")" "$n1" "$n2"
  fi
}

ims_text() { case "$1" in true) m ims_true ;; false) m ims_false ;; *) m ims_unknown ;; esac; }

info=$STATE/action.info
chk=$STATE/action.check
tgt=$STATE/action.target

echo "EFS Carrier Profile (KR VoLTE) $(sed -n 's/^version=//p' "$MODDIR/module.prop")"
$CTL info > "$info"
m model "$(kv MODEL "$info")" "$(kv BUILD "$info")"
m efsver "$(kv EFS_VERSION "$info")"
echo
m reading
$CTL check > "$chk" 2>&1
case "$(kv CHECK_RESULT "$chk")" in
  OK)
    for s in 1 2; do
      echo "SIM$s EFS: $(slot_text "$(kv SLOT${s}_CARRIER "$chk")" "$(kv SLOT${s}_MATCH "$chk")" "$(kv SLOT${s}_TOTAL "$chk")")"
      echo "      IMS: $(ims_text "$(kv IMS$s "$chk")")"
    done
    if [ "$(kv APPLIED_TOTAL "$chk")" -gt 0 ] 2>/dev/null; then
      if [ "$(kv APPLIED_MATCH "$chk")" = "$(kv APPLIED_TOTAL "$chk")" ]; then
        m applied_kept
      elif [ -z "$(kv MARKER "$chk")" ]; then
        m applied_gone
      else
        m applied_part "$(kv APPLIED_MATCH "$chk")" "$(kv APPLIED_TOTAL "$chk")"
      fi
    fi
    ;;
  BUSY) m busy ;;
  *) m nodiag ;;
esac
echo

if [ -f "$MODDIR/integrated" ]; then
  m integrated
  exit 0
fi

$CTL action-target > "$tgt"
if [ "$(kv TESTMODE "$tgt")" = 1 ]; then
  m testmode
else
  t1=$(kv TARGET1 "$tgt")
  t2=$(kv TARGET2 "$tgt")
  if [ "$t1" = NONE ] && [ "$t2" = NONE ]; then
    m notarget
    rm -f "$info" "$chk" "$tgt"
    exit 0
  fi
  from() { [ "$1" = sim ] && m from_sim || m from_config; }
  m target "$(label "$t1")" "$(from "$(kv TARGET1_FROM "$tgt")")" "$(label "$t2")" "$(from "$(kv TARGET2_FROM "$tgt")")"
  [ "$(kv GBAND "$info")" = 1 ] && m gband
fi
echo
m keys
key=$(wait_key 10)
rm -f "$info" "$chk" "$tgt"
if [ "$key" != up ]; then
  echo
  m cancelled
  exit 0
fi
echo
m starting
if $CTL quickapply; then
  echo
  m done
else
  echo
  m failed
fi
