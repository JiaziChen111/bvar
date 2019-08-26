irf.bvar <- function(x, ..., conf_bands, n_thin = 1L) {

  if(!inherits(x, "bvar")) {stop("Please provide a `bvar` object.")}


  # Retrieve / calculate irf ----------------------------------------------

  dots <- list(...)

  irf_store <- x[["irf"]]

  # If a forecast exists and no settings are provided
  if(is.null(irf_store) || length(dots) != 0L) {

    irf <- if(length(dots) > 0 && inherits(dots[[1]], "bv_irf")) {
      dots[[1]]
    } else {bv_irf(...)}

    n_pres <- x[["meta"]][["n_save"]]
    n_thin <- int_check(n_thin, min = 1, max = (n_pres / 10),
                        "Problematic value for parameter `n_thin`.")
    n_save <- int_check((n_pres / n_thin), min = 1)

    Y <- x[["meta"]][["Y"]]
    N <- x[["meta"]][["N"]]
    K <- x[["meta"]][["K"]]
    M <- x[["meta"]][["M"]]
    lags <- x[["meta"]][["lags"]]
    beta <- x[["beta"]]
    sigma <- x[["sigma"]]

    irf_store <- list(
      "irf" = array(NA, c(n_save, M, irf[["horizon"]], M)),
      "fevd" = if(irf[["fevd"]]) {array(NA, c(n_save, M, M))} else {NULL},
      "setup" = irf,
      "variables" = variables
    )
    class(irf_store) <- "bvar_irf"

    j <- 1
    for(i in seq_len(n_save)) {
      beta_comp <- get_beta_comp(beta[j, , ], K, M, lags)
      irf_comp  <- compute_irf(
        beta_comp = beta_comp,
        sigma = sigma[j, , ], sigma_chol = t(chol(sigma[j, , ])),
        M = M, lags = lags,
        horizon = irf[["horizon"]], identification = irf[["identification"]],
        sign_restr = irf[["sign_restr"]], fevd = irf[["fevd"]])
      irf_store[["irf"]][i, , , ] <- irf_comp[["irf"]]
      if(irf[["fevd"]]) {irf_store[["fevd"]][i, , ] <- irf_comp[["fevd"]]}
      j <- j + n_thin
    }
  }


  # Apply confidence bands ------------------------------------------------

  if(is.null(irf_store[["quants"]]) || !missing(conf_bands)) {
    irf_store <- if(!missing(conf_bands)) {
      irf.bvar_irf(irf_store, conf_bands)
    } else {irf.bvar_irf(irf_store, c(0.16))}
  }

  return(irf_store)
}


#' @rdname irf.bvar
#' @export
irf.bvar_irf <- function(x, conf_bands) {

  if(!inherits(x, "bvar_irf")) {stop("Please provide a `bvar_irf` object.")}

  if(!missing(conf_bands)) {
    quantiles <- quantile_check(conf_bands)
    x[["quants"]] <- apply(x[["irf"]], c(2, 3, 4), quantile, quantiles)
  }

  return(x)
}


#' @rdname irf.bvar
#' @export
irf <- function(x, ...) {
  UseMethod("irf", x)
}