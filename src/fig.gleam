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

import fig/geometry

// =============================================================================
// PUBLIC TYPES
// =============================================================================

/// This type is used to allow for custom dimension data types while still
/// providing type checking across series. You probably shouldn't need to use
/// this.
pub type And(head, tail)

/// A standard chart, use [`new`](#new) instead to avoid having to fill out all
/// the options. `a` represents the type of the data.
pub type Chart(a) {
  Chart(
    series: List(Series(a)),
    area: #(Float, Float),
    padding: geometry.Padding,
  )
}

/// This type is used to allow for custom dimension data types while still
/// providing type checking across series. You probably shouldn't need to use
/// this.
pub type Empty

/// A data series.
pub type Series(a) {
  Series(label: String, data: Data(a))
}

// pub type Scale {
//   Linear(domain: Interval, range: Interval)
//   Logarithmic(domain: Interval, range: Interval)
// }

// =============================================================================
// PUBLIC OPAQUE TYPES
// =============================================================================

/// Data types, construct with [`numerical`](#numerical) or
/// [`categorical`](#categorical). Kept opaque to let the axis type checking
/// work. Phantom type `b` indicates the shape of the specific holding within
/// the data wrapper, see [`datum`](#datum) and [`with`](#with) for more info
/// on custom data types.
pub opaque type Data(b) {
  Data(points: List(Datum(b)))
}

/// A single data point. Kept opaque to let the axis type checking work.
/// Phantom type `b` indicates the shape of the specific holding within the
/// data wrapper, see [`datum`](#datum) and [`with`](#with) for more info on
/// custom data types.
pub opaque type Datum(b) {
  Datum(dimensions: List(Value))
}

// Wrapper over a value in a dimension with a phantom type `c` to allow for type
// checking over different series of data.
pub opaque type Dimension(c) {
  Dimension(value: Value)
}

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

/// Tick values are basically each index multiplied/divided by spacing for
/// numerical domains.
pub opaque type TickRecipe {
  TickRecipe(first_index: Int, last_index: Int, spacing: TickSpacing)
}

// =============================================================================
// PUBLIC INTERNAL TYPES
// =============================================================================

@internal
pub type Domain {
  CategoricalDomain(List(String))
  EmptyDomain
  NumericalDomain(Interval)
}

// =============================================================================
// PRIVATE TYPES
// =============================================================================

type Value {
  Number(Float)
  Category(String)
}

// =============================================================================
// PUBLIC FUNCTIONS
// =============================================================================

/// Add a [`Series`](#Series) (prepends onto `chart.series`).
pub fn add_series(chart: Chart(a), series: Series(a)) -> Chart(a) {
  Chart(..chart, series: [series, ..chart.series])
}

/// Wrap a string or label or category within a [`Dimension`](#Dimension) type
/// when defining custom data dimensions.
pub fn category(value: String) -> Dimension(String) {
  Dimension(Category(value))
}

/// Create categorical data with `String` on the x-axis and `Float` on the
/// y-axis.
pub fn categorical(
  points: List(#(String, Float)),
) -> Data(And(Float, And(String, Empty))) {
  data(
    list.map(points, fn(point) {
      let #(x, y) = point
      datum() |> with(category(x)) |> with(number(y))
    }),
  )
}

/// Returns a [`Datum(Empty)`](#Datum) to allow you to define custom data shapes
/// when chained with [`with`](#with).
///
/// Example with two categorical values of a single datum:
///
/// ```
/// datum() |> with(category(x)) |> with(category(y))
/// ```
pub fn datum() -> Datum(Empty) {
  Datum([])
}

/// Takes a datum and then adds an additional value to the list within datum.
/// For custom data types, this can be chained both on top of an existing one
/// or to begin with, use (`datum`)[#datum]
///
/// Example with two categorical values of a single datum:
///
/// ```
/// datum() |> with(category(x)) |> with(category(y))
/// ```
pub fn with(
  datum: Datum(tail),
  dimension: Dimension(head),
) -> Datum(And(head, tail)) {
  Datum([dimension.value, ..datum.dimensions])
}

/// Create data out of a list of [`Datum`](#Datum)s.
pub fn data(points: List(Datum(a))) -> Data(a) {
  Data(points)
}

/// Delete all instances of [`Series`](#Series) with `label` of `series_label`.
pub fn delete_series(chart: Chart(a), series_label: String) -> Chart(a) {
  Chart(
    ..chart,
    series: list.filter(chart.series, fn(series) {
      series.label != series_label
    }),
  )
}

/// Union over two [`Domain`](#Domain).
///
/// Invalid operations result in EmptyDomain.
pub fn domain_union(domain_a: Domain, domain_b: Domain) {
  case domain_a, domain_b {
    EmptyDomain, EmptyDomain -> EmptyDomain
    EmptyDomain, NumericalDomain(_) -> domain_b
    NumericalDomain(_), EmptyDomain -> domain_a
    EmptyDomain, CategoricalDomain(_) -> domain_b
    CategoricalDomain(_), EmptyDomain -> domain_a
    NumericalDomain(interval_a), NumericalDomain(interval_b) -> {
      let #(Interval(a_min, a_max), Interval(b_min, b_max)) = #(
        interval_a,
        interval_b,
      )
      NumericalDomain(Interval(float.min(a_min, b_min), float.max(a_max, b_max)))
    }
    CategoricalDomain(categories_a), CategoricalDomain(categories_b) ->
      CategoricalDomain(list.append(categories_a, categories_b))
    _, _ -> EmptyDomain
  }
}

