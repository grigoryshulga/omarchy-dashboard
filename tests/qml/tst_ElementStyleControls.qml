import QtQuick
import QtTest
import "../../qml/ui" as Ui
import "../../qml/layout" as Layout
import "../../qml/state/DashboardModel.js" as DashboardModel

TestCase {
  id: test
  name: "ElementStyleControls"
  when: windowShown
  visible: true
  width: 700
  height: 400
  property var state: DashboardModel.defaultState()
  property int changes: 0
  readonly property var selectedElement: state.spaces[0].elements.filter(function(element) {
    return element.id === dashboard.selectedElementId
  })[0] || null

  function apply(command) {
    state = DashboardModel.apply(state, command, 700, 400)
    changes += 1
  }

  QtObject {
    id: dashboard
    property string mode: "edit"
    property string selectedElementId: "text"
    property var dashboardState: test.state
    function selectElement(id) { selectedElementId = id }
    function placeElement(id, geometry) { test.apply({type: "placeElement", elementId: id, geometry: geometry}) }
    function removeElement(id) {}
  }

  Ui.ElementStyleControls {
    id: controls
    x: 30
    y: 20
    element: test.selectedElement
    onAlignmentRequested: function(alignment) {
      test.apply({ type: "setTextAlignment", elementId: element.id, alignment: alignment })
    }
    onThicknessRequested: function(thickness) {
      test.apply({ type: "setDividerThickness", elementId: element.id, thickness: thickness })
    }
  }

  Layout.DashboardGraphicElement {
    id: graphic
    dashboard: dashboard
    canvas: test
    gridWidth: test.width
    gridHeight: test.height
    element: test.selectedElement || ({ id: "empty", kind: "text", text: "", x: 0, y: 0, w: 0, h: 0 })
  }

  function init() {
    state = DashboardModel.normalize({ spaces: [{ id: "space-main", elements: [
      { id: "text", kind: "text", text: "Title", x: 30, y: 100, w: 500, h: 80 },
      { id: "line", kind: "divider", x1: 30, y1: 250, x2: 530, y2: 250 },
      { id: "vertical", kind: "divider", x1: 600, y1: 100, x2: 600, y2: 350, thickness: 5 }
    ] }] })
    dashboard.selectedElementId = "text"
    changes = 0
    mouseMove(test, 680, 380)
    waitForRendering(controls)
  }

  function test_alignment_buttons_update_text_inside_its_existing_container() {
    var text = findChild(graphic, "graphicText")
    compare(text.horizontalAlignment, Text.AlignLeft)
    var directions = ["center", "right", "left"]
    var expected = [Text.AlignHCenter, Text.AlignRight, Text.AlignLeft]
    for (var i = 0; i < directions.length; i++) {
      var button = findChild(controls, "align-" + directions[i])
      mouseClick(button)
      compare(test.selectedElement.alignment, directions[i])
      compare(text.horizontalAlignment, expected[i])
      verify(button.checked)
      compare(test.selectedElement.x, 30)
      compare(test.selectedElement.w, 500)
    }
    compare(changes, 3)
  }

  function test_slider_changes_both_divider_orientations_and_tracks_selection() {
    dashboard.selectedElementId = "line"
    var slider = findChild(controls, "dividerThicknessSlider")
    verify(slider.visible)
    verify(!findChild(controls, "textAlignmentControls").visible)
    compare(slider.value, 2)
    waitForPolish(controls)
    mousePress(slider, slider.leftPadding + slider.visualPosition * slider.availableWidth, slider.height / 2)
    mouseMove(slider, slider.width - slider.rightPadding, slider.height / 2)
    mouseRelease(slider, slider.width - slider.rightPadding, slider.height / 2)
    compare(test.selectedElement.thickness, 16)
    compare(findChild(graphic, "graphicDivider").height, 16)
    compare(findChild(graphic, "graphicDivider").width, 500)
    var priorChanges = changes
    dashboard.selectedElementId = "vertical"
    compare(slider.value, 5)
    compare(changes, priorChanges)
    slider.forceActiveFocus()
    keyClick(Qt.Key_Right)
    compare(test.selectedElement.thickness, 6)
    compare(findChild(graphic, "graphicDivider").width, 6)
    compare(findChild(graphic, "graphicDivider").height, 250)
    dashboard.selectedElementId = "text"
    verify(!slider.visible)
    verify(findChild(controls, "textAlignmentControls").visible)
    dashboard.selectedElementId = ""
    verify(!slider.visible)
    verify(!findChild(controls, "textAlignmentControls").visible)
  }

  function test_styles_survive_geometry_changes_text_edits_and_serialization() {
    apply({ type: "setTextAlignment", elementId: "text", alignment: "right" })
    apply({ type: "setDividerThickness", elementId: "line", thickness: 9 })
    apply({ type: "updateText", elementId: "text", text: "New title" })
    apply({ type: "placeElement", elementId: "text", geometry: { x: 50, y: 100, w: 550, h: 90 } })
    apply({ type: "placeElement", elementId: "line", geometry: { x1: 50, y1: 270, x2: 550, y2: 270 } })
    state = DashboardModel.normalize(JSON.parse(DashboardModel.serialize(state)))
    compare(state.spaces[0].elements[0].alignment, "right")
    compare(state.spaces[0].elements[0].text, "New title")
    compare(state.spaces[0].elements[1].thickness, 9)
    apply({ type: "setTextAlignment", elementId: "line", alignment: "center" })
    apply({ type: "setDividerThickness", elementId: "text", thickness: 3 })
    compare(state.spaces[0].elements[0].alignment, "right")
    compare(state.spaces[0].elements[1].thickness, 9)
  }

  function test_untrusted_style_values_are_normalized() {
    compare(DashboardModel.normalizeDividerThickness(undefined), 2)
    compare(DashboardModel.normalizeDividerThickness("bad"), 2)
    compare(DashboardModel.normalizeDividerThickness(-20), 1)
    compare(DashboardModel.normalizeDividerThickness(1000), 16)
    compare(DashboardModel.normalizeDividerThickness(4.4), 4)
    compare(DashboardModel.normalizeTextAlignment("justify"), "left")
  }
}
