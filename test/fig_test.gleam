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