/// Gives the extents of a series in terms of a [`Domain`](#Domain). For
/// numerical axes, this would be the minimum and maximum, where as for
/// categorical ones it would be all the strings.
pub fn extents(data: Data(b)) -> List(Domain) {
  data.points
  |> list.map(fn(point) { list.reverse(point.dimensions) })
  |> list.transpose
  |> list.map(fn(values: List(Value)) -> Domain {
    case values {
      [Number(value), ..rest] ->
        NumericalDomain(numerical_domain(rest, value, value))
      [Category(category), ..rest] ->
        CategoricalDomain(categorical_domain(rest, [category]))
      [] -> EmptyDomain
    }
  })
}

/// Construct an interval, always arranges it so that the minimum value is
/// matches the labels for Interval.
pub fn interval(a: Float, b: Float) -> Interval {
  case a <=. b {
    True -> Interval(a, b)
    False -> Interval(b, a)
  }
}

pub fn generate(chart: Chart(a)) -> List(geometry.Geometry) {
  // extents of each series
  let extents =
    chart.series
    |> list.map(fn(series) { extents(series.data) })

  extents
  |> list.transpose()
  |> string.inspect
  |> io.println

  // let #(x_interval, y_interval) = #(combine_intervals(x_extents), combine_intervals(y_extents))

  // // need a config branch here for custom tick counts and strict ticks
  // let x_tick_count = float.round(chart.area.0 /. 50.0)
  // let y_tick_count = float.round(chart.area.1 /. 50.0)

  // let x_ticks = generate_ticks(x_interval, x_tick_count)

  // #(x_interval, y_interval)
  // |> string.inspect
  // |> io.print

  // Setup overall display area
  // let display =
  //   geometry.Rectangle(
  //     points: #(
  //       geometry.Point(0.0 -. chart.padding.left, 0.0 -. chart.padding.bottom),
  //       geometry.Point(
  //         chart.area.0 +. chart.padding.right,
  //         chart.area.1 +. chart.padding.top,
  //       ),
  //     ),
  //     role: geometry.Display,
  //   )

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

/// Create a new chart with default settings.
pub fn new() -> Chart(a) {
  Chart(
    series: [],
    area: #(640.0, 400.0),
    padding: geometry.Padding(40.0, 40.0, 40.0, 40.0),
  )
}

/// Wrap a number within a [`Dimension`](#Dimension) type when defining custom
/// data dimensions.
pub fn number(value: Float) -> Dimension(Float) {
  Dimension(Number(value))
}

/// Create categorical data with `Float` on the x-axis and `Float` on the
/// y-axis.
pub fn numerical(
  points: List(#(Float, Float)),
) -> Data(And(Float, And(Float, Empty))) {
  data(
    list.map(points, fn(point) {
      let #(x, y) = point
      datum() |> with(number(x)) |> with(number(y))
    }),
  )
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
// PRIVATE FUNCTIONS
// =============================================================================

fn categorical_domain(values: List(Value), acc: List(String)) -> List(String) {
  case values {
    [] -> list.reverse(acc)
    [Category(category), ..rest] ->
      case list.contains(acc, category) {
        True -> categorical_domain(rest, acc)
        False -> categorical_domain(rest, [category, ..acc])
      }
    [_, ..rest] -> categorical_domain(rest, acc)
  }
}

fn generate_ticks_recursive(
  interval: Interval,
  rough_count: Int,
  previous: Option(TickSpacing),
  iterations_remaining: Int,
) -> #(Interval, TickRecipe) {
  let tick_recipe = generate_tick_recipe(interval, rough_count)
  let spacing = tick_recipe.spacing

  case iterations_remaining, previous == Some(spacing) {
    0, _ -> #(interval, tick_recipe)
    _, True -> #(interval, tick_recipe)
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

fn numerical_domain(
  values: List(Value),
  minimum: Float,
  maximum: Float,
) -> Interval {
  case values {
    [] -> Interval(minimum, maximum)
    [Number(value), ..rest] ->
      numerical_domain(
        rest,
        float.min(minimum, value),
        float.max(maximum, value),
      )
    [_, ..rest] -> numerical_domain(rest, minimum, maximum)
  }
}

pub fn main() -> Nil {
  let series = Series("new_series", numerical([#(4.0, 2.0), #(1.0, 3.0)]))
  let series1 = Series("new_series", numerical([#(4.0, -3.0), #(5.0, 1.0)]))

  new()
  |> add_series(series)
  |> add_series(series1)
  |> generate()

  Nil
}
