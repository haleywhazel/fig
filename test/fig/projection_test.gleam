import fig/geometry
import fig/projection.{ScreenDirection}

// =============================================================================
// VIEW SETUP
// =============================================================================

pub fn view_test() {
  let directions = [
    ScreenDirection(1.0, 0.0, 0.0),
    ScreenDirection(0.0, -1.0, 0.0),
  ]

  assert projection.directions(projection.view(directions)) == directions
}

pub fn isometric_test() {
  let assert [x_axis, y_axis, z_axis] =
    projection.directions(projection.isometric())

  // the two base axes mirror each other about the vertical, which is what
  // makes the view isometric
  assert x_axis.x == 0.0 -. y_axis.x
  assert x_axis.y == y_axis.y
  assert z_axis.x == 0.0
}

// =============================================================================
// PROJECTION
// =============================================================================

pub fn project_test() {
  let projection =
    projection.new(
      bounds: [#(0.0, 10.0), #(0.0, 100.0)],
      area: #(640.0, 400.0),
      padding: geometry.Padding(20.0, 20.0, 20.0, 20.0),
      view: projection.view([]),
    )

  // the plot area runs x 20..620 and y 20..380, and the vertical axis is
  // inverted since data grows upward while screen coordinates grow downward
  assert projection.project(projection, [0.0, 0.0])
    == ScreenDirection(20.0, 380.0, 0.0)
  assert projection.project(projection, [10.0, 100.0])
    == ScreenDirection(620.0, 20.0, 0.0)
  assert projection.project(projection, [5.0, 50.0])
    == ScreenDirection(320.0, 200.0, 0.0)
}

pub fn project_degenerate_axis_test() {
  let projection =
    projection.new(
      bounds: [#(5.0, 5.0), #(0.0, 10.0)],
      area: #(640.0, 400.0),
      padding: geometry.Padding(20.0, 20.0, 20.0, 20.0),
      view: projection.view([]),
    )

  // no range to spread across, so it sits in the middle rather than pinning
  // to an edge
  assert projection.project(projection, [5.0, 0.0])
    == ScreenDirection(320.0, 380.0, 0.0)
}

pub fn project_isometric_test() {
  let projection =
    projection.new(
      bounds: [#(0.0, 1.0), #(0.0, 1.0), #(0.0, 1.0)],
      area: #(640.0, 400.0),
      padding: geometry.Padding(20.0, 20.0, 20.0, 20.0),
      view: projection.isometric(),
    )

  let origin = projection.project(projection, [0.0, 0.0, 0.0])
  let left = projection.project(projection, [1.0, 0.0, 0.0])
  let right = projection.project(projection, [0.0, 1.0, 0.0])

  // the fitted box is centred in the plot area, whose midpoint is 320.0
  assert left.x +. right.x == 640.0

  // depth has to vary or painter's algorithm has nothing to sort on
  assert origin.depth != projection.project(projection, [1.0, 1.0, 1.0]).depth
}
