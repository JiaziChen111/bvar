#' Hyperparameter trace & density plot
#'
#' Diagnostic plots of the trace / density of a single hyperparameter.
#' A parameter may be plotted across multiple iterations of \code{\link{bvar}}
#' via the ellipsis parameter. Given that the settings for \code{\link{bvar}}
#' are identical this can be used to assess convergence.
#'
#' @param x A \code{bvar} object, obtained from \code{\link{bvar}}.
#' @param name String with the name of the hyperparameter to plot. Possible
#' values are names of hyperparameters and \code{"ml"} for the posterior
#' marginal likelihood.
#' @param ... Further \code{bvar} objects to include in the plot. The desired
#' hyperparameter must be available and priors of the objects should match.
#'
#' @export
#'
#' @examples
#' \donttest{
#' data <- matrix(rnorm(200), ncol = 2)
#' x <- bvar(data, lags = 2)
#'
#' # Plot the trace of lambda
#' bv_plot_trace(x, "lambda")
#'
#' # Adjust par() and plot the density of the posterior marginal likelihood
#' op <- par(mar = c(2, 2, 2, 0.5))
#' bv_plot_density(x, "ml")
#' par(op)
#'
#' # Assess parameter convergence of several chains via their trace
#' y <- bvar(data, lags = 2)
#' z <- bvar(data, lags = 2)
#' bv_plot_trace(x, "lambda", y, z)
#' }
bv_plot_trace <- function(x, name, ...) {

  .Deprecated("plot.bvar")
  plot_hyper(x, name, fun = plot_trace, ...)
}


#' @rdname bv_plot_trace
#' @export
bv_plot_density <- function(x, name, ...) {

  .Deprecated("plot.bvar")
  plot_hyper(x, name, fun = plot_dens, ...)
}


#' Hyperparameter plot helper
#'
#' Helper function to provide input checks, prepare data et cetera for
#' hyperparameter plots.
#'
#' @param x A \code{bvar} object, obtained from \code{\link{bvar}}.
#' @param name String. Name of the parameter to plot.
#' @param fun Function to use for plotting.
#' @param ... Further \code{bvar} objects to include in the plot.
#'
#' @noRd
plot_hyper <- function(x, name, fun = c(plot_trace, plot_dens), ...) {

  if(!inherits(x, "bvar")) {stop("Please provide a `bvar` object.")}

  if(missing(name)) {
    stop("Please set `name` to specify a parameter to plot.")
  } else if(!name %in% c("ml", colnames(x[["hyper"]]))) {
    stop("Parameter named '", name, "' not found.")
  }

  dots <- list(...)
  lapply(dots, function(x) {
    if(!inherits(x, "bvar")) {
      stop("Please provide `bvar` objects to the ellipsis.")
    }
  })

  if(name == "ml") {
    y <- x[["ml"]]
    dots <- lapply(dots, function(x) x[["ml"]])
    bounds <- NULL
  } else {
    y <- x[["hyper"]][, which(colnames(x[["hyper"]]) == name)]
    dots <- lapply(dots, function(x) {
      x[["hyper"]][, which(colnames(x[["hyper"]]) == name)]
    })
    bounds <- vapply(name, function(z) {
      c(x[["priors"]][[z]][["min"]], x[["priors"]][[z]][["max"]])}, double(2))
  }

  fun(y, name, bounds, dots)

  return(invisible(x))
}