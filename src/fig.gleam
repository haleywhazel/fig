//// This is the main module you interact with to generate charts using fig!

// =============================================================================
// IMPORTS
// =============================================================================

import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

import fig/geometry
import fig/projection

import fig/internal/utils

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

/// Where the axis is drawn. To draw at a specific value, use `AtValue`, e.g.
/// for Cartesian grids, set `AtValue(0.0, False)`.
///
/// This also governs where the ticks are, as ticks are attached to the Axis.
pub type AxisDisplay {
  /// Default, draws at the minimums of the range, e.g. bottom and left on a
  /// standard 2D graph
  AtMinimum
  AtMaximum
  /// `clamped` clamps the value to between minimum and maximum if you don't
  /// axis and ticks to suddenly disappear.
  AtValue(Float, clamped: Bool)
  Hidden
}

/// The way that a dimension of data is represented within a plot, e.g. through
/// position or colour.
pub type Channel {
  PositionalChannel(rough_tick_count: Int)
}

/// A standard chart, use [`new`](#new) instead to construct the entire
/// structure and modify the defaults you want to change.
///
/// Phantom type `shape` represents the type of the data and helps make sure you
/// don't add series with incongruent types (e.g. [Float, Float] in series 1
/// but [Float, String] in series 2). While there are occasional cases where
/// this might be what you want to plot (e.g. two y-axes layered on top of
/// each other, one for categorical data and one for numerical), these are
/// mostly cases of bad data visualisation design rather than a genuine need.
pub type Chart(shape) {
  Chart(
    series: List(Series(shape)),
    projection: projection.Projection,
    geometries: List(geometry.Geometry),
    view: projection.View,
    config: ChartConfiguration,
  )
}

