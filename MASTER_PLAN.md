# Omarchy Dashboard — мастер-план реализации

Статус: реализовано; актуализировано для `v1.6.6`  
Дата снимка окружения: 2026-08-28  
Проверенное окружение: Omarchy `4.0.1-1`, Quickshell `0.3.1`

План ниже сохранён как архитектурная запись. Реализация прошла все этапы;
после UX-проверки исходная крупная сетка 12×8 была заменена свободной
пиксельной сеткой с настраиваемым шагом 5–80 px. Legacy migration намеренно удалена; текущая
схема v3 принимает только pixel-state v2/v3.

## 1. Резюме решения

Dashboard стоит реализовать как полноэкранный layer-shell overlay внутри уже
работающего `omarchy-shell`, а не как настоящее special workspace Hyprland.
Пользовательский опыт будет похож на scratchpad workspace, но технически это
должна быть одна поверхность Quickshell: только так QML-страницы разных
плагинов можно разместить в общей сетке, менять их размеры и централизованно
управлять клавиатурным фокусом.

Рекомендуемая форма Omarchy-плагина:

- `kinds: ["panel", "bar-widget"]`;
- `Dashboard.qml` — единственный долгоживущий host сессии и окон;
- `BarWidget.qml` — тонкая кнопка-launcher на каждом мониторе;
- `keepLoaded: true` — host остаётся живым между открытиями;
- один `PanelWindow`-вариант на монитор, но в каждый момент виден только вариант
  целевого монитора;
- layout хранится в отдельном XDG state-файле, а не целиком в `shell.json`;
- плагины встраиваются через явный `dashboardPage`, безопасную адаптацию
  стандартного `KeyboardPanel` или native fallback.

Ключевое отличие от прямого форка side panel: поведение нужно разнести по
глубоким модулям. Сетка, состояние, навигация и lifecycle встраиваемых страниц
не должны снова собраться в один QML-файл на несколько тысяч строк.

## 2. Что было изучено

### Установленный Omarchy Shell

Изучены:

- `/usr/share/omarchy/shell/shell.qml`;
- `/usr/share/omarchy/shell/services/PluginRegistry.qml`;
- `/usr/share/omarchy/shell/services/BarWidgetRegistry.qml`;
- `/usr/share/omarchy/shell/plugins/bar/Bar.qml`;
- `/usr/share/omarchy/shell/Ui/KeyboardPanel.qml`;
- системные manifests и характерные panel/overlay/service-плагины;
- пользовательские плагины из `~/.config/omarchy/plugins`;
- текущий `~/.config/omarchy/shell.json` и способ вызова панелей из Hyprland.

На машине обнаружено 54 плагина: 37 системных и 17 пользовательских.
Системные и пользовательские плагины используют один manifest-контракт;
различаются только каталогом и флагом `__isFirstParty` в registry.

### Соседний `omarchy-side-panel`

Изучены manifest, runtime, model, persistence, keyboard navigation, plugin
catalog, QML lifecycle-тесты и Python-адаптер. Текущий набор проверок side panel
успешен: 33 Python-теста, adapter smoke test и QML model test.

Side panel уже доказал работоспособность следующих решений:

- получение `pluginRegistry`, shell, bar и service из текущего Omarchy host;
- явный entry point `sidePanelPage`;
- преобразование обычного `KeyboardPanel` в обычный вложенный `Item`;
- fingerprinted cache без изменения установленного плагина;
- отключение дублирующихся IPC handlers и bar buttons в адаптированной копии;
- отложенная загрузка и прогрев панелей;
- focus prime `Exclusive -> OnDemand` для layer-shell surface;
- атомарное и ограниченное по размеру XDG-state;
- versioned normalization, recovery и защита от повреждённого state;
- управление страницами, размерами, drag-and-drop и клавиатурой.

Главный долг для переиспользования: `SidePanel.qml` сейчас содержит около 3 000
строк и объединяет слишком много поведений. Копировать его целиком не следует.

## 3. Как устроены Omarchy-плагины

### Discovery и загрузка

`PluginRegistry` сканирует системный и пользовательский каталоги, проверяет
`manifest.json`, добавляет к manifest `__sourceDir` и `__isFirstParty` и
разрешает entry points только внутри каталога плагина.

Основные kinds:

