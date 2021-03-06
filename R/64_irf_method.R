#' Impulse response and forecast error methods for Bayesian VARs
#'
#' Retrieves / calculates impulse response functions (IRFs) and/or forecast
#' error variance decompositions (FEVDs) for Bayesian VARs generated via
#' \code{\link{bvar}}. If the object is already present and no settings are
#' supplied it is simply retrieved, otherwise it will be calculated ex-post.
#' Note that FEVDs require the presence / calculation of IRFs.
#' To store IRFs you may want to assign the output of \code{irf.bvar} to
#' \code{x$irf}. May also be used to update confidence bands, i.e.
#' credible intervals.
#'
#' @param x,object A \code{bvar} object, obtained from \code{\link{bvar}}.
#' Summary and print methods take in a \code{bvar_irf} / \code{bvar_fevd}
#' object.
#' @param ... A \code{bv_irf} object or arguments to be fed into
#' \code{\link{bv_irf}}. Contains settings for the IRFs / FEVDs.
#' @param conf_bands Numeric vector of desired confidence bands to apply.
#' E.g. for bands at 5\%, 10\%, 90\% and 95\% set this to \code{c(0.05, 0.1)}.
#' Note that the median, i.e. \code{0.5} is always included.
#' @param n_thin Integer scalar. Every \emph{n_thin}'th draw in \emph{x} is used
#' for calculations, others are dropped.
#' @param vars,vars_impulse,vars_response Optional numeric or character vector.
#' Used to subset the summary method's outputs to certain variables by position
#' or name (must be available). Defaults to \code{NULL}, i.e. all variables.
#'
#' @return Returns a list of class \code{bvar_irf} including IRFs and optionally
#' FEVDs at desired confidence bands. Also see \code{\link{bvar}}.
#' Note that the \code{fevd} method only returns a numeric array of FEVDs at
#' desired confidence bands.
#' The summary method returns a numeric array of impulse responses at the
#' specified confidence bands.
#'
#' @seealso \code{\link{plot.bvar_irf}}; \code{\link{bv_irf}}
#'
#' @keywords VAR BVAR irf impulse-responses fevd
#' forecast-error-variance-decomposition
#'
#' @export
#'
#' @examples
#' \donttest{
#' data <- matrix(rnorm(400), ncol = 4)
#' x <- bvar(data, lags = 2)
#'
#' # Add IRFs
#' x$irf <- irf(x)
#'
#' # Access IRFs and update confidence bands
#' irf(x, conf_bands = 0.01)
#'
#' # Compute and store IRFs with a longer horizon
#' x$irf <- irf(x, horizon = 24L)
#'
#' # Lower draws, use `bv_irf()` to set options and add confidence bands
#' irf(x, bv_irf(24L), n_thin = 10L, conf_bands = c(0.05, 0.16))
#'
#' # Get a summary of the last saved IRFs
#' summary(x)
#'
#' # Limit the summary to responses of variable #2
#' summary(x, vars_response = 2L)
#' }
irf.bvar <- function(x, ..., conf_bands, n_thin = 1L) {

  if(!inherits(x, "bvar")) {stop("Please provide a `bvar` object.")}


  # Retrieve / calculate irf ----------------------------------------------

  dots <- list(...)
  irf_store <- x[["irf"]]

  # If no forecast exists or settings are provided
  if(is.null(irf_store) || length(dots) != 0L) {

    irf <- if(length(dots) > 0 && inherits(dots[[1]], "bv_irf")) {
      dots[[1]]
    } else {bv_irf(...)}

    n_pres <- x[["meta"]][["n_save"]]
    n_thin <- int_check(n_thin, min = 1, max = (n_pres / 10),
      "Issue with n_thin. Maximum allowed is n_save / 10.")
    n_save <- int_check((n_pres / n_thin), min = 1)

    Y <- x[["meta"]][["Y"]]
    N <- x[["meta"]][["N"]]
    K <- x[["meta"]][["K"]]
    M <- x[["meta"]][["M"]]
    lags <- x[["meta"]][["lags"]]
    beta <- x[["beta"]]
    sigma <- x[["sigma"]]

    # Check sign restrictions
    if(!is.null(irf[["sign_restr"]]) && length(irf[["sign_restr"]]) != M ^ 2) {
      stop("Dimensions of provided sign restrictions do not fit the data.")
    }

    irf_store <- list(
      "irf" = array(NA, c(n_save, M, irf[["horizon"]], M)),
      "fevd" = if(irf[["fevd"]]) {
        structure(
          list("fevd" = array(NA, c(n_save, M, irf[["horizon"]], M)),
            "variables" = x[["variables"]]), class = "bvar_fevd")
      } else {NULL},
      "setup" = irf, "variables" = x[["variables"]]
    )

    class(irf_store) <- "bvar_irf"

    j <- 1
    for(i in seq_len(n_save)) {
      beta_comp <- get_beta_comp(beta[j, , ], K, M, lags)

      irf_comp  <- compute_irf(
        beta_comp = beta_comp, sigma = sigma[j, , ],
        sigma_chol = t(chol(sigma[j, , ])), M = M, lags = lags,
        horizon = irf[["horizon"]], identification = irf[["identification"]],
        sign_restr = irf[["sign_restr"]], sign_lim = irf[["sign_lim"]],
        fevd = irf[["fevd"]])

      irf_store[["irf"]][i, , , ] <- irf_comp[["irf"]]
      if(irf[["fevd"]]) {
        irf_store[["fevd"]][i, , , ] <- irf_comp[["fevd"]]
      }
      j <- j + n_thin
    }
  }

  if(is.null(irf_store[["quants"]]) || !missing(conf_bands)) {
    irf_store <- if(!missing(conf_bands)) {
      irf.bvar_irf(irf_store, conf_bands)
    } else {irf.bvar_irf(irf_store, c(0.16))}
  }

  return(irf_store)
}


