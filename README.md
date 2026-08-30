# Omarchy Dashboard

Полноэкранный, keyboard-first дашборд для плагинов Omarchy Shell. Dashboard
похож по поведению на scratchpad workspace, но остаётся одной Quickshell
surface: поэтому страницы плагинов можно размещать в общей сетке, менять их
размер и переключать с клавиатуры.

## Возможности

- свободная пиксельная сетка с настраиваемым шагом 5–80 px, drag-and-drop,
  resize и запретом пересечений;
- декоративные элементы поверх сетки: горизонтальные/вертикальные разделители
  между точками и текстовые подписи с автоматическим масштабированием шрифта;
- несколько именованных Spaces с компактным переключателем и inline rename;
- режимы `browse`, `interact` и `edit` с предсказуемым владением фокусом;
- открытие на мониторе, с которого вызван launcher, либо на focused monitor;
- каталог установленных системных и пользовательских плагинов;
- универсальные плитки: embedded page, компактный `dashboardWidget`,
  service-control, Dashboard popout или native/information fallback;
- два surface-режима: классический `Framed` и полноэкранный `Glass`;
- изолированная wallpaper-подложка без окон: текущие обои берутся из
  `omarchy.background`, а эффект следует live-настройкам blur Hyprland;
- тема, размеры, отступы и скругления из текущего Omarchy Shell; скругления
  обновляются после Hyprland config reload без перезапуска shell;
- ограниченное по размеру и проверяемое состояние в XDG state directory.

## Установка

Из Git-репозитория:

```bash
omarchy plugin add https://github.com/grigoryshulga/omarchy-dashboard.git --enable
```

Если launcher не был добавлен автоматически:

```bash
omarchy plugin enable gshulga.dashboard --section left
```

