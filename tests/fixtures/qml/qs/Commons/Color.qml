pragma Singleton
import QtQuick
QtObject {
  property color background: "#202020"
  property color accent: "#88aaff"
  property QtObject popups: QtObject {
    property color background: "#303030"
    property color text: "#eeeeee"
  }
}
