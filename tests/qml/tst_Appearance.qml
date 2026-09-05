import QtQuick
import QtTest
import "../../qml/appearance/DashboardAppearance.js" as DashboardAppearance
import "../../qml/appearance/HyprlandBlur.js" as HyprlandBlur

TestCase {
  name: "Appearance"
  when: windowShown

  function test_surface_modes_normalize_legacy_push_to_glass() {
    compare(DashboardAppearance.surfaceMode("Framed"), "framed")
    compare(DashboardAppearance.surfaceMode("glass"), "glass")
    compare(DashboardAppearance.surfaceMode("Push"), "glass")
    compare(DashboardAppearance.surfaceMode("unknown"), "glass")
    verify(!DashboardAppearance.usesGlass("Framed"))
    verify(DashboardAppearance.usesGlass("Glass"))
    verify(DashboardAppearance.usesGlass("Push"))
  }

  function test_hyprland_blur_rule_targets_the_dashboard_layer() {
    var enabled = HyprlandBlur.ruleExpression(true)
    verify(enabled.indexOf("hl.layer_rule") >= 0)
    verify(enabled.indexOf('name = "gshulga-dashboard-blur"') >= 0)
    verify(enabled.indexOf('namespace = "gshulga-dashboard"') >= 0)
    verify(enabled.indexOf("blur = true") >= 0)
    verify(enabled.indexOf("xray = true") >= 0)
    verify(enabled.indexOf("gshulga_dashboard_blur_rule_version ~= 2") >= 0)
    verify(enabled.indexOf(":set_enabled(false)") >= 0)
    verify(enabled.indexOf(":set_enabled(true)") >= 0)
    verify(enabled.indexOf("decoration:blur") < 0)

    var disabled = HyprlandBlur.ruleExpression(false)
    verify(disabled.indexOf(":set_enabled(false)") >= 0)
  }
}
