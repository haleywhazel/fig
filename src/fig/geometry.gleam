//// The main geometry module that lays out the scene for various charts and
//// figures. Although the main fig module can help you automatically generate
//// various geometries just based on configs and data, you can also use types
//// and functions in this module to layout your own scene or modify the
//// generated scenes.

// =============================================================================
// IMPORTS
// =============================================================================

// =============================================================================
// PUBLIC TYPES
// =============================================================================

pub type Command {
  // ArcTo(point: Point, radius: Float)
  Close
  // CurveTo
  LineTo(point: Point)
  MoveTo(point: Point)
}

pub type Geometry {
  Path(commands: List(Command), role: GeometryRole)
  Rectangle(points: #(Point, Point), role: GeometryRole)
  Text(at: Point, content: String, role: TextRole)
}

pub type GeometryRole {
  Axis
  Display
  Grid
  Series(index: Int)
  TickMark
}

pub type Padding {
  Padding(top: Float, right: Float, bottom: Float, left: Float)
}

pub type Point {
  Point(x: Float, y: Float)
}

pub type TextRole {
  TickLabel
}

// =============================================================================
// PUBLIC FUNCTIONS
// =============================================================================

pub fn add_points(point1: Point, point2: Point) {
  // TODO: add tests
  Point(point1.x +. point2.x, point1.y +. point2.y)
}