Для локальной разработки скопируйте содержимое репозитория в
`~/.config/omarchy/plugins/gshulga.dashboard`, затем выполните:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/gshulga.dashboard
omarchy plugin enable gshulga.dashboard --section left
omarchy restart shell
```

Dashboard можно открыть кнопкой в bar или командой:

```bash
omarchy-shell shell toggle gshulga.dashboard
```

Пример пользовательского Hyprland binding:

```ini
bindd = SUPER, D, Dashboard, exec, omarchy-shell shell toggle gshulga.dashboard
```

## Управление

| Клавиши | Действие |
| --- | --- |
| `← ↑ ↓ →` | Выбрать ближайшую плитку по геометрии |
| `Ctrl+Tab` / `Ctrl+Shift+Tab` | Следующая / предыдущая плитка |
| `Enter` | Передать фокус выбранному плагину (`interact`) |
| `Esc` | Выйти из `interact`, затем из `edit`, затем закрыть Dashboard |
| `Page Up` / `Page Down` | Предыдущее / следующее Space |
| `Alt+1` … `Alt+9` | Перейти к Space по номеру |
| `Alt++` | Открыть каталог плагинов в `edit` |
| `Alt+E` | Включить или выключить `edit` |
| `Alt+V` | Переключить `Framed` / `Glass` в `edit` |
| `Alt+стрелки` | Переместить выбранную плитку или графический элемент в `edit` |
| `Ctrl+Alt+стрелки` | Изменить размер выбранной плитки или графического элемента в `edit` |
| `стрелки` / `Ctrl+стрелки` | Переместить / изменить размер силуэта новой плитки |
| `Enter` / `Esc` | Разместить / отменить новую плитку |
| `Alt+C` / `Alt+R` | Создать / переименовать Space |
| `Alt+X` | Удалить текущее Space с подтверждением (последнее удалить нельзя) |
| `Delete` | Удалить выбранную плитку или графический элемент |
| `?` | Показать встроенную шпаргалку |

`Alt+1` … `Alt+9` зарегистрированы как оконные shortcuts Dashboard, поэтому
переключают Space даже тогда, когда клавиатурный фокус находится внутри
встроенного плагина. Во время rename, каталога и popout они приостанавливаются.

В `edit` плитка перемещается перетаскиванием за любую её область и изменяет
размер за маркер в правом нижнем углу. Собственной шапки у Tile нет, а между
рамкой и обычной Plugin Page остаётся theme-aware внутренний отступ. Панели,
адаптированные из отдельного окна наподобие Omaland, размещаются от края до
края: их типовая оконная `BorderSurface` разворачивается до границ плитки и не
получает второй внешний отступ. Шаг сетки настраивается блоком `Grid step` в
правом нижнем углу холста от 5 до 80 px и сохраняется в layout.
Он одновременно задаёт расстояние между точками, keyboard move/resize, snap
при drag/resize и позиции автоматического размещения. Если существующая плитка
не кратна новому шагу, первая keyboard-операция выравнивает изменяемую грань
по ближайшей линии в направлении действия; mouse resize снапит итоговый размер,
а не сохраняет старый остаток. При перетаскивании плитки, силуэта новой плитки
или текстового блока возле центра холста включается магнитное выравнивание:
полупрозрачные акцентные направляющие отдельно показывают совпадение по
вертикальной и горизонтальной центральным осям. Сами оси проходят по ближайшим
линиям активной сетки и не уводят начало объекта с её шага; несовместимая с
текущим размером объекта ось не активируется. Двойной клик по
содержимому переводит плитку в `interact`; `Escape` всегда возвращает в
`browse`, не закрывая внутреннюю панель.

Кнопка `Draw Divider` включает короткий режим рисования: нужно протянуть линию
между двумя точками сетки, после чего Dashboard зафиксирует доминирующую ось и
сохранит строго горизонтальный или вертикальный разделитель. В `edit` линию
можно перемещать целиком, а её круглые концы — растягивать независимо. `Add Text`
создаёт текстовую подпись; размер шрифта автоматически подстраивается под рамку,
которую можно перетаскивать и растягивать. Двойной клик по подписи повторно
открывает редактор текста. Декоративные элементы не участвуют в запрете
пересечений и поэтому могут проходить поверх плиток и друг друга.

Добавление из каталога проходит через короткий режим предварительного
размещения: Dashboard сначала показывает на холсте силуэт, автоматически
подбирая свободный размер между `preferred` и `min` плагина. Силуэт можно
переместить за любую область и уменьшить маркером до подтверждения. Зелёный
контур означает допустимое место, красный — пересечение; в этом режиме
существующие плитки по-прежнему можно двигать, поэтому место разрешается
освободить без отмены добавления. `Enter` или кнопка `Place` сохраняют плитку,
`Escape` отменяет черновик. При перемещении и resize уже размещённой плитки её
живое содержимое остаётся приглушённым на исходном месте, а за указателем
движется такой же лёгкий силуэт.

Холст использует единый системный `panelGap`: такой же отступ отделяет его от
шапки, боковых и нижней границ. Геометрия одинакова в `Framed` и `Glass`,
обновляется вместе с системным spacing и не уменьшает полезную область плиток.
Внутри доступной области холст центрируется по обеим осям и, когда layout это
позволяет, получает размеры, кратные текущему шагу. Точки начинаются на верхней
и левой границах и отдельным рядом отмечают правую и нижнюю: move/resize
используют ровно этот видимый прямоугольник как bounds.

В центре шапки находится название активного Space в акцентном цвете; остальные
индикаторы располагаются вокруг него круглыми точками. В `edit` индикатор можно
перетащить, чтобы изменить порядок Spaces; отдельная кнопка
удаления текущего Space находится слева от карусели и всегда запрашивает
подтверждение. Двойной клик по названию включает редактирование имени прямо в
шапке, без диалога.

## Surface и системный blur

Оформление выбирается в настройке bar widget `Surface mode`:

- `Framed` сохраняет непрозрачную карточку с системными отступами и радиусом;
- `Glass` рисует Dashboard от края до края, не изменяя геометрию окон.

В `edit` оба варианта доступны отдельной группой `Appearance` в шапке: кнопка
окна включает `Framed`, а кнопка разворота — `Glass`. Активный вариант
подсвечивается; `Alt+V` переключает их с клавиатуры.

Для `Glass` Dashboard берёт путь текущих обоев непосредственно у
живого сервиса `omarchy.background` и рисует их внутри собственной поверхности.
Поэтому перемещённые окна не попадают в backdrop даже во время анимации.
Поддерживаемые параметры `enabled`, `size`, `passes`, `brightness`, `contrast`
и `vibrancy` читаются из текущего `decoration.blur` Hyprland и обновляются после
`configreloaded`; они переводятся в ограниченный `MultiEffect` Qt, поскольку
compositor blur не умеет исключать окна без внешней layer rule. Цвет и
прозрачность затемнения берутся из live-токена `Color.menu.scrim` темы Omarchy.
Опцию `Blur wallpaper` можно отключить независимо от затемнения.

## Как встраиваются плагины

Dashboard выбирает первый доступный вариант:

1. встроенный Dashboard-side control для известных не-визуальных сервисов;
2. `entryPoints.dashboardPage` или совместимая `sidePanelPage`;
3. `entryPoints.dashboardWidget` — компактный безопасный Widget;
4. локальная адаптация стандартного `KeyboardPanel`;
5. консервативная адаптация `panel`/`overlay` с одной вложенной `PanelWindow`;
6. Launcher, открывающий native surface или независимый Dashboard popout;
7. информационная плитка, если безопасного действия нет.

Dashboard никогда не записывает изменения в каталог чужого плагина. Для
адаптации он создаёт fingerprinted копию в XDG cache. Встроенные управляющие
плитки сейчас доступны для Stay Awake (`omarchy.idle`), Night Light и Do Not
Disturb; они обращаются к тем же публичным service-методам, что и штатные
индикаторы Omarchy.

Для `bar-widget` launcher сначала использует живой экземпляр в bar. Если
плагин не добавлен в bar, но его QML удалось безопасно адаптировать, интерфейс
открывается в popout внутри Dashboard. Поэтому Bluetooth может работать как
кнопка без отдельной настройки bar.

Launcher выглядит как цельная плитка-кнопка: иконка, название и никаких
служебных описаний. Обычный клик сразу запускает действие. Иконка выбирается из
явного manifest-поля, живого bar-widget, conventional `icon.svg`/`icon.png`,
литерального `icon`/`heroGlyph` в entry point или семантического Nerd Font
fallback. Discovery только читает ограниченный объём файлов и никогда не
импортирует и не исполняет чужой QML.

В `edit` маленькая кнопка в левом верхнем углу плитки циклически переключает
автоматический выбор, `Embedded`, `Widget` и `Launcher`, оставляя только реально
доступные варианты. Произвольный `barWidget` не загружается как компактный
Widget автоматически: он может создавать собственные Wayland surfaces.
Dashboard либо адаптирует его стандартную панель, либо честно оставляет
native/information fallback.

Один plugin id может занимать только одну плитку во всём Dashboard. Это
исключает конкурирующие IPC handlers, таймеры и singleton service state.
Подробный контракт для авторов находится в
[`docs/PLUGIN_CONTRACT.md`](docs/PLUGIN_CONTRACT.md).

## Состояние и кэш

- layout: `$XDG_STATE_HOME/omarchy/gshulga.dashboard.json` или
  `~/.local/state/omarchy/gshulga.dashboard.json`;
- адаптированные копии: `$XDG_CACHE_HOME/omarchy-dashboard` или
  `~/.cache/omarchy-dashboard`.

Исходные каталоги плагинов никогда не изменяются. Кэш адресуется fingerprint
содержимого, создаётся через staging directory и проверяется перед повторным
использованием. Служебные каталоги систем контроля версий (`.git`, `.hg`,
`.svn`) не копируются в runtime-кэш. State ограничен 256 KiB, читается без
следования symlink и сохраняется атомарно.

## IPC и диагностика

`status` доступен напрямую:

```bash
omarchy-shell shell call gshulga.dashboard status x
```

Сложные операции передаются одним JSON-аргументом через `execute`:

```bash
omarchy-shell shell call gshulga.dashboard execute '{"type":"getState"}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"addSpace","name":"Work"}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"addPlugin","pluginId":"omarchy.network"}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"setTileEmbedding","embedding":"launcher"}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"setMode","mode":"edit"}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"setGridSpacing","value":20}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"addText","text":"System status"}'
omarchy-shell shell call gshulga.dashboard execute '{"type":"addDivider","x1":0,"y1":100,"x2":600,"y2":100}'
```

Поддерживаются `status`, `getState`, `listPlugins`, `open`, `close`, `toggle`,
`selectSpace`, `nextSpace`, `addSpace`, `renameSpace`, `removeSpace`,
`addPlugin`, `selectTile`, `removeTile`, `moveTile`, `resizeTile`, `placeTile`,
`activateTile`, `setTileEmbedding`, `addText`, `updateText`, `addDivider`,
`placeElement`, `removeElement`, `setGridSpacing`, `reorderSpace` и `setMode`.
Все layout-команды проходят ту же валидацию, что
и UI.

## Разработка и проверки

```bash
bash tests/all.sh
```

При запущенных Hyprland и Omarchy Shell live-обновление системного радиуса
проверяется отдельно: `bash tests/live-corner-radius.sh`. Скрипт временно
меняет effective rounding через тот же Lua `eval`, проверяет реакцию на
`configreloaded` и восстанавливает исходное значение.

Набор включает QML unit tests модели/сетки/навигации, Python-тесты безопасного
адаптера и state reader, adapter smoke test и проверку manifest Omarchy.
`Dashboard.qml` отвечает только за сессию и команды интерфейса;
`DashboardStore.qml` скрывает persistence, а `PluginRuntime.qml` — discovery,
инъекцию lifecycle и адаптацию страниц плагинов.
Архитектурные решения и этапы реализации зафиксированы в
[`MASTER_PLAN.md`](MASTER_PLAN.md).