| Kind | Как живёт |
| --- | --- |
| `bar-widget` | Component регистрируется в `BarWidgetRegistry`, затем bar создаёт экземпляр на каждом мониторе. |
| `panel`, `overlay`, `menu` | Shell создаёт один Loader; по умолчанию грузит по summon, с `keepLoaded` держит постоянно. |
| `service` | Один невидимый экземпляр в shell, доступный через `shell.serviceFor(id)`. |
| `bar` | Полная замена штатного bar. |

Плагин может объявлять несколько kinds. Для пары `panel + bar-widget` shell
отдаёт lifecycle панели общему panel Loader, а bar-widget остаётся launcher.
Это как раз нужная модель для Dashboard.

### Enabled-state и settings

- Сторонний плагин считается enabled, если его id встречается в bar layout,
  `bar.id` или `plugins[]` в `shell.json`.
- First-party non-bar плагины включены по умолчанию, пока не попали в
  `disabledPlugins[]`.
- Настройки лежат прямо в соответствующей записи `shell.json`.
- Один bar-layout entry создаёт живой widget на каждом мониторе.
- Hotkey для bar-widget панели маршрутизируется в экземпляр на focused monitor.
- Panel/overlay/menu entry point получает `shell`, `manifest`, registries и при
  наличии одноимённый service.

Важное следствие: если Dashboard добавляет отключённый сторонний bar-widget в
сетку, его можно включить записью в `plugins[]`, не добавляя лишнюю кнопку в
bar. При удалении tile Dashboard не должен автоматически выключать плагин:
enabled-state может быть нужен другим поверхностям.

### Ограничение Wayland

Уже созданный `PanelWindow`, `PopupWindow` или overlay нельзя «пересадить» внутрь
другой Wayland-поверхности. Dashboard способен встроить только обычное QML-дерево
`Item`/Control. Поэтому native window — это fallback, а не полноценная tile.

## 4. Целевая модель предметной области

Использовать эти термины последовательно:

- **Dashboard** — весь полноэкранный host.
- **Space** — именованная страница Dashboard. Не Hyprland workspace.
- **Grid** — логическая координатная система Space.
- **Tile** — размещение одного Plugin Page в Grid.
- **Plugin Page** — встраиваемое QML-содержимое плагина.
- **Host mode** — один из `browse`, `interact`, `edit`.
- **Native fallback** — запуск обычной панели плагина вне Grid.

Для MVP один plugin id может присутствовать только в одной Tile во всём
Dashboard. Это повторяет безопасную модель side panel и не создаёт несколько
копий таймеров, моделей и IPC одного плагина. У Tile всё равно должен быть
собственный стабильный `tileId`, чтобы позднее разрешить несколько views без
миграции схемы.

## 5. Целевая архитектура

```text
Omarchy shell
├── PluginRegistry / services / theme
├── BarWidget.qml × monitor          тонкие launchers
└── Dashboard.qml × 1                singleton panel host
    ├── DashboardStore               state + normalization + persistence
    ├── DashboardSession             open/close + target monitor + modes
    ├── DashboardSurface × monitor   полноэкранный framed/glass overlay
    │   ├── SpaceViewport
    │   ├── GridCanvas
    │   └── TileHost × visible tile
    ├── PluginCatalog
    └── PluginRuntime
        ├── ExplicitPageAdapter
        ├── StandardPanelAdapter
        └── NativeFallbackAdapter
```

### Модули и их интерфейсы

| Module | Малый внешний Interface | Скрытая Implementation |
| --- | --- | --- |
| `DashboardStore` | `document`, `commit(command)`, `flush()` | normalization, limits, revision, debounce, safe read, atomic state writes |
| `GridEngine.js` | `place`, `move`, `resize`, `canPlace`, `rectForTile` | bounds, collision checks, snapping, deterministic commands |
| `SpatialNavigation.js` | `next(tileId, direction, tiles)` | поиск ближайшего соседа по геометрии и tie-break rules |
| `PluginPresentation.js` | `capabilities(manifest)`, `resolve(manifest, preference, sources)` | безопасный выбор Embedded/Widget/Launcher и fallback policy |
| `DashboardSession` | `open(targetScreen)`, `close()`, `dispatch(action)` | modes, focus ownership, selected space/tile, Escape hierarchy |
| `PluginRuntime` | `availablePlugins`, `descriptor`, `sizeHints`, `inject/deactivate/focus`, `requestAdaptation` | registry resolution, services/settings injection, adapter selection, errors, cache |
| `TileHost` | `tile`, `runtime`, lifecycle signals | Loader, frame, focus handoff, clipping, placeholder/error/fallback UI |
| `DashboardSurface` | `screen`, `opened`, `session`, `store` | PanelWindow, layer-shell focus, scrim, edit chrome, pointer input |

