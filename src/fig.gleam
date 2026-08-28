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
import fig/projection

// =============================================================================
// PUBLIC TYPES
// =============================================================================

/// This type is used to allow for custom dimension data types while still
/// providing type checking across series.
///
/// You probably shouldn't need to use this directly, although if you see this
/// in a type error, that means that you probably have some mismatched data
/// types or axes types.
///
/// Also note that the dimensions are shown in reverse order since it uses
/// type-level pre-pend.
pub type And(head, tail)

/// Defines the type of an axis, e.g. a simple x-axis with float values that are
/// determined by position on the screen would be `Axis(Float, Position`).
pub type Axis(data_type, channel)

/// The way that a dimension of data is represented within a plot, e.g. through
/// position or colour.
pub type Channel {
  PositionalChannel(rough_tick_count: Int)
}

/// A standard chart, use [`new`](#new) instead to avoid having to fill out all
/// the options. `shape` represents the type of the data.
pub type Chart(shape) {
  Chart(
    series: List(Series(shape)),
    area: #(Float, Float),
    padding: geometry.Padding,
    projection: projection.Projection,
    geometries: List(geometry.Geometry),
    view: projection.View,
  )
}

/// A domain of values across a single dimension or axis.
pub type Domain {
  CategoricalDomain(List(String))
  // Construct the [`Interval`](#Interval) using [`interval`](#interval) which
  // sanitises the input to ensure that the smaller value is always first.
  NumericalDomain(Interval)
}

/// This type is used to allow for custom dimension data types while still
/// providing type checking across series.
///
/// You probably shouldn't need to use this directly, although if you see this
/// in a type error, that means that you probably have some mismatched data
/// types or axes types.
///
pub type Empty

/// If a dimension is expressed as positional, that means that its data points
/// should match up to some sort of position on the screen. This is mostly used
/// type checking, the actual sum type over all the possible channels would
/// be [`Channel`](#Channel)
pub type Positional

/// A single resolved axis with a [`Domain`](#Domain) and the ticks as float
/// positions associated with it.
pub type ResolvedAxis {
  ResolvedAxis(domain: Domain, ticks: List(Float))
}

/// A data series.
///
/// * `label`: the label of the series
/// * `drawn_as`: how the graph is drawn, e.g. [`line`](#line)
/// * `data`: the data, e.g. constructed using [`numerical`](#numerical)
///
/// If `drawn_as` and `data` have incompatible shapes, a type error should show
/// up. Anytime you see a long type errors with types kind of looking like:
/// `Data(And(Axis(y, Positional), And(Axis(x, Positional), Empty)))`, that
/// means that either the data type of your actual data or the drawing type
/// disagree with each other.
pub type Series(shape) {
  Series(label: String, drawn_as: Drawing(shape), data: Data(shape))
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
pub opaque type Data(data_type) {
  Data(points: List(Datum(data_type)))
}

/// A single data point. Kept opaque to let the axis type checking work.
/// Phantom type `b` indicates the shape of the specific holding within the
/// data wrapper, see [`datum`](#datum) and [`with`](#with) for more info on
/// custom data types.
pub opaque type Datum(data_type) {
  Datum(dimensions: List(Value))
}

// Wrapper over a value in a dimension with a phantom type `c` to allow for type
// checking over different series of data.
pub opaque type Dimension(value_type) {
  Dimension(value: Value)
}

// How the [`Series`](#Series) is drawn as (e.g. line, bar) etc. Keeps the
// phantom type `a` to ensure that the type of data required by the graph or
// chart drawn matches that of the series data.
pub opaque type Drawing(shape) {
  Drawing(drawing_type: DrawingType)
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
// PRIVATE TYPES
// =============================================================================

type DrawingRequirements {
  DrawingRequirements(channels: List(Channel))
}

type DrawingType {
  Line(drawing_requirements: DrawingRequirements)
}

type Value {
  Number(Float)
  Category(String)
}

// =============================================================================
// PUBLIC FUNCTIONS
// =============================================================================

/// Add a [`Series`](#Series) (prepends onto `chart.series`).
///
/// Note that adding a series resets the existing generated geometries to make
/// sure that you don't accidentally forget to run [`generate`](#generate)
/// again after adding a series.
pub fn add_series(
  to_chart chart: Chart(shape),
  series series: Series(shape),
) -> Chart(shape) {
  Chart(
    ..chart,
    series: [series, ..chart.series],
    geometries: [],
    projection: projection.empty_projection(),
  )
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
) -> Data(And(Axis(Float, channel), And(Axis(String, channel), Empty))) {
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
) -> Datum(And(Axis(head, channel), tail)) {
  Datum([dimension.value, ..datum.dimensions])
}

/// Given a list of series, combine the domains across the series to give a
/// list of [`Domain`](#Domain) for each individual dimension.
pub fn combine_domains(series: List(Series(shape))) -> List(Domain) {
  series
  |> list.map(fn(series) { extents(series.data) })
  |> list.transpose()
  |> list.map(fn(dimension) {
    list.reduce(dimension, domain_union)
    |> result.unwrap(NumericalDomain(interval(0.0, 1.0)))
  })
}

/// Create data out of a list of [`Datum`](#Datum)s.
pub fn data(points: List(Datum(shape))) -> Data(shape) {
  Data(points)
}

/// Delete all instances of [`Series`](#Series) with `label` of `series_label`.
///
/// Note that deleting a series resets the existing generated geometries to make
/// sure that you don't accidentally forget to run [`generate`](#generate)
/// again after deleting a series.
pub fn delete_series(
  from_chart chart: Chart(shape),
  series_label series_label: String,
) -> Chart(shape) {
  Chart(
    ..chart,
    series: list.filter(chart.series, fn(series) {
      series.label != series_label
    }),
    geometries: [],
    projection: projection.empty_projection(),
  )
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
      [Number(_), ..] -> NumericalDomain(numerical_domain(values))
      [Category(_), ..] -> CategoricalDomain(categorical_domain(values))
      // should be unreachable, throwing a default value in here
      [] -> NumericalDomain(interval(0.0, 1.0))
    }
  })
}

