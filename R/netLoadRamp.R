# Copyright © 2016 RTE Réseau de transport d’électricité

#' Ramp of an area
#'
#' This function computes the ramp of the consumption and the balance of areas
#' and/or districts.
#'
#' @param x
#'   Object of class \code{antaresData} containing data for areas and/or
#'   districts. It must contain the column \code{BALANCE}  and either the column
#'   "netLoad" or the columns needed to compute the net load  see \link[antaresProcessing]{addNetLoad}.
#' @param ignoreMustRun
#'   Should the must run production be ignored in the computation of the net
#'   load?
#' @param opts opts where clusterDesc will be read if null based on data
#' @inheritParams surplus
#'
#' @return
#' \code{netLoadRamp} returns a data.table or a list of data.tables with the
#' following columns:
#' \item{netLoadRamp}{
#'   Ramp of the net load of an area. If \code{timeStep} is not hourly, then these
#'   columns contain the average value for the given time step.
#'   Formula = netLoad - shift(netLoad, fill = 0)
#' }
#' \item{balanceRamp}{
#'   Ramp of the balance of an area. If \code{timeStep} is not hourly, then
#'   these columns contain the average value for the given time step.
#'
#'   formula = BALANCE - shift(BALANCE, fill = 0)
#' }
#' \item{areaRamp}{
#'   Sum of the two previous columns. If \code{timeStep} is not hourly, then
#'   these columns contain the average value for the given time step.
#'
#'   formula = netLoadRamp + balanceRamp
#' }
#' \item{minNetLoadRamp}{Minimum ramp of the net load of an area, if \code{timeStep} is not hourly.}
#' \item{minBalanceRamp}{Minimum ramp of the balance of an area, if \code{timeStep} is not hourly.}
#' \item{minAreaRamp}{Minimum ramp sum of the sum of balance and net load, if \code{timeStep} is not hourly.}
#' \item{maxNetLoadRamp}{Maximum ramp of the net load of an area, if \code{timeStep} is not hourly.}
#' \item{maxBalanceRamp}{Maximum ramp of the balance of an area, if \code{timeStep} is not hourly.}
#' \item{maxAreaRamp}{Maximum ramp of the sum of balance and net load, if \code{timeStep} is not hourly.}
#'
#' For convenience the function invisibly returns the modified input.
#'
#'
#' @examples
#' \dontrun{
#' # data required by the function
#' showAliases("netLoadRamp")
#'
#' mydata <- readAntares(select="netLoadRamp")
#' netLoadRamp(mydata, timeStep = "annual")
#' }
#'
#' @export
#'
netLoadRamp <- function(x, timeStep = "hourly", synthesis = FALSE, ignoreMustRun = FALSE, opts = NULL) {
  .checkAttrs(x, "hourly", "FALSE")
  if(is.null(opts))
  {
    opts <- simOptions(x)
  }

  if (is(x, "antaresDataList")) {
    if (is.null(x$areas) & is.null(x$districts)) stop("'x' does not contain area or district data")

    res <- list()

    if (!is.null(x$areas)) res$areas <- netLoadRamp(x$areas, timeStep, synthesis, ignoreMustRun)
    if (!is.null(x$districts)) res$districts <- netLoadRamp(x$districts, timeStep, synthesis, ignoreMustRun)

    if (length(res) == 0) stop("'x' needs to contain area and/or district data.")

    res <- .addClassAndAttributes(res, synthesis, timeStep, opts, simplify = TRUE)

    return(res)
  }

  if(! attr(x, "type") %in% c("areas", "districts")) stop("'x' does not contain area or district data")

  if (is.null(x$BALANCE)) stop("Column 'BALANCE' is needed but missing.")
  if (is.null(x$netLoad)) addNetLoad(x, ignoreMustRun)

  x <- x[, c(.idCols(x), "BALANCE", "netLoad"), with = FALSE]

  idVars <- .idCols(x)

  setorderv(x, idVars)
  x[, `:=`(netLoadRamp = netLoad - shift(netLoad, fill = 0),
           balanceRamp = BALANCE - shift(BALANCE, fill = 0))]

  x[timeId == min(timeId), c("netLoadRamp", "balanceRamp") := 0]
  x[, areaRamp := netLoadRamp + balanceRamp]

  x <- x[, c(idVars, "netLoadRamp", "balanceRamp", "areaRamp"), with = FALSE]

  x <- .addClassAndAttributes(x, FALSE, "hourly", opts, type = "netLoadRamp")

  if (synthesis) {

    x <- synthesize(x, "min", "max", prefixForMeans = "avg")

    x <- changeTimeStep(x, timeStep,
                        fun = c("mean", "min", "max",
                                "mean", "min", "max",
                                "mean", "min", "max"))

  } else if (timeStep != "hourly") {

    x[, `:=`(
      min_netLoadRamp = netLoadRamp,
      min_balanceRamp = balanceRamp,
      min_areaRamp = areaRamp,
      max_netLoadRamp = netLoadRamp,
      max_balanceRamp = balanceRamp,
      max_areaRamp = areaRamp
    )]

    x <- changeTimeStep(x, timeStep,
                        fun = c("mean", "mean", "mean",
                                "min", "min", "min",
                                "max", "max", "max"))

    setcolorder(x, c(.idCols(x),
                     "netLoadRamp", "min_netLoadRamp", "max_netLoadRamp",
                     "balanceRamp", "min_balanceRamp", "max_balanceRamp",
                     "areaRamp", "min_areaRamp", "max_areaRamp"))

    setnames(x,
             c("netLoadRamp", "balanceRamp", "areaRamp"),
             c("avg_netLoadRamp", "avg_balanceRamp", "avg_areaRamp"))
  }

  x
}
