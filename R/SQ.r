#' Sequential model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#'
#' @param data: a nested list of data
#' @param par: a vector of parameter values, this is functions specific
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = SQ(data = data, par = par)
#'}

SQ = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 8){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument for readability
  t0 = round(par[1])
  t0_chill = round(par[2])
  T_base = par[3]
  T_opt = par[4]
  T_min = par[5]
  T_max = par[6]
  F_crit = par[7]
  C_req = par[8]

  # sanity check
  if (t0 <= t0_chill){
    return(rep(9999,ncol(data$Ti)))
  }

  # chilling
  Rc = matrix(0,nrow(data$Ti),ncol(data$Ti)) # allocate empty matrix
  Rc[data$Ti < T_opt & data$Ti >= T_min] = (Rc[data$Ti < T_opt & data$Ti >= T_min] - T_min)/(T_opt - T_min)
  Rc[data$Ti < T_max & data$Ti >= T_opt] = (Rc[data$Ti < T_max & data$Ti >= T_opt] - T_opt)/(T_max - T_opt)
  Rc[1:t0_chill,] = 0
  Rc[t0:nrow(Rc),] = 0
  Sc = apply(Rc,2, cumsum)

  # chilling requirement has to be met before
  # accumulation starts (binary choice)
  k = as.numeric(Sc >= C_req)

  # forcing
  Rf = data$Ti - T_base
  Rf[Rf < 0] = 0
  Rf = Rf * k
  Rf[1:t0,] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    doy[is.na(doy)] = 9999
    return(doy)
  })
  return(doy)
}
