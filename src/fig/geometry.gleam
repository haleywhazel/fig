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

pub type Geometry {
  Padding(top: Float, right: Float, bottom: Float, left: Float)
  Point(x: Float, y: Float)
  Rectangle(x: Float, y: Float, width: Float, height: Float)
}
