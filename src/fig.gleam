//// This is the main module you interact with to generate charts using fig!

// =============================================================================
// IMPORTS
// =============================================================================

import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import fig/geometry.{type Geometry}

// =============================================================================
// PUBLIC TYPES
// =============================================================================

pub type Chart {
  Chart(chart_type: Option(ChartType), series: List(Series))
}

pub type ChartType {
  LineChart
}

pub type Datum {
  FloatDatum(x: Float, y: Float)
}

pub type Series {
  Series(label: String, data: List(Datum))
}

// pub type Interval {
//   Interval(minimum: Float, maximum: Float)
// }

// pub type Scale {
//   Linear(domain: Interval, range: Interval)
//   Logarithmic(domain: Interval, range: Interval)
// }

// =============================================================================
// PRIVATE TYPES
// =============================================================================

// =============================================================================
// PUBLIC FUNCTIONS
// =============================================================================

/// Add a [`Series`](#Series) (prepends onto `chart.series`).
pub fn add_series(chart: Chart, series: Series) -> Chart {
  Chart(..chart, series: [series, ..chart.series])
}

/// Delete all instances of [`Series`](#Series) with `label` of `series_label`.
pub fn delete_series(chart: Chart, series_label: String) -> Chart {
  Chart(
    ..chart,
    series: list.drop_while(chart.series, fn(series) {
      series.label == series_label
    }),
  )
}

pub fn generate(chart: Chart) -> List(Geometry) {
  case chart.chart_type {
    Some(LineChart) -> []
    None -> []
  }
}

pub fn new() -> Chart {
  Chart(chart_type: None, series: [])
}

pub fn set_type(chart: Chart, chart_type: ChartType) -> Chart {
  Chart(..chart, chart_type: Some(chart_type))
}

pub fn main() -> Nil {
  let series =
    Series("new_series", [FloatDatum(1.0, 2.0), FloatDatum(2.0, 3.0)])

  let chart =
    new()
    |> add_series(series)
    |> set_type(LineChart)

  chart.chart_type
  |> string.inspect
  |> io.println

  generate(chart)
  |> string.inspect
  |> io.println
}