`GridEngine`, `SpatialNavigation` и schema normalization должны быть чистыми JS
модулями. Их Interface одновременно становится основной test surface.

### Почему singleton panel host лучше side-panel-подхода

Side panel создаётся внутри bar widget, поэтому на нескольких мониторах
существует несколько независимых host-экземпляров. Для Dashboard это породило
бы конкурирующие записи layout и несогласованный current Space.

`panel + bar-widget` даёт:

- один store и один session;
- стабильный state между мониторами;
- bar button на каждом экране;
- click может передать `screen.name` в payload;
- hotkey без payload выбирает `Hyprland.focusedMonitor`;
- только одна интерактивная Dashboard surface в каждый момент.

## 6. Surface и lifecycle

`Dashboard.qml` держит `Variants { model: Quickshell.screens }`. Каждый delegate
создаёт полноэкранный `PanelWindow`, но visible только окно с именем
`session.activeScreenName`.

Полноэкранный overlay намеренно использует `ExclusionMode.Ignore` и не
резервирует work area: открытие Dashboard не меняет геометрию окон. `Glass`
отображает текущие обои из `omarchy.background` внутри overlay и переводит
live-параметры Hyprland blur в Qt `MultiEffect`. Это намеренно не использует
compositor backdrop: окна не должны быть видны сквозь Dashboard, а плагин не
должен требовать внешней layer rule.

Рекомендуемые layer-shell свойства:

- `WlrLayer.Overlay`;
- `ExclusionMode.Ignore`;
- anchors на четыре края;
- прозрачный window color и отдельный theme-aware scrim;
- полный input mask только пока Dashboard открыт;
- короткий focus prime `Exclusive`, затем `OnDemand`;
- немедленный сброс keyboard focus при logical close, даже если fade-out ещё
  продолжается.

Lifecycle:

1. Launcher вызывает `shell.summon(id, {screenName})`.
2. `open(payload)` выбирает экран, Space и Tile, затем показывает нужный surface.
3. Store загружает visible Space; PluginRuntime активирует его tiles.
4. После закрытия tiles получают deactivate, Loaders освобождаются по cache
   policy, surface теряет keyboard focus.
5. Если монитор исчез, session переносится на текущий focused monitor или
   закрывается, если экранов не осталось.

## 7. Grid

### Рекомендуемая модель MVP

- свободная сетка в логических QML-пикселях с настраиваемым шагом `5–80 px`;
- координаты и размеры Tile — целые кратные пяти: `x`, `y`, `w`, `h`;
- Grid использует фактические размеры доступного canvas;
- gap и outer padding берутся из `Style`;
- Tile не может выйти за bounds или пересечь другую Tile;
- invalid drop/resize не меняет model и визуально показывает причину;
- добавление Tile сначала создаёт несохранённый placement draft: GridEngine
  ищет наименее уменьшенный свободный rect между preferred и min, а UI
  подтверждает его только после move/resize preview;
- все pointer и keyboard операции проходят через одни команды GridEngine.

Такой state переносим между разрешениями и мониторами. Пиксельные координаты
сделали бы сохранённую раскладку хрупкой.

Начать следует с запрета overlap, а не с автоматического «расталкивания» tiles.
Это предсказуемее и даёт простой общий закон для drag и keyboard. Auto-pack и
collision pushing можно добавить позднее как отдельную placement policy.

### Размеры Plugin Page

Manifest может необязательно публиковать hints:

```json
"entryPoints": {
  "dashboardPage": "DashboardPage.qml"
},
"dashboard": {
  "minWidth": 240,
  "minHeight": 160,
  "preferredWidth": 420,
  "preferredHeight": 300
}
```

Текущий validator принимает дополнительные entry point и metadata, если путь
безопасен и существует. Dashboard сам валидирует hints и применяет bounds.

## 8. Контракт Plugin Page

Предпочтительный entry point:

```json
"entryPoints": {
  "dashboardPage": "DashboardPage.qml"
}
```

