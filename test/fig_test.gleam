import fig
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

// =============================================================================
// SERIES
// =============================================================================

pub fn add_series_test() {
  let series = fig.Series("0", [fig.FloatDatum(1.0, 2.0)])
  let chart =
    fig.new()
    |> fig.add_series(series)

  assert chart.series == [series]
}

pub fn delete_series_test() {
  let series = fig.Series("0", [fig.FloatDatum(1.0, 2.0)])
  let chart =
    fig.new()
    |> fig.add_series(series)
    |> fig.delete_series("0")

  assert chart.series == []
}
