import QtQuick
import QtTest
import "../../qml/plugins" as Plugins

TestCase {
  id: test
  name: "DashboardPopout"
  when: windowShown
  visible: true
  width: 1200
  height: 900
  property int closes: 0

  QtObject {
    id: fakePlugins
    property var saved: null
    property bool failInitialization: false
    function descriptor(id) { return { manifest: { dashboard: {} } } }
    function presentation(tile) {
      return { name: "Test plugin", source: Qt.resolvedUrl("../fixtures/PopoutPage.qml"), contentLayout: "padded" }
    }
    function popoutSize(id) { return saved }
    function setPopoutSize(id, value) { saved = value; return true }
    function injectInto(page, tile, host) {
      if (failInitialization) return false
      page.initializeDashboard({ dashboard: host })
      page.open()
      return true
    }
    function deactivate(page, reason) { page.close() }
    function focusPage(page) { if (page) page.forceActiveFocus() }
    function requestAdaptation(id) {}
  }

  QtObject {
    id: fakeDashboard
    property var plugins: fakePlugins
    property bool opened: true
    property string activeScreenName: "test"
    function focusKeyboardPlugin(delta) {}
  }

  Component {
    id: popoutComponent
    Plugins.DashboardPopout {
      width: 1000
      height: 800
      dashboard: fakeDashboard
      tile: ({ pluginId: "test.plugin" })
      onCloseRequested: { test.closes += 1; visible = false }
    }
  }

  function init() { fakePlugins.saved = null; fakePlugins.failInitialization = false; test.closes = 0 }

  function createPopout() {
    var popout = createTemporaryObject(popoutComponent, test)
    verify(popout !== null)
    tryVerify(function() { return popout.loadedPage !== null })
    return popout
  }

  function test_resize_persists_reopen_and_auto_size_restores_preference() {
    var popout = createPopout()
    compare(popout.geometry.width, 500)
    compare(popout.geometry.height, 380)
    var handle = findChild(popout, "popoutResizeHandle")
    verify(handle !== null)
    var start = handle.mapToItem(popout, handle.width / 2, handle.height / 2)
    mousePress(popout, start.x, start.y)
    mouseMove(popout, start.x + 30, start.y + 20)
    mouseRelease(popout, start.x + 30, start.y + 20)
    compare(fakePlugins.saved.width, 560)
    compare(fakePlugins.saved.height, 420)
    popout.visible = false
    popout.tile = null
    popout.tile = { pluginId: "test.plugin" }
    popout.visible = true
    tryVerify(function() { return popout.loadedPage !== null })
    compare(popout.geometry.width, 560)
    popout.useAutomaticSize()
    compare(fakePlugins.saved, null)
    compare(popout.geometry.width, 500)
    popout.width = 300
    popout.height = 250
    verify(popout.geometry.width <= 270)
    verify(popout.geometry.height <= 212)
  }

  function test_plugin_dismiss_and_outside_click_leave_dashboard_open() {
    var popout = createPopout()
    popout.loadedPage.dismiss()
    compare(test.closes, 1)
    verify(fakeDashboard.opened)
    verify(!popout.visible)
    popout.visible = true
    tryVerify(function() { return popout.loadedPage !== null })
    mouseClick(popout, 2, 2)
    compare(test.closes, 2)
    verify(fakeDashboard.opened)
  }

  function test_failed_initialization_can_recover_on_reopen() {
    fakePlugins.failInitialization = true
    var popout = createTemporaryObject(popoutComponent, test)
    tryVerify(function() { return popout.pageError !== "" })
    fakePlugins.failInitialization = false
    popout.visible = false
    popout.tile = null
    popout.tile = { pluginId: "test.plugin" }
    popout.visible = true
    tryVerify(function() { return popout.loadedPage !== null })
    compare(popout.pageError, "")
    verify(fakeDashboard.opened)
  }
}
