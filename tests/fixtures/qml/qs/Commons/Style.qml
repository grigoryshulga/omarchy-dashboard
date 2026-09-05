pragma Singleton
import QtQuick
QtObject {
  property int cornerRadius: 8
  property var spacing: ({ panelPadding: 10, sm: 6, md: 10, lg: 16 })
  property var font: ({ family: "sans-serif", body: 14, bodySmall: 12, caption: 11 })
  function space(value) { return value }
  function selectedFillFor(foreground, accent) { return accent }
  function hoverFillFor(foreground, accent) { return accent }
}
