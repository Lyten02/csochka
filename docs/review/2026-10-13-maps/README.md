> Исторический аудит **22 карт**: позже пользователь решил удалить из игрового каталога семь карт без собственного GLB — `bhop_flyblocks`, `bhop_perfect2012`, `bhop_without_colors`, `kz_bhop`, `kzsk_xmas2010`, `kzy_fastbhop`, `kzy_junglerocks`. [Текущий каталог и проверка удаления](../2026-10-13-map-removal/README.md).

# Аудит карт — 2026-10-13

## Итог

- Каталог: **22 карты**. Файлы карт: **22 BSP + 15 GLB = 37**. Всего в `godot/maps/`: **886 файлов** (ещё 417 PNG и 432 import-файла). Каждый файл перечислен в таблице приложения ниже.
- Сняты и визуально просмотрены **67 настоящих кадров для 22/22 карт**: spawn, elevated, reverse; для bkz_goldbhop дополнительно course. JPEG 1280×720, качество 0.85, каждый менее 238 KB. Изображения не генерировались; уменьшенные монтажи использовались только для просмотра, оригиналы сохранены.
- **15 карт имеют собственный визуальный GLB; 7 провалили визуальную загрузку из-за отсутствия GLB.** Все 22 процесса загрузили BSP и завершились с кодом 0; падений/таймаутов 0. Не путать успешный процесс с исправной картой.
- На каждой карте есть **16 ERROR material=null и 2 WARNING утечек на выходе**. Поэтому ни одна не заявлена как «загрузилась без ошибок».
- Все 22 игрока к концу наблюдения стоят на ground=0, velocity=(0,0,0), solid=-1. Во всех шести замерах каждого запуска solid=-1. Это проверка только начального спавна за шесть секунд, не всех спавнов/маршрута.
- [Галерея](index.html), [каталог из работающей игры](catalog.json), [машиночитаемые результаты](summary.json), [точные команды, PID, время и exit](commands.json).
- Доказательства: этот каталог `docs/review/2026-10-13-maps/` (снят в отдельном Orca-checkout `map-audit-2026-10-13` с собственным `.godot` cache), **около 10.3 MiB**, 116 файлов.
- Галерея прочитана через Python HTMLParser: все **182 href/src** разрешаются на диске; все **67 JPEG** декодированы Pillow, проверен размер 1280×720. Это разрешённая заданием проверка ссылок на диске, не браузерный/UI-тест.

## Сверка и обнаруженный дефект

Каталог не является фиксированным списком: `scripts/ui/map_select_dialog.gd::_refresh_maps()` вызывает `SettingsManager.get_available_maps()`, который перечисляет каждый `.bsp` в `res://maps`, даже если GLB отсутствует. Имя каталога совпадает с basename. Запасная запись `35hp_3` используется только без менеджера/при пустом списке и не является дополнительной картой.

Все 22 BSP присутствуют в каталоге; карт только в файлах — 0; записей без BSP — 0; GLB без BSP — 0. BSP без GLB — 7: `bhop_flyblocks`, `bhop_perfect2012`, `bhop_without_colors`, `kz_bhop`, `kzsk_xmas2010`, `kzy_fastbhop`, `kzy_junglerocks`.

В `scripts/main.gd:15` визуальная карта заменяется только при непустом `current_map_glb`. При отсутствующем GLB каталог возвращает пустую строку: сцена сохраняет встроенный `35hp_3.glb`, но загружает коллизии выбранного BSP. Это объясняет реальные кадры пустоты/фрагментов чужой арены. Эти кадры являются свидетельством дефекта, НЕ изображениями корректно импортированных семи карт. Никаких исправлений карт/загрузчика не делалось.

## Метод и ограничения

`ground` в JSON — это GoldSrc `pm.onground`, индекс опорной физической сущности, не булево значение: **0 = стоит на worldspawn (геометрии мира), -1 = в воздухе, >0 = на другой brush-сущности**. Подтверждение: `scripts/player/cs_pmove.gd:306–314` присваивает `onground = tr.ent` либо `-1`; `scripts/goldsrc/goldsrc_bsp.gd:192–198` добавляет worldspawn первым; `scripts/player/cs_player.gd:606–607` прямо описывает индекс 0. HUD (`scripts/ui/hud.gd:303`) выводит «на земле: да» при `pm.onground != -1`. Следовательно, зафиксированное `ground=0` означает, что игрок стоит на земле.

Из отдельного checkout запускался Godot 4.7 stable с GL Compatibility/OpenGL 3.3, NVIDIA RTX 2060 SUPER, оконный режим, без `--headless`. `godot/tests/audit_maps_capture.gd` выбирает карту в существующем SettingsManager без сохранения настроек и инстанцирует настоящую `scenes/main.tscn`: штатный main.gd загружает GLB/BSP и вызывает настоящий player.setup(). Меню мышью не проходилось.

Реальная физика работает шесть секунд без команд движения; каждую секунду пишутся origin, velocity, ground, solid и teleports. Затем игрок заморожен только для кадров. Spawn — вид после шести секунд; elevated — камера на 3 м выше, reverse — камера развёрнута. Они не доказывают проходимость. Course у bkz_goldbhop — камера в известной точке коридора, не прохождение игроком. HUD на дополнительных ракурсах показывает исходную позицию игрока, а не позицию перемещённой камеры.

Все 67 финальных JPEG открыты и осмотрены: 35hp_3 отдельно, остальные в подписанных уменьшенных полосах всех трёх ракурсов; дополнительный course отдельно. Полностью чёрных экранов или розовой missing-texture шахматки не наблюдалось. Отсутствие дефекта на небольшом участке не подтверждает всю карту. Подземные чёрные ямы, однотонные материалы и открытое небо описаны без предположения, что это ошибка конвертации.

Не проверены: полный bhop/kz маршрут, все телепорты, финиш/таймер, все точки спавна, сравнение с оригинальным GoldSrc. Для 35hp_3 наблюдён лишь автоматический стартовый телепорт (1) и приземление. Прочих телепортов за окно наблюдения не было. Настройки уже существующего user:// загружались как в игре; harness не вызывает save_settings и не меняет файлы настроек. Viewmodel/HUD оставлены как есть. Владелец сам заполняет keep/delete; рекомендаций об удалении нет.

## Ошибки логов

У каждой карты отдельный `<map>_log.txt` и `<map>.json`. Во всех финальных логах одинаковая группа:

- 16 × `ERROR: Parameter "material" is null.`: `material_casts_shadows`, `material_is_animated`, `material_get_instance_shader_parameters`, `material_update_dependency` в GLES3 storage. Классификация по порядку строк — старт/загрузка сцены до первого замера; не teardown. Точная граница загрузки и первого кадра в логах не размечена.
- 1 × `WARNING: 1 RID of type "CanvasItem" was leaked.`
- 1 × `WARNING: 2 ObjectDB instances were leaked at exit (run with --verbose for details).`

Во всех 22 финальных логах ошибки стоят на строках 4, 6, …, 34, сразу после заголовка OpenGL и до первого `AUDIT_SAMPLE` (строка 36, second=1). На карту: **16 ошибок на старте/до первого замера, 0 от первого замера до завершения capture, 0 после завершения**. Всего по 22 сохранённым логам: **352 / 0 / 0**. Это не сумма всех 23 запусков: повторный bkz_goldbhop заменил свой предыдущий лог.

Маркеры `AUDIT_SAMPLE` занимают строки 36–41; `AUDIT_IMAGE` — 42–44 (у bkz_goldbhop также 45). `AUDIT_COMPLETE` находится на строке 45 (bkz_goldbhop: 46), непосредственно перед `quit()` в harness. Обе WARNING идут после него: **2 предупреждения teardown на карту, 44 суммарно**. Отдельного маркера «начало/конец загрузки карты» и маркера входа в quit в существующем harness нет: нельзя отличить синхронную загрузку от раннего runtime в первую секунду. «Старт» здесь означает именно интервал до первого замера, а нулевой runtime-count — только последующий наблюдаемый интервал.

Одинаковая стартовая группа на всех картах согласуется с общей viewmodel-проблемой: **вероятно, дублирование материалов ножа при смене модели в том же кадре, исправленное позднее в main**, по сообщению интегратора через Main. Положение ошибок поддерживает эту гипотезу, но сами GLES3-стеки не называют cs_knife.gd и не доказывают источник. Исправление отсутствует в этом checkout; здесь оно не проверялось. Ошибки не следует приписывать материалам каждой карты или считать исчезнувшими.

В таблице «16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown» означает именно эту классификацию, не чистый лог. Полные стеки находятся в ссылках на логи.

## По картам

**Для всех 22 карт:** grounded-спавн показывает только опору коллизии в коротком наблюдении; он не доказывает, что карта работает, визуально корректна или проходима.

