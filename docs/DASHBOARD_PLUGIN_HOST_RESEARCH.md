# Dashboard как второй host плагинов Omarchy Shell

Дата исследования: 2026-08-30. Проверена установленная на машине версия
Omarchy Shell из `/usr/share/omarchy/shell`, её CLI из
`/usr/share/omarchy/bin` и текущая реализация `omarchy-dashboard`.

## Короткий вывод

Сделать Dashboard самостоятельным визуальным host внутри существующего процесса
`omarchy-shell` возможно без второго процесса Quickshell. Более того, основная
часть механизма уже существует: Dashboard использует общий `PluginRegistry`,
показывает все обнаруженные manifests, умеет загружать обычные QML `Item` в
плитки и повторно использует shell singleton services.

Но Dashboard пока не является равноправным host в публичном контракте Omarchy:

- schema и CLI знают размещение только в `bar.layout.left|center|right`;
- `omarchy plugin enable` считает `bar-widget` размещённым именно в bar;
- shell знает только общий факт enabled и не моделирует владельца/host;
- `dashboardPage` и `dashboardWidget` — расширения этого репозитория, а не
  валидируемые виды Omarchy plugin API;
- произвольный `barWidget` нельзя безопасно считать Dashboard-плиткой: его UI,
  размеры, panel lifecycle и Wayland surfaces привязаны к bar.

Практичный путь — оставить единый shell-level discovery/service lifecycle, но
ввести отдельный host-scoped placement `dashboard`, который ссылается на тот же
manifest и явно предпочитает `dashboardPage`/`dashboardWidget`. Не следует
делать второй PluginRegistry или запускать второй Quickshell.

## Что уже предоставляет Omarchy

### Discovery и manifest

`shell.qml` создаёт ровно по одному `PluginRegistry` и `BarWidgetRegistry` и
передаёт их дочерним компонентам через property injection
(`/usr/share/omarchy/shell/shell.qml:14-20`). Registry сканирует first-party и
`~/.config/omarchy/plugins`, хранит manifests вместе с `__sourceDir` и
`__isFirstParty` (`services/PluginRegistry.qml:10-24`). Manifest schemaVersion 1
требует `id`, `name`, `version`, `kinds`, `entryPoints`, ограничивает entry point
относительным путём внутри plugin source directory
(`services/PluginRegistry.qml:36-90`, `:93-108`).

Официально документированы kinds `bar-widget`, `panel`, `overlay`, `menu`,
`service`, `bar` (`/usr/share/omarchy/shell/README.md:74-90`). Валидатор требует
фиксированные пары kind/entry point: `bar:bar`, `bar-widget:barWidget`,
`menu:menu`, `overlay:overlay`, `panel:panel`, `service:service`
(`/usr/share/omarchy/bin/omarchy-plugin-validate:89-109`). При этом неизвестные
ключи `entryPoints`, например `dashboardPage`, не запрещаются: каждый путь лишь
проверяется на безопасность и существование (`:59-87`). Значит расширение
совместимо с текущей schema 1, но Omarchy не обещает загрузить его.

Проверка пути не является sandbox исполнения: после загрузки plugin QML работает
как доверенный код внутри процесса `omarchy-shell` и имеет доступ к Quickshell
API. Официальная документация также прямо предупреждает, что plugins исполняются
unsandboxed (`/usr/share/omarchy/shell/README.md:107-125`).

### Enabled state уже допускает non-bar placement

Registry определяет enabled как наличие plugin id в одном из трёх мест:
`bar.id`, `bar.layout.*` или верхнеуровневом `plugins[]`
(`/usr/share/omarchy/shell/services/PluginRegistry.qml:110-139`, `:206-223`).
Это важнейший существующий seam: third-party `bar-widget` можно сделать enabled,
записав его в `plugins[]`, не добавляя в bar. Тогда shell создаст и зарегистрирует
его QML `Component`, но сам bar не создаст widget instance, пока id отсутствует
в layout (`/usr/share/omarchy/shell/shell.qml:656-717`,
`plugins/bar/Bar.qml:1527-1549`, `:1601-1611`).

