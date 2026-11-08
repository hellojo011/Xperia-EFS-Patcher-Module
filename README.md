# EFS Carrier Profile (KR VoLTE)

EFSTools `uploadDirectory`를 대신하는 KernelSU/Magisk 모듈입니다. PC 없이 기기 안에서 vendor `libdiag.so`(DCI)를 통해 Qualcomm 모뎀 EFS에 SKT/KT/LG U+ 프로필을 씁니다.

## 빌드

```
python build.py
```

- NDK: `C:\Android\Sdk\ndk\28.2.13676358`
- 프로필: `efs/<SKT|KT|LGU>/sim1`, `sim2` (모듈 `profiles/`에 같은 구조로 들어갑니다)
- EFS 버전: `efs/info.json`의 `version`, `source`를 빌드할 때 `profiles/info.prop`으로 바꿔 넣습니다. WebUI 기기 카드와 적용 로그에 표시됩니다.
- 결과: `dist/efsprofile_kr-<version>.zip`

## 동작

- WebUI에서 SIM1/SIM2 통신사를 고르고 적용합니다. SIM1에는 `profiles/<통신사>/sim1`, SIM2에는 `profiles/<통신사>/sim2` 폴더를 씁니다(`_Subscription01`).
- `ims_user_agent`는 `TTA-VoLTE/3.0 <기기명>/<ro.build.id> Device_Type/Android_Phone <통신사>` 형식으로 새로 만들고, 1024바이트까지 NUL로 채웁니다.
- 파일을 쓰는 순서는 EfsTools와 같습니다. 상위 폴더를 만들고(mkdir -p), 기존 파일을 지운 뒤(unlink), 새로 만들어 씁니다(open O_CREAT/write). 그다음 다시 읽어서 비교합니다.
- 쓰기 전에 모든 대상 파일을 `/data/adb/efsprofile/tx/<시각>/backup`에 백업합니다. 쓰는 도중 실패하면 자동으로 롤백합니다.
- MBN 자동 선택(`/nv/item_files/mcfg/mcfg_autoselect_by_uim`, SIM2는 `_Subscription01`)은 그대로 / 잠금(0바이트) / 해제(순정 값 0x05) 중에서 SIM1/SIM2별로 따로 고릅니다. 통신사 선택과는 별개로 적용됩니다.
- `*.bak` 파일은 건너뜁니다. `NvItem__*` 항목은 옵션을 켰을 때만 씁니다(NV_WRITE 0x27, 133바이트 패킷).
- 설치할 때 `modemst1/modemst2/fsg/fsc` 파티션을 `/data/adb/efsprofile/partitions/`에 dd로 백업합니다.

## 테스트 모드

`/sdcard/.efstestmode` 파일이 있으면 통신사 선택 대신 `/sdcard/efsinject/SIM1`, `/sdcard/efsinject/SIM2` 폴더의 파일을 그대로 씁니다.

- 폴더 안의 상대 경로가 EFS 경로가 됩니다(예: `SIM1/nv/item_files/ims/IMS_enable` → `/nv/item_files/ims/IMS_enable`).
- SIM2 파일은 이름이 `_Subscription01`로 끝나면 그대로 두고, 아니면 붙입니다.
- 없는 폴더는 건너뜁니다. 적용할 때 폴더를 트랜잭션 폴더(`tx/<시각>/inject`)에 복사해 둡니다.
- 폴더에 `nv/item_files/ims/ims_user_agent`가 있으면 그 파일을 쓰고, WebUI에 내용을 보여 줍니다. SIM2는 `ims_user_agent_Subscription01`도 인식합니다.
- 폴더에 UA 파일이 없으면 UA 자동 생성 메뉴가 다시 나옵니다. 그 SIM에 대해 UA에 넣을 통신사를 고르면 생성합니다.
- MBN 자동 선택, VoLTE 속성, NvItem 옵션은 그대로 적용됩니다.

## modem 초기화 감지 시 자동 재패치 (실험적, 기본 꺼짐)

- 적용에 성공할 때마다 실제로 쓴 내용을 `/data/adb/efsprofile/applied/`에 그대로 복사해 둡니다. 테스트 모드로 적용한 경우도 포함됩니다.
- 옵션을 켜면 `service.sh`가 부팅할 때마다(부팅 완료 후 약 60초 뒤) `efsdiag verify`로 모뎀 EFS를 읽어 이 복사본과 비교합니다. 읽기만 합니다.
- 적용할 때 마커 파일 `/efsprofile_kr/applied`를 마지막에 씁니다. 이 경로는 어떤 통신사 MBN도 건드리지 않으므로, 이 파일이 사라졌다면 모뎀 EFS가 초기화된 것입니다.
- 부팅 때 상황에 따라 다음과 같이 처리합니다.

  | 상황 | 판단 | 동작 |
  |---|---|---|
  | 마커 없음 | 모뎀 초기화 | 달라진 파일 다시 쓰기 (NV 항목 포함) |
  | 빌드 번호(`ro.build.id`) 바뀜 | 펌웨어 업데이트 | 기록된 UA의 빌드 번호를 새 값으로 바꾸고 달라진 파일 다시 쓰기 |
  | 마커 있음, 빌드 같음, 파일만 다름 | 모뎀이 직접 바꿈 (다른 SIM용 MBN 전환 등) | 건드리지 않고 로그만 남김 |
  | 마커 내용이 기록과 다름 | 기록이 실제 적용보다 오래됨 | 건드리지 않음 |

