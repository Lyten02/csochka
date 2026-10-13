# 35hp_3 (CS 1.6) → Blender / Three.js / Godot 4.7.2

Исходник: `35hp_3.bsp` (GoldSrc BSP v30, все текстуры встроены в BSP).

```
tools/goldsrc_bsp.py        парсер BSP: энтити, miptex-текстуры, грани, лайтмапы
tools/bsp_to_blender.py     сборка оптимизированной сцены в Blender + экспорт GLB
tools/make_skybox.py        рендер 360° скайбокса «desert» в Blender (Cycles)
tools/mdl_to_glb.py         GoldSrc MDL v10 → GLB (скелет, скиннинг, анимации) для viewmodel ножа
models_src/                 исходник `v_knife.mdl` и PNG-скины для перекрашенных ножей
blender/35hp_3.blend        редактируемая сцена (текстуры и лайтмап упакованы)
export/35hp_3.glb           GLB с PNG (Godot / любые glTF-потребители)
export/35hp_3_web.glb       GLB с WebP (для браузера)
export/35hp_3_stats.json    статистика сборки
export/sky/                 скайбокс: PNG-мастер 4096×2048, WebP 4096 (Godot), WebP 2048 (веб)
web/                        Three.js-просмотрщик (Vite)
godot/                      проект Godot 4.7.2 с контроллером CS 1.6
.tools/Godot_v4.7.2-*.exe   portable Godot 4.7.2 (скачан с официального релиза)
```

## 1. Blender: оптимизированная карта

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background --factory-startup `
  --python tools/bsp_to_blender.py -- 35hp_3.bsp
```

