import gleam/float

import fig/internal/utils

// =============================================================================
// TEXT MEASUREMENT
// =============================================================================

pub fn text_width_digits_test() {
  assert float.loosely_equals(
    utils.text_width("42", 10.0),
    0.556 *. 2.0 *. 10.0 *. 1.1,
    0.000_001,
  )
}

pub fn text_width_narrow_characters_test() {
  assert float.loosely_equals(
    utils.text_width("0.5", 10.0),
    { 0.556 +. 0.278 +. 0.556 } *. 10.0 *. 1.1,
    0.000_001,
  )
}

pub fn text_width_runs_high_test() {
  assert utils.text_width("0", 10.0) >. 0.556 *. 10.0
}

pub fn text_width_full_width_characters_test() {
  assert float.loosely_equals(
    utils.text_width("中文", 10.0),
    2.0 *. 10.0 *. 1.1,
    0.000_001,
  )
  assert utils.text_width("中文", 10.0) >. utils.text_width("ab", 10.0)
}

pub fn text_width_empty_test() {
  assert utils.text_width("", 10.0) == 0.0
}
