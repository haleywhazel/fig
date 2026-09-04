import gleam/io
import gleam/string
import simplifile

import fig
import fig/svg

const output_path = "out.svg"

pub fn main() -> Nil {
  let chart =
    fig.new()
    |> fig.add_series(fig.Series(
      "1",
      fig.line(),
      fig.numerical([#(0.0, 2.0), #(1.0, 3.0), #(2.0, 2.5), #(3.0, 4.0)]),
    ))
    |> fig.add_series(fig.Series(
      "2",
      fig.line(),
      fig.numerical([#(0.0, 4.0), #(1.0, 1.0), #(2.0, 3.0), #(3.0, 0.5)]),
    ))
    |> fig.set_dimension_labels(["x", "y"])
    |> fig.generate

  case simplifile.write(to: output_path, contents: svg.to_svg(chart)) {
    Ok(_) -> io.println("\nGenerated!")
    Error(error) -> io.println(string.inspect(error))
  }
}
