#' @export
print.bv_irf <- function(x, ...) {

  if(!inherits(x, "bv_irf")) {stop("Please provide a `bv_irf` object.")}

  cat("Object with settings for computing impulse responses.\n")

  print_irf(x, ...)

  return(invisible(x))
}


#' @export
print.bvar_irf <- function(x, ...) {

  if(!inherits(x, "bvar_irf")) {stop("Please provide a `bvar_irf` object.")}

  cat("Impulse response object from `bvar()`.\n")

  print_irf(x[["setup"]], ...)

  cat("Variables: ", dim(x[["irf"]])[2], "\n",
      "Iterations: ", dim(x[["irf"]])[1], "\n", sep = "")

  return(invisible(x))
}


#' @export
print.bvar_fevd <- function(x, digits = 4L, complete = FALSE, ...) {

  if(!inherits(x, "bvar_fevd")) {stop("Please provide a `bvar_fevd` object.")}

  # Average over time for printing
  if(length(dim(x[["quants"]])) == 4) {
    y <- apply(x[["quants"]], c(1, 2, 4), mean)
  } else if(length(dim(x[["quants"]])) == 3) {
    y <- apply(x[["quants"]], c(1, 3), mean)
  }

  print_coefs(y, digits = digits, type = "FEVD", complete = complete, ...)

  return(invisible(x))
}


#' @noRd
print_irf <- function(x, ...) {

  cat("Horizon:", x[["horizon"]])

  cat("\nIdentification: ")
  if(x[["identification"]]) {
    if(is.null(x[["sign_restr"]])) {
      cat("Cholesky decomposition")
    } else {
      cat("Sign restrictions", "\nChosen restrictions:\n", sep = "")
      sign_restr <- apply(x[["sign_restr"]], 2, factor,
        levels = c(-1, 0, 1), labels = c("-", "0", "+"))
      if(length(sign_restr) < 10 ^ 2) {
        cat("\t\t\tShock to\n\t\t\t", # Use cat cause it's nice
          paste0("Var", 1:nrow(sign_restr), sep = "\t"),
          paste0(c("\nResponse of\t", rep("\n\t\t", nrow(sign_restr) - 1)),
            "Var", 1:nrow(sign_restr), "\t",
            apply(sign_restr, 1, function(x) {
              paste0(" ", x, sep = "\t", collapse = "")}),
            collapse = "\n"))
      } else if(length(sign_restr) < 18 ^ 2) {
        print(sign_restr) # Print the matrix
      } else {
        cat("Too large to print.") # Skip
      }
    }
  } else {
    cat(FALSE)
  }

  cat("\nFEVD: ", x[["fevd"]], "\n", sep = "")

  return(invisible(x))
}



#' @rdname irf.bvar
#' @export
summary.bvar_irf <- function(
  object,
  vars_impulse = NULL, vars_response = NULL,
  ...) {

  if(!inherits(object, "bvar_irf")) {
    stop("Please provide a `bvar_irf` object.")
  }

  quants <- object[["quants"]]
  has_quants <- length(dim(quants)) == 4
  M <- if(has_quants) {dim(quants)[2]} else {dim(quants)[1]}

  variables <- name_deps(variables = object[["variables"]], M = M)
  pos_imp <- pos_vars(vars_impulse, variables, M)
  pos_res <- pos_vars(vars_response, variables, M)

  out <- list(
    "irf" = object, "quants" = quants,
    "variables" = variables, "pos_imp" = pos_imp,"pos_res" = pos_res,
    "has_quants" = has_quants)

  class(out) <- "bvar_irf_summary"

  return(out)
}


#' @noRd
#' @export
print.bvar_irf_summary <- function(x, digits = 2L, ...) {

  if(!inherits(x, "bvar_irf_summary")) {
    stop("Please provide a `bvar_irf_summary` object.")
  }

  print.bvar_irf(x$irf)

  cat(if(!x$has_quants) {"Median impulse"} else {"Impulse"}, "responses:\n")

  for(i in x$pos_res) {for(j in x$pos_imp) {
    cat("\tShock ", x[["variables"]][j], " on ", x[["variables"]][i],
      ":\n", sep = "")
    print(round(
      if(x[["has_quants"]]) {
        x[["quants"]][, i, , j]
      } else {x[["quants"]][i, , j]}, digits = digits))
  }}

  return(invisible(x))
}


#' @rdname irf.bvar
#' @export
summary.bvar_fevd <- function(object, vars = NULL, ...) {

  if(!inherits(object, "bvar_fevd")) {
    stop("Please provide a `bvar_fevd` object.")
  }

  quants <- object[["quants"]]
  has_quants <- length(dim(quants)) == 4
  M <- if(has_quants) {dim(quants)[2]} else {dim(quants)[1]}

  variables <- name_deps(variables = object[["variables"]], M = M)
  pos <- pos_vars(vars, variables = variables, M = M)

  out <- list(
    "fevd" = object, "quants" = quants,
    "variables" = variables, "pos" = pos, "has_quants" = has_quants
  )

  class(out) <- "bvar_fevd_summary"

  return(out)
}


#' @export
print.bvar_fevd_summary <- function(x, digits = 2L, ...) {

  if(!inherits(x, "bvar_fevd_summary")) {
    stop("Please provide a `bvar_fevd_summary` object.")
  }

  print.bvar_fcast(x[["fevd"]])

  cat(if(!x[["has_quants"]]) {"Median forecast"} else {"Forecast"},
    "error variance decomposition:\n")

  for(i in x[["pos"]]) {
    cat("\tVariable ", x[["variables"]][i], ":\n", sep = "")
    print(round(
      if(x[["has_quants"]]) {x[["quants"]][, , i]} else {x[["quants"]][, i]},
      digits = digits))
  }

  return(invisible(x))
}