pub fn generate(chart: Chart(shape)) -> Chart(shape) {
  // TODO: some drawing_requirements should be able to be overriden by user
  // this feels a bit redundant right now but it's make more sense when there's
  // more stuff in
  let drawing_requirements =
    chart.series
    |> list.map(fn(series) { series.drawn_as.drawing_type.drawing_requirements })
    |> list.reduce(fn(previous_requirement, current_requirement) {
      DrawingRequirements(
        channels: list.map2(
          previous_requirement.channels,
          current_requirement.channels,
          fn(previous_channel, current_channel) {
            case previous_channel, current_channel {
              PositionalChannel(x), PositionalChannel(y) ->
                PositionalChannel(int.max(x, y))
            }
          },
        ),
      )
    })
    |> result.unwrap(DrawingRequirements(channels: []))

  // extents of each series; TODO: override the extents of one particular dim
  let extents = combine_domains(chart.series)

  // generated axes with ticks; TODO modify tick_count hardcodedness, user
  // defined stuff
  //
  // resolved_axes only returns positional channels
  let resolved_axes =
    list.zip(extents, drawing_requirements.channels)
    |> list.filter_map(with: fn(dimension) {
      let #(domain, channel) = dimension
      case channel {
        // only positional channels become axes; colour and size will not
        PositionalChannel(_) -> Ok(resolve_axis(domain, channel))
      }
    })

  let bounds = list.map(resolved_axes, fn(axis) { domain_bounds(axis.domain) })
  let minimums = list.map(bounds, fn(bound) { bound.0 })

  // set projection
  let projection =
    projection.new(
      bounds:,
      area: chart.area,
      padding: chart.padding,
      view: chart.view,
    )

  let axes_geometry =
    bounds
    |> list.index_map(fn(bound, index) {
      let #(minimum, maximum) = bound
      let corner = fn(value: Float) {
        list.index_map(minimums, fn(other, other_index) {
          case other_index == index {
            True -> value
            False -> other
          }
        })
      }

      geometry.axis(
        starting_at: geometry.Point(corner(minimum)),
        ending_at: geometry.Point(corner(maximum)),
      )
    })

  let series_geometry =
    chart.series
    |> list.reverse
    |> list.index_map(fn(series, index) {
      let commands =
        series.data.points
        |> list.map(fn(datum) { coordinates_of(datum, resolved_axes) })
        |> list.index_map(fn(point, position) {
          case position {
            0 -> geometry.MoveTo(geometry.Point(point))
            _ -> geometry.LineTo(geometry.Point(point))
          }
        })

      geometry.Path(commands, geometry.Series(index))
    })

  Chart(
    ..chart,
    projection: projection,
    geometries: list.append(axes_geometry, series_geometry),
  )
}

/// Updating an interval so that it has nice step values, inspired by the D3
/// nice function. `rough_count` is the rough number of counts you are targeting
/// for the ticks, rather than a strict number id adheres to to make sure
/// the resulting output is nice to read.
pub fn generate_ticks(
  interval: Interval,
  rough_count: Int,
) -> #(Interval, TickRecipe) {
  // D3 uses 10 iterations, I think most cases should end before then
  generate_ticks_recursive(interval, rough_count, None, 10)
}

/// Construct an interval, always arranges it so that the minimum value is
/// matches the labels for Interval.
pub fn interval(a: Float, b: Float) -> Interval {
  case a <=. b {
    True -> Interval(a, b)
    False -> Interval(b, a)
  }
}

