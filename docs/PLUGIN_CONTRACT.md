# Dashboard Plugin Page Contract

Плагин может предоставить обычный QML `Item`, который Dashboard загрузит
внутрь плитки без преобразования:

```json
{
  "entryPoints": {
    "barWidget": "BarWidget.qml",
    "dashboardPage": "DashboardPage.qml"
  },
  "dashboard": {
    "minWidth": 240,
    "minHeight": 160,
    "preferredWidth": 420,
    "preferredHeight": 300
  }
}
```

`dashboardPage` должен быть визуальным `Item`/Control, а не `PanelWindow`,
`PopupWindow` или другой mapped Wayland surface. Dashboard задаёт размеры,
clip и lifecycle Loader самостоятельно.

## Компактный Dashboard Widget

Если полноценная страница не нужна, плагин может объявить отдельный компактный
entry point:

```json
{
  "entryPoints": {
    "dashboardWidget": "DashboardWidget.qml"
  }
}
```

`dashboardWidget` использует тот же lifecycle и context, что и
`dashboardPage`, но должен хорошо выглядеть начиная примерно с 160×120 px.
Обычный `barWidget` не считается безопасным Widget автоматически: bar entry
point может загружать `PanelWindow`, popup или bar-only anchors.

Если ни Page, ни Widget нельзя встроить, Dashboard создаёт Launcher-плитку.
Для `panel` и `overlay` она может открыть родной surface через shell. Для
`bar-widget` native launch доступен только при наличии живого экземпляра в
bar; иначе безопасно адаптированная панель открывается в Dashboard popout.
Service-only plugin остаётся информационной плиткой, кроме сервисов, для
которых Dashboard содержит собственный проверенный control-adapter.

Launcher icon разрешается best-effort без исполнения plugin QML. Поддерживаются
`dashboard.icon`, корневой `icon`, `barWidget.icon`, conventional
`icon.svg`/`icon.png`/`icon.webp`, а также короткий литеральный Nerd Font glyph
в свойстве `icon` или `heroGlyph` entry point. Если ничего не найдено,
Dashboard выбирает семантический glyph по plugin id/name/kind.

## Рекомендуемый минимальный API

```qml
import QtQuick

Item {
  id: root

  property var dashboard: null
  property var dashboardTile: null
  property string pluginId: ""
  property var settings: ({})
  property var service: null

  function initializeDashboard(context) {
    dashboard = context.dashboard
    dashboardTile = context.tile
    pluginId = context.pluginId
    settings = context.settings
    service = context.service
  }

  function dashboardActivate(context) {
    // Resume refreshes, subscriptions, or timers.
  }

  function dashboardDeactivate(reason) {
    // Stop transient work before the Loader releases this page.
  }

  function dashboardFocus() {
    firstFocusableControl.forceActiveFocus()
  }
}
```

Все функции необязательны. Если `initializeDashboard` отсутствует, host
пытается присвоить только объявленные writable properties:

- `dashboard`, `dashboardHost`, `dashboardTile`;
- `pluginId`, `settings`, `service`, `shell`, `bar`;
- совместимые aliases `sidePanel`, `sidePanelHost`, `sidePanelItem`.

Если lifecycle hooks отсутствуют, Dashboard использует `open()`, `close()` и
`forceActiveFocus()` как fallback. Страница с контрактом `sidePanelPage` и
методами `initializeSidePanel`, `sidePanelActivate`, `sidePanelDeactivate`,
`sidePanelFocus` загружается без изменений.

## Правила lifecycle

- Не создавайте собственный IPC handler с тем же target, что и bar widget.
- Останавливайте таймеры и подписки в `dashboardDeactivate`.
- Не предполагайте фиксированный пиксельный размер; используйте anchors/Layout.
- Не закрывайте весь Dashboard из локального `Escape`: embedded controls
  должны позволить host выйти из `interact`.
- Настройки и service принадлежат Omarchy Shell; не кэшируйте их глобально.
- Не меняйте layout Dashboard напрямую. Для этого используется публичный host
  и его валидируемые команды.

## Размеры

Hints измеряются в логических QML-пикселях и округляются к шагу 5 px.
Отсутствующие значения дают минимум 160×120 и предпочтительный размер 360×260.
Dashboard может предоставить больше места, но никогда не уменьшит плитку ниже
`minWidth`/`minHeight` через штатный resize. Старые `minColumns`, `minRows`,
`preferredColumns` и `preferredRows` поддерживаются как compatibility hints.

## Совместимость стандартных панелей

Для `barWidget`, `panel` или `overlay` Dashboard создаёт fingerprinted копию в
XDG cache. Один стандартный `KeyboardPanel` заменяется вложенным
`DashboardHost`; также поддерживается форма `Item` с ровно одной вложенной
`PanelWindow`, у которой в копии удаляются layer-shell bindings. Bar-only
controls и дублирующиеся IPC handlers отключаются. Неоднозначные host-ы,
несколько mapped surfaces, `PopupWindow`/`FloatingWindow`, symlink escape или
превышение лимитов получают native/information fallback. Исходный plugin tree
никогда не изменяется. Обычный `KeyboardPanel` получает стандартный внутренний
отступ Dashboard; адаптированный `PanelWindow` занимает весь контейнер, так как
такие плагины обычно уже рисуют собственную полноразмерную поверхность и рамку.
Если его единственный прямой `BorderSurface` использует простые однострочные
`anchors.centerIn`, `width` и `height`, кэшированная адаптация разворачивает эту
карточку до границ host-а; неоднозначная разметка остаётся без изменений.