Текущий Dashboard уже использует этот seam: при добавлении third-party plugin
`PluginRuntime.enable()` снимает `disabledPlugins` и добавляет `{id}` в
`plugins[]`, а не вызывает bar placement
([PluginRuntime.qml](../PluginRuntime.qml):102). Для service UI он получает уже
созданный singleton через `shell.serviceFor(id)`
([PluginRuntime.qml](../PluginRuntime.qml):149). Это позволяет не дублировать
таймеры, IPC handlers и модель состояния.

Слабое место: storage rule в документации описывает `plugins[]` как место для
panels/overlays/services/menus, а bar widgets — как записи bar layout
(`/usr/share/omarchy/shell/README.md:254-272`). Текущее поведение Registry шире
документации и потому полезно, но пока не является надёжным публичным контрактом
для отдельного host.

Есть и наблюдаемая несовместимость UI: `shell listPlugins` для `bar-widget`
вычисляет поле `enabled` через `inBar(id)`, а не через общий `isEnabled(id)`
(`/usr/share/omarchy/shell/shell.qml:952-975`). Поэтому Dashboard-only widget,
на который ссылается `plugins[]`, реально загружен, но штатный список покажет его
disabled. Это уже требует host-aware статуса, даже если загрузку не менять.

### Bar — host, а не универсальный контейнер

Bar получает `shell`, manifest, registries и `barConfig` от корневого host
(`/usr/share/omarchy/shell/shell.qml:214-223`). Его layout жёстко нормализован в
три секции `left`, `center`, `right`; те же значения единственные допустимые в
manifest `barWidget.defaultSection`
(`/usr/share/omarchy/shell/services/PluginRegistry.qml:72-78`, `:169-193`).
Каждая layout entry превращается в `ModuleSlot`, а зарегистрированный Component
инстанцируется своим `Loader` (`plugins/bar/Bar.qml:1473-1524`, `:1527-1568`,
`:1601-1611`). Следовательно, reusable seam — это registry из Components плюс
host-specific entry/settings, а не сам `ModuleSlot`.

CLI усиливает эту связанность. `omarchy plugin enable <bar-widget>` передаёт
placement в shell IPC, разрешая только left/center/right
(`/usr/share/omarchy/bin/omarchy-plugin-enable:30-85`). `omarchy bar` также
поддерживает только эти секции и операции put/move/set
(`/usr/share/omarchy/bin/omarchy-bar:14-40`, `:59-137`). Поэтому команды вида
`omarchy plugin enable X --host dashboard` сейчас нет.

### Lifecycle остальных kinds

Shell создаёт невидимый singleton каждого enabled `service` и инъецирует
`omarchyPath`, `shell`, manifest и registries
(`/usr/share/omarchy/shell/shell.qml:263-346`). Для `panel|overlay|menu` существует
по одному on-demand Loader; `keepLoaded` удерживает instance, а при загрузке
инъецируются те же зависимости и matching service (`shell.qml:581-652`).
Чистый `bar-widget`, напротив, при `summon` маршрутизируется к живому экземпляру
в bar (`shell.qml:421-460`). Поэтому Dashboard не должен вызывать native summon
для bar-widget, отсутствующего в bar.

## Что уже реализовано в Dashboard

Manifest Dashboard объявляет обычные Omarchy kinds `panel + bar-widget`, чтобы
иметь singleton panel host и launcher в bar
([manifest.json](../manifest.json):1). Сам `Dashboard.qml` получает от shell
`pluginRegistry` и создаёт собственный runtime
([Dashboard.qml](../Dashboard.qml):11).

`PluginRuntime`:

- строит каталог из общего `registry.installedPlugins`, исключая сам Dashboard и
  уже размещённые plugin ids ([PluginRuntime.qml](../PluginRuntime.qml):27);
- читает необязательные `dashboardPage`, совместимый `sidePanelPage` и
  `dashboardWidget` ([PluginRuntime.qml](../PluginRuntime.qml):123);
