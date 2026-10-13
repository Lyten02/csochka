# Удаление карт без GLB — 2026-10-13

После [исторического аудита 22 карт](../2026-10-13-maps/README.md) пользователь решил убрать из игрового каталога семь BSP без собственных GLB: `bhop_flyblocks`, `bhop_perfect2012`, `bhop_without_colors`, `kz_bhop`, `kzsk_xmas2010`, `kzy_fastbhop`, `kzy_junglerocks`. Удалены **только** соответствующие `godot/maps/<имя>.bsp`; исходные BSP в корне, текстуры и материалы аудита сохранены.

В `godot/maps/` осталось **15 пар BSP + GLB**: `35hp_3`, `bhop_blocks`, `bhop_dea`, `bhop_rabiga`, `bhop_run_1`, `bhop_squareblock`, `bhop_tk_speedrun`, `bhop_train`, `bhop_training_final`, `bhop_ytt_neon_light`, `bkz_goldbhop`, `bkz_noob`, `kzru_airway`, `kzsca_toonbhop`, `kzy_juhxbhop`. SHA-256 всех 30 оставшихся файлов совпадает с состоянием до удаления (контрольные списки `.orchestration/map-removal/hashes_before.json` и `hashes_after.json`).

Проверка настоящего каталога Godot: `test_map_removal.gd` — **PASS, 0 ошибок, 15 карт**; все BSP и GLB существуют, удалённых семи в списке нет. Синтетическое сохранение `kz_bhop` при загрузке переключается на `35hp_3` (`res://maps/35hp_3.bsp` и `res://maps/35hp_3.glb`); исправная сохранённая `bhop_dea` остаётся выбранной. При отсутствующем GLB тоже выбирается `35hp_3`. `test_menu_and_settings.gd` — **PASS, 0 ошибок**. Настоящий `user://cs16_settings.cfg` восстановлен побайтно: SHA-256 до и после `6ac8e03ef1601d0a71b0ac5116d35b63704d360b93a0417aecdc2520f4af6d72`.

[Скриншот меню выбора карт](map_selection.jpg) — реальный кадр Godot GL Compatibility, JPEG 1280×720, визуально проверен. На вкладке «Все карты» видны все 15 записей и ни одной из семи удалённых; диалог увеличен только в тестовом скрипте захвата для читаемости на экране с высоким DPI.

Ограничения: проверены файлы, каталог, загрузка настроек и отображение меню, но не прохождение трасс или полная загрузка каждой оставшейся карты. Исторические скриншоты и логи 22 карт отражают состояние **до** удаления и остаются неизменёнными.