- 다시 쓸 때 백업과 롤백은 일반 적용과 같습니다.
  - 성공하면 상태바 알림을 보내고, 다음에 WebUI를 열 때 토스트를 띄웁니다.
  - 실패하면 `/sdcard/efsprofile_failed.log`에 로그를 남깁니다.
- 초기화 후 다시 쓴 내용이 다음 부팅에서 또 사라져 있으면 더 시도하지 않고 실패로 알립니다. 수동으로 적용하면 다시 시작합니다.
- "마지막 적용 되돌리기"로 복원하면 기록을 지워 자동 재패치를 멈춥니다. 다음 적용 때 다시 켜집니다.
- diag에 연결할 수 없으면 그 부팅은 건너뜁니다. 빌드 변경은 다음 부팅에서 처리합니다.
- 기록은 `/data/adb/efsprofile/auto.log`에 남습니다.

## SIM 통신사 감지 시 자동 패치 (실험적, 기본 꺼짐)

- 부팅 후 SIM 상태가 정해지면(최대 2분 대기) 슬롯별로 `gsm.sim.operator.numeric`(SIM에 기록된 MCC/MNC)를 읽습니다.
  - `45005` SKT, `45002`/`45004`/`45008` KT, `45006` LG U+로 판단합니다. 알뜰폰은 원래 통신사 번호를 그대로 씁니다.
- 마지막으로 적용에 성공한 통신사와 다른 슬롯이 있으면 그 통신사로 바꿔 적용합니다. 이름·UA·MBN·VoLTE 등 다른 옵션은 마지막 적용 값을 그대로 씁니다.
  - 적용 후 재부팅해야 반영됩니다. 상태바 알림과 WebUI 토스트로 알립니다.
- 다음 경우에는 그 슬롯을 건드리지 않습니다: 해외 SIM, 모르는 번호, 빈 슬롯, 준비되지 않은 슬롯. 접속한 망이 아니라 SIM을 보므로 로밍 중에도 바뀌지 않습니다.
- 테스트 모드가 켜져 있거나 마지막 적용이 테스트 모드였으면 동작하지 않습니다.
- 같은 대상으로 적용에 실패하면 다음 성공 전까지 다시 시도하지 않습니다.
- 같은 부팅에서 SIM 변경으로 적용했다면 모뎀 초기화 검사는 건너뜁니다. 방금 쓴 내용이 최신이기 때문입니다.
- **켜진 상태의 SIM 교체**: 옵션이 켜져 있는 동안 감시 프로세스가 떠 있습니다. 부팅이 끝난 뒤 시작되고, WebUI에서 옵션을 켜면 바로 시작됩니다.
  - 폴링하지 않습니다. `efsdiag propwait`가 bionic `__system_property_wait`로 `gsm.sim.state`가 바뀔 때까지 커널(futex)에서 잠들어 있습니다. 실기기에서 측정한 결과 대기 중 CPU 사용은 0틱이었습니다.
  - SIM 상태가 15초 동안 바뀌지 않으면 교체가 끝난 것으로 보고 비교합니다. 다르면 적용하고 재시작 알림을 보냅니다.
  - 옵션을 끄면 감시 프로세스를 바로 종료합니다. 6시간마다 한 번 깨어나 옵션을 다시 확인합니다.
  - propwait를 쓸 수 없는 환경이면 10초 간격 확인으로 자동 전환합니다.
  - 안드로이드의 SIM 변경 브로드캐스트(`SIM_STATE_CHANGED` 등)는 앱만 받을 수 있어서, 모듈 스크립트에서는 속성 대기를 씁니다.

## EFS 프로필 업데이트 (GitHub 릴리스)

