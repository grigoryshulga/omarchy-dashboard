import QtQuick
import qs.Commons as Commons
import "HostChrome.js" as Chrome

// Normalized, always-valid view of the Omarchy Shell system tokens
// (qs.Commons). Visual files read this instead of Commons directly, so a
// missing token, an older shell, or a retargeted theme degrades to the
// built-in defaults in HostChrome.js instead of throwing inside a binding.
//
// Deliberately NOT a singleton: the shell loads this plugin from file:// URLs
// without our directories on its QML import path, and relative singleton
// imports do not share state in that setup — every file would get its own
// copy anyway. A plain QtObject keeps that honest: each instance is a live
// view over the shared qs.Commons singletons, so all instances still observe
// the same system data.
QtObject {
  id: root

  // Bumped by scheduleRefresh(); every binding below reads it, so a refresh
  // re-evaluates the system reads even when qs.Commons emits no notify.
  property int epoch: 0

  // ------------------------------------------------------------- palette

  readonly property color background: {
    void root.epoch
    try {
      return Chrome.colorOr(Commons.Color.background, Chrome.DEFAULTS.background)
    } catch (e) {
      return Chrome.DEFAULTS.background
    }
  }

  readonly property color foreground: {
    void root.epoch
    try {
      return Chrome.colorOr(Commons.Color.foreground, Chrome.DEFAULTS.foreground)
    } catch (e) {
      return Chrome.DEFAULTS.foreground
    }
  }

  readonly property color accent: {
    void root.epoch
    try {
      return Chrome.colorOr(Commons.Color.accent, Chrome.DEFAULTS.accent)
    } catch (e) {
      return Chrome.DEFAULTS.accent
    }
  }

  readonly property color urgent: {
    void root.epoch
    try {
      return Chrome.colorOr(Commons.Color.urgent, Chrome.DEFAULTS.urgent)
    } catch (e) {
      return Chrome.DEFAULTS.urgent
    }
  }

  readonly property color muted: {
    void root.epoch
    try {
      return Chrome.colorOr(Commons.Color.muted, Chrome.DEFAULTS.muted)
    } catch (e) {
      return Chrome.DEFAULTS.muted
    }
  }

  readonly property color popupBackground: {
    void root.epoch
    try {
      return Chrome.colorOr(Commons.Color.popups.background, Chrome.DEFAULTS.popupBackground)
    } catch (e) {
      return Chrome.DEFAULTS.popupBackground
    }
  }

  readonly property color popupText: {
    void root.epoch
    try {
      return Chrome.colorOr(Commons.Color.popups.text, Chrome.DEFAULTS.popupText)
    } catch (e) {
      return Chrome.DEFAULTS.popupText
    }
  }

  readonly property color popupBorder: {
    void root.epoch
    try {
      return Chrome.colorOr(Commons.Color.popups.border, Chrome.DEFAULTS.popupBorder)
    } catch (e) {
      return Chrome.DEFAULTS.popupBorder
    }
  }

  readonly property color menuScrim: {
    void root.epoch
    try {
      return Chrome.colorOr(Commons.Color.menu.scrim, Chrome.DEFAULTS.menuScrim)
    } catch (e) {
      return Chrome.DEFAULTS.menuScrim
    }
  }

  // ------------------------------------------------------------- metrics

  readonly property int cornerRadius: {
    void root.epoch
    try {
      return Chrome.intOr(Commons.Style.cornerRadius, Chrome.DEFAULTS.cornerRadius, 0)
    } catch (e) {
      return Chrome.DEFAULTS.cornerRadius
    }
  }

  readonly property int gapsOut: {
    void root.epoch
    try {
      return Chrome.intOr(Commons.Style.gapsOut, Chrome.DEFAULTS.gapsOut, 0)
    } catch (e) {
      return Chrome.DEFAULTS.gapsOut
    }
  }

  readonly property int borderWidth: {
    void root.epoch
    try {
      return Chrome.intOr(Commons.Style.normalBorderWidth, Chrome.DEFAULTS.borderWidth, 0)
    } catch (e) {
      return Chrome.DEFAULTS.borderWidth
    }
  }

  readonly property string fontFamily: {
    void root.epoch
    // Prefer Style.font.family (the installed shell and every call site use
    // it); older shells only expose Style.fontFamily. Either way fall back
    // to the built-in default instead of throwing.
    try {
      var family = Commons.Style.font.family
      if (typeof family === "string" && family !== "") return family
    } catch (e) {
      // Style.font missing or hostile; try the flat property below.
    }
    try {
      return Chrome.textOr(Commons.Style.fontFamily, Chrome.DEFAULTS.fontFamily)
    } catch (e) {
      return Chrome.DEFAULTS.fontFamily
    }
  }

  readonly property int fontTitle: {
    void root.epoch
    try {
      return Chrome.intOr(Commons.Style.font.title, Chrome.DEFAULTS.fontTitle, 1)
    } catch (e) {
      return Chrome.DEFAULTS.fontTitle
    }
  }

  readonly property int fontSubtitle: {
    void root.epoch
    try {
      return Chrome.intOr(Commons.Style.font.subtitle, Chrome.DEFAULTS.fontSubtitle, 1)
    } catch (e) {
      return Chrome.DEFAULTS.fontSubtitle
    }
  }

  readonly property int fontBody: {
    void root.epoch
    try {
      return Chrome.intOr(Commons.Style.font.body, Chrome.DEFAULTS.fontBody, 1)
    } catch (e) {
      return Chrome.DEFAULTS.fontBody
    }
  }

  readonly property int fontBodySmall: {
    void root.epoch
    try {
      return Chrome.intOr(Commons.Style.font.bodySmall, Chrome.DEFAULTS.fontBodySmall, 1)
    } catch (e) {
      return Chrome.DEFAULTS.fontBodySmall
    }
  }

  readonly property int fontCaption: {
    void root.epoch
    try {
      return Chrome.intOr(Commons.Style.font.caption, Chrome.DEFAULTS.fontCaption, 1)
    } catch (e) {
      return Chrome.DEFAULTS.fontCaption
    }
  }

  readonly property int spaceXs: {
    void root.epoch
    try {
      return Chrome.intOr(Commons.Style.spacing.xs, Chrome.DEFAULTS.spaceXs, 0)
    } catch (e) {
      return Chrome.DEFAULTS.spaceXs
    }
  }

  readonly property int spaceSm: {
    void root.epoch
    try {
      return Chrome.intOr(Commons.Style.spacing.sm, Chrome.DEFAULTS.spaceSm, 0)
    } catch (e) {
      return Chrome.DEFAULTS.spaceSm
    }
  }

  readonly property int spaceMd: {
    void root.epoch
    try {
      return Chrome.intOr(Commons.Style.spacing.md, Chrome.DEFAULTS.spaceMd, 0)
    } catch (e) {
      return Chrome.DEFAULTS.spaceMd
    }
  }

  readonly property int spaceLg: {
    void root.epoch
    try {
      return Chrome.intOr(Commons.Style.spacing.lg, Chrome.DEFAULTS.spaceLg, 0)
    } catch (e) {
      return Chrome.DEFAULTS.spaceLg
    }
  }

  readonly property int panelPadding: {
    void root.epoch
    try {
      return Chrome.intOr(Commons.Style.spacing.panelPadding, Chrome.DEFAULTS.panelPadding, 0)
    } catch (e) {
      return Chrome.DEFAULTS.panelPadding
    }
  }

  readonly property int panelGap: {
    void root.epoch
    try {
      return Chrome.intOr(Commons.Style.spacing.panelGap, Chrome.DEFAULTS.panelGap, 0)
    } catch (e) {
      return Chrome.DEFAULTS.panelGap
    }
  }

  readonly property int controlPaddingY: {
    void root.epoch
    try {
      return Chrome.intOr(Commons.Style.spacing.controlPaddingY, Chrome.DEFAULTS.controlPaddingY, 0)
    } catch (e) {
      return Chrome.DEFAULTS.controlPaddingY
    }
  }

  // ------------------------------------------------------------ functions

  // Scaled spacing in px. Prefers the system Style.space; falls back to the
  // local curve in Chrome.spaceOr when it is missing or throws.
  function space(px) {
    void root.epoch
    try {
      return Chrome.spaceOr(px, Commons.Style.space)
    } catch (e) {
      return Chrome.spaceOr(px, null)
    }
  }

  // Interactive-state fills. Call the system helpers when present; otherwise
  // tint the accent with the shell's own default alphas.
  function hoverFill(foreground, accent) {
    void root.epoch
    var fallback = Chrome.alpha(accent, 0.08)
    try {
      return Chrome.colorOr(Commons.Style.hoverFillFor(foreground, accent), fallback)
    } catch (e) {
      return fallback
    }
  }

  function selectedFill(foreground, accent) {
    void root.epoch
    var fallback = Chrome.alpha(accent, 0.18)
    try {
      return Chrome.colorOr(Commons.Style.selectedFillFor(foreground, accent), fallback)
    } catch (e) {
      return fallback
    }
  }

  function normalFill(foreground, accent) {
    void root.epoch
    var fallback = Chrome.alpha(accent, 0.04)
    try {
      return Chrome.colorOr(Commons.Style.normalFillFor(foreground, accent), fallback)
    } catch (e) {
      return fallback
    }
  }

  // Re-read the system: ask the shell to repoll Hyprland when it can, then
  // bump epoch so every binding above re-evaluates regardless of notifies.
  function scheduleRefresh() {
    try {
      if (typeof Commons.Style.scheduleRefresh === "function") Commons.Style.scheduleRefresh()
    } catch (e) {
      // System refresh unavailable; the epoch bump below still re-reads.
    }
    root.epoch += 1
  }
}
