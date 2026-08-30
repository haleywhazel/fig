// most stuff here was originally private functions shared by multiple modules

import gleam/float
import gleam/int
import gleam/result
import gleam/string

@internal
pub fn log10(x: Float) -> Float {
  {
    x
    |> float.logarithm
    |> result.unwrap(0.0)
  }
  /. 2.302_585_092_994_046
}

// 2D offset given point + direction
@internal
pub fn offset(
  point: #(Float, Float),
  direction: #(Float, Float),
  by offset: Float,
) {
  let dx = direction.0 -. point.0
  let dy = direction.1 -. point.1
  let length = float.square_root(dx *. dx +. dy *. dy) |> result.unwrap(0.0)

  let #(unit_x, unit_y) = case length == 0.0 {
    True -> #(0.0, 0.0)
    False -> #(dx /. length, dy /. length)
  }

  let x = point.0 +. unit_x *. offset
  let y = point.1 +. unit_y *. offset

  #(x, y, unit_x, unit_y)
}

@internal
pub fn round_to_string(value: Float, decimals: Int) -> String {
  let factor = float.power(10.0, int.to_float(decimals)) |> result.unwrap(1.0)

  let scaled = float.round(value *. factor)
  let sign = case scaled < 0 {
    True -> "-"
    False -> ""
  }
  let magnitude = int.absolute_value(scaled)

  case decimals <= 0 {
    True -> sign <> int.to_string(magnitude)
    False ->
      sign
      <> int.to_string(magnitude / float.round(factor))
      <> "."
      <> string.pad_start(
        int.to_string(magnitude % float.round(factor)),
        decimals,
        "0",
      )
  }
}
