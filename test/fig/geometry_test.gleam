import fig/geometry

// =============================================================================
// GEOMETRY SETUP
// =============================================================================

pub fn axis_test() {
  let point1 = geometry.Point([0.2, 5.3])
  let point2 = geometry.Point([-1023.2, 3.2])

  assert geometry.axis(point1, point2)
    == geometry.Path(
      [geometry.MoveTo(point1), geometry.LineTo(point2)],
      role: geometry.Axis,
    )
}

// =============================================================================
// POINT OPERATIONS
// =============================================================================

pub fn add_points_test() {
  let point1 = geometry.Point([0.2, 5.3])
  let point2 = geometry.Point([-1023.2, 3.2])

  assert geometry.add_points(point1, point2) == geometry.Point([-1023.0, 8.5])
}
