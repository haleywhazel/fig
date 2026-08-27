import gleam/option.{None, Some}

import fig
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

// =============================================================================
// SERIES
// =============================================================================

pub fn add_series_test() {
  let series = fig.LineSeries("0", fig.Numeric([#(1.0, 2.0)]))
  let chart =
    fig.new()
    |> fig.add_series(series)

  assert chart.series == [series]
}

pub fn delete_series_test() {
  let series = fig.LineSeries("0", fig.Numeric([#(1.0, 2.0)]))
  let chart =
    fig.new()
    |> fig.add_series(series)
    |> fig.delete_series("0")

  assert chart.series == []
}

pub fn delete_multiple_series_test() {
  let series0 = fig.LineSeries("0", fig.Numeric([]))
  let series1 = fig.LineSeries("1", fig.Numeric([]))

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

pub fn extents_test() {
  let empty_numeric_series = fig.Numeric([])
  let empty_categorical_series = fig.Categorical([])

  assert fig.extents(empty_numeric_series) == #(None, None)
  assert fig.extents(empty_categorical_series) == #(None, None)

  let numeric_series = fig.Numeric([#(0.0, 0.0), #(-0.1, 0.0)])

  assert fig.extents(numeric_series)
    == #(Some(fig.interval(-0.1, 0.0)), Some(fig.interval(0.0, 0.0)))

  let categorical_series =
    fig.Categorical([#("a", -0.3), #("b", 0.0), #("c", 5.2)])

  assert fig.extents(categorical_series)
    == #(None, Some(fig.interval(-0.3, 5.2)))
}

pub fn interval_union_test() {
  let #(interval_a, interval_b) = #(
    fig.interval(-0.2, 5.0),
    fig.interval(-6.0, 2.0),
  )
  assert fig.interval_union(interval_a, interval_b) == fig.interval(-6.0, 5.0)
}

// =============================================================================
// TICK GENERATION TESTS
// =============================================================================

pub fn ticks_basic_whole_numbers_test() {
  let #(interval, tick_recipe) = fig.generate_ticks(fig.interval(0.0, 96.0), 10)
  let tick_values = fig.tick_values(tick_recipe)

  assert interval == fig.interval(0.0, 100.0)
  assert tick_values
    == [0.0, 10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
}

pub fn ticks_basic_sub_one_test() {
  let #(interval, tick_recipe) =
    fig.generate_ticks(fig.interval(0.21, 0.95), 10)
  let tick_values = fig.tick_values(tick_recipe)

  assert interval == fig.interval(0.2, 1.0)
  assert tick_values == [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
}

pub fn ticks_negative_numbers_test() {
  let #(interval, tick_recipe) = fig.generate_ticks(fig.interval(-3.0, 7.0), 5)
  let tick_values = fig.tick_values(tick_recipe)

  assert interval == fig.interval(-4.0, 8.0)
  assert tick_values == [-4.0, -2.0, 0.0, 2.0, 4.0, 6.0, 8.0]
}

pub fn ticks_degenerate_interval_test() {
  let #(interval, tick_recipe) = fig.generate_ticks(fig.interval(1.0, 1.0), 10)
  let tick_values = fig.tick_values(tick_recipe)

  assert interval == fig.interval(1.0, 1.0)
  assert tick_values == [1.0]
}
