import gleam/list

import gleeunit

import fig
import fig/geometry
import fig/projection

pub fn main() -> Nil {
  gleeunit.main()
}

// =============================================================================
// SERIES
// =============================================================================

pub fn add_series_test() {
  let series = fig.Series("0", fig.line(), fig.numerical([#(1.0, 2.0)]))
  let chart =
    fig.new()
    |> fig.add_series(series)

  assert chart.series == [series]
}

pub fn delete_series_test() {
  let series = fig.Series("0", fig.line(), fig.numerical([#(1.0, 2.0)]))
  let chart =
    fig.new()
    |> fig.add_series(series)
    |> fig.delete_series("0")

  assert chart.series == []
}

pub fn delete_multiple_series_test() {
  let series0 = fig.Series("0", fig.line(), fig.numerical([]))
  let series1 = fig.Series("1", fig.line(), fig.numerical([]))

  let chart =
    fig.new()
    |> fig.add_series(series0)
    |> fig.add_series(series0)
    |> fig.add_series(series1)
    |> fig.delete_series("0")

  assert chart.series == [series1]
}

// =============================================================================
// EXTENT TESTS
// =============================================================================

pub fn empty_extents_test() {
  let empty_numeric_series = fig.numerical([])
  let empty_categorical_series = fig.categorical([])

  assert fig.extents(empty_numeric_series) == []
  assert fig.extents(empty_categorical_series) == []
}

pub fn numerical_extents_test() {
  let numeric_series = fig.numerical([#(0.0, 0.0), #(-0.1, 0.0)])

  assert fig.extents(numeric_series)
    == [
      fig.NumericalDomain(fig.interval(-0.1, 0.0)),
      fig.NumericalDomain(fig.interval(0.0, 0.0)),
    ]
}

pub fn categorical_extents_test() {
  let categorical_series =
    fig.categorical([#("a", -0.3), #("b", 0.0), #("c", 5.2)])

  assert fig.extents(categorical_series)
    == [
      fig.CategoricalDomain(["a", "b", "c"]),
      fig.NumericalDomain(fig.interval(-0.3, 5.2)),
    ]
}

// =============================================================================
// DOMAIN UNION TESTS
// =============================================================================

pub fn numerical_domain_union_test() {
  let #(domain_a, domain_b) = #(
    fig.NumericalDomain(fig.interval(-0.2, 5.0)),
    fig.NumericalDomain(fig.interval(-6.0, 2.0)),
  )
  assert fig.domain_union(domain_a, domain_b)
    == fig.NumericalDomain(fig.interval(-6.0, 5.0))
}

pub fn categorical_domain_union_test() {
  let #(domain_a, domain_b) = #(
    fig.CategoricalDomain(["a", "b", "c"]),
    fig.CategoricalDomain(["d", "e"]),
  )
  assert fig.domain_union(domain_a, domain_b)
    == fig.CategoricalDomain(["a", "b", "c", "d", "e"])
}

pub fn combine_domain_test() {
  let series1 =
    fig.Series("1", fig.line(), fig.categorical([#("a", 0.8), #("b", -0.3)]))
  let series2 =
    fig.Series("2", fig.line(), fig.categorical([#("b", 0.2), #("c", 10.0)]))
  let series3 =
    fig.Series("3", fig.line(), fig.categorical([#("a", 11.0), #("d", 0.0)]))
  let series = [series1, series2, series3]

  assert fig.combine_domains(series)
    == [
      fig.CategoricalDomain(["a", "b", "c", "d"]),
      fig.NumericalDomain(fig.interval(-0.3, 11.0)),
    ]
}

// =============================================================================
// TICK GENERATION TESTS
// =============================================================================

pub fn ticks_basic_whole_numbers_test() {
  let #(interval, tick_recipe) = fig.generate_ticks(fig.interval(0.0, 96.0), 10)

  assert interval == fig.interval(0.0, 100.0)
  assert fig.tick_values(tick_recipe)
    == [0.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
}

pub fn ticks_basic_sub_one_test() {
  let #(interval, tick_recipe) =
    fig.generate_ticks(fig.interval(0.21, 0.95), 10)

  assert interval == fig.interval(0.2, 1.0)
  assert fig.tick_values(tick_recipe)
    == [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
}

pub fn ticks_negative_numbers_test() {
  let #(interval, tick_recipe) = fig.generate_ticks(fig.interval(-3.0, 7.0), 5)

  assert interval == fig.interval(-4.0, 8.0)
  assert fig.tick_values(tick_recipe) == [-4.0, -2.0, 0.0, 2.0, 4.0, 6.0, 8.0]
}

pub fn ticks_degenerate_interval_test() {
  let #(interval, tick_recipe) = fig.generate_ticks(fig.interval(1.0, 1.0), 10)

  assert interval == fig.interval(1.0, 1.0)
  assert fig.tick_values(tick_recipe) == [1.0]
}

pub fn ticks_multiple_passes_test() {
  let #(interval, tick_recipe) =
    fig.generate_ticks(fig.interval(-95.0, -89.0), 2)

  assert interval == fig.interval(-100.0, -80.0)
  assert fig.tick_values(tick_recipe) == [-100.0, -90.0, -80.0]
}

// =============================================================================
// RESOLVE AXIS TESTS
// =============================================================================

pub fn numerical_positional_axis_test() {
  let domain = fig.NumericalDomain(fig.interval(-95.0, -89.0))
  let channel = fig.PositionalChannel(2)

  assert fig.resolve_axis(domain, channel)
    == fig.ResolvedAxis(fig.NumericalDomain(fig.interval(-100.0, -80.0)), [
      -100.0,
      -90.0,
      -80.0,
    ])
}

pub fn categorical_positional_axis_test() {
  let domain = fig.CategoricalDomain(["a", "b", "c"])
  let channel = fig.PositionalChannel(2)

  assert fig.resolve_axis(domain, channel)
    == fig.ResolvedAxis(domain, [
      0.0,
      1.0,
      2.0,
    ])
}

// =============================================================================
// DOMAIN BOUNDS TESTS
// =============================================================================

pub fn numerical_domain_bounds_test() {
  assert fig.domain_bounds(fig.NumericalDomain(fig.interval(-6.0, 2.0)))
    == #(-6.0, 2.0)
}

pub fn categorical_domain_bounds_test() {
  // inset by one slot on each side so the first and last categories do not
  // sit exactly on the ends of the axis
  assert fig.domain_bounds(fig.CategoricalDomain(["a", "b", "c"]))
    == #(-1.0, 3.0)
}

// =============================================================================
// GENERATE TESTS
// =============================================================================

pub fn generate_empty_chart_test() {
  assert fig.generate(fig.new()).geometries == []
}

pub fn generate_line_chart_series_test() {
  let chart =
    fig.new()
    |> fig.add_series(fig.Series(
      "a",
      fig.line(),
      fig.numerical([#(0.0, 0.0), #(1.0, 1.0)]),
    ))

  let geometries = fig.generate(chart).geometries

  // the series is drawn last
  assert list.last(geometries)
    == Ok(geometry.Path(
      [
        geometry.MoveTo(geometry.Point([0.0, 0.0])),
        geometry.LineTo(geometry.Point([1.0, 1.0])),
      ],
      geometry.Series(0),
    ))
}

// =============================================================================
// GEOMETRY GENERATION TESTS
// =============================================================================

pub fn generate_axes_geometry_test() {
  assert fig.generate_axes_geometry(fig.AtMinimum, [0.0, 0.0], [
      #(0.0, 10.0),
      #(0.0, 100.0),
    ])
    == [
      geometry.line(
        starting_at: geometry.Point([0.0, 0.0]),
        ending_at: geometry.Point([10.0, 0.0]),
        with_role: geometry.Axis,
      ),
      geometry.line(
        starting_at: geometry.Point([0.0, 0.0]),
        ending_at: geometry.Point([0.0, 100.0]),
        with_role: geometry.Axis,
      ),
    ]
}

pub fn generate_axes_geometry_at_value_test() {
  assert fig.generate_axes_geometry(
      fig.AtValue(0.0, clamped: True),
      [2.0, 3.0],
      [
        #(0.0, 10.0),
        #(0.0, 100.0),
      ],
    )
    == [
      geometry.line(
        starting_at: geometry.Point([0.0, 3.0]),
        ending_at: geometry.Point([10.0, 3.0]),
        with_role: geometry.Axis,
      ),
      geometry.line(
        starting_at: geometry.Point([2.0, 0.0]),
        ending_at: geometry.Point([2.0, 100.0]),
        with_role: geometry.Axis,
      ),
    ]
}

pub fn generate_axes_geometry_hidden_test() {
  assert fig.generate_axes_geometry(fig.Hidden, [0.0, 0.0], [#(0.0, 10.0)])
    == []
}

pub fn generate_framed_geometry_test() {
  assert list.length(
      fig.generate_framed_geometry(True, [0.0, 0.0], [10.0, 100.0], [
        #(0.0, 10.0),
        #(0.0, 100.0),
      ]),
    )
    == 4

  assert fig.generate_framed_geometry(False, [0.0, 0.0], [10.0, 100.0], [
      #(0.0, 10.0),
    ])
    == []
}

pub fn generate_ticks_geometry_test() {
  let resolved_axes = [
    fig.ResolvedAxis(fig.NumericalDomain(fig.interval(0.0, 1.0)), [
      0.0, 0.5, 1.0,
    ]),
    fig.ResolvedAxis(fig.NumericalDomain(fig.interval(0.0, 1.0)), [0.0, 1.0]),
  ]

  assert fig.generate_ticks_geometry(
      fig.AtMinimum,
      True,
      [0.0, 0.0],
      resolved_axes,
    )
    == [
      geometry.Tick(
        geometry.Point([0.0, 0.0]),
        geometry.Point([0.0, -1.0]),
        geometry.TickMark,
      ),
      geometry.Tick(
        geometry.Point([0.5, 0.0]),
        geometry.Point([0.0, -1.0]),
        geometry.TickMark,
      ),
      geometry.Tick(
        geometry.Point([1.0, 0.0]),
        geometry.Point([0.0, -1.0]),
        geometry.TickMark,
      ),
      geometry.Tick(
        geometry.Point([0.0, 0.0]),
        geometry.Point([-1.0, 0.0]),
        geometry.TickMark,
      ),
      geometry.Tick(
        geometry.Point([0.0, 1.0]),
        geometry.Point([-1.0, 0.0]),
        geometry.TickMark,
      ),
    ]

  assert fig.generate_ticks_geometry(
      fig.Hidden,
      True,
      [0.0, 0.0],
      resolved_axes,
    )
    == []

  assert fig.generate_ticks_geometry(
      fig.AtMinimum,
      False,
      [0.0, 0.0],
      resolved_axes,
    )
    == []
}

pub fn generate_grid_geometry_test() {
  let resolved_axes = [
    fig.ResolvedAxis(fig.NumericalDomain(fig.interval(0.0, 10.0)), [0.0, 10.0]),
    fig.ResolvedAxis(fig.NumericalDomain(fig.interval(0.0, 100.0)), [50.0]),
  ]

  assert fig.generate_grid_geometry(
      True,
      [0.0, 0.0],
      [#(0.0, 10.0), #(0.0, 100.0)],
      resolved_axes,
    )
    == [
      geometry.line(
        starting_at: geometry.Point([0.0, 50.0]),
        ending_at: geometry.Point([10.0, 50.0]),
        with_role: geometry.Grid,
      ),
      geometry.line(
        starting_at: geometry.Point([0.0, 0.0]),
        ending_at: geometry.Point([0.0, 100.0]),
        with_role: geometry.Grid,
      ),
      geometry.line(
        starting_at: geometry.Point([10.0, 0.0]),
        ending_at: geometry.Point([10.0, 100.0]),
        with_role: geometry.Grid,
      ),
    ]

  assert fig.generate_grid_geometry(
      False,
      [0.0, 0.0],
      [#(0.0, 10.0), #(0.0, 100.0)],
      resolved_axes,
    )
    == []
}

// =============================================================================
// TICK LABEL TESTS
// =============================================================================

pub fn numerical_tick_label_content_test() {
  let domain = fig.NumericalDomain(fig.interval(0.0, 1.0))

  assert fig.tick_label_content(domain, 0.25, 2) == "0.25"
  assert fig.tick_label_content(domain, 3.0, 0) == "3"
}

pub fn categorical_tick_label_content_test() {
  let domain = fig.CategoricalDomain(["alpha", "beta", "gamma"])

  assert fig.tick_label_content(domain, 0.0, 0) == "alpha"
  assert fig.tick_label_content(domain, 2.0, 0) == "gamma"
}

pub fn generate_tick_labels_categorical_test() {
  let resolved_axes = [
    fig.ResolvedAxis(fig.CategoricalDomain(["alpha", "beta"]), [0.0, 1.0]),
    fig.ResolvedAxis(fig.NumericalDomain(fig.interval(0.0, 1.0)), [0.0, 1.0]),
  ]

  assert fig.generate_tick_labels(
      fig.AtMinimum,
      True,
      [0.0, 0.0],
      resolved_axes,
    )
    == [
      geometry.Text(
        geometry.Point([0.0, 0.0]),
        geometry.Point([0.0, -1.0]),
        "alpha",
        geometry.TickLabel,
      ),
      geometry.Text(
        geometry.Point([1.0, 0.0]),
        geometry.Point([0.0, -1.0]),
        "beta",
        geometry.TickLabel,
      ),
      geometry.Text(
        geometry.Point([0.0, 0.0]),
        geometry.Point([-1.0, 0.0]),
        "0",
        geometry.TickLabel,
      ),
      geometry.Text(
        geometry.Point([0.0, 1.0]),
        geometry.Point([-1.0, 0.0]),
        "1",
        geometry.TickLabel,
      ),
    ]
}

// =============================================================================
// GENERATE PROJECTION TESTS
// =============================================================================

pub fn generate_projection_fixed_padding_test() {
  let chart =
    fig.new() |> fig.set_padding(geometry.Padding(20.0, 20.0, 20.0, 20.0))

  let projection =
    fig.generate_projection(chart, [#(0.0, 1.0), #(0.0, 1.0)], [], [])

  assert projection.project(projection, geometry.Point([0.0, 0.0]))
    == projection.ScreenCoordinates(20.0, 380.0, 0.0)
}

pub fn generate_projection_auto_padding_test() {
  let chart = fig.new() |> fig.set_padding(geometry.AutoPadding)

  let projection =
    fig.generate_projection(chart, [#(0.0, 1.0), #(0.0, 1.0)], [], [])

  assert projection.project(projection, geometry.Point([0.0, 0.0]))
    == projection.ScreenCoordinates(10.0, 390.0, 0.0)
}

pub fn generate_projection_measures_labels_test() {
  let chart = fig.new() |> fig.set_padding(geometry.AutoPadding)

  let label =
    geometry.Text(
      at: geometry.Point([0.0, 0.0]),
      offset: geometry.Point([-1.0, 0.0]),
      content: "1000",
      role: geometry.TickLabel,
    )

  let projection =
    fig.generate_projection(chart, [#(0.0, 1.0), #(0.0, 1.0)], [], [label])

  let projection.ScreenCoordinates(x, _, _) =
    projection.project(projection, geometry.Point([0.0, 0.0]))

  assert x >. 10.0
}

pub fn generate_projection_caps_padding_test() {
  let chart =
    fig.new()
    |> fig.set_area(#(100.0, 100.0))
    |> fig.set_padding(geometry.AutoPadding)

  // a very very very very very long label
  let label =
    geometry.Text(
      at: geometry.Point([0.0, 0.0]),
      offset: geometry.Point([-1.0, 0.0]),
      content: "a very very very very very long label",
      role: geometry.TickLabel,
    )

  let projection =
    fig.generate_projection(chart, [#(0.0, 1.0), #(0.0, 1.0)], [], [label])

  let projection.ScreenCoordinates(x, _, _) =
    projection.project(projection, geometry.Point([0.0, 0.0]))

  assert x <=. 40.0
}