/// Constructor of a standard 2D line graph, with independent axis on x and
/// dependent axis on y. By default, we include 5 ticks per axes.
pub fn line() -> Drawing(
  And(Axis(y, Positional), And(Axis(x, Positional), Empty)),
) {
  Drawing(
    Line(DrawingRequirements([PositionalChannel(5), PositionalChannel(5)])),
  )
}

/// Create a new chart with default settings.
pub fn new() -> Chart(a) {
  Chart(
    series: [],
    area: #(640.0, 400.0),
    padding: geometry.Padding(20.0, 20.0, 20.0, 20.0),
    projection: projection.empty_projection(),
    geometries: [],
    view: projection.isometric(),
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
) -> Data(And(Axis(Float, channel), And(Axis(Float, channel), Empty))) {
  data(
    list.map(points, fn(point) {
      let #(x, y) = point
      datum() |> with(number(x)) |> with(number(y))
    }),
  )
}

/// Resolve a single domain into an axis based on the channel
pub fn resolve_axis(
  domain domain: Domain,
  with_channel channel: Channel,
) -> ResolvedAxis {
  case domain, channel {
    NumericalDomain(interval), PositionalChannel(rough_tick_count) -> {
      let #(interval, recipe) = generate_ticks(interval, rough_tick_count)
      ResolvedAxis(NumericalDomain(interval), tick_values(recipe))
    }
    CategoricalDomain(categories), PositionalChannel(_) -> {
      ResolvedAxis(
        domain,
        list.index_map(categories, fn(_, position) { int.to_float(position) }),
      )
    }
  }
}

/// Retrieve tick values for a numerical line based on a
/// [`TickRecipe`](#TickRecipe)
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

/// Union over two [`Domain`](#Domain).
@internal
pub fn domain_union(domain_a: Domain, domain_b: Domain) {
  case domain_a, domain_b {
    NumericalDomain(interval_a), NumericalDomain(interval_b) -> {
      let #(Interval(a_min, a_max), Interval(b_min, b_max)) = #(
        interval_a,
        interval_b,
      )
      NumericalDomain(Interval(float.min(a_min, b_min), float.max(a_max, b_max)))
    }
    CategoricalDomain(categories_a), CategoricalDomain(categories_b) ->
      CategoricalDomain(list.append(categories_a, categories_b) |> list.unique)

    // should in theory be unreachable as the phantom type should catch it at
    // compile time
    _, _ -> domain_a
  }
}

/// The bounds of a [`Domain`](#Domain).
///
/// Categorical domains have an extra space on each side so that the first and
/// last categories aren't exactly at the ends.
@internal
pub fn domain_bounds(domain: Domain) -> #(Float, Float) {
  case domain {
    NumericalDomain(interval) -> #(interval.minimum, interval.maximum)
    CategoricalDomain(categories) -> #(
      -1.0,
      int.to_float(list.length(categories)),
    )
  }
}

// =============================================================================
// PRIVATE FUNCTIONS
// =============================================================================

fn categorical_domain(values: List(Value)) -> List(String) {
  // filter_map is here but type checking means that it should be impossible to
  // have number within a category dimension
  values
  |> list.filter_map(category_of)
  |> list.unique
}

fn category_of(value: Value) -> Result(String, Nil) {
  case value {
    Category(category) -> Ok(category)
    Number(_) -> Error(Nil)
  }
}

// datum -> plain numbers in axis order
fn coordinates_of(
  datum: Datum(shape),
  resolved_axes: List(ResolvedAxis),
) -> List(Float) {
  list.map2(list.reverse(datum.dimensions), resolved_axes, fn(value, axis) {
    case value, axis.domain {
      Number(number), _ -> number
      Category(category), CategoricalDomain(categories) ->
        categories
        |> list.take_while(fn(other) { other != category })
        |> list.length
        |> int.to_float
      // should be unreachable
      Category(_), _ -> 0.0
    }
  })
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

fn number_of(value: Value) -> Result(Float, Nil) {
  case value {
    Number(number) -> Ok(number)
    Category(_) -> Error(Nil)
  }
}

fn numerical_domain(values: List(Value)) -> Interval {
  // filter_map is here but type checking means that it should be impossible to
  // have category within a number dimension
  case list.filter_map(values, number_of) {
    [] -> interval(0.0, 1.0)
    [first, ..rest] -> {
      let #(minimum, maximum) =
        list.fold(rest, #(first, first), fn(acc, number) {
          let #(minimum, maximum) = acc
          #(float.min(minimum, number), float.max(maximum, number))
        })
      Interval(minimum, maximum)
    }
  }
}

pub fn main() -> Nil {
  let series =
    Series("new_series", line(), numerical([#(0.0, 2.0), #(0.99, 3.0)]))
  let series1 =
    Series("new_series", line(), numerical([#(4.0, -3.0), #(5.0, 1.0)]))

  new()
  |> add_series(series)
  |> add_series(series1)
  |> generate()
  |> string.inspect
  |> io.println

  Nil
}
