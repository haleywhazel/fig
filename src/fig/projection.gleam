//// Projects geometry coordinates onto screen positions.

// =============================================================================
// IMPORTS
// =============================================================================

import gleam/float
import gleam/list

import fig/geometry

// =============================================================================
// PUBLIC TYPES
// =============================================================================

/// The screen direction for a data axis, with `depth` used for painter's
/// algorithm ordering in 3D and is 0.0 in 2D.
pub type ScreenDirection {
  ScreenDirection(x: Float, y: Float, depth: Float)
}

// =============================================================================
// PUBLIC OPAQUE TYPES
// =============================================================================

/// Point of view looking at the chart, one direction per data axis,
/// before scaling. You can construct with [`view`](#view) or a preset, e.g.
/// [`isometric`](#isometric).
pub opaque type View {
  View(directions: List(ScreenDirection))
}

/// Projects geometry coordinates onto the screen, construct with [`new`](#new).
pub opaque type Projection {
  Projection(origin: ScreenDirection, axes: List(AxisProjection))
  EmptyProjection
}

// =============================================================================
// PRIVATE TYPES
// =============================================================================

type AxisProjection {
  AxisProjection(minimum: Float, span: Float, direction: ScreenDirection)
}

// =============================================================================
// PUBLIC FUNCTIONS
// =============================================================================

/// The directions a [`View`](#View) was built from.
pub fn directions(view: View) -> List(ScreenDirection) {
  view.directions
}

/// Construct an empty projection that always returns a null
/// point when using [`project`](#project)
pub fn empty_projection() -> Projection {
  EmptyProjection
}

/// A standard isometric view for three axes: the two base axes rise
/// symmetrically to the left and right, the third runs straight up.
pub fn isometric() -> View {
  View([
    ScreenDirection(
      -0.707_106_781_186_547_6,
      -0.408_248_290_463_863_1,
      0.577_350_269_189_625_8,
    ),
    ScreenDirection(
      0.707_106_781_186_547_6,
      -0.408_248_290_463_863_1,
      0.577_350_269_189_625_8,
    ),
    ScreenDirection(0.0, -0.816_496_580_927_726, -0.577_350_269_189_625_8),
  ])
}

/// Build a projection for a chart.
pub fn new(
  bounds bounds: List(#(Float, Float)),
  area area: #(Float, Float),
  padding padding: geometry.Padding,
  view view: View,
) -> Projection {
  let width = area.0 -. padding.left -. padding.right
  let height = area.1 -. padding.top -. padding.bottom

  let #(origin, directions) = case list.length(bounds) {
    2 -> #(ScreenDirection(padding.left, area.1 -. padding.bottom, 0.0), [
      ScreenDirection(width, 0.0, 0.0),
      ScreenDirection(0.0, 0.0 -. height, 0.0),
    ])
    _ -> fit(view.directions, padding.left, padding.top, width, height)
  }

  Projection(
    origin:,
    axes: list.map2(bounds, directions, fn(bound, direction) {
      let #(minimum, maximum) = bound
      AxisProjection(minimum:, span: maximum -. minimum, direction:)
    }),
  )
}

/// Project a point given in geometry coords.
pub fn project(
  projection: Projection,
  coordinates: List(Float),
) -> ScreenDirection {
  case projection {
    EmptyProjection -> ScreenDirection(0.0, 0.0, 0.0)
    Projection(origin, axes) ->
      list.map2(coordinates, axes, fn(value, axis) {
        let along = case axis.span == 0.0 {
          True -> 0.5
          False -> { value -. axis.minimum } /. axis.span
        }

        ScreenDirection(
          along *. axis.direction.x,
          along *. axis.direction.y,
          along *. axis.direction.depth,
        )
      })
      // add origin here
      |> list.fold(origin, fn(total, contribution) {
        ScreenDirection(
          total.x +. contribution.x,
          total.y +. contribution.y,
          total.depth +. contribution.depth,
        )
      })
  }
}

/// A view built from your own directions, one per data axis.
pub fn view(directions: List(ScreenDirection)) -> View {
  View(directions)
}

// =============================================================================
// PRIVATE FUNCTIONS
// =============================================================================

// fit the projected data geometry inside the chart area, needed for 3D
fn fit(
  directions: List(ScreenDirection),
  left: Float,
  top: Float,
  width: Float,
  height: Float,
) -> #(ScreenDirection, List(ScreenDirection)) {
  let extent_x = extent(directions, fn(direction) { direction.x })
  let extent_y = extent(directions, fn(direction) { direction.y })

  case extent_x == 0.0 || extent_y == 0.0 {
    // degenerate view
    True -> #(ScreenDirection(left, top, 0.0), directions)
    False -> {
      let scale = float.min(width /. extent_x, height /. extent_y)

      let scaled =
        list.map(directions, fn(direction) {
          ScreenDirection(
            direction.x *. scale,
            direction.y *. scale,
            direction.depth,
          )
        })

      // where the box's own minimum corner sits relative to the origin
      let offset_x = lowest(scaled, fn(direction) { direction.x })
      let offset_y = lowest(scaled, fn(direction) { direction.y })

      #(
        ScreenDirection(
          left +. { width -. extent_x *. scale } /. 2.0 -. offset_x,
          top +. { height -. extent_y *. scale } /. 2.0 -. offset_y,
          0.0,
        ),
        scaled,
      )
    }
  }
}

fn extent(
  directions: List(ScreenDirection),
  component: fn(ScreenDirection) -> Float,
) -> Float {
  list.fold(directions, 0.0, fn(total, direction) {
    total +. float.absolute_value(component(direction))
  })
}

fn lowest(
  directions: List(ScreenDirection),
  component: fn(ScreenDirection) -> Float,
) -> Float {
  list.fold(directions, 0.0, fn(total, direction) {
    total +. float.min(0.0, component(direction))
  })
}
