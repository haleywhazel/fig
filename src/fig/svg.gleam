// Renders a chart into an SVG string. This doesn't give you something you can
// embed inside Lustre, so look to fig_lustre for that (not built yet).
//
// Currently has a minimal set of SVG types as helpers to generate the svg
// string, not really meant to be used directly (use Geometry instead).

import gleam/float
import gleam/int
import gleam/list

// import gleam/result
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
    size: String,
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
  let #(width, height) = #(chart.config.width, chart.config.height)

  let body =
    to_svg_elements(
      width,
      height,
      chart.geometries,
      chart.projection,
      chart.config,
    )
    |> list.sort(fn(a, b) { float.compare(b.depth, a.depth) })
    |> list.map(to_svg_string)
    |> string.join("")

  "<svg viewBox=\"0 0 "
  <> utils.round_to_string(width, 0)
  <> " "
  <> utils.round_to_string(height, 0)
  <> "\" font-family=\""
  <> chart.config.font_family
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
  config: fig.ChartConfiguration,
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
        let direction = project(geometry.add_points(at, direction))

        let #(ending_coordinate_x, ending_coordinate_y, _, _) =
          utils.offset(
            #(starting_coordinates.x, starting_coordinates.y),
            #(direction.x, direction.y),
            by: config.tick_size,
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
        let offset = project(geometry.add_points(at, direction))
        let #(x, y, unit_x, unit_y) =
          utils.offset(
            #(starting_coordinates.x, starting_coordinates.y),
            #(offset.x, offset.y),
            by: config.tick_label_offset,
          )

        let text_anchor = case unit_x {
          unit_x if unit_x <. -0.1 -> "end"
          unit_x if unit_x <. 0.1 -> "middle"
          _ -> "start"
        }

        let dominant_baseline = case unit_y {
          // text-bottom
          unit_y if unit_y <. -0.1 -> "alphabetic"
          // middle
          unit_y if unit_y <. 0.1 -> "central"
          // text-top
          _ -> "hanging"
        }

        Text(
          depth: starting_coordinates.depth,
          x: round(x),
          y: round(y),
          size: round(config.tick_label_size),
          text_anchor: text_anchor,
          dominant_baseline: dominant_baseline,
          content: content,
          role: geometry.TickLabel,
        )
      }
      geometry.Text(at, direction, content, geometry.AxisLabel) -> {
        let starting_coordinates = project(at)
        let offset = project(geometry.add_points(at, direction))
        let #(x, y, unit_x, unit_y) =
          utils.offset(
            #(starting_coordinates.x, starting_coordinates.y),
            #(offset.x, offset.y),
            by: config.axis_label_offset,
          )

        let text_anchor = case unit_x {
          unit_x if unit_x <. -0.1 -> "end"
          unit_x if unit_x <. 0.1 -> "middle"
          _ -> "start"
        }

        let dominant_baseline = case unit_y {
          // text-bottom
          unit_y if unit_y <. -0.1 -> "alphabetic"
          // middle
          unit_y if unit_y <. 0.1 -> "central"
          // text-top
          _ -> "hanging"
        }

        Text(
          depth: starting_coordinates.depth,
          x: round(x),
          y: round(y),
          size: round(config.axis_label_size),
          text_anchor: text_anchor,
          dominant_baseline: dominant_baseline,
          content: content,
          role: geometry.AxisLabel,
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

fn escape_text(content: String) -> String {
  content
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
}

fn to_svg_string(element: SvgElements) -> String {
  case element {
    Path(_depth, d, role) ->
      "<path d=\""
      <> d
      <> "\" class=\""
      <> geometry.geometry_role_class(role)
      <> "\" fill=\"none\" stroke=\""
      <> default_stroke(role)
      <> "\" stroke-width=\"1\"/>"
    Text(_depth, x, y, size, text_anchor, dominant_baseline, content, role) ->
      "<text x=\""
      <> x
      <> "\" y=\""
      <> y
      <> "\" font-size=\""
      <> size
      <> "\" text-anchor=\""
      <> text_anchor
      <> "\" dominant-baseline=\""
      <> dominant_baseline
      <> "\" class=\""
      <> geometry.text_role_class(role)
      <> "\">"
      <> escape_text(content)
      <> "</text>"
  }
}
