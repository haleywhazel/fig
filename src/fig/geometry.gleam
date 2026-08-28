//// The main geometry module that lays out the scene for various charts and
//// figures. Although the main fig module can help you automatically generate
//// various geometries just based on configs and data, you can also use types
//// and functions in this module to layout your own scene or modify the
//// generated scenes.

import gleam/float
import gleam/list

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
  Point(coordinates: List(Float))
}

pub type TextRole {
  TickLabel
}

// =============================================================================
// PUBLIC FUNCTIONS
// =============================================================================

// not used currently
pub fn add_points(point1: Point, point2: Point) {
  Point(list.map2(point1.coordinates, point2.coordinates, float.add))
}

pub fn axis(starting_at starting: Point, ending_at ending: Point) {
  Path(commands: [MoveTo(starting), LineTo(ending)], role: Axis)
}
