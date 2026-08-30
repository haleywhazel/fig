// most stuff here was originally private functions shared by multiple modules

import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string

// =============================================================================
// PUBLIC INTERNAL FUNCTIONS
// =============================================================================

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

/// text width estimation
@internal
pub fn text_width(content: String, font_size: Float) -> Float {
  content
  |> string.to_utf_codepoints
  |> list.fold(0.0, fn(total, codepoint) {
    total +. character_width(string.utf_codepoint_to_int(codepoint))
  })
  // safety factor
  |> float.multiply(font_size *. 1.1)
}

// =============================================================================
// PRIVATE FUNCTIONS
// =============================================================================

fn character_width(codepoint: Int) -> Float {
  case codepoint {
    // digits
    codepoint if codepoint >= 48 && codepoint <= 57 -> 0.556
    // space, full stop, comma
    32 | 44 | 46 -> 0.278
    // hyphen
    45 -> 0.333
    // percent
    37 -> 0.889
    // lowercase, averaged
    codepoint if codepoint >= 97 && codepoint <= 122 -> 0.5
    // uppercase, averaged
    codepoint if codepoint >= 65 && codepoint <= 90 -> 0.667
    codepoint ->
      case is_full_width(codepoint) {
        True -> 1.0
        // anything else, assume roughly a digit
        False -> 0.6
      }
  }
}

fn is_full_width(codepoint: Int) -> Bool {
  { codepoint >= 0x1100 && codepoint <= 0x115F }
  || { codepoint >= 0x2E80 && codepoint <= 0xA4CF }
  || { codepoint >= 0xAC00 && codepoint <= 0xD7A3 }
  || { codepoint >= 0xF900 && codepoint <= 0xFAFF }
  || { codepoint >= 0xFE30 && codepoint <= 0xFE6F }
  || { codepoint >= 0xFF00 && codepoint <= 0xFF60 }
  || { codepoint >= 0xFFE0 && codepoint <= 0xFFE6 }
}