모듈을 다시 설치하지 않고 EFS 프로필만 새로 받습니다. 배포 저장소는 [hellojo011/Xperia_KR_EFS_REPO](https://github.com/hellojo011/Xperia_KR_EFS_REPO)이고, 주소는 `efsctl.sh`의 `PACK_REPO`에 고정되어 있습니다.

- WebUI "EFS 프로필 업데이트" 카드에서 "업데이트 확인"을 누르면 최신 릴리스의 태그와 `info.json` 버전을 읽어 옵니다(`efsctl.sh pack-check`). 네트워크는 이 버튼을 누를 때만 씁니다.
- "받기"(`efsctl.sh pack-update <tag>`)는 다음 순서로 진행합니다.
  1. 태그의 소스 zip을 받습니다.
  2. GitHub API에서 그 태그의 파일 목록과 파일별 git blob 해시를 받습니다.
  3. 압축을 풀고 모든 파일의 blob 해시를 계산해 대조합니다. 빠진 파일, 내용이 다른 파일, 목록에 없는 파일이 하나라도 있으면 설치하지 않습니다.
  4. `SKT/KT/LGU` 각각의 `sim1`, `sim2` 폴더와 `info.json`의 version이 있는지 확인한 뒤 `/data/adb/efsprofile/pack/`으로 교체합니다.
- 받기만 하고 모뎀에는 쓰지 않습니다. 반영하려면 받은 뒤 "적용"을 누릅니다.
- 받은 팩과 모듈 내장 팩 중 `info.json` 버전이 더 새로운 쪽을 씁니다. 버전이 같으면 받은 팩을 씁니다(같은 버전을 고쳐 다시 올린 릴리스일 수 있으므로). 그래서 더 새 팩이 들어 있는 모듈로 업데이트하면 자동으로 내장 팩으로 돌아갑니다.
- "업데이트 확인"은 최신 릴리스의 태그가 지금 쓰는 팩의 태그와 다르면 받을 수 있다고 표시합니다. 단, 그 릴리스의 버전이 지금 팩보다 낮으면 표시하지 않습니다. 태그 이름끼리는 비교하지 않으므로 태그는 아무 이름이나 써도 됩니다(기존 태그를 옮기지 말고 새 태그를 만드세요).
- "내장 프로필로 되돌리기"(`pack-remove`)는 받은 팩을 지웁니다.
- **채널 (안정 | 실험)**: WebUI에서 고르면 바로 저장하고 그 채널을 확인합니다(`efsctl.sh pack-channel stable|lab`). 기본값은 안정입니다.
  - 태그가 `-LAB`으로 끝나는 릴리스(예: `261106-1803-LAB`)는 실험 릴리스입니다. 안정 채널은 이 릴리스를 받지 않습니다.
  - 실험 채널은 가장 최근에 발행한 `-LAB` 릴리스를 받습니다. 단, 그 릴리스의 `info.json` 버전이 최신 안정 릴리스보다 높을 때만입니다.
  - `-LAB` 릴리스가 없거나 버전이 안정 릴리스와 같거나 낮으면 "현재 테스트중인 릴리즈가 없습니다."라고 표시하고 안정 릴리스를 대상으로 삼습니다.
  - 실험 팩을 쓰다가 안정 채널로 바꾸면 버전이 더 낮아도 안정 릴리스를 받을 수 있게 표시합니다.
  - 채널별 "최신"은 GitHub 목록 순서가 아니라 각 릴리스의 발행 시각(`published_at`)으로 정합니다.
- 빌드할 때 `efs/`가 태그 위에 있으면 그 태그를 내장 팩의 `info.prop`에 기록합니다.

```
* -text
```

`build.py`는 `efs/`의 파일 중 저장소와 줄바꿈이 다른 파일이 있으면 경고를 출력합니다.

## 현재 상태 확인 (읽기 전용)

WebUI "현재 상태" 카드의 "EFS 상태 확인" 또는 액션 버튼으로 실행합니다(`efsctl.sh check`).

- `efsdiag pull`이 diag 세션 한 번으로 필요한 EFS 파일을 모두 읽어 옵니다. 모뎀에는 아무것도 쓰지 않습니다.
- 슬롯별로 SKT/KT/LG U+ 프로필 파일과 비교해 가장 많이 맞는 통신사를 보여 줍니다.
  - SIM1은 SIM2 폴더가 함께 쓰는 경로(7개)를 빼고 판단합니다.
  - SIM2는 `_Subscription01` 경로만으로 판단합니다.
  - UA와 NV 항목은 비교하지 않습니다.
- 마지막으로 적용한 패치가 그대로인지, 마커가 남아 있는지(초기화 여부)도 보여 줍니다.
- EFS에 들어 있는 UA의 빌드 번호가 현재 빌드와 같은지, MBN 자동 선택 값(잠금/해제/없음)도 보여 줍니다.
- IMS 등록 상태는 `dumpsys`의 `mImsRegistered`를 슬롯별로 읽습니다. 확인 버튼과 관계없이 WebUI를 열 때마다 새로 읽습니다.
- 적용이나 복원에 성공하면 이전 확인 결과를 지웁니다.
## 수동 명령

```
sh /data/adb/modules/efsprofile_kr/efsctl.sh start probe
sh /data/adb/modules/efsprofile_kr/efsctl.sh status
sh /data/adb/modules/efsprofile_kr/efsctl.sh start restore [tx]
```
