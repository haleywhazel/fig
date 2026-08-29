// Renders a chart into an SVG string. This doesn't give you something you can
// embed inside Lustre, so look to fig_lustre for that (not built yet).
//
// Currently has a minimal set of SVG types as helpers to generate the svg
// string, not really meant to be used directly (use Geometry instead).

import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string

import fig
import fig/geometry
import fig/projection

// =============================================================================
// PUBLIC OPAQUE TYPE
// =============================================================================

/// Type representation for SVGs to reduce boilerplate code when converting
/// either to actual .svg files or to Lustre svg elements.
pub opaque type SvgElements {
  // Svg(width: Float, height: Float, view_box: #(Float, Float, Float, Float), children: List(Svg))
  // note that depth gives the sorting direction (what place to put these
  // elements inside of svg)
  // Rect(x: Float, y: Float, width: Float, height: Float, depth: Float, role: geometry.GeometryRole)
  Path(d: String, depth: Float, role: geometry.GeometryRole)
}

// =============================================================================
// PUBLIC FUNCTIONS
// =============================================================================

/// Create an SVG string from a chart with generated geometries. Note that if
/// no geometries have been generated, it's just be an empty SVG.
pub fn to_svg(chart: fig.Chart(shape)) -> String {
  let #(width, height) = chart.area

  let body =
    to_svg_elements(
      width,
      height,
      chart.geometries,
      chart.projection,
      chart.tick_size,
    )
    |> list.sort(fn(a, b) { float.compare(b.depth, a.depth) })
    |> list.map(to_svg_string)
    |> string.join("")

  "<svg viewBox=\"0 0 "
  <> round_to_string(width, 0)
  <> " "
  <> round_to_string(height, 0)
  <> "\" xmlns=\"http://www.w3.org/2000/svg\">"
  <> body
  <> "</svg>"
}

// =============================================================================
// PUBLIC INTERNAL FUNCTIONS
// =============================================================================

// need width & height for precision clamping purposes
@internal
pub fn to_svg_elements(
  width: Float,
  height: Float,
  geometries: List(geometry.Geometry),
  projection: projection.Projection,
  tick_size: Float,
) -> List(SvgElements) {
  // d.p. to clamp string representations at
  let decimals =
    int.clamp(
      int.subtract(
        5,
        float.round(
          {
            float.max(width, height)
            |> float.logarithm
            |> result.unwrap(1.0)
          }
          /. 2.302_585_092_994_046,
        ),
      ),
      0,
      7,
    )
  let round = fn(x) { round_to_string(x, decimals) }

  let project = fn(point: geometry.Point) {
    projection.project(projection, point)
  }

  geometries
  |> list.map(fn(geometry) {
    case geometry {
      geometry.Path(commands, role) -> {
        let #(ds, depths) =
          commands
          |> list.map(fn(command) {
            case command {
              geometry.LineTo(point) -> {
                let coordinates = project(point)
                #(
                  "L" <> round(coordinates.x) <> " " <> round(coordinates.y),
                  coordinates.depth,
                )
              }
              geometry.MoveTo(point) -> {
                let coordinates = project(point)
                #(
                  "M" <> round(coordinates.x) <> " " <> round(coordinates.y),
                  coordinates.depth,
                )
              }
            }
          })
          |> list.unzip

        let d = string.join(ds, " ")

        // use centroid depth for paths
        let depth =
          {
            depths
            |> list.fold(0.0, float.add)
          }
          /. int.to_float(list.length(depths))

        Path(d: d, depth: depth, role: role)
      }
      geometry.Tick(at, direction, role) -> {
        let starting_coordinates = project(at)
        let direction_vector = project(geometry.add_points(at, direction))

        let dx = direction_vector.x -. starting_coordinates.x
        let dy = direction_vector.y -. starting_coordinates.y
        let length =
          float.square_root(dx *. dx +. dy *. dy) |> result.unwrap(0.0)

        let #(unit_x, unit_y) = case length == 0.0 {
          True -> #(0.0, 0.0)
          False -> #(dx /. length, dy /. length)
        }

        let ending_coordinates_x = starting_coordinates.x +. unit_x *. tick_size
        let ending_coordinates_y = starting_coordinates.y +. unit_y *. tick_size

        Path(
          d: "M"
            <> round(starting_coordinates.x)
            <> " "
            <> round(starting_coordinates.y)
            <> " L"
            <> round(ending_coordinates_x)
            <> " "
            <> round(ending_coordinates_y),
          depth: starting_coordinates.depth,
          role: role,
        )
      }
      // _ ->
    }
  })
}

// =============================================================================
// PRIVATE FUNCTIONS
// =============================================================================

// need to allow for more options for strokes later, probably use stuff from
// chart options that the user can set
fn default_stroke(role: geometry.GeometryRole) -> String {
  case role {
    geometry.Grid -> "#ddd"
    geometry.Display -> "none"
    _ -> "#333"
  }
}

fn to_svg_string(element: SvgElements) -> String {
  case element {
    Path(d, _depth, role) ->
      "<path d=\""
      <> d
      <> "\" class=\""
      <> geometry.role_class(role)
      <> "\" fill=\"none\" stroke=\""
      <> default_stroke(role)
      <> "\" stroke-width=\"1\"/>"
  }
}

fn round_to_string(value: Float, decimals: Int) -> String {
  let factor = float.power(10.0, int.to_float(decimals)) |> result.unwrap(1.0)

  let scaled = float.round(value *. factor)
  let sign = case scaled < 0 {
    True -> "-"
    False -> ""
  }
  let magnitude = int.absolute_value(scaled)

  case decimals <= 0 {
    True -> sign <> int.to_string(magnitude)
    False ->
      sign
      <> int.to_string(magnitude / float.round(factor))
      <> "."
      <> string.pad_start(
        int.to_string(magnitude % float.round(factor)),
        decimals,
        "0",
      )
  }
}
