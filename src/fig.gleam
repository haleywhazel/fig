//// This is the main module you interact with to generate charts using fig!

// =============================================================================
// IMPORTS
// =============================================================================

import gleam/float
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string

import fig/geometry.{type Geometry}

// =============================================================================
// PUBLIC TYPES
// =============================================================================

/// A standard chart, use [`new`](#new) instead to avoid having to fill out all
/// the options. `a` and `b` are the types of the x- and y-axis.
pub type Chart {
  Chart(series: List(Series), chart_area: #(Float, Float))
}

/// Data types, construct with [`numeric`](#numeric) or
/// [`categorical`](#categorical).
pub type Data {
  /// Set up numeric data from `List(#(Float, Float))`, convert to this format
  /// first, even if the data should be integers.
  Numeric(List(#(Float, Float)))

  /// Set up categorical data from `List(#(String, Float))`, convert to this
  /// format first.
  Categorical(List(#(String, Float)))
}

/// A data series.
pub type Series {
  LineSeries(label: String, data: Data)
}

// pub type Scale {
//   Linear(domain: Interval, range: Interval)
//   Logarithmic(domain: Interval, range: Interval)
// }

// =============================================================================
// PUBLIC OPAQUE TYPES
// =============================================================================

/// Any numerical (`Float`) interval between a minimum or a maximum. Construct
/// with [`interval`](#interval).
pub opaque type Interval {
  Interval(minimum: Float, maximum: Float)
}

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
    series: list.filter(chart.series, fn(series) {
      series.label != series_label
    }),
  )
}

/// Construct an interval.
pub fn interval(a: Float, b: Float) -> Interval {
  case a <=. b {
    True -> Interval(a, b)
    False -> Interval(b, a)
  }
}

pub fn generate(chart: Chart) -> List(Geometry) {
  []
}

pub fn new() -> Chart {
  Chart(series: [], chart_area: #(640.0, 400.0))
}

// =============================================================================
// PUBLIC INTERNAL FUNCTIONS
// =============================================================================

/// Gives the extents of a series. Returns a tuple of [`Interval`](#Interval) as
/// options, where the tuple content will be `None` if not a numeric type.
@internal
pub fn extents(data: Data) -> #(Option(Interval), Option(Interval)) {
  case data {
    Numeric([]) | Categorical([]) -> #(None, None)

    // To make things easier to read independent and dependent are shortened to
    // i and d. For typical line graphs, this would be values on the x & y axes.
    Numeric([#(i, d), ..rest]) -> {
      let #(i_min, i_max, d_min, d_max) =
        list.fold(rest, #(i, i, d, d), fn(acc, point) {
          let #(i_min, i_max, d_min, d_max) = acc
          let #(i, d) = point
          #(
            float.min(i_min, i),
            float.max(i_max, i),
            float.min(d_min, d),
            float.max(d_max, d),
          )
        })
      #(Some(Interval(i_min, i_max)), Some(Interval(d_min, d_max)))
    }

    Categorical([#(_, d), ..rest]) -> {
      let #(d_min, d_max) =
        list.fold(rest, #(d, d), fn(acc, point) {
          let #(d_min, d_max) = acc
          let #(_, d) = point
          #(float.min(d_min, d), float.max(d_max, d))
        })
      #(None, Some(Interval(d_min, d_max)))
    }
  }
}

/// Union over two [`Interval`](#Interval).
@internal
pub fn interval_union(a: Interval, b: Interval) {
  let #(Interval(a_min, a_max), Interval(b_min, b_max)) = #(a, b)
  Interval(float.min(a_min, b_min), float.max(a_max, b_max))
}

pub fn main() -> Nil {
  let series = LineSeries("new_series", Numeric([#(1.0, 2.0), #(2.0, 3.0)]))

  let chart =
    new()
    |> add_series(series)

  chart.series
  |> string.inspect
  |> io.println

  generate(chart)
  |> string.inspect
  |> io.println
}
