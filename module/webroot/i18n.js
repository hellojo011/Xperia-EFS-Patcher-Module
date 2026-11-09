// UI strings of the WebUI: key -> [ko, en, ru, zh]. {0}, {1}... are filled in
// by t(). The body between the first "{" and the last "}" is plain JSON (the
// companion app generates its Android string resources from it).
const I18N_LANGS = ["ko", "en", "ru", "zh"];
const I18N = {
"lang.name": ["한국어", "English", "Русский", "中文"],
"title": ["EFS 통신사 프로필", "EFS Carrier Profile", "Профиль оператора EFS", "EFS 运营商配置"],
"sub": ["EFSTools 없이 기기 안에서 모뎀 EFS에 통신사 프로필을 씁니다.", "Writes carrier profiles to the modem EFS on the device, without EFSTools.", "Записывает профили операторов в EFS модема прямо на устройстве, без EFSTools.", "无需 EFSTools，直接在设备上将运营商配置写入调制解调器 EFS。"],
"noksu": ["KernelSU WebUI 안에서 열어야 동작합니다.", "Open this page in the KernelSU WebUI.", "Откройте эту страницу в WebUI KernelSU.", "请在 KernelSU WebUI 中打开此页面。"],
"loading": ["기기 정보를 불러오는 중…", "Loading device info…", "Загрузка сведений об устройстве…", "正在读取设备信息…"],
"loadfail": ["매니저가 명령 결과를 돌려주지 않아 기기 정보를 불러오지 못했습니다.", "The manager returned no command result, so the device info could not be loaded.", "Менеджер не вернул результат команды, сведения об устройстве не загружены.", "管理器未返回命令结果，无法读取设备信息。"],
"reload": ["다시 시도", "Retry", "Повторить", "重试"],
"applink": ["앱과 연결되어있습니다. 이곳에서 적용한 설정은 앱에서도 확인할 수 있습니다.", "Linked with the app. Settings applied here can also be seen in the app.", "Связано с приложением. Настройки, применённые здесь, видны и в приложении.", "已与应用关联。在此应用的设置也可在应用中查看。"],
"integrated": ["앱과 통합되어있습니다. 이곳에서 설정을 변경할 수 없습니다.", "Integrated with the app. Settings cannot be changed here.", "Интегрировано с приложением. Здесь нельзя менять настройки.", "已与应用整合，无法在此更改设置。"],
"integrated.warn": ["주의: 통합 설정이 켜진 상태에서 앱을 제거하면 모듈을 다시 설치하기 전까지 설정을 영구히 변경할 수 없습니다.", "Note: if the app is uninstalled while integration is on, settings cannot be changed again until the module is reinstalled.", "Внимание: если удалить приложение при включённой интеграции, настройки нельзя будет изменить до переустановки модуля.", "注意：在整合开启时卸载应用，重新安装模块之前将无法再更改设置。"],
"efstrigger": ["efstrigger 모듈이 켜져 있습니다. 두 도구가 동시에 diag를 쓰지 않도록 efstrigger를 비활성화하세요.", "The efstrigger module is enabled. Disable it so the two tools never use diag at the same time.", "Модуль efstrigger включён. Отключите его, чтобы два инструмента не использовали diag одновременно.", "efstrigger 模块已启用。请将其禁用，以免两个工具同时使用 diag。"],

"h.device": ["기기", "Device", "Устройство", "设备"],
"k.model": ["모델", "Model", "Модель", "型号"],
"k.build": ["빌드", "Build", "Сборка", "版本号"],
"k.platform": ["칩셋", "Chipset", "Чипсет", "芯片组"],
"k.efsversion": ["EFS 버전", "EFS version", "Версия EFS", "EFS 版本"],
"k.efssource": ["EFS 출처", "EFS source", "Источник EFS", "EFS 来源"],
"k.simdetect": ["감지된 SIM", "Detected SIMs", "Обнаруженные SIM", "检测到的 SIM"],
"k.partbackup": ["파티션 백업", "Partition backup", "Резервная копия разделов", "分区备份"],
"k.lastresult": ["마지막 결과", "Last result", "Последний результат", "上次结果"],
"b.export": ["파티션 백업을 /sdcard로 내보내기", "Export the partition backup to /sdcard", "Экспортировать резервную копию разделов в /sdcard", "将分区备份导出到 /sdcard"],

"h.pack": ["EFS 프로필 업데이트", "EFS profile update", "Обновление профилей EFS", "EFS 配置更新"],
"pack.channel": ["받을 채널", "Channel", "Канал", "更新通道"],
"k.current": ["사용 중", "In use", "Используется", "当前使用"],
"k.remote": ["최신 릴리스", "Latest release", "Последний релиз", "最新发布"],
"v.notchecked": ["확인 전", "Not checked", "Не проверено", "未检查"],
"b.packcheck": ["업데이트 확인", "Check for updates", "Проверить обновления", "检查更新"],
"b.packupdate": ["받기", "Download", "Скачать", "下载"],
"b.packremove": ["내장 프로필로 되돌리기", "Back to the bundled profiles", "Вернуть встроенные профили", "恢复内置配置"],

"h.status": ["현재 상태", "Current status", "Текущее состояние", "当前状态"],
"k.applied": ["마지막 적용", "Last apply", "Последнее применение", "上次写入"],
"k.ua": ["EFS의 UA", "UA in EFS", "UA в EFS", "EFS 中的 UA"],
"k.mcfg": ["MBN 자동 선택", "MBN auto-select", "Автовыбор MBN", "MBN 自动选择"],
"b.check": ["EFS 상태 확인", "Check EFS status", "Проверить EFS", "检查 EFS 状态"],
"check.hint": ["모뎀 EFS를 읽어 어느 통신사 프로필이 들어 있는지 확인합니다. 쓰지 않습니다. IMS 등록 상태는 열 때마다 새로 읽습니다.", "Reads the modem EFS to see which carrier profile it holds. Writes nothing. IMS registration is read each time the page opens.", "Читает EFS модема, чтобы определить профиль оператора. Ничего не записывает. Регистрация IMS считывается при каждом открытии.", "读取调制解调器 EFS，判断其中是哪家运营商的配置。不写入任何内容。每次打开时重新读取 IMS 注册状态。"],

"testmode.msg": ["테스트 모드입니다.\n/sdcard/efsinject/SIM1\n/sdcard/efsinject/SIM2\n폴더에 efs 파일을 위치시키십시오. 폴더가 없으면 적용하지 않습니다.\n테스트 모드를 중단하려면 /sdcard/.efstestmode 파일을 삭제하십시오.", "Test mode.\nPut the EFS files in the folders\n/sdcard/efsinject/SIM1\n/sdcard/efsinject/SIM2\nA SIM without a folder is skipped.\nDelete /sdcard/.efstestmode to leave test mode.", "Тестовый режим.\nПоместите файлы EFS в папки\n/sdcard/efsinject/SIM1\n/sdcard/efsinject/SIM2\nSIM без папки пропускается.\nЧтобы выйти из тестового режима, удалите /sdcard/.efstestmode.", "测试模式。\n请将 EFS 文件放入以下文件夹：\n/sdcard/efsinject/SIM1\n/sdcard/efsinject/SIM2\n没有文件夹的 SIM 将被跳过。\n删除 /sdcard/.efstestmode 即可退出测试模式。"],
"k.testsim1": ["SIM1 폴더", "SIM1 folder", "Папка SIM1", "SIM1 文件夹"],
"k.testsim2": ["SIM2 폴더", "SIM2 folder", "Папка SIM2", "SIM2 文件夹"],
"test.ua1": ["SIM1: 폴더의 ims_user_agent를 사용합니다.", "SIM1: uses the ims_user_agent from the folder.", "SIM1: используется ims_user_agent из папки.", "SIM1：使用文件夹中的 ims_user_agent。"],
"test.ua2": ["SIM2: 폴더의 ims_user_agent를 사용합니다.", "SIM2: uses the ims_user_agent from the folder.", "SIM2: используется ims_user_agent из папки.", "SIM2：使用文件夹中的 ims_user_agent。"],
"test.hint": ["SIM2 파일은 이름이 _Subscription01로 끝나면 그대로, 아니면 붙여서 씁니다.", "SIM2 files are written as named when the name ends in _Subscription01, otherwise with _Subscription01 added.", "Файлы SIM2 записываются как есть, если имя оканчивается на _Subscription01, иначе этот суффикс добавляется.", "SIM2 文件名以 _Subscription01 结尾则按原名写入，否则自动加上该后缀。"],

"h.carrier": ["SIM별 통신사", "Carrier per SIM", "Оператор для каждой SIM", "各 SIM 的运营商"],
"opt.ua": ["UA 자동 생성", "Generate the UA", "Создавать UA", "自动生成 UA"],
"opt.ua.d": ["TTA-VoLTE/3.0 기기명/빌드 Device_Type/Android_Phone 통신사", "TTA-VoLTE/3.0 device-name/build Device_Type/Android_Phone carrier", "TTA-VoLTE/3.0 имя-устройства/сборка Device_Type/Android_Phone оператор", "TTA-VoLTE/3.0 设备名/版本号 Device_Type/Android_Phone 运营商"],
"ua.testhint": ["테스트 모드: 폴더에 ims_user_agent가 없는 SIM에만 생성합니다. UA 끝에 붙일 통신사를 고르세요(\"없음\"이면 생성하지 않습니다).", "Test mode: a UA is generated only for a SIM whose folder has no ims_user_agent. Pick the carrier for the end of the UA (\"None\" generates none).", "Тестовый режим: UA создаётся только для SIM, в папке которой нет ims_user_agent. Выберите оператора в конце UA («Нет» — не создавать).", "测试模式：仅为文件夹中没有 ims_user_agent 的 SIM 生成 UA。请选择 UA 末尾的运营商（选“无”则不生成）。"],
"ua.carrier1": ["SIM 1 UA 통신사", "SIM 1 UA carrier", "Оператор UA для SIM 1", "SIM 1 UA 运营商"],
"ua.carrier2": ["SIM 2 UA 통신사", "SIM 2 UA carrier", "Оператор UA для SIM 2", "SIM 2 UA 运营商"],
"f.name": ["기기명", "Device name", "Имя устройства", "设备名称"],
"t.badName": ["기기명에는 영문, 숫자, 공백과 ._+()- 만 쓸 수 있습니다", "The device name may only use letters, digits, spaces and ._+()-", "В имени устройства допустимы только латинские буквы, цифры, пробел и ._+()-", "设备名称只能使用英文字母、数字、空格和 ._+()-"],

"h.mcfg": ["MBN 자동 선택 (mcfg_autoselect_by_uim)", "MBN auto-select (mcfg_autoselect_by_uim)", "Автовыбор MBN (mcfg_autoselect_by_uim)", "MBN 自动选择 (mcfg_autoselect_by_uim)"],
"mcfg.hint": ["그대로: 건드리지 않음 · 잠금: 0바이트로 써서 SIM에 따른 MBN 자동 전환을 막고 현재 프로필로 고정 · 해제: 순정 값(1바이트 0x05)으로 되돌려 자동 전환을 다시 켬. 통신사 선택과 따로 적용됩니다.", "Keep: leave as is · Lock: write 0 bytes to stop the SIM-based MBN switch and pin the current profile · Unlock: restore the stock value (1 byte 0x05) to switch automatically again. Applied separately from the carrier choice.", "Не менять: не трогать · Блок.: записать 0 байт, чтобы запретить автопереключение MBN по SIM и закрепить текущий профиль · Разблок.: вернуть заводское значение (1 байт 0x05) и снова включить автопереключение. Применяется отдельно от выбора оператора.", "保持：不改动 · 锁定：写入 0 字节，禁止按 SIM 自动切换 MBN，固定当前配置 · 解锁：恢复原厂值（1 字节 0x05），重新启用自动切换。与运营商选择分开应用。"],
"mcfg.keep": ["그대로", "Keep", "Не менять", "保持"],
"mcfg.lock": ["잠금", "Lock", "Блок.", "锁定"],
"mcfg.unlock": ["해제", "Unlock", "Разблок.", "解锁"],
"mcfg.keep.d": ["그대로 · 건드리지 않음", "Keep · leave as is", "Не менять · не трогать", "保持 · 不改动"],
"mcfg.lock.d": ["잠금 · SIM에 따른 MBN 자동 전환을 막고 현재 프로필로 고정", "Lock · stop the SIM-based MBN switch, pin the current profile", "Блок. · запретить автопереключение MBN по SIM, закрепить текущий профиль", "锁定 · 禁止按 SIM 自动切换 MBN，固定当前配置"],
"mcfg.unlock.d": ["해제 · 순정 값(0x05)으로 되돌려 자동 전환을 다시 켬", "Unlock · stock value (0x05), switch automatically again", "Разблок. · заводское значение (0x05), снова автопереключение", "解锁 · 恢复原厂值 (0x05)，重新自动切换"],

"h.options": ["옵션", "Options", "Параметры", "选项"],
"opt.volte": ["VoLTE 표시 속성 켜기", "Turn on the VoLTE availability props", "Включить свойства доступности VoLTE", "开启 VoLTE 可用性属性"],
"opt.nv": ["NvItem 항목도 쓰기 (실험적)", "Also write NvItem entries (experimental)", "Записывать также NvItem (экспериментально)", "同时写入 NvItem 项（实验性）"],
"opt.nv.d": ["원래 도구는 NV 쓰기 실패를 무시합니다. 꼭 필요할 때만 켜세요.", "The original tool ignores NV write failures. Turn this on only when needed.", "Исходный инструмент игнорирует ошибки записи NV. Включайте только при необходимости.", "原工具会忽略 NV 写入失败。仅在必要时开启。"],
"opt.gband": ["글로벌 통합 밴드셋 사용", "Use the global band set", "Использовать глобальный набор диапазонов", "使用全球通用频段集"],
"opt.gband.d": ["policyman/band_set_01.xml을 통신사 프로필의 파일 대신 글로벌 통합 밴드셋으로 씁니다. 해외에서 쓸 때 필요합니다. 적용을 눌러야 모뎀에 반영되며, 테스트 모드에서는 쓰지 않습니다.", "Writes the global band set as policyman/band_set_01.xml instead of the carrier profile's file. Needed for use outside Korea. Takes effect with Apply; not used in test mode.", "Записывает глобальный набор диапазонов в policyman/band_set_01.xml вместо файла из профиля оператора. Нужно для использования за пределами Кореи. Вступает в силу после «Применить»; в тестовом режиме не используется.", "以全球通用频段集写入 policyman/band_set_01.xml，取代运营商配置中的该文件。在韩国境外使用时需要。点击“写入”后生效；测试模式下不使用。"],
"opt.gband.na": ["이 EFS 프로필 팩에는 글로벌 밴드셋 파일이 없습니다.", "This EFS profile pack has no global band set file.", "В этом пакете профилей EFS нет файла глобального набора диапазонов.", "此 EFS 配置包中没有全球频段集文件。"],
"opt.auto": ["modem 초기화 감지시 자동으로 다시 패치 (실험적)", "Re-patch when a modem reset is detected (experimental)", "Повторять запись при сбросе модема (экспериментально)", "检测到调制解调器重置时自动重新写入（实验性）"],
"opt.auto.d": ["부팅할 때마다 마지막으로 성공한 패치를 모뎀에서 읽어 비교합니다. 펌웨어 플래싱 등으로 모뎀이 초기화되었거나 펌웨어 업데이트로 빌드가 바뀌었으면 달라진 파일만 다시 씁니다. 빌드가 바뀐 경우 ims_user_agent의 빌드 번호도 새 값으로 바꿉니다. 로밍·다른 SIM으로 모뎀이 프로필을 바꾼 경우는 초기화로 보지 않습니다. 다시 쓴 내용이 다음 부팅에서 또 사라져 있으면 더 이상 시도하지 않습니다.", "At every boot, reads the last successful patch back from the modem and compares. If the modem was reset (e.g. by flashing firmware) or a firmware update changed the build, only the files that differ are written again; on a new build the build number in ims_user_agent is updated too. A profile change by the modem itself for roaming or another SIM is not treated as a reset. If the rewritten files are gone again at the next boot, no more attempts are made.", "При каждой загрузке считывает из модема последнюю успешную запись и сравнивает. Если модем был сброшен (например, прошивкой) или обновление сменило сборку, заново записываются только отличающиеся файлы; при новой сборке номер сборки в ims_user_agent тоже обновляется. Смена профиля самим модемом из‑за роуминга или другой SIM сбросом не считается. Если записанное снова пропало при следующей загрузке, попытки прекращаются.", "每次开机时从调制解调器读回上次成功写入的内容并进行比较。若调制解调器被重置（如刷写固件）或固件更新导致版本号变化，只重新写入不同的文件；版本号变化时也会更新 ims_user_agent 中的版本号。漫游或更换 SIM 导致调制解调器自行切换配置不视为重置。若重新写入的内容在下次开机时再次丢失，则不再尝试。"],
"opt.autosim": ["SIM 통신사 감지 시 자동 패치 (실험적)", "Patch for the detected SIM carrier (experimental)", "Запись по обнаруженному оператору SIM (экспериментально)", "根据检测到的 SIM 运营商自动写入（实验性）"],
"opt.autosim.d": ["부팅할 때와 켜진 상태에서 SIM을 교체했을 때 꽂힌 SIM의 통신사(MCC/MNC)를 읽어, 마지막으로 적용한 통신사와 다르면 그 통신사 프로필로 적용합니다. 다른 옵션은 마지막 적용 값을 그대로 씁니다. 해외 SIM·빈 슬롯은 건드리지 않고, 로밍 중에도 바뀌지 않습니다. 테스트 모드로 적용한 상태에서는 동작하지 않습니다. 적용 후 재부팅해야 반영되며, MBN 잠금과 함께 쓰는 것을 권장합니다.", "At boot, and when a SIM is swapped while the phone is on, reads the carrier (MCC/MNC) of the inserted SIM and, if it differs from the last applied carrier, applies that carrier's profile with the other options of the last apply. Foreign SIMs and empty slots are left alone, and roaming changes nothing. Does nothing after a test mode apply. Takes effect after a reboot; best used together with the MBN lock.", "При загрузке и при замене SIM на включённом телефоне определяет оператора (MCC/MNC) вставленной SIM и, если он отличается от последнего применённого, применяет профиль этого оператора с остальными параметрами последнего применения. Иностранные SIM и пустые слоты не трогаются, роуминг ничего не меняет. Не работает после применения в тестовом режиме. Вступает в силу после перезагрузки; лучше использовать вместе с блокировкой MBN.", "开机时以及开机状态下更换 SIM 时，读取所插 SIM 的运营商（MCC/MNC），若与上次写入的运营商不同，则沿用上次写入的其他选项写入该运营商的配置。不处理境外 SIM 和空卡槽，漫游时也不会改变。以测试模式写入后不生效。重启后生效，建议与 MBN 锁定一起使用。"],

"b.apply": ["적용", "Apply", "Применить", "写入"],
"b.probe": ["연결 확인", "Test connection", "Проверить связь", "连接测试"],
"b.restore": ["마지막 적용 되돌리기", "Undo the last apply", "Отменить последнее применение", "撤销上次写入"],
"h.progress": ["진행 상황", "Progress", "Ход выполнения", "进度"],
"st.idle": ["대기 중", "Idle", "Ожидание", "空闲"],
"st.running": ["실행 중…", "Running…", "Выполняется…", "正在运行…"],
"st.done": ["완료: {0} — 10초쯤 기다린 뒤 재부팅하세요.", "Done: {0} — wait about 10 seconds, then reboot.", "Готово: {0} — подождите около 10 секунд и перезагрузите.", "完成：{0} — 等待约 10 秒后重启。"],
"st.failed": ["실패: {0}", "Failed: {0}", "Ошибка: {0}", "失败：{0}"],

"carrier.NONE": ["없음", "None", "Нет", "无"],
"ch.stable": ["안정", "Stable", "Стабильный", "稳定"],
"ch.lab": ["실험", "Lab", "Эксперим.", "实验"],
"t.channelFail": ["채널을 바꾸지 못했습니다", "Could not change the channel", "Не удалось сменить канал", "无法切换通道"],
"t.channelLab": ["실험 채널: -LAB 릴리스까지 받습니다", "Lab channel: -LAB releases included", "Экспериментальный канал: включая релизы -LAB", "实验通道：包含 -LAB 版本"],
"t.channelStable": ["안정 채널: -LAB 릴리스는 받지 않습니다", "Stable channel: no -LAB releases", "Стабильный канал: без релизов -LAB", "稳定通道：不包含 -LAB 版本"],
"t.needInfo": ["기기 정보를 먼저 불러와야 합니다", "Load the device info first", "Сначала загрузите сведения об устройстве", "请先读取设备信息"],
"t.saveFail": ["설정 저장 실패", "Could not save the settings", "Не удалось сохранить настройки", "无法保存设置"],
"t.busy": ["이미 실행 중입니다", "Already running", "Уже выполняется", "已在运行"],
"t.otherBusy": ["다른 작업이 실행 중입니다", "Another operation is running", "Выполняется другая операция", "另一项操作正在运行"],
"t.startFail": ["시작 실패", "Could not start", "Не удалось запустить", "无法启动"],
"t.infoFail": ["기기 정보를 불러오지 못했습니다. 다시 눌러 주세요.", "Could not load the device info. Tap again.", "Не удалось загрузить сведения об устройстве. Нажмите ещё раз.", "无法读取设备信息，请再点一次。"],
"t.noInject": ["efsinject 폴더가 없습니다", "There are no efsinject folders", "Нет папок efsinject", "没有 efsinject 文件夹"],
"t.nothing": ["통신사, MBN 자동 선택, 글로벌 밴드셋 중 하나 이상 고르세요", "Choose a carrier, an MBN auto-select change or the global band set", "Выберите оператора, изменение автовыбора MBN или глобальный набор диапазонов", "请至少选择运营商、MBN 自动选择或全球频段集之一"],
"sum.test": ["[테스트 모드]", "[Test mode]", "[Тестовый режим]", "[测试模式]"],
"sum.noFolder": ["폴더 없음, 건너뜀", "no folder, skipped", "нет папки, пропуск", "无文件夹，跳过"],
"sum.folderUaFile": ["폴더 적용, UA는 폴더 파일", "folder, UA from the folder", "папка, UA из папки", "文件夹，UA 取自文件夹"],
"sum.folderUaGen": ["폴더 적용, UA 생성({0})", "folder, UA generated ({0})", "папка, UA создаётся ({0})", "文件夹，生成 UA（{0}）"],
"sum.folderNoUa": ["폴더 적용, UA 없음", "folder, no UA", "папка, без UA", "文件夹，无 UA"],
"sum.gband": ["글로벌 밴드셋: 사용", "Global band set: on", "Глобальный набор диапазонов: вкл.", "全球频段集：开启"],
"confirm.apply": ["{0}\n모뎀 EFS에 씁니다. 기존 값은 자동 백업됩니다. 계속할까요?", "{0}\nThis writes to the modem EFS. The current values are backed up first. Continue?", "{0}\nБудет выполнена запись в EFS модема. Текущие значения сначала сохраняются. Продолжить?", "{0}\n将写入调制解调器 EFS，现有值会先自动备份。继续吗？"],
"confirm.restore": ["마지막으로 적용하기 전 상태로 EFS를 되돌릴까요?", "Put the EFS back to how it was before the last apply?", "Вернуть EFS в состояние до последнего применения?", "将 EFS 恢复到上次写入之前的状态吗？"],
"t.autoOn": ["모뎀 초기화 자동 패치를 켰습니다.", "Re-patch on modem reset is on.", "Повтор записи при сбросе модема включён.", "已开启调制解调器重置后自动重新写入。"],
"t.autoOff": ["모뎀 초기화 자동 패치를 껐습니다.", "Re-patch on modem reset is off.", "Повтор записи при сбросе модема выключен.", "已关闭调制解调器重置后自动重新写入。"],
"t.autosimOn": ["SIM 통신사 감지 자동 패치를 켰습니다. 켜진 상태의 SIM 교체도 감지합니다.", "Patching for the SIM carrier is on. SIM swaps while the phone is on are detected too.", "Запись по оператору SIM включена. Замена SIM на включённом телефоне тоже отслеживается.", "已开启 SIM 运营商自动写入。开机状态下更换 SIM 也会被检测到。"],
"t.autosimOff": ["SIM 통신사 감지 자동 패치를 껐습니다.", "Patching for the SIM carrier is off.", "Запись по оператору SIM выключена.", "已关闭 SIM 运营商自动写入。"],

"v.unknown": ["알 수 없음", "Unknown", "Неизвестно", "未知"],
"v.none": ["없음", "None", "Нет", "无"],
"sim.notTarget": ["대상 아님", "not supported", "не поддерживается", "不适用"],
"sim.watching": ["교체 감시 중", "watching for SIM swaps", "отслеживание замены SIM", "正在监测 SIM 更换"],
"test.folderYes": ["있음", "Present", "Есть", "有"],
"test.folderNo": ["없음 (건너뜀)", "Missing (skipped)", "Нет (пропуск)", "无（跳过）"],
"test.emptyFile": ["(빈 파일)", "(empty file)", "(пустой файл)", "（空文件）"],
"export.last": ["마지막 내보내기: {0} · /sdcard/efsprofile_backup", "Last export: {0} · /sdcard/efsprofile_backup", "Последний экспорт: {0} · /sdcard/efsprofile_backup", "上次导出：{0} · /sdcard/efsprofile_backup"],
"export.hint": ["백업은 /data에 있어서 기기를 초기화하면 사라집니다. 한 번 내보내 PC 등에 보관하세요.", "The backup lives in /data and is lost on a factory reset. Export it once and keep it on a PC or elsewhere.", "Резервная копия хранится в /data и теряется при сбросе к заводским настройкам. Экспортируйте её и сохраните, например, на ПК.", "备份位于 /data，恢复出厂设置后会丢失。请导出一次并保存到电脑等处。"],
"confirm.export": ["설치 때 떠 둔 모뎀 파티션 이미지를 /sdcard/efsprofile_backup 에 복사합니다.\n이 파일에는 IMEI 등 기기 고유 정보가 들어 있으니 다른 사람과 공유하지 마세요.\n계속할까요?", "Copies the modem partition images taken at install time to /sdcard/efsprofile_backup.\nThey hold device-unique data such as the IMEI; do not share them.\nContinue?", "Копирует образы разделов модема, снятые при установке, в /sdcard/efsprofile_backup.\nВ них есть уникальные данные устройства, например IMEI; не передавайте их другим.\nПродолжить?", "将安装时备份的调制解调器分区镜像复制到 /sdcard/efsprofile_backup。\n其中包含 IMEI 等设备唯一信息，请勿与他人分享。\n继续吗？"],
"t.exported": ["{0}개 이미지를 {1}에 내보냈습니다 (SHA-256 확인 완료)", "Exported {0} images to {1} (SHA-256 checked)", "Экспортировано образов: {0} в {1} (SHA-256 проверены)", "已将 {0} 个镜像导出到 {1}（SHA-256 校验通过）"],
"t.exportFail": ["내보내기 실패", "Export failed", "Ошибка экспорта", "导出失败"],

"pack.lab": ["실험", "lab", "эксп.", "实验"],
"pack.fromPack": ["받은 팩", "downloaded pack", "загруженный пакет", "已下载的包"],
"pack.bundled": ["기본 내장", "bundled", "встроенный", "内置"],
"pack.hintLab": ["실험 채널: 태그가 -LAB으로 끝나는 실험 릴리스까지 받습니다. 그 버전이 안정 릴리스보다 높을 때만 받고, 아니면 안정 릴리스를 받습니다. 검증이 덜 된 프로필일 수 있습니다.", "Lab channel: experimental releases whose tag ends in -LAB are included, but only when newer than the stable release; otherwise the stable release is used. These profiles may be less tested.", "Экспериментальный канал: включаются релизы с тегом на -LAB, но только если они новее стабильного; иначе берётся стабильный. Такие профили могут быть менее проверены.", "实验通道：包含标签以 -LAB 结尾的实验版本，但仅在其比稳定版本更新时才下载，否则下载稳定版本。这些配置可能验证不足。"],
"pack.hintStable": ["안정 채널: -LAB 릴리스는 받지 않습니다.", "Stable channel: -LAB releases are not downloaded.", "Стабильный канал: релизы -LAB не загружаются.", "稳定通道：不下载 -LAB 版本。"],
"pack.hintTail": ["저장소: github.com/{0} · 받기만 하고 모뎀에는 쓰지 않습니다. 받은 뒤 \"적용\"을 눌러야 모뎀에 반영됩니다.", "Repository: github.com/{0} · Downloading writes nothing to the modem; tap \"Apply\" afterwards to use the new profiles.", "Репозиторий: github.com/{0} · Загрузка ничего не пишет в модем; затем нажмите «Применить».", "仓库：github.com/{0} · 下载不会写入调制解调器；下载后需点击“写入”才会生效。"],
"pack.checking": ["확인 중…", "Checking…", "Проверка…", "正在检查…"],
"pack.noResponse": ["응답 없음", "No response", "Нет ответа", "无响应"],
"pack.checkFail": ["확인 실패 (네트워크를 확인하세요)", "Check failed (check the network)", "Ошибка проверки (проверьте сеть)", "检查失败（请检查网络）"],
"pack.labNone": ["현재 테스트중인 릴리즈가 없습니다. · 안정", "No lab release at the moment. · Stable", "Сейчас нет экспериментального релиза. · Стабильный", "目前没有测试中的版本。· 稳定"],
"pack.canSwitch": ["안정 버전으로 되돌릴 수 있음", "can go back to stable", "можно вернуться к стабильному", "可退回稳定版"],
"pack.canUpdate": ["받을 수 있음", "available", "доступно", "可下载"],
"pack.older": ["사용 중인 팩이 더 새로움", "the pack in use is newer", "используемый пакет новее", "当前使用的包更新"],
"pack.latest": ["최신 상태", "up to date", "актуально", "已是最新"],
"pack.download": ["{0} 받기", "Download {0}", "Скачать {0}", "下载 {0}"],
"confirm.pack": ["{0} 릴리스를 받아 EFS 프로필 팩으로 씁니다.\n모든 파일을 GitHub의 파일 목록(해시)과 대조하고, 하나라도 다르면 설치하지 않습니다.\n모뎀에는 쓰지 않습니다. 반영하려면 받은 뒤 \"적용\"을 누르세요.\n계속할까요?", "Downloads release {0} and uses it as the EFS profile pack.\nEvery file is checked against GitHub's file list (hashes); if any differs, nothing is installed.\nNothing is written to the modem; tap \"Apply\" afterwards to use it.\nContinue?", "Загружает релиз {0} и использует его как пакет профилей EFS.\nКаждый файл сверяется со списком файлов GitHub (хэши); при любом расхождении ничего не устанавливается.\nВ модем ничего не записывается; затем нажмите «Применить».\nПродолжить?", "下载 {0} 版本并用作 EFS 配置包。\n每个文件都会与 GitHub 的文件列表（哈希）比对，只要有一个不同就不安装。\n不会写入调制解调器；下载后请点击“写入”使其生效。\n继续吗？"],
"pack.downloading": ["받는 중… (파일 검증 포함, 1분 정도 걸릴 수 있습니다)", "Downloading… (with file checks, may take about a minute)", "Загрузка… (с проверкой файлов, около минуты)", "正在下载…（包括文件校验，可能需要约一分钟）"],
"t.packOk": ["EFS 프로필 {1} ({0})을 받았습니다. 적용을 눌러야 모뎀에 반영됩니다.", "Downloaded EFS profiles {1} ({0}). Tap Apply to write them to the modem.", "Загружены профили EFS {1} ({0}). Нажмите «Применить», чтобы записать их в модем.", "已下载 EFS 配置 {1}（{0}）。点击“写入”后才会写入调制解调器。"],
"pack.got": ["받음", "downloaded", "загружено", "已下载"],
"t.noResponseRetry": ["응답이 없습니다. 잠시 뒤 다시 확인하세요.", "No response. Check again shortly.", "Нет ответа. Проверьте ещё раз чуть позже.", "无响应，请稍后再检查。"],
"t.packFail": ["받지 못했습니다. 진행 상황 로그를 확인하세요.", "The download failed. See the progress log.", "Загрузка не удалась. Смотрите журнал выполнения.", "下载失败，请查看进度日志。"],
"pack.failed": ["받기 실패", "Download failed", "Ошибка загрузки", "下载失败"],
"confirm.packRemove": ["받은 EFS 프로필 팩을 지우고 기본 내장 프로필을 씁니다. 모뎀에는 쓰지 않습니다. 계속할까요?", "Deletes the downloaded EFS profile pack and uses the bundled profiles. Nothing is written to the modem. Continue?", "Удаляет загруженный пакет профилей EFS и использует встроенные профили. В модем ничего не записывается. Продолжить?", "删除已下载的 EFS 配置包并改用内置配置。不会写入调制解调器。继续吗？"],
"t.packRemoved": ["기본 내장 프로필로 되돌렸습니다", "Back to the bundled profiles", "Возвращены встроенные профили", "已恢复内置配置"],
"t.packRemoveFail": ["되돌리지 못했습니다", "Could not go back", "Не удалось вернуть", "无法恢复"],

"slot.unknown": ["판단할 수 없음", "Cannot tell", "Не определить", "无法判断"],
"slot.match": ["{0} 프로필과 일치 ({1}/{2})", "Matches the {0} profile ({1}/{2})", "Совпадает с профилем {0} ({1}/{2})", "与 {0} 配置一致（{1}/{2}）"],
"slot.none": ["어느 통신사 프로필과도 맞지 않음 (가장 가까운 {0} {1}/{2})", "Matches no carrier profile (closest {0} {1}/{2})", "Не совпадает ни с одним профилем (ближе всего {0} {1}/{2})", "与任何运营商配置都不符（最接近 {0} {1}/{2}）"],
"slot.near": ["{0} 프로필에 가까움 ({1}/{2} 일치)", "Close to the {0} profile ({1}/{2} match)", "Близко к профилю {0} (совпадает {1}/{2})", "接近 {0} 配置（{1}/{2} 一致）"],
"mcfg.unlockAuto": ["해제 (자동 전환)", "Unlocked (auto switch)", "Разблок. (автопереключение)", "解锁（自动切换）"],
"mcfg.noFile": ["파일 없음", "No file", "Нет файла", "无文件"],
"mcfg.other": ["기타 값 0x{0}", "Other value 0x{0}", "Другое значение 0x{0}", "其他值 0x{0}"],
"ims.yes": ["등록됨", "Registered", "Зарегистрирован", "已注册"],
"ims.no": ["등록 안 됨", "Not registered", "Не зарегистрирован", "未注册"],
"applied.none": ["기록 없음", "No record", "Нет записи", "无记录"],
"applied.kept": ["그대로 유지됨", "Still in place", "Сохраняется", "保持不变"],
"applied.gone": ["사라짐 (모뎀 EFS 초기화로 보입니다)", "Gone (the modem EFS looks reset)", "Пропало (похоже на сброс EFS модема)", "已丢失（调制解调器 EFS 似乎已重置）"],
"applied.partial": ["{0}/{1} 파일 일치 (모뎀이 일부를 바꿨습니다)", "{0}/{1} files match (the modem changed some)", "Совпадает файлов: {0}/{1} (модем изменил часть)", "{0}/{1} 个文件一致（调制解调器修改了部分文件）"],
"ua.current": ["현재 빌드", "current build", "текущая сборка", "当前版本号"],
"ua.other": ["다른 빌드 번호", "other build number", "другой номер сборки", "其他版本号"],
"check.at": ["확인 시각: {0}", "Checked: {0}", "Проверено: {0}", "检查时间：{0}"],
"check.unread": ["읽지 못한 파일 {0}개", "{0} files could not be read", "Не прочитано файлов: {0}", "{0} 个文件无法读取"],
"check.diff": ["마지막 적용과 달라진 파일 {0}개 보기", "Show {0} files that differ from the last apply", "Показать файлы, отличающиеся от последнего применения: {0}", "查看与上次写入不同的 {0} 个文件"],
"check.diffMax": ["({0}개까지 표시)", "(showing up to {0})", "(показано до {0})", "（最多显示 {0} 个）"],
"check.reading": ["모뎀 EFS를 읽는 중… (몇 초 걸립니다)", "Reading the modem EFS… (takes a few seconds)", "Чтение EFS модема… (несколько секунд)", "正在读取调制解调器 EFS…（需要几秒钟）"],
"t.checkNoResult": ["결과를 받지 못했습니다. 다시 눌러 주세요.", "No result came back. Tap again.", "Результат не получен. Нажмите ещё раз.", "未收到结果，请再点一次。"],
"t.noDiag": ["diag에 연결하지 못했습니다", "Could not connect to diag", "Не удалось подключиться к diag", "无法连接 diag"],
"auto.noBase": ["비교할 패치가 없습니다. 한 번 적용에 성공하면 그 내용을 기준으로 삼습니다.", "No patch to compare yet. The first successful apply becomes the reference.", "Пока нечего сравнивать. Первое успешное применение станет эталоном.", "暂无可比较的写入。首次成功写入后将以其为基准。"],
"auto.gaveup": ["다시 패치해도 유지되지 않아 자동 패치를 멈췄습니다. 수동으로 적용하면 다시 시작합니다.", "Stopped: the re-patch did not hold. A manual apply starts it again.", "Остановлено: повторная запись не сохранилась. Ручное применение запускает снова.", "已停止：重新写入后仍无法保持。手动写入一次即可重新开始。"],
"auto.base": ["기준 패치: {0} 적용분", "Reference: the apply of {0}", "Эталон: применение от {0}", "基准：{0} 的写入"],
"auto.last": ["마지막 자동 패치: {0}", "Last automatic patch: {0}", "Последняя автоматическая запись: {0}", "上次自动写入：{0}"],
"auto.k.ok": ["재패치 성공", "re-patch succeeded", "повторная запись успешна", "重新写入成功"],
"auto.k.fail": ["재패치 실패", "re-patch failed", "повторная запись не удалась", "重新写入失败"],
"auto.k.sim_ok": ["SIM 변경 패치 성공", "SIM change patch succeeded", "запись после смены SIM успешна", "SIM 更换写入成功"],
"auto.k.sim_fail": ["SIM 변경 패치 실패", "SIM change patch failed", "запись после смены SIM не удалась", "SIM 更换写入失败"]
};

// Language: saved choice, else the system (WebView) language, else English.
function i18nPick() {
  let saved = null;
  try { saved = localStorage.getItem("efs.lang"); } catch (e) { saved = null; }
  if (saved && I18N_LANGS.includes(saved)) return saved;
  const sys = String(navigator.language || "").toLowerCase().slice(0, 2);
  return I18N_LANGS.includes(sys) ? sys : "en";
}
let LANG = i18nPick();

function t(key, ...args) {
  const row = I18N[key];
  let s = row ? (row[I18N_LANGS.indexOf(LANG)] || row[1] || row[0]) : key;
  args.forEach((a, i) => { s = s.split("{" + i + "}").join(String(a)); });
  return s;
}

// Static text: data-i18n="key" sets textContent.
function i18nApply(root) {
  document.documentElement.lang = LANG;
  (root || document).querySelectorAll("[data-i18n]").forEach((el) => { el.textContent = t(el.dataset.i18n); });
}

function i18nSet(lang) {
  if (!I18N_LANGS.includes(lang)) return;
  LANG = lang;
  try { localStorage.setItem("efs.lang", lang); } catch (e) { /* private mode */ }
}
