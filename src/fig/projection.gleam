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
pub type ScreenCoordinates {
  ScreenCoordinates(x: Float, y: Float, depth: Float)
}

// =============================================================================
// PUBLIC OPAQUE TYPES
// =============================================================================

/// Point of view looking at the chart, one direction per data axis,
/// before scaling. You can construct with [`view`](#view) or a preset, e.g.
/// [`isometric`](#isometric).
pub opaque type View {
  View(directions: List(ScreenCoordinates))
}

/// Projects geometry coordinates onto the screen, construct with [`new`](#new).
pub opaque type Projection {
  Projection(origin: ScreenCoordinates, axes: List(AxisProjection))
  EmptyProjection
}

// =============================================================================
// PRIVATE TYPES
// =============================================================================

type AxisProjection {
  AxisProjection(minimum: Float, span: Float, direction: ScreenCoordinates)
}

// =============================================================================
// PUBLIC FUNCTIONS
// =============================================================================

/// The directions a [`View`](#View) was built from.
pub fn directions(view: View) -> List(ScreenCoordinates) {
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
    ScreenCoordinates(
      -0.707_106_781_186_547_6,
      -0.408_248_290_463_863_1,
      0.577_350_269_189_625_8,
    ),
    ScreenCoordinates(
      0.707_106_781_186_547_6,
      -0.408_248_290_463_863_1,
      0.577_350_269_189_625_8,
    ),
    ScreenCoordinates(0.0, -0.816_496_580_927_726, -0.577_350_269_189_625_8),
  ])
}

/// Build a projection for a chart.
pub fn new(
  bounds bounds: List(#(Float, Float)),
  width width: Float,
  height height: Float,
  padding padding: geometry.Padding,
  view view: View,
) -> Projection {
  let #(padding_top, padding_right, padding_bottom, padding_left) = case
    padding
  {
    geometry.AutoPadding -> #(0.0, 0.0, 0.0, 0.0)
    geometry.Padding(top, right, bottom, left) -> #(top, right, bottom, left)
  }

  // padding exceeding the chart area cannot invert axes
  let minimum_extent = 1.0

  // padding larger than the area would give a negative extent, which flips
  // the axis direction and renders the chart inside out
  let smaller_width =
    float.max(width -. padding_left -. padding_right, minimum_extent)
  let smaller_height =
    float.max(height -. padding_top -. padding_bottom, minimum_extent)

  let #(origin, directions) = case list.length(bounds) {
    // the origin is the bottom left of the plot area, measured against the
    // full chart height; the directions span the plot area, so they use the
    // padded extents instead
    2 -> #(ScreenCoordinates(padding_left, height -. padding_bottom, 0.0), [
      ScreenCoordinates(smaller_width, 0.0, 0.0),
      ScreenCoordinates(0.0, 0.0 -. smaller_height, 0.0),
    ])
    _ ->
      fit(
        view.directions,
        padding_left,
        padding_top,
        smaller_width,
        smaller_height,
      )
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
  point: geometry.Point,
) -> ScreenCoordinates {
  case projection {
    EmptyProjection -> ScreenCoordinates(0.0, 0.0, 0.0)
    Projection(origin, axes) ->
      list.map2(point.coordinates, axes, fn(value, axis) {
        let along = case axis.span == 0.0 {
          True -> 0.5
          False -> { value -. axis.minimum } /. axis.span
        }

        ScreenCoordinates(
          along *. axis.direction.x,
          along *. axis.direction.y,
          along *. axis.direction.depth,
        )
      })
      // add origin here
      |> list.fold(origin, fn(total, contribution) {
        ScreenCoordinates(
          total.x +. contribution.x,
          total.y +. contribution.y,
          total.depth +. contribution.depth,
        )
      })
  }
}

/// A view built from your own directions, one per data axis.
pub fn view(directions: List(ScreenCoordinates)) -> View {
  View(directions)
}

// =============================================================================
// PRIVATE FUNCTIONS
// =============================================================================

// fit the projected data geometry inside the chart area, needed for 3D
fn fit(
  directions: List(ScreenCoordinates),
  left: Float,
  top: Float,
  width: Float,
  height: Float,
) -> #(ScreenCoordinates, List(ScreenCoordinates)) {
  let extent_x = extent(directions, fn(direction) { direction.x })
  let extent_y = extent(directions, fn(direction) { direction.y })

  case extent_x == 0.0 || extent_y == 0.0 {
    // degenerate view
    True -> #(ScreenCoordinates(left, top, 0.0), directions)
    False -> {
      let scale = float.min(width /. extent_x, height /. extent_y)

      let scaled =
        list.map(directions, fn(direction) {
          ScreenCoordinates(
            direction.x *. scale,
            direction.y *. scale,
            direction.depth,
          )
        })

      // where the box's own minimum corner sits relative to the origin
      let offset_x = lowest(scaled, fn(direction) { direction.x })
      let offset_y = lowest(scaled, fn(direction) { direction.y })

      #(
        ScreenCoordinates(
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
  directions: List(ScreenCoordinates),
  component: fn(ScreenCoordinates) -> Float,
) -> Float {
  list.fold(directions, 0.0, fn(total, direction) {
    total +. float.absolute_value(component(direction))
  })
}

fn lowest(
  directions: List(ScreenCoordinates),
  component: fn(ScreenCoordinates) -> Float,
) -> Float {
  list.fold(directions, 0.0, fn(total, direction) {
    total +. float.min(0.0, component(direction))
  })
}