| Карта | Имя каталога | Файлы в godot/maps | Загружается? | Спавн | Визуальные наблюдения / примечания | Ошибки | Кадры | User decision (keep/delete) |
|---|---|---|---|---|---|---|---|---|
| 35hp_3 | 35hp_3 | `35hp_3.bsp`, `35hp_3.glb`; всего 29 с сопутствующими | BSP + GLB да; лог не чистый | [Стоит на worldspawn за 6 с; это НЕ доказательство работоспособности карты](35hp_3.json) | Каменная арена и мост видны; один стартовый телепорт, затем приземление ко 2-й секунде. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](35hp_3_log.txt) | [elevated](35hp_3_elevated.jpg) / [reverse](35hp_3_reverse.jpg) / [spawn](35hp_3_spawn.jpg) | |
| bhop_blocks | bhop_blocks | `bhop_blocks.bsp`, `bhop_blocks.glb`; всего 59 с сопутствующими | BSP + GLB да; лог не чистый | [Стоит на worldspawn за 6 с; это НЕ доказательство работоспособности карты](bhop_blocks.json) | Каменные блоки над водой, кирпичные стены и ящики; явных дефектов в этих ракурсах не видно. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](bhop_blocks_log.txt) | [elevated](bhop_blocks_elevated.jpg) / [reverse](bhop_blocks_reverse.jpg) / [spawn](bhop_blocks_spawn.jpg) | |
| bhop_dea | bhop_dea | `bhop_dea.bsp`, `bhop_dea.glb`; всего 45 с сопутствующими | BSP + GLB да; лог не чистый | [Стоит на worldspawn за 6 с; это НЕ доказательство работоспособности карты](bhop_dea.json) | Светлые кирпичные стены, стартовая площадка и кнопка в обратном ракурсе. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](bhop_dea_log.txt) | [elevated](bhop_dea_elevated.jpg) / [reverse](bhop_dea_reverse.jpg) / [spawn](bhop_dea_spawn.jpg) | |
| bhop_flyblocks | bhop_flyblocks | `bhop_flyblocks.bsp`; GLB отсутствует | ВИЗУАЛЬНО НЕ ЗАГРУЖЕНА: нет GLB, показана чужая 35hp_3 + коллизия выбранного BSP | [Только BSP: стоит на worldspawn за 6 с; это НЕ доказательство работоспособности, своего визуального пола нет](bhop_flyblocks.json) | Нет собственного GLB: видны небо и фрагменты чужой 35hp_3 вместо выбранной карты. BSP/коллизия загружены, но визуальная загрузка выбранной карты НЕ успешна. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](bhop_flyblocks_log.txt) | [elevated](bhop_flyblocks_elevated.jpg) / [reverse](bhop_flyblocks_reverse.jpg) / [spawn](bhop_flyblocks_spawn.jpg) | |
| bhop_perfect2012 | bhop_perfect2012 | `bhop_perfect2012.bsp`; GLB отсутствует | ВИЗУАЛЬНО НЕ ЗАГРУЖЕНА: нет GLB, показана чужая 35hp_3 + коллизия выбранного BSP | [Только BSP: стоит на worldspawn за 6 с; это НЕ доказательство работоспособности, своего визуального пола нет](bhop_perfect2012.json) | Нет собственного GLB: видны небо и фрагменты чужой 35hp_3 вместо выбранной карты. BSP/коллизия загружены, но визуальная загрузка выбранной карты НЕ успешна. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](bhop_perfect2012_log.txt) | [elevated](bhop_perfect2012_elevated.jpg) / [reverse](bhop_perfect2012_reverse.jpg) / [spawn](bhop_perfect2012_spawn.jpg) | |
| bhop_rabiga | bhop_rabiga | `bhop_rabiga.bsp`, `bhop_rabiga.glb`; всего 53 с сопутствующими | BSP + GLB да; лог не чистый | [Стоит на worldspawn за 6 с; это НЕ доказательство работоспособности карты](bhop_rabiga.json) | Тёмная кирпичная стартовая комната; текстуры различимы, вид ограничен комнатой. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](bhop_rabiga_log.txt) | [elevated](bhop_rabiga_elevated.jpg) / [reverse](bhop_rabiga_reverse.jpg) / [spawn](bhop_rabiga_spawn.jpg) | |
| bhop_run_1 | bhop_run_1 | `bhop_run_1.bsp`, `bhop_run_1.glb`; всего 57 с сопутствующими | BSP + GLB да; лог не чистый | [Стоит на worldspawn за 6 с; это НЕ доказательство работоспособности карты](bhop_run_1.json) | Длинный освещённый коридор с металлическими блоками; обратный вид показывает стартовую площадку. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](bhop_run_1_log.txt) | [elevated](bhop_run_1_elevated.jpg) / [reverse](bhop_run_1_reverse.jpg) / [spawn](bhop_run_1_spawn.jpg) | |
| bhop_squareblock | bhop_squareblock | `bhop_squareblock.bsp`, `bhop_squareblock.glb`; всего 57 с сопутствующими | BSP + GLB да; лог не чистый | [Стоит на worldspawn за 6 с; это НЕ доказательство работоспособности карты](bhop_squareblock.json) | Кирпичный коридор с блоками над чёрной ямой; происхождение чёрной поверхности отдельно не проверялось. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](bhop_squareblock_log.txt) | [elevated](bhop_squareblock_elevated.jpg) / [reverse](bhop_squareblock_reverse.jpg) / [spawn](bhop_squareblock_spawn.jpg) | |
| bhop_tk_speedrun | bhop_tk_speedrun | `bhop_tk_speedrun.bsp`, `bhop_tk_speedrun.glb`; всего 43 с сопутствующими | BSP + GLB да; лог не чистый | [Стоит на worldspawn за 6 с; это НЕ доказательство работоспособности карты](bhop_tk_speedrun.json) | Однотонные серые стены и синий пол без мелкой текстурной детализации; это не чёрный экран. Соответствие исходному оформлению не проверялось. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](bhop_tk_speedrun_log.txt) | [elevated](bhop_tk_speedrun_elevated.jpg) / [reverse](bhop_tk_speedrun_reverse.jpg) / [spawn](bhop_tk_speedrun_spawn.jpg) | |
| bhop_train | bhop_train | `bhop_train.bsp`, `bhop_train.glb`; всего 139 с сопутствующими | BSP + GLB да; лог не чистый | [Стоит на worldspawn за 6 с; это НЕ доказательство работоспособности карты](bhop_train.json) | Кирпичные стены, сетчатое ограждение и вывески; виден стартовый коридор. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](bhop_train_log.txt) | [elevated](bhop_train_elevated.jpg) / [reverse](bhop_train_reverse.jpg) / [spawn](bhop_train_spawn.jpg) | |
| bhop_training_final | bhop_training_final | `bhop_training_final.bsp`, `bhop_training_final.glb`; всего 27 с сопутствующими | BSP + GLB да; лог не чистый | [Стоит на worldspawn за 6 с; это НЕ доказательство работоспособности карты](bhop_training_final.json) | Серые WALL-сетки и оранжевые CRATE-блоки с размерами; не розовая missing-texture шахматка. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](bhop_training_final_log.txt) | [elevated](bhop_training_final_elevated.jpg) / [reverse](bhop_training_final_reverse.jpg) / [spawn](bhop_training_final_spawn.jpg) | |
| bhop_without_colors | bhop_without_colors | `bhop_without_colors.bsp`; GLB отсутствует | ВИЗУАЛЬНО НЕ ЗАГРУЖЕНА: нет GLB, показана чужая 35hp_3 + коллизия выбранного BSP | [Только BSP: стоит на worldspawn за 6 с; это НЕ доказательство работоспособности, своего визуального пола нет](bhop_without_colors.json) | Нет собственного GLB: видны небо и фрагменты чужой 35hp_3 вместо выбранной карты. BSP/коллизия загружены, но визуальная загрузка выбранной карты НЕ успешна. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](bhop_without_colors_log.txt) | [elevated](bhop_without_colors_elevated.jpg) / [reverse](bhop_without_colors_reverse.jpg) / [spawn](bhop_without_colors_spawn.jpg) | |
| bhop_ytt_neon_light | bhop_ytt_neon_light | `bhop_ytt_neon_light.bsp`, `bhop_ytt_neon_light.glb`; всего 85 с сопутствующими | BSP + GLB да; лог не чистый | [Стоит на worldspawn за 6 с; это НЕ доказательство работоспособности карты](bhop_ytt_neon_light.json) | Тёмный коридор с красными световыми полосами и жёлтым рисунком потолка; геометрия различима. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](bhop_ytt_neon_light_log.txt) | [elevated](bhop_ytt_neon_light_elevated.jpg) / [reverse](bhop_ytt_neon_light_reverse.jpg) / [spawn](bhop_ytt_neon_light_spawn.jpg) | |
| bkz_goldbhop | bkz_goldbhop | `bkz_goldbhop.bsp`, `bkz_goldbhop.glb`; всего 49 с сопутствующими | BSP + GLB да; лог не чистый | [Стоит на worldspawn за 6 с; это НЕ доказательство работоспособности карты](bkz_goldbhop.json) | Спавн смотрит в близкую каменную стену. Дополнительный course-ракурс показывает золотистые блоки в коридоре над чёрной ямой. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](bkz_goldbhop_log.txt) | [course](bkz_goldbhop_course.jpg) / [elevated](bkz_goldbhop_elevated.jpg) / [reverse](bkz_goldbhop_reverse.jpg) / [spawn](bkz_goldbhop_spawn.jpg) | |
| bkz_noob | bkz_noob | `bkz_noob.bsp`, `bkz_noob.glb`; всего 43 с сопутствующими | BSP + GLB да; лог не чистый | [Стоит на worldspawn за 6 с; это НЕ доказательство работоспособности карты](bkz_noob.json) | Светлые каменные блоки в открытом небе и стартовая кнопка; открытое пространство не само по себе доказательство отсутствующей геометрии. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](bkz_noob_log.txt) | [elevated](bkz_noob_elevated.jpg) / [reverse](bkz_noob_reverse.jpg) / [spawn](bkz_noob_spawn.jpg) | |
| kz_bhop | kz_bhop | `kz_bhop.bsp`; GLB отсутствует | ВИЗУАЛЬНО НЕ ЗАГРУЖЕНА: нет GLB, показана чужая 35hp_3 + коллизия выбранного BSP | [Только BSP: стоит на worldspawn за 6 с; это НЕ доказательство работоспособности, своего визуального пола нет](kz_bhop.json) | Нет собственного GLB: видны небо и фрагменты чужой 35hp_3 вместо выбранной карты. BSP/коллизия загружены, но визуальная загрузка выбранной карты НЕ успешна. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](kz_bhop_log.txt) | [elevated](kz_bhop_elevated.jpg) / [reverse](kz_bhop_reverse.jpg) / [spawn](kz_bhop_spawn.jpg) | |
| kzru_airway | kzru_airway | `kzru_airway.bsp`, `kzru_airway.glb`; всего 79 с сопутствующими | BSP + GLB да; лог не чистый | [Стоит на worldspawn за 6 с; это НЕ доказательство работоспособности карты](kzru_airway.json) | Открытые высотные каменные платформы и наклонные конструкции; стартовая кнопка видна сзади. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](kzru_airway_log.txt) | [elevated](kzru_airway_elevated.jpg) / [reverse](kzru_airway_reverse.jpg) / [spawn](kzru_airway_spawn.jpg) | |
| kzsca_toonbhop | kzsca_toonbhop | `kzsca_toonbhop.bsp`, `kzsca_toonbhop.glb`; всего 41 с сопутствующими | BSP + GLB да; лог не чистый | [Стоит на worldspawn за 6 с; это НЕ доказательство работоспособности карты](kzsca_toonbhop.json) | Мультяшные текстурированные стены, вывеска, цветные поверхности и кнопка; явных дефектов в этих ракурсах не видно. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](kzsca_toonbhop_log.txt) | [elevated](kzsca_toonbhop_elevated.jpg) / [reverse](kzsca_toonbhop_reverse.jpg) / [spawn](kzsca_toonbhop_spawn.jpg) | |
| kzsk_xmas2010 | kzsk_xmas2010 | `kzsk_xmas2010.bsp`; GLB отсутствует | ВИЗУАЛЬНО НЕ ЗАГРУЖЕНА: нет GLB, показана чужая 35hp_3 + коллизия выбранного BSP | [Только BSP: стоит на worldspawn за 6 с; это НЕ доказательство работоспособности, своего визуального пола нет](kzsk_xmas2010.json) | Нет собственного GLB: видны небо и фрагменты чужой 35hp_3 вместо выбранной карты. BSP/коллизия загружены, но визуальная загрузка выбранной карты НЕ успешна. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](kzsk_xmas2010_log.txt) | [elevated](kzsk_xmas2010_elevated.jpg) / [reverse](kzsk_xmas2010_reverse.jpg) / [spawn](kzsk_xmas2010_spawn.jpg) | |
| kzy_fastbhop | kzy_fastbhop | `kzy_fastbhop.bsp`; GLB отсутствует | ВИЗУАЛЬНО НЕ ЗАГРУЖЕНА: нет GLB, показана чужая 35hp_3 + коллизия выбранного BSP | [Только BSP: стоит на worldspawn за 6 с; это НЕ доказательство работоспособности, своего визуального пола нет](kzy_fastbhop.json) | Нет собственного GLB: видны небо и фрагменты чужой 35hp_3 вместо выбранной карты. BSP/коллизия загружены, но визуальная загрузка выбранной карты НЕ успешна. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](kzy_fastbhop_log.txt) | [elevated](kzy_fastbhop_elevated.jpg) / [reverse](kzy_fastbhop_reverse.jpg) / [spawn](kzy_fastbhop_spawn.jpg) | |
| kzy_juhxbhop | kzy_juhxbhop | `kzy_juhxbhop.bsp`, `kzy_juhxbhop.glb`; всего 73 с сопутствующими | BSP + GLB да; лог не чистый | [Стоит на worldspawn за 6 с; это НЕ доказательство работоспособности карты](kzy_juhxbhop.json) | Песчаные каменные стены, арка и ступени; текстуры и надписи видны. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](kzy_juhxbhop_log.txt) | [elevated](kzy_juhxbhop_elevated.jpg) / [reverse](kzy_juhxbhop_reverse.jpg) / [spawn](kzy_juhxbhop_spawn.jpg) | |
| kzy_junglerocks | kzy_junglerocks | `kzy_junglerocks.bsp`; GLB отсутствует | ВИЗУАЛЬНО НЕ ЗАГРУЖЕНА: нет GLB, показана чужая 35hp_3 + коллизия выбранного BSP | [Только BSP: стоит на worldspawn за 6 с; это НЕ доказательство работоспособности, своего визуального пола нет](kzy_junglerocks.json) | Нет собственного GLB: видны небо и фрагменты чужой 35hp_3 вместо выбранной карты. BSP/коллизия загружены, но визуальная загрузка выбранной карты НЕ успешна. | [16E старт; 0E наблюдение/capture; 0E teardown; 2W teardown](kzy_junglerocks_log.txt) | [elevated](kzy_junglerocks_elevated.jpg) / [reverse](kzy_junglerocks_reverse.jpg) / [spawn](kzy_junglerocks_spawn.jpg) | |