`DashboardPage.qml` обязан быть обычным `Item` или Control, заполнять parent,
не создавать собственный window и нормально реагировать на изменение размера.

Host передаёт единый context:

```qml
function initializeDashboard(context) {
  // context.dashboard
  // context.tile
  // context.pluginId
  // context.settings
  // context.service
  // context.shell
}
```

Необязательный lifecycle:

- `dashboardActivate(context)`;
- `dashboardDeactivate(reason)`;
- `dashboardFocus()`;
- `dashboardBlur()`.

Для простых страниц сохраняется property injection, если writable properties
существуют. Метод `initializeDashboard` предпочтительнее: это более маленький и
явный Interface.

### Лестница совместимости

1. `dashboardPage` — основной и полностью поддерживаемый путь.
2. Временно совместимый обычный `sidePanelPage`, только если он не зависит от
   геометрии side panel; ошибки изолируются на уровне Tile.
3. Адаптированный стандартный `KeyboardPanel`.
4. Native fallback: Tile показывает описание и кнопку открытия обычной панели.

На текущей машине ни один установленный плагин ещё не объявляет явный
`sidePanelPage` или `dashboardPage`; текущий side panel работает благодаря
адаптации стандартных панелей. Поэтому пункт 3 нужен уже в MVP/первой beta, но
пункт 1 должен быть публичным долгосрочным контрактом.

### Переиспользование адаптера side panel

Не связывать установку Dashboard с соседним git-репозиторием: Omarchy-плагин
должен быть самодостаточен. Для первой версии нужно перенести адаптер с
сохранением лицензии и тестов, затем обобщить имена:

- `SidePanelHost` -> нейтральный `EmbeddedPanelHost`;
- side-panel context -> host context с capabilities;
- сохранить fingerprinted immutable cache;
- сохранить запрет symlink/special files/вложенных mapped windows;
- сохранить отключение copied IPC handlers и copied bar buttons;
- ограничить число файлов, размер дерева, глубину и время процесса.

После стабилизации имеет смысл предложить нейтральный embedded-page контракт в
Omarchy core, чтобы side panel и Dashboard перестали каждый владеть source
rewriter. До появления реального второго core adapter не создавать отдельный
shared package: self-contained vendor здесь практичнее гипотетической seam.

## 9. State и persistence

Основной state-файл:

`$XDG_STATE_HOME/omarchy/gshulga.dashboard.json`

`shell.json` хранит только обычные настройки launcher/appearance, но не всю
сетку. Это избавляет от больших bar entries и shell-config churn во время drag.

Предлагаемая schema:

```json
{
  "version": 3,
  "revision": 1,
  "gridSpacing": 10,
  "activeSpaceId": "space-main",
  "spaces": [
    {
      "id": "space-main",
      "name": "Main",
      "tiles": [
        {
          "id": "tile-audio",
          "pluginId": "omarchy.audio",
          "x": 0,
          "y": 0,
          "w": 360,
          "h": 260,
          "embedding": "auto"
        }
      ]
    }
  ]
}
```

Правила:

- stable ids для Space и Tile;
- schema version и отказ от legacy cell-state;
- bounds на число Spaces, Tiles, длину names и размер файла;
- normalization удаляет неизвестные поля и чинит допустимые значения;
- повреждённый state не перезаписывается пустым до успешной загрузки fallback;
- debounce во время drag/resize, обязательный flush на commit/close;
- atomic write;
- state reader запускается с чистым environment, byte limit и timeout;
- разумные стартовые лимиты: 12 Spaces, 24 Tiles на Space, 64 Tiles всего,
  256 KiB state. После profiling их можно скорректировать.

## 10. Клавиатурная модель

Нужны три явных режима, иначе host и embedded plugin будут спорить за keys.

### Browse

- `Arrow keys` — выбрать геометрически ближайшую Tile;
- `Ctrl+Tab` / `Ctrl+Shift+Tab` — следующая/предыдущая Tile в стабильном порядке;
- `Enter` — перейти в Interact;
- `Alt+1…9` — открыть Space по номеру;
- `Alt+Left/Right` или `PageUp/PageDown` — соседний Space;
- `Alt+E` — Edit;
- `Escape` — закрыть Dashboard.

### Interact

- keys получает Plugin Page;
- host перехватывает `Escape` с `Keys.BeforeItem` и возвращается в Browse;
- второй `Escape` уже в Browse закрывает Dashboard;
- `Ctrl+Tab` остаётся host-level переходом между Tiles.

