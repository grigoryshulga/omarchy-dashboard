import QtQuick
import QtTest
import "../../qml/layout/GridEngine.js" as GridEngine

TestCase {
  name: "GridEngine"
  when: windowShown

  function tile(id, x, y, w, h) {
    return { id: id, pluginId: "plugin." + id, x: x, y: y, w: w, h: h }
  }

  function test_grid_uses_five_pixel_snap() {
    compare(GridEngine.snap(0), 0)
    compare(GridEngine.snap(7), 5)
    compare(GridEngine.snap(8), 10)
    var normalized = GridEngine.normalizeRect({ x: 13, y: 18, w: 203, h: 197 }, 100, 100, 800, 600)
    compare(normalized.x, 15)
    compare(normalized.y, 20)
    compare(normalized.w, 205)
    compare(normalized.h, 195)
  }

  function test_grid_rejects_collisions_bounds_and_unsnapped_values() {
    var tiles = [tile("a", 0, 0, 300, 200)]
    verify(!GridEngine.canPlace({ x: 295, y: 195, w: 100, h: 100 }, tiles, "", 800, 600))
    verify(GridEngine.canPlace({ x: 300, y: 0, w: 100, h: 100 }, tiles, "", 800, 600))
    verify(!GridEngine.canPlace({ x: 750, y: 0, w: 100, h: 100 }, tiles, "", 800, 600))
    verify(!GridEngine.canPlace({ x: 302, y: 0, w: 100, h: 100 }, tiles, "", 800, 600))
    verify(!GridEngine.canPlace({ x: "300", y: 0, w: 100, h: 100 }, tiles, "", 800, 600))
  }

  function test_first_free_is_deterministic() {
    var rect = GridEngine.firstFree(300, 200, [tile("a", 0, 0, 300, 200)], 800, 600)
    compare(rect.x, 300)
    compare(rect.y, 0)
  }

  function test_best_free_keeps_preferred_size_when_it_fits() {
    var rect = GridEngine.bestFree(360, 260, 160, 120,
                                   [tile("a", 0, 0, 360, 260)], 800, 600, 20)
    compare(rect.x, 360)
    compare(rect.y, 0)
    compare(rect.w, 360)
    compare(rect.h, 260)
  }

  function test_best_free_shrinks_to_use_a_narrow_gap() {
    var rect = GridEngine.bestFree(360, 260, 160, 120,
                                   [tile("a", 0, 0, 600, 600)], 800, 600, 20)
    verify(rect !== null)
    compare(rect.x, 600)
    compare(rect.y, 0)
    compare(rect.w, 200)
    compare(rect.h, 260)
    verify(GridEngine.canPlace(rect, [tile("a", 0, 0, 600, 600)], "", 800, 600))
  }

  function test_best_free_can_use_minimum_size_between_coarse_grid_lines() {
    var rect = GridEngine.bestFree(360, 260, 160, 120,
                                   [tile("a", 0, 0, 630, 600)], 800, 600, 30)
    verify(rect !== null)
    compare(rect.x, 630)
    compare(rect.w, 170)
    compare(rect.h, 260)
  }

  function test_best_free_returns_null_when_minimum_size_does_not_fit() {
    var rect = GridEngine.bestFree(360, 260, 160, 120,
                                   [tile("a", 0, 0, 800, 600)], 800, 600, 20)
    verify(rect === null)
  }

  function test_centered_canvas_uses_dotted_bounds_without_clipping_layout() {
    var spaces = [{ tiles: [
      { x: 0, y: 0, w: 2010, h: 1050 }
    ] }]
    var fitted = GridEngine.centeredBounds(2020, 1065, 30, spaces)
    compare(fitted.width, 2010)
    compare(fitted.height, 1050)

    var fallback = GridEngine.centeredBounds(2020, 1065, 80, spaces)
    compare(fallback.width, 2020)
    compare(fallback.height, 1065)

    var empty = GridEngine.centeredBounds(2020, 1065, 80, [])
    compare(empty.width, 2000)
    compare(empty.height, 1040)

    var decorated = GridEngine.centeredBounds(800, 600, 40, [{
      tiles: [], elements: [
        { kind: "divider", x1: 0, y1: 560, x2: 760, y2: 560 },
        { kind: "text", x: 600, y: 400, w: 200, h: 160 }
      ]
    }])
    compare(decorated.width, 800)
    compare(decorated.height, 600)
  }

  function test_rect_snaps_to_canvas_center_axes_within_threshold() {
    var vertical = GridEngine.snapRectToCenter(
      { x: 344, y: 40, w: 300, h: 200 }, 1000, 600, 12)
    compare(vertical.rect.x, 350)
    compare(vertical.rect.y, 40)
    verify(vertical.vertical)
    verify(!vertical.horizontal)

    var both = GridEngine.snapRectToCenter(
      { x: 345, y: 205, w: 300, h: 200 }, 1000, 600, 12)
    compare(both.rect.x, 350)
    compare(both.rect.y, 200)
    verify(both.vertical)
    verify(both.horizontal)

    var outside = GridEngine.snapRectToCenter(
      { x: 330, y: 180, w: 300, h: 200 }, 1000, 600, 12)
    compare(outside.rect.x, 330)
    compare(outside.rect.y, 180)
    verify(!outside.vertical)
    verify(!outside.horizontal)
  }

  function test_center_snap_keeps_origin_on_five_pixel_lattice() {
    var aligned = GridEngine.snapRectToCenter(
      { x: 300, y: 200, w: 200, h: 100 }, 805, 505, 5)
    compare(aligned.rect.x, 305)
    compare(aligned.rect.y, 205)
    compare(aligned.rect.x % GridEngine.STEP, 0)
    compare(aligned.rect.y % GridEngine.STEP, 0)
    verify(aligned.vertical)
    verify(aligned.horizontal)
  }

  function test_center_snap_keeps_origin_on_active_grid() {
    var aligned = GridEngine.snapRectToCenter(
      { x: 870, y: 390, w: 300, h: 300 }, 2010, 1050, 15, 30)
    verify(aligned.vertical)
    verify(aligned.horizontal)
    compare(aligned.rect.x % 30, 0)
    compare(aligned.rect.y % 30, 0)
    compare(aligned.verticalPosition, 1020)
    compare(aligned.horizontalPosition, 540)
  }

  function test_center_snap_skips_axis_when_size_cannot_stay_on_grid() {
    var aligned = GridEngine.snapRectToCenter(
      { x: 810, y: 0, w: 390, h: 300 }, 2010, 1050, 15, 30)
    verify(!aligned.vertical)
    compare(aligned.rect.x, 810)
    compare(aligned.rect.x % 30, 0)
    compare(aligned.verticalPosition % 30, 0)
  }
}
