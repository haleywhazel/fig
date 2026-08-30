import gleam/string

import fig
import fig/geometry
import fig/svg

// =============================================================================
// BASIC SVG GENERATION
// =============================================================================

pub fn to_svg_empty_chart_test() {
  assert svg.to_svg(fig.new())
    == "<svg viewBox=\"0 0 640 400\" xmlns=\"http://www.w3.org/2000/svg\"></svg>"
}

pub fn to_svg_basic_line_test() {
  let chart =
    fig.new()
    |> fig.set_grid(False)
    |> fig.set_ticks(False)
    |> fig.set_padding(geometry.Padding(20.0, 20.0, 20.0, 20.0))
    |> fig.add_series(fig.Series(
      "a",
      fig.line(),
      fig.numerical([#(0.0, 0.0), #(1.0, 1.0)]),
    ))
    |> fig.generate

  assert svg.to_svg(chart)
    == "<svg viewBox=\"0 0 640 400\" xmlns=\"http://www.w3.org/2000/svg\">"
    <> "<path d=\"M20.00 380.00 L620.00 380.00\" class=\"fig-axis\" fill=\"none\" stroke=\"#333\" stroke-width=\"1\"/>"
    <> "<path d=\"M20.00 380.00 L20.00 20.00\" class=\"fig-axis\" fill=\"none\" stroke=\"#333\" stroke-width=\"1\"/>"
    <> "<path d=\"M20.00 380.00 L620.00 20.00\" class=\"fig-series fig-series-0\" fill=\"none\" stroke=\"#333\" stroke-width=\"1\"/>"
    <> "</svg>"
}

// =============================================================================
// TICKS
// =============================================================================

pub fn to_svg_ticks_test() {
  let chart =
    fig.new()
    |> fig.set_grid(False)
    |> fig.set_ticks(True)
    |> fig.set_padding(geometry.Padding(20.0, 20.0, 20.0, 20.0))
    |> fig.add_series(fig.Series(
      "a",
      fig.line(),
      fig.numerical([#(0.0, 0.0), #(1.0, 1.0)]),
    ))
    |> fig.generate

  let rendered = svg.to_svg(chart)

  assert string.contains(rendered, "M20.00 380.00 L20.00 385.00")
  assert string.contains(rendered, "M20.00 380.00 L15.00 380.00")
}

pub fn to_svg_tick_labels_test() {
  let chart =
    fig.new()
    |> fig.set_grid(False)
    |> fig.set_ticks(True)
    |> fig.set_padding(geometry.Padding(40.0, 40.0, 40.0, 40.0))
    |> fig.set_label_offset(10.0)
    |> fig.add_series(fig.Series(
      "a",
      fig.line(),
      fig.numerical([#(0.0, 0.0), #(1.0, 1.0)]),
    ))
    |> fig.generate

  let rendered = svg.to_svg(chart)

  assert string.contains(
    rendered,
    "<text x=\"264.00\" y=\"370.00\" text-anchor=\"middle\" dominant-baseline=\"text-top\">0.4</text>",
  )
  assert string.contains(
    rendered,
    "<text x=\"30.00\" y=\"168.00\" text-anchor=\"end\" dominant-baseline=\"middle\">0.6</text>",
  )
}
