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

import fig/internal/utils

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
  Path(depth: Float, d: String, role: geometry.GeometryRole)
  Text(
    depth: Float,
    x: String,
    y: String,
    text_anchor: String,
    dominant_baseline: String,
    content: String,
    role: geometry.TextRole,
  )
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
      chart.label_offset,
    )
    |> list.sort(fn(a, b) { float.compare(b.depth, a.depth) })
    |> list.map(to_svg_string)
    |> string.join("")

  "<svg viewBox=\"0 0 "
  <> utils.round_to_string(width, 0)
  <> " "
  <> utils.round_to_string(height, 0)
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
  label_offset: Float,
) -> List(SvgElements) {
  // d.p. to clamp string representations at
  let decimals =
    int.clamp(
      int.subtract(
        5,
        float.round(
          float.max(width, height)
          |> utils.log10,
        ),
      ),
      0,
      7,
    )
  let round = fn(x) { utils.round_to_string(x, decimals) }

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

        let #(ending_coordinate_x, ending_coordinate_y, _, _) =
          offset(
            starting_coordinates,
            project(geometry.add_points(at, direction)),
            by: tick_size,
          )

        Path(
          depth: starting_coordinates.depth,
          d: "M"
            <> round(starting_coordinates.x)
            <> " "
            <> round(starting_coordinates.y)
            <> " L"
            <> round(ending_coordinate_x)
            <> " "
            <> round(ending_coordinate_y),
          role: role,
        )
      }
      geometry.Text(at, direction, content, geometry.TickLabel) -> {
        let starting_coordinates = project(at)
        let #(x, y, unit_x, unit_y) =
          offset(
            starting_coordinates,
            project(geometry.add_points(at, direction)),
            by: label_offset,
          )

        let text_anchor = case unit_x {
          unit_x if unit_x <. -0.1 -> "end"
          unit_x if unit_x <. 0.1 -> "middle"
          _ -> "start"
        }

        let dominante_baseline = case unit_y {
          unit_y if unit_y <. -0.1 -> "text-bottom"
          unit_y if unit_y <. 0.1 -> "middle"
          _ -> "text-top"
        }

        Text(
          depth: starting_coordinates.depth,
          x: round(x),
          y: round(y),
          text_anchor: text_anchor,
          dominant_baseline: dominante_baseline,
          content: content,
          role: geometry.TickLabel,
        )
      }
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

fn offset(
  start: projection.ScreenCoordinates,
  direction: projection.ScreenCoordinates,
  by offset: Float,
) {
  let dx = direction.x -. start.x
  let dy = direction.y -. start.y
  let length = float.square_root(dx *. dx +. dy *. dy) |> result.unwrap(0.0)

  let #(unit_x, unit_y) = case length == 0.0 {
    True -> #(0.0, 0.0)
    False -> #(dx /. length, dy /. length)
  }

  let x = start.x +. unit_x *. offset
  let y = start.y +. unit_y *. offset

  #(x, y, unit_x, unit_y)
}

fn to_svg_string(element: SvgElements) -> String {
  case element {
    Path(_depth, d, role) ->
      "<path d=\""
      <> d
      <> "\" class=\""
      <> geometry.role_class(role)
      <> "\" fill=\"none\" stroke=\""
      <> default_stroke(role)
      <> "\" stroke-width=\"1\"/>"
    Text(_depth, x, y, text_anchor, dominant_baseline, content, _role) ->
      "<text x=\""
      <> x
      <> "\" y=\""
      <> y
      <> "\" text-anchor=\""
      <> text_anchor
      <> "\" dominant-baseline=\""
      <> dominant_baseline
      <> "\">"
      <> content
      <> "</text>"
  }
}
