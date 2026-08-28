import gleeunit

import fig
import fig/geometry

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
// RESOLVE AXIS TESTS
// =============================================================================

pub fn generate_linear_axis_projection_test() {
  let resolved_axis =
    fig.ResolvedAxis(fig.NumericalDomain(fig.interval(-6.0, 2.0)), [
      -6.0,
      -5.0,
      -4.0,
      -3.0,
      -2.0,
      -1.0,
      0.0,
      1.0,
      2.0,
    ])

  let projection =
    fig.generate_axis_projection(
      resolved_axis,
      starting_at: geometry.Point([-8.0, 6.0]),
      ending_at: geometry.Point([7.0, 2.0]),
    )

  assert projection(-6.0) == [-8.0, 6.0]
  assert projection(2.0) == [7.0, 2.0]
  assert projection(0.0) == [3.25, 3.0]
  assert projection(3.0) == [8.875, 1.5]
}
