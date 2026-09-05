import QtQuick

// In-process replacement for Omarchy's KeyboardPanel in a copied standard
// panel. It preserves the panel content and lifecycle without mapping another
// Wayland surface inside Dashboard.
Item {
  id: root

  property Item anchorItem: null
  property var owner: null
  property var bar: null
  property var dashboardHost: null
  property var page: null
  property bool open: true
  property Item focusTarget: null
  property int padding: 0
  property int margin: 0
  property int gap: 0
  property bool centerOnBar: false
  property var borderSpec: null
  // Compatibility properties used by PanelWindow-based plugins after their
  // mapped surface is replaced with this in-process host.
  property color color: "transparent"
  property string title: ""
  property size minimumSize: Qt.size(0, 0)
  property size maximumSize: Qt.size(0, 0)
  property var exclusionMode: null
  property var mask: null
  property int contentWidth: width
  property int contentHeight: height
  property bool dashboardContentWidthHint: false
  property bool dashboardContentHeightHint: false
  property real preferredContentWidth: 0
  property real preferredContentHeight: 0
  readonly property real dashboardPreferredWidth: preferredContentWidth
    || (dashboardContentWidthHint ? contentWidth : implicitWidth)
  readonly property real dashboardPreferredHeight: preferredContentHeight
    || (dashboardContentHeightHint ? contentHeight : implicitHeight)
  readonly property bool interactionAllowed: visible && dashboardHost && dashboardHost.mode === "interact"
  default property alias contentItem: contentHolder.children

  function fittedContentWidth(value, cap) {
    var desired = Math.max(1, Number(value) || 1)
    Qt.callLater(root.rememberWidth, cap > 0 ? Math.min(desired, Number(cap)) : desired)
    var maximum = root.width > 0 ? root.width : desired
    if (cap !== undefined && Number(cap) > 0) maximum = Math.min(maximum, Number(cap))
    return Math.round(Math.min(desired, maximum))
  }

  function fittedContentHeight(value, cap) {
    var desired = Math.max(1, Number(value) || 1)
    Qt.callLater(root.rememberHeight, cap > 0 ? Math.min(desired, Number(cap)) : desired)
    var maximum = root.height > 0 ? root.height : desired
    if (cap !== undefined && Number(cap) > 0) maximum = Math.min(maximum, Number(cap))
    return Math.round(Math.min(desired, maximum))
  }

  function cappedContentHeight(value) {
    var desired = Math.max(1, Number(value) || 1)
    Qt.callLater(root.rememberHeight, desired)
    return Math.round(Math.min(desired, root.height > 0 ? root.height : desired))
  }

  function rememberWidth(value) { preferredContentWidth = value }
  function rememberHeight(value) { preferredContentHeight = value }

  onDashboardHostChanged: {
    if (dashboardHost && typeof dashboardHost.registerSurface === "function")
      dashboardHost.registerSurface(root)
  }

  function focusPanel() {
    if (interactionAllowed && focusTarget) focusTarget.forceActiveFocus()
  }

  visible: open
  Keys.priority: Keys.BeforeItem
  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Escape && dashboardHost && typeof dashboardHost.handleEscape === "function") {
      dashboardHost.handleEscape()
      event.accepted = true
    } else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ControlModifier)
               && dashboardHost && typeof dashboardHost.focusKeyboardPlugin === "function") {
      dashboardHost.focusKeyboardPlugin((event.modifiers & Qt.ShiftModifier) ? -1 : 1)
      event.accepted = true
    }
  }
  onOpenChanged: if (open) Qt.callLater(root.focusPanel)

  Connections {
    target: root.dashboardHost
    function onModeChanged() {
      if (root.interactionAllowed && root.open) Qt.callLater(root.focusPanel)
    }
  }

  Rectangle { anchors.fill: parent; color: root.color; z: -1 }
  Item { id: contentHolder; anchors.fill: parent }
}
