generate_figure <- function(data) {
  ggplot2::ggplot(data, ggplot2::aes(x, y)) +
    ggplot2::geom_point()
}