Одна команда пересобирает `.blend`, оба GLB и обновляет копии в `web/public/maps/` и `godot/maps/`
(туда же кладётся `.bsp` — из него Godot берёт clip-hull'ы для столкновений).

Что сделано для слабых устройств:

| | |
|---|---|
| Удалены | clip / aaatrigger / origin / null грани, триггеры, `func_ladder` |
| Геометрия | ~6.5 k треугольников + 484 треугольника sky-брашей, всё статическое слито → **14 draw call'ов** (по одному на материал) |
| Освещение | родные лайтмапы из BSP упакованы в один атлас 1024×512 (UV1, с паддингом от протечек фильтрации). Рантайм — unlit: без источников света, теней и нормалей |
| Вершины | сварены (`remove_doubles`), нормали/тангенты не экспортируются |
| Размер | `35hp_3_web.glb` ≈ 0.55 MB (WebP), `35hp_3.glb` ≈ 1.1 MB (PNG); скайбокс для веба ≈ 40 KB |

Материал в glTF: `baseColorTexture` (UV0) = текстура, `occlusionTexture` (texCoord 1) = **RGB-лайтмап**.
Просмотрщик и Godot читают его как цветной light map (texture × lightmap), как в GoldSrc.
Прозрачные `func_breakable` (rendermode 2, renderamt 100) → alpha blend 0.39, `{ladder1` → alpha test.
Гамма как в движке: лайтмап `pow(x, 1/2.5)` (`lightgamma`), текстуры `pow(x, 2.0/2.5)` (`texgamma`/`gamma`).
Грани с текстурой `sky` экспортируются отдельным материалом `sky`: как в GoldSrc, через них виден скайбокс
и они закрывают всё, что за ними.

### Скайбокс

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" --background --factory-startup `
  --python tools/make_skybox.py              # добавьте `-- --preview` для быстрого рендера 1024×512
```

Файлов скайбокса `desert` в BSP нет, поэтому он собирается процедурно: физическое небо Blender, солнце
там же, где его ставит `light_spot` карты (азимут +Y, высота 30° — совпадает с тенями в лайтмапе),
красные слоистые меса, песчаная равнина, облака и дымка. Рендер — эквиректангулярная панорама Cycles
(~4 мин на RTX 2060 SUPER); копии кладутся в `web/public/sky/` и `godot/sky/`.

## 2. Three.js просмотрщик

```powershell
cd web
npm install
npm run dev      # http://localhost:5173 (с --host доступен с телефона в той же сети)
npm run build    # статическая сборка в web/dist (base './')
```

Свободная камера (ПК: клик → pointer lock, WASD, Space/E вверх, Ctrl/C/Q вниз, Shift ×4, Alt ×0.25,
колесо — базовая скорость; телефон: левая половина — джойстик, правая — обзор, кнопки ▲/▼).
Debug overlay (F3): FPS / 1% low / frame time + график, CPU и GPU время кадра
(`EXT_disjoint_timer_query_webgl2`), загрузка CPU/GPU от бюджета кадра и вердикт, draw calls /
треугольники / программы, оценка памяти GPU под геометрию и текстуры, JS heap, long tasks, GPU/устройство,
время загрузки, позиция камеры в метрах и юнитах GoldSrc, выбор render scale.
Кнопки: спавны 1–9 / выпадающий список, R — к спавну, «Освещение» (лайтмап вкл/выкл), «Каркас».
Скриншоты проверки: `web/screenshots/`.

Спавны 35hp_3 висят в «небесной» комнате ~27 м над ареной (так устроена карта: падение в шахту →
`trigger_teleport`); вокруг спавна виден только скайбокс.

## 3. Godot 4.7.2: контроллер CS 1.6

Открыть `godot/project.godot` в Godot 4.7.2 (`.tools/Godot_v4.7.2-stable_win64.exe`) и запустить (F5).

Управление: WASD, мышь, Space **или колесо мыши** — прыжок, Ctrl — присед, Shift — шаг, E — use,
R — следующий спавн, V — noclip, F2 — автобхоп, F3 — лимит скорости bhop, F4 — стамина прыжка,
F1 — скрыть HUD, F — осмотр ножа (если модель его поддерживает), Esc — отпустить мышь.

### Как устроено

- **Столкновения — родные clip hull'ы карты**, а не физика Godot. `scripts/goldsrc/goldsrc_bsp.gd`
  читает `PLANES / CLIPNODES / NODES / LEAVES / MODELS` из `.bsp` и повторяет движковые
  `PM_RecursiveHullCheck` (с `DIST_EPSILON`), `PM_HullPointContents`, `PM_PlayerTrace`,
  `PM_TestPlayerPosition`. Хулл стоя 32×32×72, присед 32×32×36 — ровно те же объёмы (включая
  clip-браши), по которым ходит игрок в CS. `func_wall` / `func_breakable` — твёрдые, `func_ladder` — лестницы,
  `trigger_teleport` работают (спавн → шахта → телепорт на арену).
- **Движение — порт `pm_shared` CS 1.6** (по ReGameDLL_CS) в `scripts/player/cs_pmove.gd`:
  `PM_Friction` (с edgefriction), `PM_Accelerate`, `PM_AirAccelerate` (кап 30 → air strafe),
  `PM_WalkMove` со step-up 18, `PM_FlyMove` с отражением в воздухе, `PM_ClipVelocity`,
  `PM_CategorizePosition`, полугравитация до/после движения, `PM_Jump` (√(2·800·45),
  анти-pogo через `oldbuttons`), **`PM_PreventMegaBunnyJumping`** (1.2 × maxspeed → ×0.8),
  **стамина `fuser2`** (замедление после приземления и пониженный повторный прыжок), `PM_Duck` /
  `PM_UnDuck` (0.4 с, duck-jump в воздухе), `PM_LadderMove`, `PM_CheckStuck`, `PM_CheckFalling` (view punch).
- Квары по умолчанию как на стоковом сервере: `sv_gravity 800, sv_accelerate 5, sv_airaccelerate 10,
  sv_friction 4, sv_stopspeed 75, edgefriction 2, stepsize 18, sv_maxvelocity 2000`, maxspeed ножа 250,
  `cl_forwardspeed/sidespeed 400`, `cl_movespeedkey 0.52`, `sensitivity 2.5`, `m_yaw 0.022`.
- Команды идут фиксированным тиком **100 Гц (msec 10 = fps_max 100)**, рендер интерполируется;
  view bob и сглаживание ступенек как в клиенте. FOV 90 в 4:3 (Hor+).
- F2/F3/F4 — отклонения «bhop-сервера» (автобхоп, без лимита скорости, без стамины). По умолчанию выкл —
  то есть ванильная CS 1.6: банихоп работает, но скорость на отрыве режется до 240 при превышении 300.

Карта рендерится из `maps/35hp_3.glb`; import-скрипт `scripts/map/map_post_import.gd` заменяет материалы
на unlit-шейдеры `shaders/lightmapped_*.gdshader` (texture × lightmap), а sky-браши — на `sky_brush.gdshader`.
Небо — `shaders/skybox_sky.gdshader` с `sky/desert_sky.webp` (та же развёртка, что в three.js). Рендерер — GL Compatibility.

### Тесты движения

```powershell
.tools\Godot_v4.7.2-stable_win64_console.exe --headless --path godot --script res://tests/pmove_test.gd
```

Проверяются на реальных хуллах карты: скорость бега 250 (и по диагонали), остановка трением,
высота прыжка 45, анти-pogo, стамина, упор в стену (хулл ровно у плоскости браша) и скольжение вдоль неё,
присед/встать/duck-jump, банихоп со стрейфами (ванильный кап → 240, без капа скорость растёт),
подъём по лестнице, телепорт; на каждом тике — что хулл не внутри твёрдого.

### Нож (viewmodel)

Оба ножа собираются из одного `models_src/v_knife.mdl` (геометрия, скелет и 8 анимаций общие, отличаются
только текстуры):

```powershell
python tools/mdl_to_glb.py models_src/v_knife.mdl godot/models/knife_black.glb
python tools/mdl_to_glb.py models_src/v_knife.mdl godot/models/knife.glb --skin models_src/frozen_
.tools\Godot_v4.7.2-stable_win64_console.exe --path godot --script res://tests/render_knives.gd -- <папка>
```

Углы костей MDL — (x, y, z) в радианах, собираются как в `AngleQuaternion` SDK: `Rz·Ry·Rx` (не как
`AngleMatrix` у энтити). Треугольники разворачиваются в CCW для glTF. Модель стоит ровно в точке
взгляда без доп. смещения/поворота/масштаба, как `v_` модели в GoldSrc. ЛКМ чередует
`midslash1`/`midslash2` (`slash1`/`slash2` в этом MDL — двухкадровые заглушки), ПКМ — `stab_miss`.
`render_knives.gd` снимает оба ножа в ключевых кадрах анимаций.

Дополнительные ножи загружаются из `godot/models/knives/catalog.json` (JSON-массив).
Поля: `id` = `cs16forge_<source_slug>`, `name`, `model`, `icon`, `desc`, `details`,
`source_slug`, `category` (`inspect` / `no_inspect`), `inspect_anim` (имя клипа / null),
`anims` (имена клипов для idle/draw/slash1/slash2/midslash1/midslash2/stab/stab_miss).
Два встроенных ножа остаются в SettingsManager; неизвестный сохранённый id сбрасывается на стандартный.
Физическая **F — осмотр ножа**: один запуск до возврата в idle; удержание и повторное нажатие
во время осмотра не перезапускают клип. ЛКМ/ПКМ прерывают осмотр, смена ножа — отменяет.
Во время draw/атаки, в меню, при вводе текста или свободной мыши F игнорируется.
Ножи с `inspect_anim: null` не имеют подменной анимации; это отмечено в списке выбора.
Каталог содержит 20 моделей CS16Forge: 10 с осмотром и 10 без; всего доступны 22 ножа.
Для осмотра используется реальная последовательность с индексом 8 исходного MDL
(`inspect`, `inspect_1` или `inspect_1_1`). Длительность GoldSrc-клипа —
`(frames - 1) / fps`, поскольку кадры пронумерованы от 0 до `frames - 1`.
Исходники и происхождение перечислены в `models_src/knives/manifest.json` (и `MANIFEST.md`). Сами MDL в Git не
хранятся: `python tools/fetch_cs16forge_knives.py` скачивает их и проверяет SHA-256, затем
`python tools/mdl_to_glb.py models_src/knives/<slug>/v_knife.mdl godot/models/knives/<slug>.glb`.
Страницы источника указывают автора «community» и не указывают лицензию.
Конвертер сохраняет все bodyparts с их default submodel и skin-family 0, а не только
первую часть рук. Additive chrome-поверхности отмечены суффиксом `__goldsrc_additive`;
CSKnife восстанавливает для них additive blending. Текстуры новых GLB импортируются
встроенными, без дублирующих PNG; миниатюры получены реальным GL Compatibility-рендером.
Для экспорта добавьте `models/knives/catalog.json` в фильтр non-resource files.

`python godot/tests/generate_knife_catalog.py` пересобирает каталог из manifest;
технические поля происхождения не выводятся в описании для игрока.
Проверки запускаются последовательно командой
`python godot/tests/run_knife_suite.py --godot "<путь к Godot console.exe>"`.
Флаг `--refresh-evidence` также переснимает ножи и игровой диалог настоящим renderer.
Runner и общий `settings_snapshot.gd` сохраняют точные байты пользовательского cfg
(либо его отсутствие) и восстанавливают их после теста, включая ошибку/assert.
Runner дополнительно защищает от аварийного завершения движка и timeout;
итоговый SHA-256 до/после сохраняется в `.orchestration/knife-evidence/followup/results.json`.

### Экспорт

`.bsp` — не ресурс Godot: в пресете экспорта добавьте `*.bsp` в «Filters to export non-resource files».

### Не перенесено

Плавание (на карте нет воды), урон от падения/`trigger_hurt`, оружие, звуки шагов, `func_conveyor`/basevelocity
от движущихся объектов — к передвижению на этой карте не относятся.