### Edit

- arrows — выбирать Tile пространственно;
- `Alt+Arrow` — перемещать Tile на один текущий шаг сетки;
- `Alt+Ctrl+Arrow` — менять размер по соответствующей оси;
- `Delete` — удалить Tile;
- `Alt++` — открыть catalog;
- `Alt+C` — создать Space;
- `Alt+R` — переименовать Space;
- `Alt+X` — удалить Space;
- `Enter` — закончить Edit для выбранной Tile;
- `Escape` — отменить активный drag/resize/dialog, затем выйти из Edit.

Spatial navigation выбирает кандидатов в нужной полуплоскости и сортирует по
расстоянию вдоль направления, затем по поперечному смещению, затем по stable
tile order. Этот алгоритм должен быть чистым и полностью покрытым тестами.

## 11. Loading и производительность

Первый вариант policy:

- загружать только tiles текущего Space;
- текущий Space — сразу, один соседний Space — idle prewarm;
- держать максимум два загруженных Space;
- при закрытии Dashboard выгружать Plugin Pages, но не shell services;
- adapted pages создавать последовательно, с timeout;
- не создавать второй service/model, если доступен `shell.serviceFor(pluginId)`;
- логировать compile/init/activate errors отдельно на каждую Tile;
- hot reload registry инвалидирует descriptors и cache URLs, но не layout state.

После измерений можно сделать policy настраиваемой. Не прогревать все Spaces по
умолчанию: dashboard потенциально существенно тяжелее side panel.

## 12. Выполненные этапы реализации

### Этап 0 — решения и scaffold

Результат:

- manifest `panel + bar-widget`, `keepLoaded`;
- каталог модулей и test harness;
- ADR о layer-shell вместо special workspace;
- ADR о настраиваемом шаге пиксельной сетки и no-overlap policy;
- ADR о XDG state как единственном источнике layout;
- fixture Plugin Pages для normal/error/slow/focus cases.

Критерий: `omarchy plugin validate .` и пустой test harness проходят.

### Этап 1 — вертикальный slice host

Сделать singleton `Dashboard.qml`, bar launcher, IPC open/close/toggle, выбор
focused/clicked monitor, fullscreen surface, focus prime и одну статическую
fixture Tile.

Критерий: hotkey открывает Dashboard только на focused monitor; bar button — на
своём monitor; повторный toggle закрывает; Escape всегда возвращает фокус
предыдущему приложению.

### Этап 2 — Store и Grid Engine

Реализовать schema, normalization, state reader/writer, spaces, pure grid
commands, drag, resize, collision feedback и edit chrome.

Критерий: раскладка переживает restart/hot reload, не ломается на другом
разрешении, invalid state и invalid moves безопасно отклоняются.

### Этап 3 — клавиатурная навигация

Реализовать modes, spatial focus, Space navigation, keyboard move/resize и
Escape hierarchy.

Критерий: весь Dashboard можно создать, заполнить и перестроить без мыши;
embedded fixture получает keys только в Interact.

### Этап 4 — Plugin Runtime и явный контракт

Реализовать catalog, manifest descriptors, `dashboardPage`, context injection,
lifecycle, service/settings resolution, per-Tile errors и native fallback.

Критерий: explicit fixture и минимум один реальный service-backed plugin
работают без дублирования service/IPC.

### Этап 5 — автоматическая совместимость

Перенести и обобщить проверенный adapter side panel, добавить cache policy и
smoke tests на характерных first-party и user plugins.

Критерий: Audio, Network/Bluetooth и два пользовательских стандартных
`KeyboardPanel` работают в Tiles; unsupported window plugins получают понятный
native fallback.

### Этап 6 — multi-monitor, hot reload и performance hardening

Добавить monitor removal/remap, bounded LRU/prewarm, registry reload recovery,
timeouts, resource cleanup, stress tests и диагностику.

Критерий: 50 циклов open/close, переключение Spaces и plugin rescans не создают
дубликаты surfaces, IPC handlers или services; state остаётся консистентным.

### Этап 7 — UX и публикация

Theme polish, settings, empty states, shortcut help, README для пользователей и
авторов плагинов, screenshots, install/remove docs и release checklist.

Критерий: чистая установка через `omarchy plugin add ... --enable`, полный test
suite и понятная compatibility matrix.

