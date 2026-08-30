//// The main geometry module that lays out the scene for various charts and
//// figures. Although the main fig module can help you automatically generate
//// various geometries just based on configs and data, you can also use types
//// and functions in this module to layout your own scene or modify the
//// generated scenes.

import gleam/float
import gleam/int
import gleam/list

// =============================================================================
// IMPORTS
// =============================================================================

// =============================================================================
// PUBLIC TYPES
// =============================================================================

/// Commands to draw a path
pub type Command {
  // ArcTo(point: Point, radius: Float)
  // Close
  // CurveTo
  LineTo(point: Point)
  MoveTo(point: Point)
}

/// A single geometry object representing something to be drawn.
pub type Geometry {
  Path(commands: List(Command), role: GeometryRole)
  // Rectangle(points: #(Point, Point), role: GeometryRole)
  Text(at: Point, offset: Point, content: String, role: TextRole)
  /// Only the direction of `direction` is meaningful, renderers will need to
  /// normalise and scale it themselves for consistency
  Tick(at: Point, direction: Point, role: GeometryRole)
}

/// Role of the [`Geometry`](#Geometry) for styling.
pub type GeometryRole {
  /// Frames and axis share the same role `Axis`
  Axis
  Display
  Grid
  Series(index: Int)
  TickMark
}

pub type Padding {
  AutoPadding
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

pub fn add_points(point1: Point, point2: Point) {
  Point(list.map2(point1.coordinates, point2.coordinates, float.add))
}

/// Create a line.
pub fn line(
  starting_at starting: Point,
  ending_at ending: Point,
  with_role role: GeometryRole,
) {
  Path(commands: [MoveTo(starting), LineTo(ending)], role: role)
}

/// The CSS class name for a role.
pub fn role_class(role: GeometryRole) -> String {
  case role {
    Axis -> "fig-axis"
    Display -> "fig-display"
    Grid -> "fig-grid"
    Series(index) -> "fig-series fig-series-" <> int.to_string(index)
    TickMark -> "fig-tick"
  }
}