## Команды и исполнение

Для каждой карты выполнена команда (полностью раскрытые 23 вызова находятся в commands.json; bkz_goldbhop переснят с дополнительным course):

```powershell
& 'C:/Users/kosta/OneDrive/Desktop/Godot_v4.7-stable_win64_console.exe' --path 'C:/Users/kosta/orca/workspaces/csochka/map-audit-2026-10-13/godot' --rendering-method gl_compatibility --windowed --resolution 1280x720 --script res://tests/audit_maps_capture.gd -- <map-id> 'C:/Users/kosta/orca/workspaces/csochka/map-audit-2026-10-13/docs/review/2026-10-13-maps'
```

Запуск через Python subprocess.Popen с stdout+stderr в `<map>_log.txt`, wait(timeout=90). Только один запущенный аудитом Godot одновременно; принудительное завершение не потребовалось. Пользовательский процесс не затрагивался. Предзаполненный Godot cache использовался без editor/import и без сборок. Выполнены только указанные реальные загрузки, наблюдение спавна, осмотр изображений и проверка ссылок галереи.

Изменения: этот каталог доказательств и один `godot/tests/audit_maps_capture.gd`; карты, каталог, gameplay и project settings не редактировались. Без commit/push.

## Полный пофайловый реестр

Пути относительно `godot/maps/`. Связь сопутствующих PNG/import с картой определена по самому длинному совпадающему basename-префиксу; непривязанных файлов нет. Это инвентаризация, а не доказательство использования каждого PNG движком. Каждый из 886 файлов имеет строку.

