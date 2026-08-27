//// This is the main module you interact with to generate charts using fig!

// =============================================================================
// IMPORTS
// =============================================================================

import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
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

/// For sub-1 steps, we need spacing to be exact. Multiplying by a sub-1 float
/// wouldn't give the closest adjacent double to the value we actually want, so
/// spacing becomes split into `Multiply` and `Divide`.
pub opaque type TickSpacing {
  Multiply(Float)
  Divide(Float)
}

/// Tick values are basically each index multiplied/divided by spacing.
pub opaque type TickRecipe {
  TickRecipe(first_index: Int, last_index: Int, spacing: TickSpacing)
}

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
    series: list.filter(chart.series, fn(series) {
      series.label != series_label
    }),
  )
}

/// Construct an interval, always arranges it so that the minimum value is
/// matches the labels for Interval.
pub fn interval(a: Float, b: Float) -> Interval {
  case a <=. b {
    True -> Interval(a, b)
    False -> Interval(b, a)
  }
}

pub fn generate(chart: Chart) -> List(Geometry) {
  []
}

/// Updating an interval so that it has nice step values, inspired by the D3
/// nice function. `rough_count` is the rough number of counts you are targeting
/// for the ticks, rather than a strict number id adheres to to make sure
/// the resulting output is nice to read.
pub fn generate_ticks(
  interval: Interval,
  rough_count: Int,
) -> #(Interval, TickRecipe) {
  // D3 uses 10 iterations
  generate_ticks_recursive(interval, rough_count, None, 10)
}

pub fn new() -> Chart {
  Chart(series: [], chart_area: #(640.0, 400.0))
}

pub fn tick_values(tick_recipe: TickRecipe) -> List(Float) {
  list.repeat(Nil, tick_recipe.last_index - tick_recipe.first_index + 1)
  |> list.index_map(fn(_, offset) {
    case tick_recipe.spacing {
      Multiply(spacing) ->
        int.to_float(tick_recipe.first_index + offset) *. spacing
      Divide(divisor) ->
        int.to_float(tick_recipe.first_index + offset) /. divisor
    }
  })
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

// =============================================================================
// PRIVATE FUNCTIONS
// =============================================================================

fn generate_ticks_recursive(
  interval: Interval,
  rough_count: Int,
  previous: Option(TickSpacing),
  iterations_remaining: Int,
) -> #(Interval, TickRecipe) {
  let tick_recipe = generate_tick_recipe(interval, rough_count)

  case iterations_remaining, previous {
    0, Some(_) -> #(interval, tick_recipe)
    _, _ -> {
      let widened = case tick_recipe.spacing {
        Multiply(spacing) ->
          Interval(
            float.floor(interval.minimum /. spacing) *. spacing,
            float.ceiling(interval.maximum /. spacing) *. spacing,
          )
        Divide(divisor) ->
          Interval(
            float.floor(interval.minimum *. divisor) /. divisor,
            float.ceiling(interval.maximum *. divisor) /. divisor,
          )
      }
      generate_ticks_recursive(
        widened,
        rough_count,
        Some(tick_recipe.spacing),
        iterations_remaining - 1,
      )
    }
  }
}

/// Setup the ticks by finding nice values that work with a certain interval and
/// a rough tick count as a target.
fn generate_tick_recipe(interval: Interval, rough_count: Int) -> TickRecipe {
  let ln10 = 2.302_585_092_994_046
  let sqrt50 = 7.071_067_811_865_476
  let sqrt10 = 3.162_277_660_168_379_5
  let sqrt2 = 1.414_213_562_373_095_1

  // base-10 log that unwraps to 1.0
  let log10 = fn(x: Float) -> Float {
    {
      float.logarithm(x)
      |> result.unwrap(0.0)
    }
    /. ln10
  }

  let raw_step =
    { interval.maximum -. interval.minimum }
    /. { float.max(int.to_float(rough_count), 1.0) }

  let order_of_magnitude = float.floor(log10(raw_step))
  let magnitude = float.power(10.0, order_of_magnitude) |> result.unwrap(1.0)
  let leading_digit = raw_step /. magnitude

  // multiplier that turns order of magnitude into a tick step
  // set it to 10 if it's above the geometric mean of 10 and 5 etc
  // basically constraints tick steps to 1, 2, 5, 10 etc
  let factor = case leading_digit {
    leading_digit if leading_digit >=. sqrt50 -> 10.0
    leading_digit if leading_digit >=. sqrt10 -> 5.0
    leading_digit if leading_digit >=. sqrt2 -> 2.0
    _ -> 1.0
  }

  case order_of_magnitude <. 0.0 {
    True -> {
      let divisor =
        { float.power(10.0, 0.0 -. order_of_magnitude) |> result.unwrap(1.0) }
        /. factor

      let first = float.round(interval.minimum *. divisor)
      let last = float.round(interval.maximum *. divisor)

      TickRecipe(
        first_index: case int.to_float(first) /. divisor <. interval.minimum {
          True -> first + 1
          False -> first
        },
        last_index: case int.to_float(last) /. divisor >. interval.maximum {
          True -> last - 1
          False -> last
        },
        spacing: Divide(divisor),
      )
    }
    False -> {
      let step = magnitude *. factor

      let first = float.round(interval.minimum /. step)
      let last = float.round(interval.maximum /. step)

      TickRecipe(
        first_index: case int.to_float(first) *. step <. interval.minimum {
          True -> first + 1
          False -> first
        },
        last_index: case int.to_float(last) *. step >. interval.maximum {
          True -> last - 1
          False -> last
        },
        spacing: Multiply(step),
      )
    }
  }
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
