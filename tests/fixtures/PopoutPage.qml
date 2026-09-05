import QtQuick
Item {
  id: root
  property var dashboard: null
  property real dashboardPreferredWidth: 480
  property real dashboardPreferredHeight: 320
  property size minimumSize: Qt.size(200, 100)
  function initializeDashboard(context) {
    dashboard = context.dashboard
    dashboard.registerSurface(root)
  }
  function open() { visible = true }
  function close() { visible = false }
  function dismiss() { dashboard.close() }
}
