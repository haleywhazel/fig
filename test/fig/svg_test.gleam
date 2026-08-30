import gleam/list
import gleam/string

import fig
import fig/geometry
import fig/svg

// =============================================================================
// BASIC SVG GENERATION
// =============================================================================

pub fn to_svg_empty_chart_test() {
  assert svg.to_svg(fig.new())
    == "<svg viewBox=\"0 0 640 400\" font-family=\"sans-serif\" xmlns=\"http://www.w3.org/2000/svg\"></svg>"
}

pub fn to_svg_view_box_test() {
  let rendered =
    fig.new()
    |> fig.set_area(#(300.0, 150.0))
    |> svg.to_svg

  assert string.contains(rendered, "viewBox=\"0 0 300 150\"")
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

  let rendered = svg.to_svg(chart)

  // the plot area runs x 20..620 and y 20..380
  assert string.contains(rendered, "d=\"M20.00 380.00 L620.00 380.00\"")
  assert string.contains(rendered, "d=\"M20.00 380.00 L20.00 20.00\"")
  assert string.contains(rendered, "d=\"M20.00 380.00 L620.00 20.00\"")

  // two axes and one series
  assert list.length(string.split(rendered, "<path")) == 4

  assert string.contains(rendered, "class=\"fig-axis\"")
  assert string.contains(rendered, "class=\"fig-series fig-series-0\"")
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

  // both axes have a tick at the origin, both come out same length
  assert string.contains(rendered, "d=\"M20.00 380.00 L20.00 385.00\"")
  assert string.contains(rendered, "d=\"M20.00 380.00 L15.00 380.00\"")
}

pub fn to_svg_tick_labels_test() {
  let chart =
    fig.new()
    |> fig.set_grid(False)
    |> fig.set_ticks(True)
    |> fig.set_padding(geometry.Padding(40.0, 40.0, 40.0, 40.0))
    |> fig.set_tick_label_offset(10.0)
    |> fig.add_series(fig.Series(
      "a",
      fig.line(),
      fig.numerical([#(0.0, 0.0), #(1.0, 1.0)]),
    ))
    |> fig.generate

  let rendered = svg.to_svg(chart)

  assert string.contains(rendered, ">0.4</text>")
  assert string.contains(rendered, ">0.6</text>")

  assert string.contains(rendered, "x=\"264.00\" y=\"370.00\"")
  assert string.contains(rendered, "x=\"30.00\" y=\"168.00\"")

  assert string.contains(rendered, "text-anchor=\"middle\"")
  assert string.contains(rendered, "text-anchor=\"end\"")
}

// =============================================================================
// PADDING
// =============================================================================

pub fn to_svg_auto_padding_test() {
  let chart =
    fig.new()
    |> fig.set_grid(False)
    |> fig.set_ticks(True)
    |> fig.set_padding(geometry.AutoPadding)
    |> fig.add_series(fig.Series(
      "a",
      fig.line(),
      fig.numerical([#(0.0, 0.0), #(1.0, 1.0)]),
    ))
    |> fig.generate

  let rendered = svg.to_svg(chart)

  // no coordinate comes out negative if auto padded
  assert !string.contains(rendered, "\"-")
  assert !string.contains(rendered, " -")
}

pub fn to_svg_zero_padding_overflows_test() {
  let chart =
    fig.new()
    |> fig.set_grid(False)
    |> fig.set_ticks(True)
    |> fig.set_padding(geometry.Padding(0.0, 0.0, 0.0, 0.0))
    |> fig.add_series(fig.Series(
      "a",
      fig.line(),
      fig.numerical([#(0.0, 0.0), #(1.0, 1.0)]),
    ))
    |> fig.generate

  let rendered = svg.to_svg(chart)

  // something is off the screen
  assert string.contains(rendered, "\"-")
}

// =============================================================================
// CATEGORICAL LABELS
// =============================================================================

pub fn to_svg_categorical_labels_test() {
  let chart =
    fig.new()
    |> fig.set_grid(False)
    |> fig.set_ticks(True)
    |> fig.set_padding(geometry.AutoPadding)
    |> fig.add_series(fig.Series(
      "a",
      fig.line(),
      fig.categorical([#("alpha", 1.0), #("beta", 2.0)]),
    ))
    |> fig.generate

  let rendered = svg.to_svg(chart)

  // the categorical axis holds its ticks as indices, so these would read
  // "0" and "1" if the domain were not consulted
  assert string.contains(rendered, ">alpha</text>")
  assert string.contains(rendered, ">beta</text>")
}

pub fn to_svg_escapes_labels_test() {
  let chart =
    fig.new()
    |> fig.set_grid(False)
    |> fig.set_ticks(True)
    |> fig.set_padding(geometry.AutoPadding)
    |> fig.add_series(fig.Series(
      "a",
      fig.line(),
      fig.categorical([#("a & b", 1.0), #("<c>", 2.0)]),
    ))
    |> fig.generate

  let rendered = svg.to_svg(chart)

  // category names are user data, so an unescaped one breaks the document
  assert string.contains(rendered, ">a &amp; b</text>")
  assert string.contains(rendered, ">&lt;c&gt;</text>")
}