#' @noRd
#' @export
#'
#' @importFrom stats quantile
irf.bvar_irf <- function(x, conf_bands, ...) {

  if(!inherits(x, "bvar_irf")) {stop("Please provide a `bvar_irf` object.")}

  if(!missing(conf_bands)) {
    quantiles <- quantile_check(conf_bands)
    x[["quants"]] <- apply(x[["irf"]], c(2, 3, 4), quantile, quantiles)
  }

  return(x)
}


#' @rdname irf.bvar
#' @export
fevd.bvar <- function(x, ..., conf_bands, n_thin = 1L) {

  if(!inherits(x, "bvar")) {stop("Please provide a `bvar` object.")}

  dots <- list(...)
  irf_store <- x[["irf"]]
  vars <- x[["variables"]]
  if(is.null(vars)) {
    vars <- paste0("var", 1:x[["meta"]][["M"]])
  }

  if(is.null(irf_store[["fevd"]]) || length(dots) != 0L) {
    irf <- if(length(dots) > 0 && inherits(dots[[1]], "bv_irf")) {
      dots[[1]]
    } else {bv_irf(...)}
    irf[["fevd"]] <- TRUE
    irf_store <- irf.bvar(x, irf, n_thin = n_thin) # Recalculate
  }

  fevd_store <- fevd.bvar_irf(irf_store, conf_bands = conf_bands)

  return(fevd_store)
}


#' @noRd
#' @export
fevd.bvar_irf <- function(x, conf_bands, ...) {

  if(!inherits(x, "bvar_irf")) {stop("Please provide a `bvar_irf` object.")}

  if(is.null(x[["fevd"]])) {
    stop("No forecast error variance decomposition found.")
  }

  fevd_store <- x[["fevd"]]

  if(is.null(fevd_store[["quants"]]) || !missing(conf_bands)) {
    fevd_store <- if(!missing(conf_bands)) {
      fevd.bvar_fevd(fevd_store, conf_bands)
    } else {fevd.bvar_fevd(fevd_store, c(0.16))}
  }

  class(x) <- "bvar_fevd"

  return(x)
}


#' @noRd
#' @export
#'
#' @importFrom stats quantile
fevd.bvar_fevd <- function(x, conf_bands, ...) {

  if(!inherits(x, "bvar_fevd")) {stop("Please provide a `bvar_fevd` object.")}

  if(!missing(conf_bands)) {
    quantiles <- quantile_check(conf_bands)
    x[["quants"]] <- apply(x[["fevd"]], c(2, 3, 4), quantile, quantiles)
  }

  return(x)
}


#' @rdname irf.bvar
#' @export
irf <- function(x, ...) {UseMethod("irf", x)}


#' @rdname irf.bvar
#' @export
fevd <- function(x, ...) {UseMethod("fevd", x)}


# vars compatibility ------------------------------------------------------

#' @noRd
irf.varest <- irf.svarest <- irf.svecest <- irf.vec2var <- function(x, ...) {
  has_vars()
  vars::irf(x, ...)
}

#' @noRd
fevd.varest <- fevd.svarest <-
  fevd.svecest <- fevd.vec2var <- function(x, ...) {
  has_vars()
  vars::fevd(x, ...)
}

#' @noRd
has_vars <- function() {has_package("vars")}
