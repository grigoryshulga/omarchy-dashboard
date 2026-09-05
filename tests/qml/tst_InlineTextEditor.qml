import QtQuick
import QtTest
import "../../qml/ui" as Ui
import "../../qml/layout" as Layout

TestCase {
  id: test
  name: "InlineTextEditor"
  when: windowShown
  visible: true
  width: 700
  height: 450
  property var element: ({ id: "text", kind: "text", text: "Title", alignment: "center", x: 30, y: 50, w: 350, h: 80 })
  property int saved: 0

  QtObject {
    id: dashboard
    property string mode: "edit"
    property string overlay: ""
    property string selectedElementId: "text"
    property var dashboardState: ({ gridSpacing: 10 })
    function selectElement(id) { selectedElementId = id }
    function placeElement(id, geometry) { test.element = Object.assign({}, test.element, geometry) }
    function removeElement(id) {}
  }

  Item {
    id: canvas
    x: 40
    y: 70
    width: 600
    height: 350
    Layout.DashboardGraphicElement {
      id: graphic
      dashboard: dashboard
      element: test.element
      canvas: canvas
      gridWidth: canvas.width
      gridHeight: canvas.height
      onEditTextRequested: dashboard.overlay = "inline-text"
    }
  }

  Ui.DashboardInlineTextEditor {
    id: editor
    anchors.fill: parent
    canvas: canvas
    element: test.element
    visible: dashboard.overlay === "inline-text"
    z: 50
    onAccepted: function(value) {
      test.element = Object.assign({}, test.element, { text: value })
      test.saved += 1
      dashboard.overlay = ""
    }
    onRejected: dashboard.overlay = ""
  }

  function init() {
    dashboard.overlay = ""
    test.element = { id: "text", kind: "text", text: "Title", alignment: "center", x: 30, y: 50, w: 350, h: 80 }
    saved = 0
    mouseMove(test, 680, 430)
    waitForRendering(test)
  }

  function cleanup() { dashboard.overlay = "" }

  function startEditing() {
    mouseDoubleClickSequence(canvas, 120, 90)
    compare(dashboard.overlay, "inline-text")
    var input = findChild(editor, "inlineTextInput")
    tryCompare(input, "activeFocus", true)
    tryCompare(input, "selectedText", "Title")
    return input
  }

  function test_double_click_edits_in_the_original_container_and_enter_saves() {
    var input = startEditing()
    var frame = findChild(editor, "inlineTextFrame")
    compare(frame.x, canvas.x + element.x)
    compare(frame.y, canvas.y + element.y)
    compare(frame.width, element.w)
    compare(frame.height, element.h)
    compare(input.horizontalAlignment, TextInput.AlignHCenter)
    keyClick(Qt.Key_X)
    compare(element.text, "Title")
    keyClick(Qt.Key_Return)
    compare(element.text.toLowerCase(), "x")
    compare(element.alignment, "center")
    compare(saved, 1)
    verify(!editor.visible)
    compare(dashboard.mode, "edit")
  }

  function test_escape_discards_and_outside_click_saves() {
    var input = startEditing()
    keyClick(Qt.Key_Y)
    keyClick(Qt.Key_Escape)
    compare(element.text, "Title")
    compare(saved, 0)
    verify(!editor.visible)
    input = startEditing()
    keyClick(Qt.Key_Z)
    mouseClick(test, 680, 430)
    compare(element.text.toLowerCase(), "z")
    compare(saved, 1)
    verify(!editor.visible)
  }

  function test_empty_input_cannot_replace_the_existing_text() {
    var input = startEditing()
    keyClick(Qt.Key_Backspace)
    compare(input.text, "")
    keyClick(Qt.Key_Return)
    verify(editor.visible)
    compare(saved, 0)
    mouseClick(test, 680, 430)
    compare(element.text, "Title")
    compare(saved, 0)
    verify(!editor.visible)
  }
}