- инъецирует host context, settings, shared service, shell и bar, затем вызывает
  lifecycle `dashboardActivate/Deactivate/Focus`
  ([PluginRuntime.qml](../PluginRuntime.qml):270);
- создаёт QML page внутри обычного `Loader`, ограниченного границами плитки
  ([TileHost.qml](../TileHost.qml):238).

Локальный авторский контракт уже правильно требует визуальный `Item`, а не
`PanelWindow`/`PopupWindow`, и описывает compact variant
`dashboardWidget` ([PLUGIN_CONTRACT.md](PLUGIN_CONTRACT.md):1). Для legacy plugin
есть консервативный adapter, но это слой совместимости, а не хороший публичный
host API.

Состояние Dashboard отдельно от `shell.json`: layout лежит в
`$XDG_STATE_HOME/omarchy/gshulga.dashboard.json` (см.
[Dashboard.qml](../Dashboard.qml):31). Это удобно для сложной геометрии и Spaces,
но создаёт два источника истины: shell решает, загружен ли plugin, Dashboard —
где и сколько раз он размещён.

## Ограничения Quickshell/QML

1. **Нельзя пересадить созданную surface внутрь Item.** `PanelWindow`,
   `PopupWindow`, `FloatingWindow` и layer-shell windows являются отдельными
   mapped Wayland surfaces. Dashboard может встроить только визуальное дерево
   `Item`; поэтому explicit page/widget — основной контракт, adapter — fallback.
2. **Component можно переиспользовать, instance — обычно нельзя.** Общий
   `BarWidgetRegistry` хранит `Component`, не визуальные instances
   (`/usr/share/omarchy/shell/services/BarWidgetRegistry.qml:10-24`). Каждый host
   создаёт свой instance, поэтому side effects, IPC handlers и timers должны
   принадлежать service либо быть строго lifecycle-aware.
3. **QML singleton через разные relative imports может раздвоиться.** Именно
   поэтому shell registries сделаны instances и инъецируются сверху
   (`BarWidgetRegistry.qml:3-6`, `shell.qml:14-18`). Новый host обязан получать
   те же объекты через injection.
4. **Один `barWidget` не равен универсальному tile.** Он может полагаться на
   `bar`, размеры/ориентацию, click-target registration или создавать popout
   surface. Dashboard обоснованно не считает его compact widget автоматически
   ([PLUGIN_CONTRACT.md](PLUGIN_CONTRACT.md):30).
5. **Несколько instances опасны по умолчанию.** Bar metadata поддерживает
   `allowMultiple`, но Dashboard сейчас сознательно допускает один plugin id во
   всех Spaces ([PluginRuntime.qml](../PluginRuntime.qml):52). До появления
   instance identity и разделённых settings это безопасное ограничение.

## Варианты архитектуры

### A. Оставить текущий Dashboard-local host

Сохранять layout в XDG state, продолжать читать общий Registry, добавлять id в
`plugins[]` для enabled state, а совместимость давать через explicit page,
adapter или launcher.

Плюсы: уже работает, не требует изменения Omarchy core, не ломает schema 1.
Минусы: нет штатного CLI, placement невидим Omarchy settings, `plugins[]` для
bar-widget опирается на недокументированное поведение, контракт принадлежит
только этому plugin. Это хороший ближайший релиз, но не полноценный system host.

### B. Добавить Dashboard как специальный host в shell.json

Например:

```json
{
  "dashboard": {
    "host": "gshulga.dashboard",
    "placements": [{ "id": "acme.weather", "space": "main", "rect": {} }]
  }
}
```

Registry должен считать id enabled при наличии в `dashboard.placements`, а CLI
получить `omarchy dashboard put/move/set` или обобщённый
`omarchy plugin enable --host dashboard`. Это делает placement видимым системе,
но связывает Omarchy core с конкретным plugin id и вынуждает core владеть
сложной Dashboard schema. Не рекомендуется как конечная модель.