/// Chart configurations! Set with the `set_`* functions.
///
/// [`new`](#new) already gives a [`Chart`](#Chart) with default options, this
/// type is not set as `opaque` because downstream modules need to access the
/// fields.
pub type ChartConfiguration {
  ChartConfiguration(
    width: Float,
    height: Float,
    padding: geometry.Padding,
    axis_display: AxisDisplay,
    axis_label_offset: Float,
    axis_label_size: Float,
    dimension_labels: List(String),
    framed: Bool,
    ticks: Bool,
    grid: Bool,
    tick_size: Float,
    tick_label_offset: Float,
    tick_label_size: Float,
    font_family: String,
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
  ResolvedAxis(dimension: Int, domain: Domain, ticks: List(Float))
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
    |> list.index_map(fn(pair, dimension) { #(dimension, pair) })
    |> list.filter_map(with: fn(entry) {
      let #(dimension, #(domain, channel)) = entry
      case channel {
        // only positional channels become axes; colour and size will not
        PositionalChannel(_) -> Ok(resolve_axis(domain, channel, dimension))
      }
    })

  let bounds =
    list.map(resolved_axes, fn(resolved_axis) {
      domain_bounds(resolved_axis.domain)
    })
  let minimums = list.map(bounds, fn(bound) { bound.0 })
  let maximums = list.map(bounds, fn(bound) { bound.1 })

  let anchor = case chart.config.axis_display {
    AtMinimum | Hidden -> minimums
    AtMaximum -> maximums
    AtValue(value, clamped) ->
      list.map(bounds, fn(bound) {
        let #(minimum, maximum) = bound
        case clamped {
          True -> float.clamp(value, minimum, maximum)
          False -> value
        }
      })
  }

  let grid_geometry =
    generate_grid_geometry(chart.config.grid, minimums, bounds, resolved_axes)

  let frame_geometry =
    generate_framed_geometry(chart.config.framed, minimums, maximums, bounds)

  let axes_geometry =
    generate_axes_geometry(chart.config.axis_display, anchor, bounds)

  let ticks_geometry =
    generate_ticks_geometry(
      chart.config.axis_display,
      chart.config.ticks,
      anchor,
      resolved_axes,
    )

  let tick_labels =
    generate_tick_labels(
      chart.config.axis_display,
      chart.config.ticks,
      anchor,
      resolved_axes,
    )

  let axis_labels =
    generate_axis_labels(
      chart.config.axis_display,
      chart.config.dimension_labels,
      anchor,
      resolved_axes,
    )

  // TODO: add series options
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

  // set projection
  let projection =
    generate_projection(chart, bounds, ticks_geometry, tick_labels, axis_labels)

  Chart(
    ..chart,
    projection: projection,
    geometries: list.flatten([
      grid_geometry,
      frame_geometry,
      axes_geometry,
      ticks_geometry,
      tick_labels,
      axis_labels,
      series_geometry,
    ]),
  )
}

/// Updating an interval so that it has nice step values, inspired by (stolen
/// from) the D3 nice function. `rough_count` is the rough number of counts you
/// are targeting for the ticks, rather than a strict number id adheres to
/// make sure the resulting output is nice to read.
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
///
/// By default, padding is automated, and this might not
/// work with certain fonts. To fix this, set custom
/// padding to make the chart work.
pub fn new() -> Chart(a) {
  Chart(
    series: [],
    projection: projection.empty_projection(),
    geometries: [],
    view: projection.isometric(),
    config: ChartConfiguration(
      width: 640.0,
      height: 400.0,
      padding: geometry.AutoPadding,
      dimension_labels: [],
      axis_display: AtMinimum,
      axis_label_offset: 40.0,
      axis_label_size: 12.0,
      framed: False,
      ticks: True,
      grid: True,
      tick_size: 5.0,
      tick_label_offset: 10.0,
      tick_label_size: 12.0,
      font_family: "sans-serif",
    ),
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

pub fn resolve_axis(
  domain domain: Domain,
  with_channel channel: Channel,
  for_dimension dimension: Int,
) -> ResolvedAxis {
  case domain, channel {
    NumericalDomain(interval), PositionalChannel(rough_tick_count) -> {
      let #(interval, recipe) = generate_ticks(interval, rough_tick_count)
      ResolvedAxis(dimension, NumericalDomain(interval), tick_values(recipe))
    }
    CategoricalDomain(categories), PositionalChannel(_) -> {
      ResolvedAxis(
        dimension,
        domain,
        list.index_map(categories, fn(_, position) { int.to_float(position) }),
      )
    }
  }
}

/// Set the axis position using an [`AxisDisplay`](#AxisDisplay).
pub fn set_axis_display(
  chart: Chart(shape),
  axis_display: AxisDisplay,
) -> Chart(shape) {
  Chart(
    ..chart,
    config: ChartConfiguration(..chart.config, axis_display: axis_display),
  )
}

/// Set the width and height
pub fn set_area(
  chart: Chart(shape),
  width: Float,
  height: Float,
) -> Chart(shape) {
  Chart(
    ..chart,
    config: ChartConfiguration(..chart.config, width: width, height: height),
  )
}

/// Set the dimension labels. For categorical dimensions (e.g. bar charts), it
/// is still useful to mention what the categories belong to.
///
/// This should have the same length as the length of each datum. While it's
/// good practice to label all dimensions, you can set a single dimension label
/// just as an empty string.
pub fn set_dimension_labels(
  chart: Chart(shape),
  labels dimension_labels: List(String),
) -> Chart(shape) {
  Chart(
    ..chart,
    config: ChartConfiguration(
      ..chart.config,
      dimension_labels: dimension_labels,
    ),
  )
}

/// Set global font family
pub fn set_font_family(
  chart: Chart(shape),
  font_family: String,
) -> Chart(shape) {
  Chart(
    ..chart,
    config: ChartConfiguration(..chart.config, font_family: font_family),
  )
}

/// Sets whether or not to display a full frame around a chart.
pub fn set_frame(chart: Chart(shape), framed: Bool) -> Chart(shape) {
  Chart(..chart, config: ChartConfiguration(..chart.config, framed: framed))
}

/// Sets whether or not to display a grid.
pub fn set_grid(chart: Chart(shape), grid: Bool) -> Chart(shape) {
  Chart(..chart, config: ChartConfiguration(..chart.config, grid: grid))
}

/// Set the height.
pub fn set_height(chart: Chart(shape), height: Float) -> Chart(shape) {
  Chart(..chart, config: ChartConfiguration(..chart.config, height: height))
}

/// Sets the padding to fixed values.
pub fn set_padding(
  chart: Chart(shape),
  padding: geometry.Padding,
) -> Chart(shape) {
  Chart(..chart, config: ChartConfiguration(..chart.config, padding: padding))
}

/// Sets the offset of tick labels from the axis.
pub fn set_tick_label_offset(
  chart: Chart(shape),
  tick_label_offset: Float,
) -> Chart(shape) {
  Chart(
    ..chart,
    config: ChartConfiguration(
      ..chart.config,
      tick_label_offset: tick_label_offset,
    ),
  )
}

/// Sets the size of tick labels.
pub fn set_tick_label_size(
  chart: Chart(shape),
  tick_label_size: Float,
) -> Chart(shape) {
  Chart(
    ..chart,
    config: ChartConfiguration(..chart.config, tick_label_size: tick_label_size),
  )
}

/// Sets the default tick size. This tick size should be in the same units as
/// the the value provided in [`set_area`](#set_area).
pub fn set_tick_size(chart: Chart(shape), tick_size: Float) -> Chart(shape) {
  Chart(
    ..chart,
    config: ChartConfiguration(..chart.config, tick_size: tick_size),
  )
}

/// Sets whether or not to display ticks.
pub fn set_ticks(chart: Chart(shape), ticks: Bool) -> Chart(shape) {
  Chart(..chart, config: ChartConfiguration(..chart.config, ticks: ticks))
}

/// Set the width.
pub fn set_width(chart: Chart(shape), width: Float) -> Chart(shape) {
  Chart(..chart, config: ChartConfiguration(..chart.config, width: width))
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

// =============================================================================
// PUBLIC INTERNAL FUNCTIONS
// =============================================================================

// these are public internal mostly for testing purposes

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

@internal
pub fn generate_axes_geometry(
  axis_display: AxisDisplay,
  anchor: List(Float),
  bounds: List(#(Float, Float)),
) -> List(geometry.Geometry) {
  case axis_display {
    Hidden -> []
    _ ->
      bounds
      |> list.index_map(fn(bound, index) {
        let #(minimum, maximum) = bound
        geometry.line(
          starting_at: geometry.Point(replace_with_index(
            anchor,
            for_index: index,
            with_value: minimum,
          )),
          ending_at: geometry.Point(replace_with_index(
            anchor,
            for_index: index,
            with_value: maximum,
          )),
          with_role: geometry.Axis,
        )
      })
  }
}

@internal
pub fn generate_axis_labels(
  axis_display: AxisDisplay,
  dimension_labels: List(String),
  anchor: List(Float),
  resolved_axes: List(ResolvedAxis),
) -> List(geometry.Geometry) {
  let tick_sign = case axis_display {
    AtMaximum -> 1.0
    _ -> -1.0
  }

  resolved_axes
  |> list.index_map(fn(axis, index) {
    case label_at(dimension_labels, axis.dimension) {
      "" -> []
      label -> {
        let #(minimum, maximum) = domain_bounds(axis.domain)
        [
          geometry.Text(
            at: geometry.Point(replace_with_index(
              anchor,
              for_index: index,
              with_value: { minimum +. maximum } /. 2.0,
            )),
            offset: geometry.Point(
              list.index_map(anchor, fn(_, other_index) {
                case other_index == index {
                  True -> 0.0
                  False -> tick_sign
                }
              }),
            ),
            content: label,
            role: geometry.AxisLabel,
          ),
        ]
      }
    }
  })
  |> list.flatten
}

@internal
pub fn generate_framed_geometry(
  framed: Bool,
  minimums: List(Float),
  maximums: List(Float),
  bounds: List(#(Float, Float)),
) -> List(geometry.Geometry) {
  case framed {
    False -> []
    True ->
      bounds
      |> list.index_map(fn(bound, index) {
        let #(minimum, maximum) = bound
        [
          geometry.line(
            starting_at: geometry.Point(replace_with_index(
              minimums,
              for_index: index,
              with_value: minimum,
            )),
            ending_at: geometry.Point(replace_with_index(
              minimums,
              for_index: index,
              with_value: maximum,
            )),
            with_role: geometry.Axis,
          ),

          geometry.line(
            starting_at: geometry.Point(replace_with_index(
              maximums,
              for_index: index,
              with_value: minimum,
            )),
            ending_at: geometry.Point(replace_with_index(
              maximums,
              for_index: index,
              with_value: maximum,
            )),
            with_role: geometry.Axis,
          ),
        ]
      })
      |> list.flatten
  }
}

@internal
pub fn generate_grid_geometry(
  grid: Bool,
  minimums: List(Float),
  bounds: List(#(Float, Float)),
  resolved_axes: List(ResolvedAxis),
) -> List(geometry.Geometry) {
  case grid {
    False -> []
    True ->
      bounds
      |> list.index_map(fn(bound, bounds_index) {
        let #(minimum, maximum) = bound

        resolved_axes
        |> list.index_map(fn(axis, axis_index) {
          case bounds_index == axis_index {
            True -> []
            False ->
              axis.ticks
              |> list.map(fn(tick) {
                let base_coordinates =
                  replace_with_index(
                    minimums,
                    for_index: axis_index,
                    with_value: tick,
                  )

                geometry.line(
                  starting_at: geometry.Point(replace_with_index(
                    base_coordinates,
                    for_index: bounds_index,
                    with_value: minimum,
                  )),
                  ending_at: geometry.Point(replace_with_index(
                    base_coordinates,
                    for_index: bounds_index,
                    with_value: maximum,
                  )),
                  with_role: geometry.Grid,
                )
              })
          }
        })
        |> list.flatten()
      })
      |> list.flatten()
  }
}

@internal
pub fn generate_projection(
  chart: Chart(shape),
  bounds: List(#(Float, Float)),
  ticks_geometry: List(geometry.Geometry),
  tick_labels: List(geometry.Geometry),
  axis_labels: List(geometry.Geometry),
) -> projection.Projection {
  case chart.config.padding {
    // first estimate how much we go out of bounds for for zero padding if it's
    // auto padding, then adjust the padding based on that
    geometry.AutoPadding -> {
      let projection =
        projection.new(
          bounds: bounds,
          width: chart.config.width,
          height: chart.config.height,
          padding: chart.config.padding,
          view: chart.view,
        )

      let #(min_x, min_y, max_x, max_y) =
        list.flatten([ticks_geometry, tick_labels, axis_labels])
        |> list.map(fn(geometry) {
          case geometry {
            geometry.Tick(at, direction, _) -> {
              let projection.ScreenCoordinates(starting_x, starting_y, _) =
                projection.project(projection, at)
              let projection.ScreenCoordinates(direction_x, direction_y, _) =
                projection.project(
                  projection,
                  geometry.add_points(at, direction),
                )

              let #(ending_x, ending_y, _, _) =
                utils.offset(
                  #(starting_x, starting_y),
                  #(direction_x, direction_y),
                  by: chart.config.tick_size,
                )

              #(
                float.min(starting_x, ending_x),
                float.min(starting_y, ending_y),
                float.max(starting_x, ending_x),
                float.max(starting_y, ending_y),
              )
            }
            geometry.Text(at, offset, content, geometry.TickLabel) -> {
              let projection.ScreenCoordinates(starting_x, starting_y, _) =
                projection.project(projection, at)
              let projection.ScreenCoordinates(direction_x, direction_y, _) =
                projection.project(projection, geometry.add_points(at, offset))

              let #(x, y, unit_x, unit_y) =
                utils.offset(
                  #(starting_x, starting_y),
                  #(direction_x, direction_y),
                  by: chart.config.tick_size,
                )

              let width =
                utils.text_width(content, chart.config.tick_label_size)

              // 1.2 takes ascenders & descenders into account
              let height = chart.config.tick_label_size *. 1.2

              // text-anchor
              let x_fraction = case unit_x {
                unit_x if unit_x <. -0.1 -> 1.0
                unit_x if unit_x <. 0.1 -> 0.5
                _ -> 0.0
              }

              // dominant-baseline
              let y_fraction = case unit_y {
                unit_y if unit_y <. -0.1 -> 1.0
                unit_y if unit_y <. 0.1 -> 0.5
                _ -> 0.0
              }

              let minimum_x = x -. width *. x_fraction
              let minimum_y = y -. height *. y_fraction

              #(minimum_x, minimum_y, minimum_x +. width, minimum_y +. height)
            }
            geometry.Text(at, offset, content, geometry.AxisLabel) -> {
              let projection.ScreenCoordinates(starting_x, starting_y, _) =
                projection.project(projection, at)
              let projection.ScreenCoordinates(direction_x, direction_y, _) =
                projection.project(projection, geometry.add_points(at, offset))

              let #(x, y, unit_x, unit_y) =
                utils.offset(
                  #(starting_x, starting_y),
                  #(direction_x, direction_y),
                  by: chart.config.axis_label_offset,
                )

              let width =
                utils.text_width(content, chart.config.axis_label_size)

              // 1.2 takes ascenders & descenders into account
              let height = chart.config.axis_label_size *. 1.2

              // text-anchor
              let x_fraction = case unit_x {
                unit_x if unit_x <. -0.1 -> 1.0
                unit_x if unit_x <. 0.1 -> 0.5
                _ -> 0.0
              }

              // dominant-baseline
              let y_fraction = case unit_y {
                unit_y if unit_y <. -0.1 -> 1.0
                unit_y if unit_y <. 0.1 -> 0.5
                _ -> 0.0
              }

              let minimum_x = x -. width *. x_fraction
              let minimum_y = y -. height *. y_fraction

              #(minimum_x, minimum_y, minimum_x +. width, minimum_y +. height)
            }
            // shouldn't run
            _ -> {
              #(0.0, 0.0, 0.0, 0.0)
            }
          }
        })
        |> list.fold(
          #(0.0, 0.0, chart.config.width, chart.config.height),
          fn(acc, bound) {
            #(
              float.min(acc.0, bound.0),
              float.min(acc.1, bound.1),
              float.max(acc.2, bound.2),
              float.max(acc.3, bound.3),
            )
          },
        )

      projection.new(
        bounds: bounds,
        width: chart.config.width,
        height: chart.config.height,
        padding: geometry.Padding(
          cap_padding(10.0 -. float.min(0.0, min_y), chart.config.height),
          cap_padding(
            10.0 +. float.max(0.0, max_x -. chart.config.width),
            chart.config.width,
          ),
          cap_padding(
            10.0 +. float.max(0.0, max_y -. chart.config.height),
            chart.config.height,
          ),
          cap_padding(10.0 -. float.min(0.0, min_x), chart.config.width),
        ),
        view: chart.view,
      )
    }
    // strict padding
    padding ->
      projection.new(
        bounds: bounds,
        width: chart.config.width,
        height: chart.config.height,
        padding: padding,
        view: chart.view,
      )
  }
}

@internal
pub fn generate_tick_labels(
  axis_display: AxisDisplay,
  ticks: Bool,
  anchor: List(Float),
  resolved_axes: List(ResolvedAxis),
) -> List(geometry.Geometry) {
  let tick_sign = case axis_display {
    AtMaximum -> 1.0
    _ -> -1.0
  }

  case axis_display, ticks {
    Hidden, _ | _, False -> []
    _, True ->
      resolved_axes
      |> list.index_map(fn(resolved_axis, index) {
        let tick_step = case resolved_axis.ticks {
          [] | [_] -> 0.0
          [x, y] | [x, y, ..] -> y -. x
        }

        let decimals = case tick_step {
          _ if tick_step >=. 1.0 -> 0
          _ -> {
            float.ceiling(0.0 -. utils.log10(tick_step))
            |> float.round
          }
        }

        resolved_axis.ticks
        |> list.map(fn(tick) {
          geometry.Text(
            at: geometry.Point(replace_with_index(
              anchor,
              for_index: index,
              with_value: tick,
            )),
            offset: geometry.Point(
              list.index_map(anchor, fn(_, other_index) {
                case other_index == index {
                  True -> 0.0
                  False -> tick_sign
                }
              }),
            ),
            content: tick_label_content(resolved_axis.domain, tick, decimals),
            role: geometry.TickLabel,
          )
        })
      })
      |> list.flatten()
  }
}

@internal
pub fn generate_ticks_geometry(
  axis_display: AxisDisplay,
  ticks: Bool,
  anchor: List(Float),
  resolved_axes: List(ResolvedAxis),
) -> List(geometry.Geometry) {
  let tick_sign = case axis_display {
    AtMaximum -> 1.0
    _ -> -1.0
  }

  case axis_display, ticks {
    Hidden, _ | _, False -> []
    _, True ->
      resolved_axes
      |> list.index_map(fn(resolved_axis, index) {
        resolved_axis.ticks
        |> list.map(fn(tick) {
          geometry.Tick(
            at: geometry.Point(replace_with_index(
              anchor,
              for_index: index,
              with_value: tick,
            )),
            direction: geometry.Point(
              list.index_map(anchor, fn(_, other_index) {
                case other_index == index {
                  True -> 0.0
                  False -> tick_sign
                }
              }),
            ),
            role: geometry.TickMark,
          )
        })
      })
      |> list.flatten()
  }
}

/// Get tick label content based on domain, the actual, tick, and d.p. to round
/// to
@internal
pub fn tick_label_content(
  domain: Domain,
  tick: Float,
  decimals: Int,
) -> String {
  case domain {
    NumericalDomain(_) -> utils.round_to_string(tick, decimals)
    CategoricalDomain(categories) ->
      categories
      |> list.drop(float.round(tick))
      |> list.first
      // shouldn't be reachable
      |> result.unwrap("")
  }
}

// =============================================================================
// PRIVATE FUNCTIONS
// =============================================================================

// not optimal for linked lists but still useful sometimes
fn at(items: List(a), index: Int) -> Result(a, Nil) {
  items |> list.drop(index) |> list.first
}

fn cap_padding(padding: Float, extent: Float) -> Float {
  // cap padding at 0.4 percent of the width; stuff that don't fit gets clipped
  // off
  float.min(padding, extent *. 0.4)
}

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

// datum -> plain numbers, one per positional axis
fn coordinates_of(
  datum: Datum(shape),
  resolved_axes: List(ResolvedAxis),
) -> List(Float) {
  select_coordinates(list.reverse(datum.dimensions), resolved_axes, 0)
}

// A single value as a position along its axis; categories are their index
// within the domain.
fn coordinate_of(value: Value, axis: ResolvedAxis) -> Float {
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
  let sqrt50 = 7.071_067_811_865_476
  let sqrt10 = 3.162_277_660_168_379_5
  let sqrt2 = 1.414_213_562_373_095_1

  let raw_step =
    { interval.maximum -. interval.minimum }
    /. { float.max(int.to_float(rough_count), 1.0) }

  let order_of_magnitude = float.floor(utils.log10(raw_step))
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

fn label_at(dimension_labels: List(String), index: Int) -> String {
  dimension_labels |> at(index) |> result.unwrap("")
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

fn replace_with_index(
  list: List(a),
  for_index index: Int,
  with_value value: a,
) -> List(a) {
  list.index_map(list, fn(v, i) {
    case i == index {
      True -> value
      False -> v
    }
  })
}

// select only the dimensions that become axes
fn select_coordinates(
  dimensions: List(Value),
  resolved_axes: List(ResolvedAxis),
  dimension: Int,
) -> List(Float) {
  case dimensions, resolved_axes {
    [], _ | _, [] -> []
    [value, ..remaining_dimensions], [axis, ..remaining_axes] ->
      case dimension == axis.dimension {
        True -> [
          coordinate_of(value, axis),
          ..select_coordinates(
            remaining_dimensions,
            remaining_axes,
            dimension + 1,
          )
        ]
        False ->
          select_coordinates(remaining_dimensions, resolved_axes, dimension + 1)
      }
  }
}