| Карта | Файл | Байт |
|---|---|---:|
| 35hp_3 | `35hp_3.bsp` | 1290644 |
| 35hp_3 | `35hp_3.glb` | 1140464 |
| 35hp_3 | `35hp_3.glb.import` | 1222 |
| 35hp_3 | `35hp_3_-0csSandWall.png` | 96016 |
| 35hp_3 | `35hp_3_-0csSandWall.png.import` | 1125 |
| 35hp_3 | `35hp_3_-0Sand.png` | 46642 |
| 35hp_3 | `35hp_3_-0Sand.png.import` | 1107 |
| 35hp_3 | `35hp_3_-1csSandWall.png` | 95669 |
| 35hp_3 | `35hp_3_-1csSandWall.png.import` | 1125 |
| 35hp_3 | `35hp_3_-3Sand.png` | 47016 |
| 35hp_3 | `35hp_3_-3Sand.png.import` | 1107 |
| 35hp_3 | `35hp_3_35hp_3_lightmap.png` | 120305 |
| 35hp_3 | `35hp_3_35hp_3_lightmap.png.import` | 1085 |
| 35hp_3 | `35hp_3_metal_wall05c.png` | 6688 |
| 35hp_3 | `35hp_3_metal_wall05c.png.import` | 1128 |
| 35hp_3 | `35hp_3_SandCCrete.png` | 135343 |
| 35hp_3 | `35hp_3_SandCCrete.png.import` | 1119 |
| 35hp_3 | `35hp_3_SandCrtLrgSd.png` | 47676 |
| 35hp_3 | `35hp_3_SandCrtLrgSd.png.import` | 1125 |
| 35hp_3 | `35hp_3_SandCrtLrgTp.png` | 41649 |
| 35hp_3 | `35hp_3_SandCrtLrgTp.png.import` | 1123 |
| 35hp_3 | `35hp_3_SandCrtSmSd.png` | 11327 |
| 35hp_3 | `35hp_3_SandCrtSmSd.png.import` | 1121 |
| 35hp_3 | `35hp_3_SandTrim.png` | 9947 |
| 35hp_3 | `35hp_3_SandTrim.png.import` | 1112 |
| 35hp_3 | `35hp_3_SandWllDoor.png` | 78605 |
| 35hp_3 | `35hp_3_SandWllDoor.png.import` | 1122 |
| 35hp_3 | `35hp_3_{ladder1.png` | 1125 |
| 35hp_3 | `35hp_3_{ladder1.png.import` | 1112 |
| bhop_blocks | `bhop_blocks.bsp` | 1697368 |
| bhop_blocks | `bhop_blocks.glb` | 701792 |
| bhop_blocks | `bhop_blocks.glb.import` | 1237 |
| bhop_blocks | `bhop_blocks_+0button2.png` | 1541 |
| bhop_blocks | `bhop_blocks_+0button2.png.import` | 1081 |
| bhop_blocks | `bhop_blocks_+0~tnnl_lgt4.png` | 2724 |
| bhop_blocks | `bhop_blocks_+0~tnnl_lgt4.png.import` | 1090 |
| bhop_blocks | `bhop_blocks_bcrate02.png` | 4465 |
| bhop_blocks | `bhop_blocks_bcrate02.png.import` | 1078 |
| bhop_blocks | `bhop_blocks_bhop.png` | 6900 |
| bhop_blocks | `bhop_blocks_bhop.png.import` | 1066 |
| bhop_blocks | `bhop_blocks_bhop_blocks_lightmap.png` | 129947 |
| bhop_blocks | `bhop_blocks_bhop_blocks_lightmap.png.import` | 1114 |
| bhop_blocks | `bhop_blocks_black.png` | 108 |
| bhop_blocks | `bhop_blocks_black.png.import` | 1068 |
| bhop_blocks | `bhop_blocks_c1a1_crate2.png` | 16689 |
| bhop_blocks | `bhop_blocks_c1a1_crate2.png.import` | 1087 |
| bhop_blocks | `bhop_blocks_c1a3wall05.png` | 3520 |
| bhop_blocks | `bhop_blocks_c1a3wall05.png.import` | 1084 |
| bhop_blocks | `bhop_blocks_crete3_wall01.png` | 15400 |
| bhop_blocks | `bhop_blocks_crete3_wall01.png.import` | 1093 |
| bhop_blocks | `bhop_blocks_crete3_wall02.png` | 16273 |
| bhop_blocks | `bhop_blocks_crete3_wall02.png.import` | 1093 |
| bhop_blocks | `bhop_blocks_end.png` | 2056 |
| bhop_blocks | `bhop_blocks_end.png.import` | 1063 |
| bhop_blocks | `bhop_blocks_nd.png` | 18336 |
| bhop_blocks | `bhop_blocks_nd.png.import` | 1060 |
| bhop_blocks | `bhop_blocks_num0.png` | 1439 |
| bhop_blocks | `bhop_blocks_num0.png.import` | 1066 |
| bhop_blocks | `bhop_blocks_num1.png` | 883 |
| bhop_blocks | `bhop_blocks_num1.png.import` | 1066 |
| bhop_blocks | `bhop_blocks_num2.png` | 1610 |
| bhop_blocks | `bhop_blocks_num2.png.import` | 1066 |
| bhop_blocks | `bhop_blocks_num3.png` | 1704 |
| bhop_blocks | `bhop_blocks_num3.png.import` | 1066 |
| bhop_blocks | `bhop_blocks_num4.png` | 1351 |
| bhop_blocks | `bhop_blocks_num4.png.import` | 1066 |
| bhop_blocks | `bhop_blocks_num5.png` | 1676 |
| bhop_blocks | `bhop_blocks_num5.png.import` | 1065 |
| bhop_blocks | `bhop_blocks_num6.png` | 1711 |
| bhop_blocks | `bhop_blocks_num6.png.import` | 1066 |
| bhop_blocks | `bhop_blocks_num7.png` | 1084 |
| bhop_blocks | `bhop_blocks_num7.png.import` | 1065 |
| bhop_blocks | `bhop_blocks_num8.png` | 1910 |
| bhop_blocks | `bhop_blocks_num8.png.import` | 1066 |
| bhop_blocks | `bhop_blocks_num9.png` | 1675 |
| bhop_blocks | `bhop_blocks_num9.png.import` | 1066 |
| bhop_blocks | `bhop_blocks_red.png` | 94 |
| bhop_blocks | `bhop_blocks_red.png.import` | 1062 |
| bhop_blocks | `bhop_blocks_start.png` | 2459 |
| bhop_blocks | `bhop_blocks_start.png.import` | 1068 |
| bhop_blocks | `bhop_blocks_STRT.png` | 3885 |
| bhop_blocks | `bhop_blocks_STRT.png.import` | 1066 |
| bhop_blocks | `bhop_blocks_water4b.png` | 4300 |
| bhop_blocks | `bhop_blocks_water4b.png.import` | 1075 |
| bhop_blocks | `bhop_blocks_white.png` | 108 |
| bhop_blocks | `bhop_blocks_white.png.import` | 1068 |
| bhop_blocks | `bhop_blocks_{nick.png` | 8995 |
| bhop_blocks | `bhop_blocks_{nick.png.import` | 1069 |
| bhop_dea | `bhop_dea.bsp` | 952308 |
| bhop_dea | `bhop_dea.glb` | 798704 |
| bhop_dea | `bhop_dea.glb.import` | 1228 |
| bhop_dea | `bhop_dea_!watergreen.png` | 3192 |
| bhop_dea | `bhop_dea_!watergreen.png.import` | 1078 |
| bhop_dea | `bhop_dea_+0button2.png` | 1541 |
| bhop_dea | `bhop_dea_+0button2.png.import` | 1072 |
| bhop_dea | `bhop_dea_+0~white.png` | 110 |
| bhop_dea | `bhop_dea_+0~white.png.import` | 1069 |
| bhop_dea | `bhop_dea_bhop_dea_lightmap.png` | 27524 |
| bhop_dea | `bhop_dea_bhop_dea_lightmap.png.import` | 1096 |
| bhop_dea | `bhop_dea_black.png` | 108 |
| bhop_dea | `bhop_dea_black.png.import` | 1060 |
| bhop_dea | `bhop_dea_c2a2a_lift1.png` | 25035 |
| bhop_dea | `bhop_dea_c2a2a_lift1.png.import` | 1078 |
| bhop_dea | `bhop_dea_c2a3_gar1.png` | 3494 |
| bhop_dea | `bhop_dea_c2a3_gar1.png.import` | 1072 |
| bhop_dea | `bhop_dea_eno15.png` | 144199 |
| bhop_dea | `bhop_dea_eno15.png.import` | 1060 |
| bhop_dea | `bhop_dea_eno4.png` | 170522 |
| bhop_dea | `bhop_dea_eno4.png.import` | 1056 |
| bhop_dea | `bhop_dea_kznum0.png` | 1779 |
| bhop_dea | `bhop_dea_kznum0.png.import` | 1063 |
| bhop_dea | `bhop_dea_kznum1.png` | 1198 |
| bhop_dea | `bhop_dea_kznum1.png.import` | 1063 |
| bhop_dea | `bhop_dea_kznum2.png` | 1673 |
| bhop_dea | `bhop_dea_kznum2.png.import` | 1062 |
| bhop_dea | `bhop_dea_kznum3.png` | 1833 |
| bhop_dea | `bhop_dea_kznum3.png.import` | 1063 |
| bhop_dea | `bhop_dea_kznum4.png` | 1524 |
| bhop_dea | `bhop_dea_kznum4.png.import` | 1063 |
| bhop_dea | `bhop_dea_kznum5.png` | 1651 |
| bhop_dea | `bhop_dea_kznum5.png.import` | 1062 |
| bhop_dea | `bhop_dea_kznum6.png` | 1849 |
| bhop_dea | `bhop_dea_kznum6.png.import` | 1063 |
| bhop_dea | `bhop_dea_kznum7.png` | 1472 |
| bhop_dea | `bhop_dea_kznum7.png.import` | 1063 |
| bhop_dea | `bhop_dea_kznum8.png` | 1978 |
| bhop_dea | `bhop_dea_kznum8.png.import` | 1063 |
| bhop_dea | `bhop_dea_kznum9.png` | 1879 |
| bhop_dea | `bhop_dea_kznum9.png.import` | 1063 |
| bhop_dea | `bhop_dea_red.png` | 94 |
| bhop_dea | `bhop_dea_red.png.import` | 1054 |
| bhop_dea | `bhop_dea_white.png` | 108 |
| bhop_dea | `bhop_dea_white.png.import` | 1060 |
| bhop_flyblocks | `bhop_flyblocks.bsp` | 1019100 |
| bhop_perfect2012 | `bhop_perfect2012.bsp` | 1056348 |
| bhop_rabiga | `bhop_rabiga.bsp` | 1019012 |
| bhop_rabiga | `bhop_rabiga.glb` | 1078168 |
| bhop_rabiga | `bhop_rabiga.glb.import` | 1237 |
| bhop_rabiga | `bhop_rabiga_+0button2.png` | 1541 |
| bhop_rabiga | `bhop_rabiga_+0button2.png.import` | 1081 |
| bhop_rabiga | `bhop_rabiga_+0~light2a.png` | 2262 |
| bhop_rabiga | `bhop_rabiga_+0~light2a.png.import` | 1084 |
| bhop_rabiga | `bhop_rabiga_+0~tnnl_lgt4.png` | 2724 |
| bhop_rabiga | `bhop_rabiga_+0~tnnl_lgt4.png.import` | 1090 |
| bhop_rabiga | `bhop_rabiga_256_ladrillo2b.png` | 159829 |
| bhop_rabiga | `bhop_rabiga_256_ladrillo2b.png.import` | 1096 |
| bhop_rabiga | `bhop_rabiga_256_plaster2.png` | 169309 |
| bhop_rabiga | `bhop_rabiga_256_plaster2.png.import` | 1089 |
| bhop_rabiga | `bhop_rabiga_256_plaster3.png` | 180489 |
| bhop_rabiga | `bhop_rabiga_256_plaster3.png.import` | 1089 |
| bhop_rabiga | `bhop_rabiga_256_plaster6.png` | 162229 |
| bhop_rabiga | `bhop_rabiga_256_plaster6.png.import` | 1090 |
| bhop_rabiga | `bhop_rabiga_bhop_rabiga_lightmap.png` | 45147 |
| bhop_rabiga | `bhop_rabiga_bhop_rabiga_lightmap.png.import` | 1114 |
| bhop_rabiga | `bhop_rabiga_black.png` | 108 |
| bhop_rabiga | `bhop_rabiga_black.png.import` | 1069 |
| bhop_rabiga | `bhop_rabiga_c1a0_labflrc.png` | 20880 |
| bhop_rabiga | `bhop_rabiga_c1a0_labflrc.png.import` | 1090 |
| bhop_rabiga | `bhop_rabiga_creditgabi.png` | 7918 |
| bhop_rabiga | `bhop_rabiga_creditgabi.png.import` | 1084 |
| bhop_rabiga | `bhop_rabiga_kznum0.png` | 1439 |
| bhop_rabiga | `bhop_rabiga_kznum0.png.import` | 1072 |
| bhop_rabiga | `bhop_rabiga_kznum1.png` | 883 |
| bhop_rabiga | `bhop_rabiga_kznum1.png.import` | 1071 |
| bhop_rabiga | `bhop_rabiga_kznum2.png` | 1610 |
| bhop_rabiga | `bhop_rabiga_kznum2.png.import` | 1072 |
| bhop_rabiga | `bhop_rabiga_kznum3.png` | 1704 |
| bhop_rabiga | `bhop_rabiga_kznum3.png.import` | 1071 |
| bhop_rabiga | `bhop_rabiga_kznum4.png` | 1351 |
| bhop_rabiga | `bhop_rabiga_kznum4.png.import` | 1072 |
| bhop_rabiga | `bhop_rabiga_kznum5.png` | 1676 |
| bhop_rabiga | `bhop_rabiga_kznum5.png.import` | 1072 |
| bhop_rabiga | `bhop_rabiga_kznum6.png` | 1711 |
| bhop_rabiga | `bhop_rabiga_kznum6.png.import` | 1072 |
| bhop_rabiga | `bhop_rabiga_kznum7.png` | 1084 |
| bhop_rabiga | `bhop_rabiga_kznum7.png.import` | 1072 |
| bhop_rabiga | `bhop_rabiga_kznum8.png` | 1910 |
| bhop_rabiga | `bhop_rabiga_kznum8.png.import` | 1071 |
| bhop_rabiga | `bhop_rabiga_kznum9.png` | 1675 |
| bhop_rabiga | `bhop_rabiga_kznum9.png.import` | 1072 |
| bhop_rabiga | `bhop_rabiga_metal_bord01.png` | 5684 |
| bhop_rabiga | `bhop_rabiga_metal_bord01.png.import` | 1090 |
| bhop_rabiga | `bhop_rabiga_s_piso6.png` | 151119 |
| bhop_rabiga | `bhop_rabiga_s_piso6.png.import` | 1075 |
| bhop_rabiga | `bhop_rabiga_startbutton2.png` | 2743 |
| bhop_rabiga | `bhop_rabiga_startbutton2.png.import` | 1090 |
| bhop_rabiga | `bhop_rabiga_white.png` | 108 |
| bhop_rabiga | `bhop_rabiga_white.png.import` | 1069 |
| bhop_run_1 | `bhop_run_1.bsp` | 693912 |
| bhop_run_1 | `bhop_run_1.glb` | 482828 |
| bhop_run_1 | `bhop_run_1.glb.import` | 1234 |
| bhop_run_1 | `bhop_run_1_+0button2.png` | 1541 |
| bhop_run_1 | `bhop_run_1_+0button2.png.import` | 1078 |
| bhop_run_1 | `bhop_run_1_-0fift_wall13.png` | 17799 |
| bhop_run_1 | `bhop_run_1_-0fift_wall13.png.import` | 1090 |
| bhop_run_1 | `bhop_run_1_000_box15.png` | 27406 |
| bhop_run_1 | `bhop_run_1_000_box15.png.import` | 1077 |
| bhop_run_1 | `bhop_run_1_000_floor_32.png` | 17170 |
| bhop_run_1 | `bhop_run_1_000_floor_32.png.import` | 1085 |
| bhop_run_1 | `bhop_run_1_000_floor_7.png` | 28259 |
| bhop_run_1 | `bhop_run_1_000_floor_7.png.import` | 1084 |
| bhop_run_1 | `bhop_run_1_000Mapby3.png` | 48884 |
| bhop_run_1 | `bhop_run_1_000Mapby3.png.import` | 1078 |
| bhop_run_1 | `bhop_run_1_bhop_run_1_lightmap.png` | 34408 |
| bhop_run_1 | `bhop_run_1_bhop_run_1_lightmap.png.import` | 1108 |
| bhop_run_1 | `bhop_run_1_black.png` | 108 |
| bhop_run_1 | `bhop_run_1_black.png.import` | 1065 |
| bhop_run_1 | `bhop_run_1_c1a4_silo2b.png` | 11809 |
| bhop_run_1 | `bhop_run_1_c1a4_silo2b.png.import` | 1084 |
| bhop_run_1 | `bhop_run_1_c3a2_light.png` | 6450 |
| bhop_run_1 | `bhop_run_1_c3a2_light.png.import` | 1081 |
| bhop_run_1 | `bhop_run_1_crete3_wall02.png` | 16273 |
| bhop_run_1 | `bhop_run_1_crete3_wall02.png.import` | 1089 |
| bhop_run_1 | `bhop_run_1_crete_bord03.png` | 8812 |
| bhop_run_1 | `bhop_run_1_crete_bord03.png.import` | 1085 |
| bhop_run_1 | `bhop_run_1_endbutton2.png` | 2652 |
| bhop_run_1 | `bhop_run_1_endbutton2.png.import` | 1081 |
| bhop_run_1 | `bhop_run_1_kznum0.png` | 1439 |
| bhop_run_1 | `bhop_run_1_kznum0.png.import` | 1069 |
| bhop_run_1 | `bhop_run_1_kznum1.png` | 883 |
| bhop_run_1 | `bhop_run_1_kznum1.png.import` | 1069 |
| bhop_run_1 | `bhop_run_1_kznum2.png` | 1610 |
| bhop_run_1 | `bhop_run_1_kznum2.png.import` | 1069 |
| bhop_run_1 | `bhop_run_1_kznum3.png` | 1704 |
| bhop_run_1 | `bhop_run_1_kznum3.png.import` | 1069 |
| bhop_run_1 | `bhop_run_1_kznum4.png` | 1351 |
| bhop_run_1 | `bhop_run_1_kznum4.png.import` | 1069 |
| bhop_run_1 | `bhop_run_1_kznum5.png` | 1676 |
| bhop_run_1 | `bhop_run_1_kznum5.png.import` | 1068 |
| bhop_run_1 | `bhop_run_1_kznum6.png` | 1711 |
| bhop_run_1 | `bhop_run_1_kznum6.png.import` | 1068 |
| bhop_run_1 | `bhop_run_1_kznum7.png` | 1084 |
| bhop_run_1 | `bhop_run_1_kznum7.png.import` | 1069 |
| bhop_run_1 | `bhop_run_1_kznum8.png` | 1910 |
| bhop_run_1 | `bhop_run_1_kznum8.png.import` | 1068 |
| bhop_run_1 | `bhop_run_1_kznum9.png` | 1675 |
| bhop_run_1 | `bhop_run_1_kznum9.png.import` | 1068 |
| bhop_run_1 | `bhop_run_1_red.png` | 94 |
| bhop_run_1 | `bhop_run_1_red.png.import` | 1059 |
| bhop_run_1 | `bhop_run_1_startbutton2.png` | 2743 |
| bhop_run_1 | `bhop_run_1_startbutton2.png.import` | 1087 |
| bhop_run_1 | `bhop_run_1_white.png` | 108 |
| bhop_run_1 | `bhop_run_1_white.png.import` | 1066 |
| bhop_run_1 | `bhop_run_1_WOODFLOOR01_512.png` | 56782 |
| bhop_run_1 | `bhop_run_1_WOODFLOOR01_512.png.import` | 1096 |
| bhop_squareblock | `bhop_squareblock.bsp` | 1226076 |
| bhop_squareblock | `bhop_squareblock.glb` | 711768 |
| bhop_squareblock | `bhop_squareblock.glb.import` | 1252 |
| bhop_squareblock | `bhop_squareblock_+0button2.png` | 1541 |
| bhop_squareblock | `bhop_squareblock_+0button2.png.import` | 1095 |
| bhop_squareblock | `bhop_squareblock_-1fifties_w06.png` | 6549 |
| bhop_squareblock | `bhop_squareblock_-1fifties_w06.png.import` | 1108 |
| bhop_squareblock | `bhop_squareblock_bhop_squareblock_lightmap.png` | 95822 |
| bhop_squareblock | `bhop_squareblock_bhop_squareblock_lightmap.png.import` | 1144 |
| bhop_squareblock | `bhop_squareblock_black.png` | 108 |
| bhop_squareblock | `bhop_squareblock_black.png.import` | 1083 |
| bhop_squareblock | `bhop_squareblock_byjeroen.png` | 3148 |
| bhop_squareblock | `bhop_squareblock_byjeroen.png.import` | 1093 |
| bhop_squareblock | `bhop_squareblock_c1a3wall04.png` | 10413 |
| bhop_squareblock | `bhop_squareblock_c1a3wall04.png.import` | 1099 |
| bhop_squareblock | `bhop_squareblock_c1a3wall05.png` | 3520 |
| bhop_squareblock | `bhop_squareblock_c1a3wall05.png.import` | 1099 |
| bhop_squareblock | `bhop_squareblock_crate22.png` | 4724 |
| bhop_squareblock | `bhop_squareblock_crate22.png.import` | 1090 |
| bhop_squareblock | `bhop_squareblock_endbutton2.png` | 2652 |
| bhop_squareblock | `bhop_squareblock_endbutton2.png.import` | 1099 |
| bhop_squareblock | `bhop_squareblock_endcounter2.png` | 27848 |
| bhop_squareblock | `bhop_squareblock_endcounter2.png.import` | 1102 |
| bhop_squareblock | `bhop_squareblock_generic93.png` | 25444 |
| bhop_squareblock | `bhop_squareblock_generic93.png.import` | 1096 |
| bhop_squareblock | `bhop_squareblock_glass_bright.png` | 10206 |
| bhop_squareblock | `bhop_squareblock_glass_bright.png.import` | 1104 |
| bhop_squareblock | `bhop_squareblock_kznum0.png` | 1779 |
| bhop_squareblock | `bhop_squareblock_kznum0.png.import` | 1087 |
| bhop_squareblock | `bhop_squareblock_kznum1.png` | 1198 |
| bhop_squareblock | `bhop_squareblock_kznum1.png.import` | 1087 |
| bhop_squareblock | `bhop_squareblock_kznum2.png` | 1673 |
| bhop_squareblock | `bhop_squareblock_kznum2.png.import` | 1087 |
| bhop_squareblock | `bhop_squareblock_kznum3.png` | 1833 |
| bhop_squareblock | `bhop_squareblock_kznum3.png.import` | 1087 |
| bhop_squareblock | `bhop_squareblock_kznum4.png` | 1524 |
| bhop_squareblock | `bhop_squareblock_kznum4.png.import` | 1087 |
| bhop_squareblock | `bhop_squareblock_kznum5.png` | 1651 |
| bhop_squareblock | `bhop_squareblock_kznum5.png.import` | 1087 |
| bhop_squareblock | `bhop_squareblock_kznum6.png` | 1849 |
| bhop_squareblock | `bhop_squareblock_kznum6.png.import` | 1087 |
| bhop_squareblock | `bhop_squareblock_kznum7.png` | 1472 |
| bhop_squareblock | `bhop_squareblock_kznum7.png.import` | 1087 |
| bhop_squareblock | `bhop_squareblock_kznum8.png` | 1978 |
| bhop_squareblock | `bhop_squareblock_kznum8.png.import` | 1087 |
| bhop_squareblock | `bhop_squareblock_kznum9.png` | 1879 |
| bhop_squareblock | `bhop_squareblock_kznum9.png.import` | 1087 |
| bhop_squareblock | `bhop_squareblock_red.png` | 94 |
| bhop_squareblock | `bhop_squareblock_red.png.import` | 1078 |
| bhop_squareblock | `bhop_squareblock_startbutton2.png` | 2743 |
| bhop_squareblock | `bhop_squareblock_startbutton2.png.import` | 1105 |
| bhop_squareblock | `bhop_squareblock_steel.png` | 12294 |
| bhop_squareblock | `bhop_squareblock_steel.png.import` | 1084 |
| bhop_squareblock | `bhop_squareblock_walkunderhere.png` | 30692 |
| bhop_squareblock | `bhop_squareblock_walkunderhere.png.import` | 1108 |
| bhop_squareblock | `bhop_squareblock_white.png` | 108 |
| bhop_squareblock | `bhop_squareblock_white.png.import` | 1084 |
| bhop_tk_speedrun | `bhop_tk_speedrun.bsp` | 3803624 |
| bhop_tk_speedrun | `bhop_tk_speedrun.glb` | 1804616 |
| bhop_tk_speedrun | `bhop_tk_speedrun.glb.import` | 1252 |
| bhop_tk_speedrun | `bhop_tk_speedrun_AAAAAAAA.png` | 4213 |
| bhop_tk_speedrun | `bhop_tk_speedrun_AAAAAAAA.png.import` | 1093 |
| bhop_tk_speedrun | `bhop_tk_speedrun_bhop_tk_speedrun_lightmap.png` | 456797 |
| bhop_tk_speedrun | `bhop_tk_speedrun_bhop_tk_speedrun_lightmap.png.import` | 1144 |
| bhop_tk_speedrun | `bhop_tk_speedrun_black.png` | 108 |
| bhop_tk_speedrun | `bhop_tk_speedrun_black.png.import` | 1084 |
| bhop_tk_speedrun | `bhop_tk_speedrun_fafa.png` | 185 |
| bhop_tk_speedrun | `bhop_tk_speedrun_fafa.png.import` | 1081 |
| bhop_tk_speedrun | `bhop_tk_speedrun_fasfa.png` | 184 |
| bhop_tk_speedrun | `bhop_tk_speedrun_fasfa.png.import` | 1084 |
| bhop_tk_speedrun | `bhop_tk_speedrun_FFF.png` | 2895 |
| bhop_tk_speedrun | `bhop_tk_speedrun_FFF.png.import` | 1078 |
| bhop_tk_speedrun | `bhop_tk_speedrun_fffffff.png` | 184 |
| bhop_tk_speedrun | `bhop_tk_speedrun_fffffff.png.import` | 1090 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum0.png` | 1439 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum0.png.import` | 1087 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum1.png` | 883 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum1.png.import` | 1086 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum2.png` | 1610 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum2.png.import` | 1087 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum3.png` | 1704 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum3.png.import` | 1087 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum4.png` | 1351 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum4.png.import` | 1087 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum5.png` | 1676 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum5.png.import` | 1086 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum6.png` | 1711 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum6.png.import` | 1087 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum7.png` | 1084 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum7.png.import` | 1085 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum8.png` | 1910 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum8.png.import` | 1087 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum9.png` | 1675 |
| bhop_tk_speedrun | `bhop_tk_speedrun_kznum9.png.import` | 1086 |
| bhop_tk_speedrun | `bhop_tk_speedrun_myk.png` | 183 |
| bhop_tk_speedrun | `bhop_tk_speedrun_myk.png.import` | 1078 |
| bhop_tk_speedrun | `bhop_tk_speedrun_red.png` | 94 |
| bhop_tk_speedrun | `bhop_tk_speedrun_red.png.import` | 1078 |
| bhop_tk_speedrun | `bhop_tk_speedrun_white.png` | 108 |
| bhop_tk_speedrun | `bhop_tk_speedrun_white.png.import` | 1084 |
| bhop_train | `bhop_train.bsp` | 4702848 |
| bhop_train | `bhop_train.glb` | 3702972 |
| bhop_train | `bhop_train.glb.import` | 1234 |
| bhop_train | `bhop_train_+0buttonsuit.png` | 4830 |
| bhop_train | `bhop_train_+0buttonsuit.png.import` | 1087 |
| bhop_train | `bhop_train_+abuttonsuit.png` | 4188 |
| bhop_train | `bhop_train_+abuttonsuit.png.import` | 1086 |
| bhop_train | `bhop_train_+aexit.png` | 5589 |
| bhop_train | `bhop_train_+aexit.png.import` | 1068 |
| bhop_train | `bhop_train_asphalt01.png` | 121313 |
| bhop_train | `bhop_train_asphalt01.png.import` | 1078 |
| bhop_train | `bhop_train_bhop_train_lightmap.png` | 397579 |
| bhop_train | `bhop_train_bhop_train_lightmap.png.import` | 1108 |
| bhop_train | `bhop_train_black.png` | 108 |
| bhop_train | `bhop_train_black.png.import` | 1065 |
| bhop_train | `bhop_train_Brick04_sm.png` | 43027 |
| bhop_train | `bhop_train_Brick04_sm.png.import` | 1081 |
| bhop_train | `bhop_train_Brick05.png` | 153208 |
| bhop_train | `bhop_train_Brick05.png.import` | 1070 |
| bhop_train | `bhop_train_Brick05_sm.png` | 43645 |
| bhop_train | `bhop_train_Brick05_sm.png.import` | 1080 |
| bhop_train | `bhop_train_Brick05b.png` | 19787 |
| bhop_train | `bhop_train_Brick05b.png.import` | 1075 |
| bhop_train | `bhop_train_Brick06_sm.png` | 41626 |
| bhop_train | `bhop_train_Brick06_sm.png.import` | 1081 |
| bhop_train | `bhop_train_Brick13b.png` | 41670 |
| bhop_train | `bhop_train_Brick13b.png.import` | 1075 |
| bhop_train | `bhop_train_c1a1c_w2.png` | 48231 |
| bhop_train | `bhop_train_c1a1c_w2.png.import` | 1074 |
| bhop_train | `bhop_train_capa2.png` | 40611 |
| bhop_train | `bhop_train_capa2.png.import` | 1066 |
| bhop_train | `bhop_train_Ceiling01.png` | 70613 |
| bhop_train | `bhop_train_Ceiling01.png.import` | 1078 |
| bhop_train | `bhop_train_CinderBlock01a.png` | 36298 |
| bhop_train | `bhop_train_CinderBlock01a.png.import` | 1093 |
| bhop_train | `bhop_train_Concrete02.png` | 69729 |
| bhop_train | `bhop_train_Concrete02.png.import` | 1081 |
| bhop_train | `bhop_train_Concrete02a.png` | 18923 |
| bhop_train | `bhop_train_Concrete02a.png.import` | 1084 |
| bhop_train | `bhop_train_conretetrim.png` | 62944 |
| bhop_train | `bhop_train_conretetrim.png.import` | 1084 |
| bhop_train | `bhop_train_crate02.png` | 6309 |
| bhop_train | `bhop_train_crate02.png.import` | 1072 |
| bhop_train | `bhop_train_CrateSide01.png` | 33653 |
| bhop_train | `bhop_train_CrateSide01.png.import` | 1084 |
| bhop_train | `bhop_train_CrateSide02.png` | 9364 |
| bhop_train | `bhop_train_CrateSide02.png.import` | 1084 |
| bhop_train | `bhop_train_crete3_wall02.png` | 16273 |
| bhop_train | `bhop_train_crete3_wall02.png.import` | 1090 |
| bhop_train | `bhop_train_Door01.png` | 53388 |
| bhop_train | `bhop_train_Door01.png.import` | 1069 |
| bhop_train | `bhop_train_dumpsterfront.png` | 31800 |
| bhop_train | `bhop_train_dumpsterfront.png.import` | 1090 |
| bhop_train | `bhop_train_dumpsterside.png` | 43833 |
| bhop_train | `bhop_train_dumpsterside.png.import` | 1087 |
| bhop_train | `bhop_train_emerglight.png` | 352 |
| bhop_train | `bhop_train_emerglight.png.import` | 1081 |
| bhop_train | `bhop_train_generic015a.png` | 5864 |
| bhop_train | `bhop_train_generic015a.png.import` | 1084 |
| bhop_train | `bhop_train_GravelGrass02.png` | 94261 |
| bhop_train | `bhop_train_GravelGrass02.png.import` | 1090 |
| bhop_train | `bhop_train_GravelGrass03.png` | 94096 |
| bhop_train | `bhop_train_GravelGrass03.png.import` | 1090 |
| bhop_train | `bhop_train_GravelGrass04.png` | 186717 |
| bhop_train | `bhop_train_GravelGrass04.png.import` | 1090 |
| bhop_train | `bhop_train_inicio2.png` | 2454 |
| bhop_train | `bhop_train_inicio2.png.import` | 1072 |
| bhop_train | `bhop_train_Ivy01a.png` | 48868 |
| bhop_train | `bhop_train_Ivy01a.png.import` | 1069 |
| bhop_train | `bhop_train_kznum0.png` | 1439 |
| bhop_train | `bhop_train_kznum0.png.import` | 1069 |
| bhop_train | `bhop_train_kznum1.png` | 883 |
| bhop_train | `bhop_train_kznum1.png.import` | 1069 |
| bhop_train | `bhop_train_kznum2.png` | 1610 |
| bhop_train | `bhop_train_kznum2.png.import` | 1068 |
| bhop_train | `bhop_train_kznum3.png` | 1704 |
| bhop_train | `bhop_train_kznum3.png.import` | 1069 |
| bhop_train | `bhop_train_kznum4.png` | 1351 |
| bhop_train | `bhop_train_kznum4.png.import` | 1069 |
| bhop_train | `bhop_train_kznum5.png` | 1676 |
| bhop_train | `bhop_train_kznum5.png.import` | 1068 |
| bhop_train | `bhop_train_kznum6.png` | 1711 |
| bhop_train | `bhop_train_kznum6.png.import` | 1068 |
| bhop_train | `bhop_train_kznum7.png` | 1084 |
| bhop_train | `bhop_train_kznum7.png.import` | 1069 |
| bhop_train | `bhop_train_kznum8.png` | 1910 |
| bhop_train | `bhop_train_kznum8.png.import` | 1069 |
| bhop_train | `bhop_train_kznum9.png` | 1675 |
| bhop_train | `bhop_train_kznum9.png.import` | 1069 |
| bhop_train | `bhop_train_mapa.png` | 1575 |
| bhop_train | `bhop_train_mapa.png.import` | 1063 |
| bhop_train | `bhop_train_MoseyPlywood01.png` | 72513 |
| bhop_train | `bhop_train_MoseyPlywood01.png.import` | 1093 |
| bhop_train | `bhop_train_out_pave1.png` | 27056 |
| bhop_train | `bhop_train_out_pave1.png.import` | 1078 |
| bhop_train | `bhop_train_red.png` | 94 |
| bhop_train | `bhop_train_red.png.import` | 1060 |
| bhop_train | `bhop_train_rope.png` | 1112 |
| bhop_train | `bhop_train_rope.png.import` | 1062 |
| bhop_train | `bhop_train_Tracks02.png` | 32690 |
| bhop_train | `bhop_train_Tracks02.png.import` | 1075 |
| bhop_train | `bhop_train_TrainEnd01.png` | 23989 |
| bhop_train | `bhop_train_TrainEnd01.png.import` | 1080 |
| bhop_train | `bhop_train_TrainEnd02.png` | 19825 |
| bhop_train | `bhop_train_TrainEnd02.png.import` | 1080 |
| bhop_train | `bhop_train_TrainSide01-1.png` | 60560 |
| bhop_train | `bhop_train_TrainSide01-1.png.import` | 1090 |
| bhop_train | `bhop_train_TrainSide01-2a.png` | 63161 |
| bhop_train | `bhop_train_TrainSide01-2a.png.import` | 1092 |
| bhop_train | `bhop_train_TrainSide02-1.png` | 61035 |
| bhop_train | `bhop_train_TrainSide02-1.png.import` | 1089 |
| bhop_train | `bhop_train_TrainSide02-2.png` | 58046 |
| bhop_train | `bhop_train_TrainSide02-2.png.import` | 1089 |
| bhop_train | `bhop_train_TrainTop01.png` | 6015 |
| bhop_train | `bhop_train_TrainTop01.png.import` | 1081 |
| bhop_train | `bhop_train_TrainTop02.png` | 5610 |
| bhop_train | `bhop_train_TrainTop02.png.import` | 1081 |
| bhop_train | `bhop_train_warehousedoor.png` | 115144 |
| bhop_train | `bhop_train_warehousedoor.png.import` | 1089 |
| bhop_train | `bhop_train_WheelEnd02.png` | 17005 |
| bhop_train | `bhop_train_WheelEnd02.png.import` | 1081 |
| bhop_train | `bhop_train_WheelSide02.png` | 39859 |
| bhop_train | `bhop_train_WheelSide02.png.import` | 1084 |
| bhop_train | `bhop_train_white.png` | 108 |
| bhop_train | `bhop_train_white.png.import` | 1065 |
| bhop_train | `bhop_train_Window04a.png` | 18984 |
| bhop_train | `bhop_train_Window04a.png.import` | 1078 |
| bhop_train | `bhop_train_Wood01.png` | 32085 |
| bhop_train | `bhop_train_Wood01.png.import` | 1068 |
| bhop_train | `bhop_train_{blue.png` | 93 |
| bhop_train | `bhop_train_{blue.png.import` | 1066 |
| bhop_train | `bhop_train_{fence3.png` | 38641 |
| bhop_train | `bhop_train_{fence3.png.import` | 1072 |
| bhop_train | `bhop_train_{invisible.png` | 93 |
| bhop_train | `bhop_train_{invisible.png.import` | 1081 |
| bhop_train | `bhop_train_{ladder1.png` | 873 |
| bhop_train | `bhop_train_{ladder1.png.import` | 1075 |
| bhop_train | `bhop_train_{rail2.png` | 752 |
| bhop_train | `bhop_train_{rail2.png.import` | 1069 |
| bhop_training_final | `bhop_training_final.bsp` | 4011104 |
| bhop_training_final | `bhop_training_final.glb` | 1578872 |
| bhop_training_final | `bhop_training_final.glb.import` | 1261 |
| bhop_training_final | `bhop_training_final_bhop_training_final_lightmap.png` | 273867 |
| bhop_training_final | `bhop_training_final_bhop_training_final_lightmap.png.import` | 1162 |
| bhop_training_final | `bhop_training_final_dev_color_02_bi.png` | 727 |
| bhop_training_final | `bhop_training_final_dev_color_02_bi.png.import` | 1122 |
| bhop_training_final | `bhop_training_final_dev_gray_50_128.png` | 775 |
| bhop_training_final | `bhop_training_final_dev_gray_50_128.png.import` | 1121 |
| bhop_training_final | `bhop_training_final_dev_gray_90_128.png` | 1388 |
| bhop_training_final | `bhop_training_final_dev_gray_90_128.png.import` | 1123 |
| bhop_training_final | `bhop_training_final_devbutton_50.png` | 230 |
| bhop_training_final | `bhop_training_final_devbutton_50.png.import` | 1114 |
| bhop_training_final | `bhop_training_final_devcrate32.png` | 260 |
| bhop_training_final | `bhop_training_final_devcrate32.png.import` | 1108 |
| bhop_training_final | `bhop_training_final_devcrate64.png` | 330 |
| bhop_training_final | `bhop_training_final_devcrate64.png.import` | 1108 |
| bhop_training_final | `bhop_training_final_devcross.png` | 493 |
| bhop_training_final | `bhop_training_final_devcross.png.import` | 1101 |
| bhop_training_final | `bhop_training_final_devcross2.png` | 482 |
| bhop_training_final | `bhop_training_final_devcross2.png.import` | 1104 |
| bhop_training_final | `bhop_training_final_devwallgray.png` | 456 |
| bhop_training_final | `bhop_training_final_devwallgray.png.import` | 1110 |
| bhop_training_final | `bhop_training_final_REKLAMX.png` | 20584 |
| bhop_training_final | `bhop_training_final_REKLAMX.png.import` | 1099 |
| bhop_training_final | `bhop_training_final_{REKLAM.png` | 28930 |
| bhop_training_final | `bhop_training_final_{REKLAM.png.import` | 1098 |
| bhop_without_colors | `bhop_without_colors.bsp` | 4252596 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light.bsp` | 4809412 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light.glb` | 4160368 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light.glb.import` | 1261 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_bhop_neon_tnx.png` | 30897 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_bhop_neon_tnx.png.import` | 1117 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_bhop_ytt_neon_light_lightmap.png` | 428997 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_bhop_ytt_neon_light_lightmap.png.import` | 1162 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_black.png` | 108 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_black.png.import` | 1093 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_deco1.png` | 39847 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_deco1.png.import` | 1102 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_deco_main_up.png` | 18369 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_deco_main_up.png.import` | 1123 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_inner_deco10.png` | 18587 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_inner_deco10.png.import` | 1122 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_inner_deco11.png` | 35810 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_inner_deco11.png.import` | 1123 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_inner_deco2.png` | 17382 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_inner_deco2.png.import` | 1120 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_inner_deco3_.png` | 38521 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_inner_deco3_.png.import` | 1123 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_inner_deco4.png` | 18782 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_inner_deco4.png.import` | 1119 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_inner_deco9.png` | 151005 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_inner_deco9.png.import` | 1119 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_o_wall001.png` | 35469 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_o_wall001.png.import` | 1113 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_o_wall002.png` | 309193 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_o_wall002.png.import` | 1113 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_tutle_bone00.png` | 137955 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_Cm_tutle_bone00.png.import` | 1122 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_egipto49mz.png` | 420933 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_egipto49mz.png.import` | 1107 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_flooors23.png` | 152415 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_flooors23.png.import` | 1105 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_floors2.png` | 147090 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_floors2.png.import` | 1099 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_iroglifi.png` | 45736 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_iroglifi.png.import` | 1101 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_iroglifi1.png` | 42973 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_iroglifi1.png.import` | 1105 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_iroglifi2.png` | 45982 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_iroglifi2.png.import` | 1105 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum0.png` | 1439 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum0.png.import` | 1096 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum1.png` | 883 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum1.png.import` | 1096 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum2.png` | 1610 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum2.png.import` | 1096 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum3.png` | 1704 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum3.png.import` | 1096 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum4.png` | 1351 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum4.png.import` | 1096 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum5.png` | 1676 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum5.png.import` | 1096 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum6.png` | 1711 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum6.png.import` | 1096 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum7.png` | 1084 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum7.png.import` | 1096 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum8.png` | 1910 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum8.png.import` | 1095 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum9.png` | 1675 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_kznum9.png.import` | 1096 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_neonwall3.png` | 124129 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_neonwall3.png.import` | 1105 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_neonwall6.png` | 48101 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_neonwall6.png.import` | 1105 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_stargate3.png` | 22944 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_stargate3.png.import` | 1105 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_zmeilogo.png` | 15461 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_zmeilogo.png.import` | 1102 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_{blue.png` | 93 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_{blue.png.import` | 1093 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_{strelka.png` | 5313 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_{strelka.png.import` | 1101 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_~lightcherven.png` | 125 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_~lightcherven.png.import` | 1117 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_~lightlilav.png` | 3213 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_~lightlilav.png.import` | 1110 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_~lightoranjev.png` | 126 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_~lightoranjev.png.import` | 1116 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_~lightsin.png` | 125 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_~lightsin.png.import` | 1105 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_~lightzelen.png` | 158 |
| bhop_ytt_neon_light | `bhop_ytt_neon_light_~lightzelen.png.import` | 1111 |
| bkz_goldbhop | `bkz_goldbhop.bsp` | 1881268 |
| bkz_goldbhop | `bkz_goldbhop.glb` | 1253424 |
| bkz_goldbhop | `bkz_goldbhop.glb.import` | 1240 |
| bkz_goldbhop | `bkz_goldbhop_+0button2.png` | 2257 |
| bkz_goldbhop | `bkz_goldbhop_+0button2.png.import` | 1084 |
| bkz_goldbhop | `bkz_goldbhop_+0~light3a.png` | 619 |
| bkz_goldbhop | `bkz_goldbhop_+0~light3a.png.import` | 1086 |
| bkz_goldbhop | `bkz_goldbhop_bkz_goldbhop_lightmap.png` | 155000 |
| bkz_goldbhop | `bkz_goldbhop_bkz_goldbhop_lightmap.png.import` | 1120 |
| bkz_goldbhop | `bkz_goldbhop_black.png` | 108 |
| bkz_goldbhop | `bkz_goldbhop_black.png.import` | 1072 |
| bkz_goldbhop | `bkz_goldbhop_endcounter2.png` | 37171 |
| bkz_goldbhop | `bkz_goldbhop_endcounter2.png.import` | 1090 |
| bkz_goldbhop | `bkz_goldbhop_gold_orange.png` | 48192 |
| bkz_goldbhop | `bkz_goldbhop_gold_orange.png.import` | 1090 |
| bkz_goldbhop | `bkz_goldbhop_Goldfre.png` | 146550 |
| bkz_goldbhop | `bkz_goldbhop_Goldfre.png.import` | 1076 |
| bkz_goldbhop | `bkz_goldbhop_kznum0.png` | 4041 |
| bkz_goldbhop | `bkz_goldbhop_kznum0.png.import` | 1075 |
| bkz_goldbhop | `bkz_goldbhop_kznum1.png` | 3397 |
| bkz_goldbhop | `bkz_goldbhop_kznum1.png.import` | 1075 |
| bkz_goldbhop | `bkz_goldbhop_kznum2.png` | 4619 |
| bkz_goldbhop | `bkz_goldbhop_kznum2.png.import` | 1075 |
| bkz_goldbhop | `bkz_goldbhop_kznum3.png` | 4306 |
| bkz_goldbhop | `bkz_goldbhop_kznum3.png.import` | 1075 |
| bkz_goldbhop | `bkz_goldbhop_kznum4.png` | 3902 |
| bkz_goldbhop | `bkz_goldbhop_kznum4.png.import` | 1075 |
| bkz_goldbhop | `bkz_goldbhop_kznum5.png` | 4340 |
| bkz_goldbhop | `bkz_goldbhop_kznum5.png.import` | 1075 |
| bkz_goldbhop | `bkz_goldbhop_kznum6.png` | 5159 |
| bkz_goldbhop | `bkz_goldbhop_kznum6.png.import` | 1075 |
| bkz_goldbhop | `bkz_goldbhop_kznum7.png` | 3402 |
| bkz_goldbhop | `bkz_goldbhop_kznum7.png.import` | 1075 |
| bkz_goldbhop | `bkz_goldbhop_kznum8.png` | 5516 |
| bkz_goldbhop | `bkz_goldbhop_kznum8.png.import` | 1075 |
| bkz_goldbhop | `bkz_goldbhop_kznum9.png` | 4933 |
| bkz_goldbhop | `bkz_goldbhop_kznum9.png.import` | 1075 |
| bkz_goldbhop | `bkz_goldbhop_lab1_door1c.png` | 15980 |
| bkz_goldbhop | `bkz_goldbhop_lab1_door1c.png.import` | 1090 |
| bkz_goldbhop | `bkz_goldbhop_mapbysprite.png` | 52713 |
| bkz_goldbhop | `bkz_goldbhop_mapbysprite.png.import` | 1089 |
| bkz_goldbhop | `bkz_goldbhop_rad_rock1.png` | 172945 |
| bkz_goldbhop | `bkz_goldbhop_rad_rock1.png.import` | 1084 |
| bkz_goldbhop | `bkz_goldbhop_rope.png` | 1545 |
| bkz_goldbhop | `bkz_goldbhop_rope.png.import` | 1069 |
| bkz_goldbhop | `bkz_goldbhop_startcounter2.png` | 45582 |
| bkz_goldbhop | `bkz_goldbhop_startcounter2.png.import` | 1096 |
| bkz_goldbhop | `bkz_goldbhop_white.png` | 108 |
| bkz_goldbhop | `bkz_goldbhop_white.png.import` | 1072 |
| bkz_noob | `bkz_noob.bsp` | 715992 |
| bkz_noob | `bkz_noob.glb` | 763904 |
| bkz_noob | `bkz_noob.glb.import` | 1228 |
| bkz_noob | `bkz_noob_+0button2.png` | 1541 |
| bkz_noob | `bkz_noob_+0button2.png.import` | 1072 |
| bkz_noob | `bkz_noob_-0AzWll.png` | 42901 |
| bkz_noob | `bkz_noob_-0AzWll.png.import` | 1066 |
| bkz_noob | `bkz_noob_AzGrnd.png` | 163048 |
| bkz_noob | `bkz_noob_AzGrnd.png.import` | 1062 |
| bkz_noob | `bkz_noob_bkz_noob_lightmap.png` | 13211 |
| bkz_noob | `bkz_noob_bkz_noob_lightmap.png.import` | 1096 |
| bkz_noob | `bkz_noob_bkz_te.png` | 1719 |
| bkz_noob | `bkz_noob_bkz_te.png.import` | 1062 |
| bkz_noob | `bkz_noob_black.png` | 108 |
| bkz_noob | `bkz_noob_black.png.import` | 1060 |
| bkz_noob | `bkz_noob_endbutton2.png` | 2652 |
| bkz_noob | `bkz_noob_endbutton2.png.import` | 1074 |
| bkz_noob | `bkz_noob_kznum0.png` | 1439 |
| bkz_noob | `bkz_noob_kznum0.png.import` | 1063 |
| bkz_noob | `bkz_noob_kznum1.png` | 883 |
| bkz_noob | `bkz_noob_kznum1.png.import` | 1063 |
| bkz_noob | `bkz_noob_kznum2.png` | 1610 |
| bkz_noob | `bkz_noob_kznum2.png.import` | 1063 |
| bkz_noob | `bkz_noob_kznum3.png` | 1704 |
| bkz_noob | `bkz_noob_kznum3.png.import` | 1062 |
| bkz_noob | `bkz_noob_kznum4.png` | 1351 |
| bkz_noob | `bkz_noob_kznum4.png.import` | 1063 |
| bkz_noob | `bkz_noob_kznum5.png` | 1676 |
| bkz_noob | `bkz_noob_kznum5.png.import` | 1063 |
| bkz_noob | `bkz_noob_kznum6.png` | 1711 |
| bkz_noob | `bkz_noob_kznum6.png.import` | 1063 |
| bkz_noob | `bkz_noob_kznum7.png` | 1084 |
| bkz_noob | `bkz_noob_kznum7.png.import` | 1063 |
| bkz_noob | `bkz_noob_kznum8.png` | 1910 |
| bkz_noob | `bkz_noob_kznum8.png.import` | 1062 |
| bkz_noob | `bkz_noob_kznum9.png` | 1675 |
| bkz_noob | `bkz_noob_kznum9.png.import` | 1063 |
| bkz_noob | `bkz_noob_red.png` | 94 |
| bkz_noob | `bkz_noob_red.png.import` | 1054 |
| bkz_noob | `bkz_noob_startbutton2.png` | 2743 |
| bkz_noob | `bkz_noob_startbutton2.png.import` | 1080 |
| bkz_noob | `bkz_noob_white.png` | 108 |
| bkz_noob | `bkz_noob_white.png.import` | 1060 |
| kz_bhop | `kz_bhop.bsp` | 52796 |
| kzru_airway | `kzru_airway.bsp` | 4273460 |
| kzru_airway | `kzru_airway.glb` | 4982344 |
| kzru_airway | `kzru_airway.glb.import` | 1237 |
| kzru_airway | `kzru_airway_!TileWater01i.png` | 93151 |
| kzru_airway | `kzru_airway_!TileWater01i.png.import` | 1093 |
| kzru_airway | `kzru_airway_!TileWater01z.png` | 150525 |
| kzru_airway | `kzru_airway_!TileWater01z.png.import` | 1092 |
| kzru_airway | `kzru_airway_black.png` | 108 |
| kzru_airway | `kzru_airway_black.png.import` | 1069 |
| kzru_airway | `kzru_airway_ezway.png` | 1043 |
| kzru_airway | `kzru_airway_ezway.png.import` | 1069 |
| kzru_airway | `kzru_airway_hway.png` | 539 |
| kzru_airway | `kzru_airway_hway.png.import` | 1064 |
| kzru_airway | `kzru_airway_jiu.png` | 336714 |
| kzru_airway | `kzru_airway_jiu.png.import` | 1063 |
| kzru_airway | `kzru_airway_jium.png` | 1697 |
| kzru_airway | `kzru_airway_jium.png.import` | 1066 |
| kzru_airway | `kzru_airway_kzru_airway_lightmap.png` | 205335 |
| kzru_airway | `kzru_airway_kzru_airway_lightmap.png.import` | 1114 |
| kzru_airway | `kzru_airway_nz_brick_.png` | 81056 |
| kzru_airway | `kzru_airway_nz_brick_.png.import` | 1081 |
| kzru_airway | `kzru_airway_nz_floor_.png` | 50533 |
| kzru_airway | `kzru_airway_nz_floor_.png.import` | 1080 |
| kzru_airway | `kzru_airway_pasto1_.png` | 188427 |
| kzru_airway | `kzru_airway_pasto1_.png.import` | 1075 |
| kzru_airway | `kzru_airway_thank.png` | 4034 |
| kzru_airway | `kzru_airway_thank.png.import` | 1069 |
| kzru_airway | `kzru_airway_TileGround01b.png` | 162024 |
| kzru_airway | `kzru_airway_TileGround01b.png.import` | 1093 |
| kzru_airway | `kzru_airway_TileGround01j.png` | 149392 |
| kzru_airway | `kzru_airway_TileGround01j.png.import` | 1092 |
| kzru_airway | `kzru_airway_TileGround01p.png` | 180682 |
| kzru_airway | `kzru_airway_TileGround01p.png.import` | 1093 |
| kzru_airway | `kzru_airway_TileGround01r.png` | 148662 |
| kzru_airway | `kzru_airway_TileGround01r.png.import` | 1093 |
| kzru_airway | `kzru_airway_TileGround01x.png` | 176185 |
| kzru_airway | `kzru_airway_TileGround01x.png.import` | 1092 |
| kzru_airway | `kzru_airway_TileGround02a.png` | 169081 |
| kzru_airway | `kzru_airway_TileGround02a.png.import` | 1093 |
| kzru_airway | `kzru_airway_TileGround02c.png` | 167785 |
| kzru_airway | `kzru_airway_TileGround02c.png.import` | 1093 |
| kzru_airway | `kzru_airway_TileGround02p.png` | 162742 |
| kzru_airway | `kzru_airway_TileGround02p.png.import` | 1093 |
| kzru_airway | `kzru_airway_TileGround02q.png` | 170146 |
| kzru_airway | `kzru_airway_TileGround02q.png.import` | 1093 |
| kzru_airway | `kzru_airway_TileGround02s.png` | 171699 |
| kzru_airway | `kzru_airway_TileGround02s.png.import` | 1092 |
| kzru_airway | `kzru_airway_TileGround02x.png` | 181647 |
| kzru_airway | `kzru_airway_TileGround02x.png.import` | 1093 |
| kzru_airway | `kzru_airway_TileGround03a1.png` | 41917 |
| kzru_airway | `kzru_airway_TileGround03a1.png.import` | 1095 |
| kzru_airway | `kzru_airway_TileGround03a10.png` | 44793 |
| kzru_airway | `kzru_airway_TileGround03a10.png.import` | 1099 |
| kzru_airway | `kzru_airway_TileGround03a9.png` | 39528 |
| kzru_airway | `kzru_airway_TileGround03a9.png.import` | 1096 |
| kzru_airway | `kzru_airway_TileGround03i.png` | 154062 |
| kzru_airway | `kzru_airway_TileGround03i.png.import` | 1093 |
| kzru_airway | `kzru_airway_TileGround03p.png` | 180535 |
| kzru_airway | `kzru_airway_TileGround03p.png.import` | 1093 |
| kzru_airway | `kzru_airway_TileRock02g.png` | 165408 |
| kzru_airway | `kzru_airway_TileRock02g.png.import` | 1087 |
| kzru_airway | `kzru_airway_TileRock03d.png` | 147822 |
| kzru_airway | `kzru_airway_TileRock03d.png.import` | 1087 |
| kzru_airway | `kzru_airway_TileRock03j.png` | 170392 |
| kzru_airway | `kzru_airway_TileRock03j.png.import` | 1086 |
| kzru_airway | `kzru_airway_TileRock04a9.png` | 31383 |
| kzru_airway | `kzru_airway_TileRock04a9.png.import` | 1090 |
| kzru_airway | `kzru_airway_TileRock05i.png` | 139972 |
| kzru_airway | `kzru_airway_TileRock05i.png.import` | 1087 |
| kzru_airway | `kzru_airway_white.png` | 855 |
| kzru_airway | `kzru_airway_white.png.import` | 1069 |
| kzru_airway | `kzru_airway_woodc01.png` | 52298 |
| kzru_airway | `kzru_airway_woodc01.png.import` | 1075 |
| kzru_airway | `kzru_airway_WOODFLOOR01_512.png` | 56782 |
| kzru_airway | `kzru_airway_WOODFLOOR01_512.png.import` | 1098 |
| kzru_airway | `kzru_airway_xway.png` | 1040 |
| kzru_airway | `kzru_airway_xway.png.import` | 1065 |
| kzru_airway | `kzru_airway_{ladder1.png` | 873 |
| kzru_airway | `kzru_airway_{ladder1.png.import` | 1077 |
| kzsca_toonbhop | `kzsca_toonbhop.bsp` | 2994220 |
| kzsca_toonbhop | `kzsca_toonbhop.glb` | 1832192 |
| kzsca_toonbhop | `kzsca_toonbhop.glb.import` | 1245 |
| kzsca_toonbhop | `kzsca_toonbhop_!wassa01.png` | 20461 |
| kzsca_toonbhop | `kzsca_toonbhop_!wassa01.png.import` | 1086 |
| kzsca_toonbhop | `kzsca_toonbhop_+0kzscabutton.png` | 33793 |
| kzsca_toonbhop | `kzsca_toonbhop_+0kzscabutton.png.import` | 1102 |
| kzsca_toonbhop | `kzsca_toonbhop_black.png` | 108 |
| kzsca_toonbhop | `kzsca_toonbhop_black.png.import` | 1078 |
| kzsca_toonbhop | `kzsca_toonbhop_block02.png` | 23844 |
| kzsca_toonbhop | `kzsca_toonbhop_block02.png.import` | 1084 |
| kzsca_toonbhop | `kzsca_toonbhop_block03.png` | 14606 |
| kzsca_toonbhop | `kzsca_toonbhop_block03.png.import` | 1084 |
| kzsca_toonbhop | `kzsca_toonbhop_gold.png` | 122945 |
| kzsca_toonbhop | `kzsca_toonbhop_gold.png.import` | 1075 |
| kzsca_toonbhop | `kzsca_toonbhop_kzsca_256_banne.png` | 40910 |
| kzsca_toonbhop | `kzsca_toonbhop_kzsca_256_banne.png.import` | 1107 |
| kzsca_toonbhop | `kzsca_toonbhop_kzsca_toonbhop_lightmap.png` | 215118 |
| kzsca_toonbhop | `kzsca_toonbhop_kzsca_toonbhop_lightmap.png.import` | 1132 |
| kzsca_toonbhop | `kzsca_toonbhop_LOGO_cosy.png` | 80389 |
| kzsca_toonbhop | `kzsca_toonbhop_LOGO_cosy.png.import` | 1090 |
| kzsca_toonbhop | `kzsca_toonbhop_pop147.png` | 122903 |
| kzsca_toonbhop | `kzsca_toonbhop_pop147.png.import` | 1081 |
| kzsca_toonbhop | `kzsca_toonbhop_toonbhop.png` | 5189 |
| kzsca_toonbhop | `kzsca_toonbhop_toonbhop.png.import` | 1086 |
| kzsca_toonbhop | `kzsca_toonbhop_toonbhopgreet.png` | 45120 |
| kzsca_toonbhop | `kzsca_toonbhop_toonbhopgreet.png.import` | 1102 |
| kzsca_toonbhop | `kzsca_toonbhop_wandkante01.png` | 26780 |
| kzsca_toonbhop | `kzsca_toonbhop_wandkante01.png.import` | 1096 |
| kzsca_toonbhop | `kzsca_toonbhop_wandkante03.png` | 27427 |
| kzsca_toonbhop | `kzsca_toonbhop_wandkante03.png.import` | 1096 |
| kzsca_toonbhop | `kzsca_toonbhop_wando01.png` | 23433 |
| kzsca_toonbhop | `kzsca_toonbhop_wando01.png.import` | 1084 |
| kzsca_toonbhop | `kzsca_toonbhop_wando03.png` | 24061 |
| kzsca_toonbhop | `kzsca_toonbhop_wando03.png.import` | 1084 |
| kzsca_toonbhop | `kzsca_toonbhop_weg01.png` | 12484 |
| kzsca_toonbhop | `kzsca_toonbhop_weg01.png.import` | 1078 |
| kzsca_toonbhop | `kzsca_toonbhop_weg02.png` | 13474 |
| kzsca_toonbhop | `kzsca_toonbhop_weg02.png.import` | 1078 |
| kzsca_toonbhop | `kzsca_toonbhop_white.png` | 108 |
| kzsca_toonbhop | `kzsca_toonbhop_white.png.import` | 1078 |
| kzsk_xmas2010 | `kzsk_xmas2010.bsp` | 2704288 |
| kzy_fastbhop | `kzy_fastbhop.bsp` | 1734312 |
| kzy_juhxbhop | `kzy_juhxbhop.bsp` | 1995924 |
| kzy_juhxbhop | `kzy_juhxbhop.glb` | 1790468 |
| kzy_juhxbhop | `kzy_juhxbhop.glb.import` | 1240 |
| kzy_juhxbhop | `kzy_juhxbhop_+0Y.png` | 2499 |
| kzy_juhxbhop | `kzy_juhxbhop_+0Y.png.import` | 1066 |
| kzy_juhxbhop | `kzy_juhxbhop_+0~fifties_lgt2.png` | 1126 |
| kzy_juhxbhop | `kzy_juhxbhop_+0~fifties_lgt2.png.import` | 1102 |
| kzy_juhxbhop | `kzy_juhxbhop_-0csSandWall.png` | 89425 |
| kzy_juhxbhop | `kzy_juhxbhop_-0csSandWall.png.import` | 1092 |
| kzy_juhxbhop | `kzy_juhxbhop_-0Sand.png` | 43877 |
| kzy_juhxbhop | `kzy_juhxbhop_-0Sand.png.import` | 1075 |
| kzy_juhxbhop | `kzy_juhxbhop_-0SandRock.png` | 70272 |
| kzy_juhxbhop | `kzy_juhxbhop_-0SandRock.png.import` | 1087 |
| kzy_juhxbhop | `kzy_juhxbhop_-1csSandWall.png` | 88950 |
| kzy_juhxbhop | `kzy_juhxbhop_-1csSandWall.png.import` | 1093 |
| kzy_juhxbhop | `kzy_juhxbhop_-1cstrike_mr2dr.png` | 45425 |
| kzy_juhxbhop | `kzy_juhxbhop_-1cstrike_mr2dr.png.import` | 1101 |
| kzy_juhxbhop | `kzy_juhxbhop_-2Sand.png` | 45599 |
| kzy_juhxbhop | `kzy_juhxbhop_-2Sand.png.import` | 1074 |
| kzy_juhxbhop | `kzy_juhxbhop_black.png` | 108 |
| kzy_juhxbhop | `kzy_juhxbhop_black.png.import` | 1072 |
| kzy_juhxbhop | `kzy_juhxbhop_generic011.png` | 5628 |
| kzy_juhxbhop | `kzy_juhxbhop_generic011.png.import` | 1087 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum0.png` | 2209 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum0.png.import` | 1075 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum1.png` | 1865 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum1.png.import` | 1075 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum2.png` | 2681 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum2.png.import` | 1075 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum3.png` | 2849 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum3.png.import` | 1075 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum4.png` | 2678 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum4.png.import` | 1075 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum5.png` | 2917 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum5.png.import` | 1075 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum6.png` | 2641 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum6.png.import` | 1074 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum7.png` | 2554 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum7.png.import` | 1075 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum8.png` | 2433 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum8.png.import` | 1075 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum9.png` | 2699 |
| kzy_juhxbhop | `kzy_juhxbhop_kznum9.png.import` | 1075 |
| kzy_juhxbhop | `kzy_juhxbhop_kzy_juhxbhop_lightmap.png` | 79086 |
| kzy_juhxbhop | `kzy_juhxbhop_kzy_juhxbhop_lightmap.png.import` | 1120 |
| kzy_juhxbhop | `kzy_juhxbhop_MltryCrteSd2.png` | 9545 |
| kzy_juhxbhop | `kzy_juhxbhop_MltryCrteSd2.png.import` | 1093 |
| kzy_juhxbhop | `kzy_juhxbhop_MltryCrteTp.png` | 9965 |
| kzy_juhxbhop | `kzy_juhxbhop_MltryCrteTp.png.import` | 1089 |
| kzy_juhxbhop | `kzy_juhxbhop_pi_wood2.png` | 7445 |
| kzy_juhxbhop | `kzy_juhxbhop_pi_wood2.png.import` | 1081 |
| kzy_juhxbhop | `kzy_juhxbhop_red.png` | 94 |
| kzy_juhxbhop | `kzy_juhxbhop_red.png.import` | 1065 |
| kzy_juhxbhop | `kzy_juhxbhop_SandCCrete.png` | 125242 |
| kzy_juhxbhop | `kzy_juhxbhop_SandCCrete.png.import` | 1087 |
| kzy_juhxbhop | `kzy_juhxbhop_SandCrtLrgSd.png` | 44448 |
| kzy_juhxbhop | `kzy_juhxbhop_SandCrtLrgSd.png.import` | 1093 |
| kzy_juhxbhop | `kzy_juhxbhop_SandCrtLrgTp.png` | 38887 |
| kzy_juhxbhop | `kzy_juhxbhop_SandCrtLrgTp.png.import` | 1093 |
| kzy_juhxbhop | `kzy_juhxbhop_SandCrtSmSd.png` | 10811 |
| kzy_juhxbhop | `kzy_juhxbhop_SandCrtSmSd.png.import` | 1090 |
| kzy_juhxbhop | `kzy_juhxbhop_SandRoad.png` | 176102 |
| kzy_juhxbhop | `kzy_juhxbhop_SandRoad.png.import` | 1080 |
| kzy_juhxbhop | `kzy_juhxbhop_SandTrim.png` | 9554 |
| kzy_juhxbhop | `kzy_juhxbhop_SandTrim.png.import` | 1080 |
| kzy_juhxbhop | `kzy_juhxbhop_SandWllDoor.png` | 71223 |
| kzy_juhxbhop | `kzy_juhxbhop_SandWllDoor.png.import` | 1089 |
| kzy_juhxbhop | `kzy_juhxbhop_SandWllDoor2.png` | 69800 |
| kzy_juhxbhop | `kzy_juhxbhop_SandWllDoor2.png.import` | 1093 |
| kzy_juhxbhop | `kzy_juhxbhop_SandWllWndw.png` | 83716 |
| kzy_juhxbhop | `kzy_juhxbhop_SandWllWndw.png.import` | 1090 |
| kzy_juhxbhop | `kzy_juhxbhop_Yamangel.png` | 66273 |
| kzy_juhxbhop | `kzy_juhxbhop_Yamangel.png.import` | 1080 |
| kzy_junglerocks | `kzy_junglerocks.bsp` | 2254984 |

## Уточнение хранения логов

22 файла `<map>.log` переименованы в `<map>_log.txt`, чтобы правило `.gitignore` `*.log` не исключало доказательства. Содержимое логов не изменялось. Ссылки README и галереи обновлены; в summary.json и commands.json ссылок на `.log` изначально не было. После переименования повторная проверка HTMLParser/Pillow: 182 href/src разрешаются, 67 JPEG успешно декодируются (1280×720). Godot повторно не запускался.
