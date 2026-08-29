import fig/geometry
import fig/projection

// =============================================================================
// VIEW SETUP
// =============================================================================

pub fn view_test() {
  let directions = [
    projection.ScreenCoordinates(1.0, 0.0, 0.0),
    projection.ScreenCoordinates(0.0, -1.0, 0.0),
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

  assert projection.project(projection, geometry.Point([0.0, 0.0]))
    == projection.ScreenCoordinates(20.0, 380.0, 0.0)
  assert projection.project(projection, geometry.Point([10.0, 100.0]))
    == projection.ScreenCoordinates(620.0, 20.0, 0.0)
  assert projection.project(projection, geometry.Point([5.0, 50.0]))
    == projection.ScreenCoordinates(320.0, 200.0, 0.0)
}

pub fn project_degenerate_axis_test() {
  let projection =
    projection.new(
      bounds: [#(5.0, 5.0), #(0.0, 10.0)],
      area: #(640.0, 400.0),
      padding: geometry.Padding(20.0, 20.0, 20.0, 20.0),
      view: projection.view([]),
    )

  assert projection.project(projection, geometry.Point([5.0, 0.0]))
    == projection.ScreenCoordinates(320.0, 380.0, 0.0)
}

pub fn project_isometric_test() {
  let projection =
    projection.new(
      bounds: [#(0.0, 1.0), #(0.0, 1.0), #(0.0, 1.0)],
      area: #(640.0, 400.0),
      padding: geometry.Padding(20.0, 20.0, 20.0, 20.0),
      view: projection.isometric(),
    )

  let origin = projection.project(projection, geometry.Point([0.0, 0.0, 0.0]))
  let left = projection.project(projection, geometry.Point([1.0, 0.0, 0.0]))
  let right = projection.project(projection, geometry.Point([0.0, 1.0, 0.0]))

  assert left.x +. right.x == 640.0

  assert origin.depth
    != projection.project(projection, geometry.Point([1.0, 1.0, 1.0])).depth
}
