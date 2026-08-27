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
  Grid
  Series(index: Int)
  TickMark
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

// pub fn