### C. Обобщить host-scoped placements (рекомендация)

Ввести нейтральный раздел, например:

```json
{
  "hosts": {
    "gshulga.dashboard": {
      "placements": [{ "id": "acme.weather", "slot": "main", "settings": {} }]
    }
  }
}
```

Core отвечает только за discovery, enabled/reference counting, безопасный
entry-point lookup, shared services и атомарную mutation. Host сам валидирует
свои slots/layout и может держать тяжёлую геометрию в собственном state, оставив
в `shell.json` минимальную ссылку `{id, instanceId?, settings?}`.

Нужны публичные операции уровня Registry/IPC:

- `putHostPlugin(hostId, pluginId, placement)`;
- `removeHostPlugin(hostId, pluginId|instanceId)`;
- `setHostPlugin(hostId, selector, key, value)`;
- `hostEntries(hostId)` и `isHosted(hostId, pluginId)`.

`isEnabled` должен означать «на plugin ссылается хотя бы один host либо
`plugins[]`», а disable без `--host` должен либо удалить все placements с явным
подтверждением, либо отказываться при неоднозначности. Bar становится первым
встроенным host, но старый `bar.layout` и весь CLI остаются совместимыми через
adapter к новому API.

## Совместимость manifest

На первом этапе достаточно стандартизовать необязательные entry points без
нового kind:

```json
{
  "entryPoints": {
    "dashboardPage": "DashboardPage.qml",
    "dashboardWidget": "DashboardWidget.qml"
  },
  "dashboard": {
    "minWidth": 160,
    "minHeight": 120,
    "preferredWidth": 360,
    "preferredHeight": 260
  }
}
```

Это проходит текущую валидацию, не заставляет plugin называться только
dashboard plugin и сохраняет native panel/bar behavior. Позже лучше заменить
брендированные ключи общим `entryPoints.hostItem` плюс capability metadata, но
только после появления второго tile/grid host: преждевременная абстракция сейчас
ухудшит понятность контракта.

Fallback policy должна остаться такой: explicit `dashboardPage` → explicit
compact `dashboardWidget` → известный shared-service control → проверенный
adapter → native launcher → information tile. Прямое создание произвольного
`barWidget` в Dashboard по умолчанию небезопасно.

## Рекомендуемый план

1. **Сейчас, в этом репозитории:** считать Dashboard-local hosting рабочей
   experimental возможностью; документировать, что добавление tile включает
   plugin через `plugins[]`, но не помещает его в bar. Сохранить один instance
   на plugin id и текущий fallback policy.
2. **Укрепить локальный seam:** выделить узкий `HostPlacementStore` вокруг
   Dashboard state и отдельный `PluginHostRuntime` вокруг Registry/injection;
   не копировать PluginRegistry и не зависеть от `Bar.ModuleSlot`.
3. **Предложить Omarchy upstream:** официально закрепить, что любая ссылка в
   `plugins[]` делает `bar-widget` loadable без bar placement, либо сразу ввести
   нейтральные host references и IPC. Добавить CLI `--host` без изменения
   существующего поведения команд без флага.
4. **Стандартизовать page contract:** сначала принять `dashboardPage` и
   `dashboardWidget` как optional manifest keys; валидатор уже безопасно
   проверяет их пути. Добавить lifecycle и запрет mapped surfaces в официальную
   документацию.
5. **Только затем поддержать multiple instances:** ввести `instanceId`,
   instance-scoped settings и явный manifest capability; services по-прежнему
   остаются singleton на plugin id.

## Итог решения

Технический verdict: **да, Dashboard может быть новым host уже на текущем
Omarchy Shell**, если под host понимать второй visual container, использующий
общий Registry и записывающий enabled reference в `plugins[]`. Для системной,
поддерживаемой наравне с bar функции требуется небольшое upstream-расширение
модели placement/CLI, но не новый процесс, не fork shell и не изменение базового
plugin discovery. Главная граница архитектуры: shell владеет plugin lifecycle и
services, host владеет визуальным layout и instances.