## 13. Стратегия тестирования

### Pure QML/JS tests

- state normalization и rejection устаревшей cell-schema;
- limits и oversized input;
- grid bounds/collisions/move/resize;
- stable ids и uniqueness;
- spatial navigation во всех направлениях;
- command undo/cancel semantics;
- selection после удаления Space/Tile.

### QML lifecycle tests

- open/close/focus prime;
- Browse -> Interact -> Browse -> close;
- context/property injection;
- activate/deactivate вызываются ровно один раз;
- Loader error одной Tile не закрывает Dashboard;
- Space switch и cache eviction;
- registry rescan не оставляет stale QML objects;
- monitor switch/removal.

### Adapter tests

Перенести весь security regression suite side panel: symlinks, special files,
tree budgets, unsafe imports/paths, ambiguous hosts, nested windows, cache
repair, fingerprint invalidation, timeout/kill.

### Integration smoke

```bash
omarchy plugin validate .
python3 -m unittest discover -s tests -p 'test_*.py'
bash tests/adapter-smoke.sh
bash tests/qml-model.sh
```

Добавить Quickshell-hosted harness для lifecycle и отдельный ручной checklist
для Wayland focus, нескольких мониторов, pointer constraints и visual clipping.

## 14. Основные риски и ответы

| Риск | Ответ |
| --- | --- |
| Чужой QML выполняется внутри `omarchy-shell` и может сломать процесс | Явно документировать trust model; compile/init errors локализовать в Tile; не обещать sandbox, которого нет. |
| Нельзя встроить готовый Wayland window | Только ordinary Item; строгий adapter; native fallback. |
| Дубли IPC/service/model у адаптированной панели | Отключать copied IPC/buttons; inject существующий shell service; explicit page — предпочтительный путь. |
| Host и plugin спорят за keyboard focus | Три host modes, `Keys.BeforeItem`, единая Escape hierarchy. |
| Несколько мониторов пишут один state | Singleton panel host; launchers не владеют store. |
| Плагин предполагает фиксированный размер | Manifest size hints, clipping, minimum tile constraints, compatibility warning. |
| Большое число tiles нагружает shell | Visible-space loading, bounded prewarm/LRU, sequential adaptation, hard limits. |
| Hot reload инвалидирует QML references | Epoch в Loader URL, centralized teardown, registry revision, state отдельно от runtime objects. |
| `shell.json` меняется одновременно с layout | Layout хранится отдельно; shell mutation только при явном enable/settings action. |

## 15. Что сознательно не входит в первую версию

- настоящий Hyprland special workspace;
- overlap плиток (свободные пиксельные координаты с настраиваемым шагом реализованы);
- auto-packing/collision pushing;
- несколько экземпляров одного plugin id;
- sandbox для стороннего QML;
- синхронизация layout между машинами;
- плавающие/отстыковываемые Tiles;
- публичный marketplace контракт до стабилизации локального `dashboardPage`.

## 16. Definition of Done первой публичной версии

- установка и удаление штатными `omarchy plugin` commands;
- open/close/toggle из bar и hotkey на правильном мониторе;
- минимум 3 именованных Space;
- mouse и keyboard placement/resize;
- полноценная Browse/Interact/Edit навигация и точечная edit-подложка;
- сохранение и восстановление layout;
- explicit `dashboardPage` contract с документацией;
- проверенная адаптация стандартных Omarchy panels;
- native fallback для несовместимых плагинов;
- отсутствие дублированных IPC/services в тестах;
- bounded state/cache/processes;
- green validation, model, adapter и live lifecycle suites;
- README, shortcuts и compatibility notes.

## 17. Первый практический инкремент (завершён)

Начать не с catalog и не с drag-and-drop, а с минимального end-to-end среза:

1. `manifest.json` с `panel + bar-widget`.
2. `BarWidget.qml`, передающий имя своего экрана.
3. Singleton `Dashboard.qml` с `open/close/toggle`.
4. `DashboardSurface.qml` через per-screen `Variants`.
5. Одна fixture Tile в свободной сетке с настраиваемым шагом.
6. Store с одним Space и атомарным versioned state.
7. Focus/Escape lifecycle tests.

После этого архитектурные риски — shell loading, screen routing, layer focus и
persistence — будут проверены до того, как появится большая UI-реализация.
