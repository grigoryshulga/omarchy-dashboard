import QtQuick
import QtTest
import "../../qml/system" as System
import "../../qml/system/HostChrome.js" as Chrome

// HostChrome.js normalization plus HostChrome against the deliberately
// incomplete qs.Commons fixture in tests/fixtures/qml: missing or retargeted
// system tokens must fall back instead of warn-crashing Dashboard bindings.
TestCase {
  name: "HostChrome"
  when: windowShown

  System.HostChrome {
    id: host
  }

  function test_missing_snapshot_inputs_return_defaults() {
    verify(Qt.colorEqual(Chrome.colorOr(undefined, Chrome.DEFAULTS.background), Chrome.DEFAULTS.background))
    verify(Qt.colorEqual(Chrome.colorOr(null, Chrome.DEFAULTS.accent), Chrome.DEFAULTS.accent))
    verify(Qt.colorEqual(Chrome.colorOr("", Chrome.DEFAULTS.urgent), Chrome.DEFAULTS.urgent))
    compare(Chrome.intOr(undefined, 7), 7)
    compare(Chrome.intOr(null, 7), 7)
    compare(Chrome.intOr(NaN, 7), 7)
    compare(Chrome.intOr("not-a-number", 7), 7)
    compare(Chrome.textOr(undefined, "monospace"), "monospace")
    compare(Chrome.textOr(null, "monospace"), "monospace")
    compare(Chrome.textOr("", "monospace"), "monospace")
  }

  function test_non_color_values_are_rejected() {
    verify(!Chrome.isColor(42))
    verify(!Chrome.isColor("red-not-hex"))
    verify(!Chrome.isColor({}))
    verify(Chrome.isColor("#abc"))
    verify(Chrome.isColor("#aabbcc"))
    verify(Chrome.isColor("#ffaabbcc"))
    verify(Qt.colorEqual(Chrome.colorOr(42, Chrome.DEFAULTS.muted), Chrome.DEFAULTS.muted))
    verify(Qt.colorEqual(Chrome.colorOr("red-not-hex", Chrome.DEFAULTS.muted), Chrome.DEFAULTS.muted))
    verify(Qt.colorEqual(Chrome.colorOr({}, Chrome.DEFAULTS.muted), Chrome.DEFAULTS.muted))
  }

  function test_valid_colors_pass_through() {
    verify(Qt.colorEqual(Chrome.colorOr("#ff8800", Chrome.DEFAULTS.background), "#ff8800"))
    var original = Qt.rgba(0.25, 0.5, 0.75, 1)
    var copy = Chrome.colorOr(original, Chrome.DEFAULTS.background)
    // QColor carries 16-bit channels, so 0.25 reads back as 0.2500038.
    verify(Math.abs(copy.r - 0.25) < 0.0001)
    verify(Math.abs(copy.g - 0.5) < 0.0001)
    verify(Math.abs(copy.b - 0.75) < 0.0001)
  }

  function test_space_fallback_floors_at_zero_and_one() {
    compare(Chrome.spaceOr(0, null), 0)
    compare(Chrome.spaceOr(-5, null), 0)
    compare(Chrome.spaceOr(Number.NaN, null), 0)
    verify(Chrome.spaceOr(7, null) >= 1)
    compare(Chrome.spaceOr(7.4, null), 7)
  }

  function test_alpha_never_throws_on_invalid_color() {
    var invalid = Chrome.alpha("red-not-hex", 0.5)
    verify(isFinite(invalid.r))
    verify(isFinite(invalid.g))
    verify(isFinite(invalid.b))
    verify(invalid.a >= 0 && invalid.a <= 1)
    var faded = Chrome.alpha("#ff0000", 0.5)
    verify(Math.abs(faded.r - 1) < 0.000001)
    // QColor stores alpha in 16 bits, so 0.5 comes back as 0.5000076.
    verify(Math.abs(faded.a - 0.5) < 0.0001)
  }

  function test_host_chrome_colors_stay_valid_on_incomplete_fixture() {
    var names = ["background", "foreground", "accent", "urgent", "muted",
                 "popupBackground", "popupText", "popupBorder", "menuScrim"]
    for (var i = 0; i < names.length; i++) {
      verify(isFinite(host[names[i]].r), names[i] + " should be a valid color")
    }
    // Fixture values pass through.
    verify(Qt.colorEqual(host.background, "#202020"))
    verify(Qt.colorEqual(host.accent, "#88aaff"))
    verify(Qt.colorEqual(host.popupBackground, "#303030"))
    verify(Qt.colorEqual(host.popupText, "#eeeeee"))
    // Missing fixture tokens (foreground, urgent, muted, popups.border, menu)
    // fall back instead of throwing.
    verify(Qt.colorEqual(host.foreground, Chrome.DEFAULTS.foreground))
    verify(Qt.colorEqual(host.urgent, Chrome.DEFAULTS.urgent))
    verify(Qt.colorEqual(host.muted, Chrome.DEFAULTS.muted))
    verify(Qt.colorEqual(host.popupBorder, Chrome.DEFAULTS.popupBorder))
    verify(Qt.colorEqual(host.menuScrim, Chrome.DEFAULTS.menuScrim))
  }

  function test_host_chrome_metrics_stay_finite_on_incomplete_fixture() {
    var names = ["cornerRadius", "gapsOut", "borderWidth", "fontTitle", "fontSubtitle",
                 "fontBody", "fontBodySmall", "fontCaption", "spaceXs", "spaceSm",
                 "spaceMd", "spaceLg", "panelPadding", "panelGap", "controlPaddingY"]
    for (var i = 0; i < names.length; i++) {
      verify(isFinite(host[names[i]]), names[i] + " should be finite")
    }
    // Fixture values pass through.
    compare(host.cornerRadius, 8)
    compare(host.fontTitle, 18)
    compare(host.fontBody, 14)
    compare(host.fontBodySmall, 12)
    compare(host.fontCaption, 11)
    compare(host.spaceXs, 4)
    compare(host.spaceSm, 6)
    compare(host.spaceMd, 10)
    compare(host.spaceLg, 16)
    compare(host.panelPadding, 10)
    // Missing fixture tokens (gapsOut, normalBorderWidth, font.subtitle,
    // spacing.panelGap, spacing.controlPaddingY) fall back.
    compare(host.gapsOut, 5)
    compare(host.borderWidth, 1)
    compare(host.fontSubtitle, 13)
    // Style.font.family is present on the fixture and preferred.
    compare(host.fontFamily, "sans-serif")
    compare(host.panelGap, 14)
    compare(host.controlPaddingY, 6)
  }

  function test_space_and_state_fills_combine_system_and_fallback() {
    // Fixture Style.space is the identity function.
    compare(host.space(8), 8)
    compare(host.space(0), 0)
    compare(host.space(-3), 0)
    // No normalFillFor on the fixture: accent tinted with the local alpha.
    verify(Qt.colorEqual(host.normalFill("#ffffff", "#123456"), Chrome.alpha("#123456", 0.04)))
    // hoverFillFor/selectedFillFor exist on the fixture and pass through.
    verify(Qt.colorEqual(host.hoverFill("#ffffff", "#123456"), "#123456"))
    verify(Qt.colorEqual(host.selectedFill("#ffffff", "#123456"), "#123456"))
  }

  function test_schedule_refresh_is_safe_and_bumps_epoch() {
    var before = host.epoch
    host.scheduleRefresh()
    compare(host.epoch, before + 1)
  }
}
