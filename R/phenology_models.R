#' Alternating model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = AT(data = data, par = par)
#'}

AT = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 5){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument for readability
  t0 = round(par[1])
  T_base = par[2]
  a = par[3]
  b = par[4]
  c = par[5]

  # chilling
  Rc = data$Ti - T_base
  Rc[Rc < 0] = 1
  Rc[Rc >= 0] = 0
  Rc[1:t0,] = 0
  Sc = apply(Rc, 2, cumsum)

  # forcing
  Rf = data$Ti - T_base
  Rf[Rf <= 0] = 0
  Rf[1:t0,] = 0
  Sf = apply(Rf, 2, cumsum)

  Sfc = Sf - (a + b * exp(c * Sc))

  doy = apply(Sfc, 2, function(x){
    doy = data$doy[which(x > 0)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Chilling Degree Day (CDD) adapted from
#' Jeong & Medvigny 2014 (Global Ecology & Biogeography)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = CDD(data = data, par = par)
#'}

CDD = function(par, data){
  # exit the routine as some parameters are missing
  if (length(par) != 3){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument for readability
  t0 = round(par[1])
  T_base = par[2]
  F_crit = par[3]

  # create forcing/chilling rate vector
  Rf = data$Tmini - T_base
  Rf[Rf > 0] = 0
  Rf[1:t0,] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) <= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' DormPhot model as defined in
#' Caffarra, Donnelly and Chuine 2011 (Clim. Res.)
#' parameter ranges are taken from Basler et al. 2016
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = DP(data = data, par = par)
#'}

DP <- function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 11){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument for readability
  a = par[1]
  b = par[2]
  c = par[3]
  d = par[4]
  e = par[5]
  f = par[6]
  g = par[7]
  F_crit = par[8]
  C_crit = par[9]
  L_crit = par[10]
  D_crit = par[11]

  # set the t0 value if necessary (~Sept. 1)
  t0 = which(data$doy < 1 & data$doy == -121)

  # dormancy induction
  # (this is all vectorized doing cell by cell multiplications with
  # the sub matrices in the nested list)
  DR = 1/(1 + exp(a * (data$Ti - b))) * 1/(1 + exp(10 * (data$Li - L_crit)))
  if (!length(t0) == 0){
    DR[1:t0,] = 0
  }
  DS = apply(DR,2, cumsum)

  # chilling
  CR = 1/(1 + exp(c * (data$Ti - d)^2 + (data$Ti - d) ))
  CR[DS < D_crit] = 0
  CS = apply(CR,2, cumsum)

  # forcing
  dl50 = 24 / (1 + exp(f * (CS - C_crit))) # f >= 0
  t50 = 60 / (1 + exp(g * (data$Li - dl50))) # g >= 0
  Rf = 1/(1 + exp(e * (data$Ti - t50))) # e <= 0
  Rf[DS < D_crit] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' DU drought model
#' Chen et al. 2017 (Journal of Ecology)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model, tropical forest
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = DU(data = data, par = par)
#'}

DU <- function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 4){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument
  ni = round(par[1])
  nd = round(par[2])
  P_base = par[3]
  F_crit = par[4]

  # calculate floral induction time series
  Fd <- apply(data$Pi, 2, function(x){
    Fi <- zoo::rollapply(x, ni, mean, align = "right", fill = 0, na.rm = TRUE)
    Fd <- c(rep(0,nd),Fi[1:(length(Fi) - nd)])
  })

  # threshold value
  Fd <- Fd - P_base
  Fd[Fd < 0] <- 0

  # DOY of budburst criterium
  doy = apply(Fd, 2, function(xt){
    doy = data$doy[which(xt >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Thermal Time grassland pollen model which includes a pulse response
#' precipitatoin trigger as defined in
#' Garcia-Mozo et al. 2009 (Agr. For. Meteorlogy)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = GRP(data = data, par = par)
#'}

GRP = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 5){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument for readability
  b = par[1]
  c = par[2]
  F_crit = par[3]
  P_crit = par[4]
  L_crit = par[5]

  # Light requirement must be met
  # and daylength increasing (as per original specs)
  P_star = ifelse(data$Li >= L_crit, 1, 0)
  P_star[diff(data$Li) < 0] = 0

  # rainfall accumulation
  data$Pi = data$Pi * P_star
  rows = nrow(data$Pi)
  cols = ncol(data$Pi)

  # This avoids inefficient moving window
  # approaches which are computationally
  # expensive (break the routine when the
  # criterium is met instead of a full run
  # for a year)

  # assign output matrix
  R_star = matrix(0,rows,cols)

  # fill in values where required
  # until P_crit is met
  for (i in 1:cols){
    for (j in 1:rows){
      if (j == rows - 7){
        break
      }
      if(sum(data$Pi[j:(j+7),i]) >= P_crit){
        R_star[j:rows,i] = 1
        break
      }
    }
  }

  # create forcing/chilling rate vector
  # forcing
  Rf = 1 / (1 + exp(b * (data$Ti + c))) * R_star

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Linear model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @param spring a vector defining spring as a couple of DOY values
#' default is March, April, May or DOY 60 - 151
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model, sequential
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = LIN(data = data, par = par)
#'}

LIN = function(par, data, spring = c(60,151)){

  # exit the routine as some parameters are missing
  if (length(par) != 2){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument for readability
  a = par[1]
  b = par[2]

  # calculate location of "spring" values
  spring_loc = data$doy %in% seq(spring[1],spring[2])

  # calculate the mean temperature for this range
  mean_spring_temp = apply(data$Ti,2,function(xt){
    mean(xt[spring_loc])
  })

  # linear regression
  doy = a * mean_spring_temp + b

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' M1 model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model, sequential
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = TT(data = data, par = par)
#'}

M1 = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 4){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument for readability
  t0 = par[1]
  T_base = par[2]
  k = par[3]
  F_crit = par[4]

  # create forcing/chilling rate vector
  # forcing
  Rf = data$Ti - T_base
  Rf[Rf < 0] = 0
  Rf = ((data$Li / 10) ^ k) * Rf
  Rf[1:t0,] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' M1 model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#' with a sigmoidal temperature response (Kramer 1994)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model, sequential
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = TT(data = data, par = par)
#'}

M1s = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 5){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument for readability
  t0 = par[1]
  b = par[2]
  c = par[3]
  k = par[4]
  F_crit = par[5]

  # create forcing/chilling rate vector
  # forcing
  Rf = 1 / (1 + exp(-b * (data$Ti - c)))
  Rf = ((data$Li / 10) ^ k) * Rf
  Rf[1:t0,] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Null model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#' returns the mean across all validation dates
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @keywords phenology, model, sequential
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = NLL(data = data)
#'}

null = function(data){
  rep(round(mean(data$transition_dates,na.rm=TRUE)),
      length(data$transition_dates))
}

#' Parallel model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = PA(data = data, par = par)
#'}

PA = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 9){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument
  t0 = round(par[1])
  t0_chill = round(par[2])
  T_base = par[3]
  T_opt = par[4]
  T_min = par[5]
  T_max = par[6]
  C_ini = par[7]
  F_crit = par[8]
  C_req = par[9]

  # chilling
  Rc = triangular_temperature_response(data$Ti,
                                       T_opt = T_opt,
                                       T_min = T_min,
                                       T_max = T_max)
  Rc[1:t0_chill,] = 0
  Sc = apply(Rc, 2, cumsum)

  # chilling requirement has to be met before
  # accumulation starts (binary choice)
  k = C_ini + Sc * (1 - C_ini)/C_req
  k[Sc >= C_req] = 1

  # forcing
  Rf = data$Ti - T_base
  Rf[Rf < 0] = 0
  Rf = Rf * k
  Rf[1:t0,] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Parallel model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#' using a bell shaped chilling response
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = PAb(data = data, par = par)
#'}

PAb = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 9){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument for readability
  t0 = round(par[1])
  t0_chill = round(par[2])
  T_base = par[3]
  C_a = par[4]
  C_b = par[5]
  C_c = par[6]
  C_ini = par[7]
  F_crit = par[8]
  C_req = par[9]

  # chilling
  Rc = 1 / ( 1 + exp( C_a * (data$Ti - C_c) ^ 2 + C_b * (data$Ti - C_c) ))
  Rc[1:t0_chill,] = 0
  Sc = apply(Rc,2, cumsum)

  # chilling requirement has to be met before
  # accumulation starts (binary choice)
  k = C_ini + Sc * (1 - C_ini)/C_req
  k[Sc >= C_req] = 1

  # forcing
  Rf = data$Ti - T_base
  Rf[Rf < 0] = 0
  Rf = Rf * k
  Rf[1:t0,] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Parallel M1 model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model, sequential
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = PM1(data = data, par = par)
#'}

# Basler parallel M1 b (bell shaped curve)
PM1 = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 8){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument
  t0 = par[1]
  T_base = par[2]
  T_opt = par[3]
  T_min = par[4]
  T_max = par[5]
  C_ini = par[6]
  F_crit = par[7]
  C_req = par[8]

  # chilling
  Rc = triangular_temperature_response(data$Ti,
                                       T_opt = T_opt,
                                       T_min = T_min,
                                       T_max = T_max)
  Rc[1:t0,] = 0
  Rc[t0:nrow(Rc),] = 0
  Sc = apply(Rc,2, cumsum)

  # chilling requirement has to be met before
  # accumulation starts (binary choice)
  k = C_ini + Sc * (1 - C_ini)/C_req
  k[Sc >= C_req] = 1

  # forcing
  Rf = data$Ti - T_base
  Rf[Rf < 0] = 0
  Rf = ((data$Li / 10) ^ k) * Rf
  Rf[1:t0,] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Parallel M1 model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#' using a bell shaped chilling response
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = PM1(data = data, par = par)
#'}

# Basler parallel M1 b (bell shaped curve)
PM1b = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 8){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument
  t0 = round(par[1])
  T_base = par[2]
  C_a = par[3]
  C_b = par[4]
  C_c = par[5]
  C_ini = par[6]
  F_crit = par[7]
  C_req = par[8]

  # chilling
  Rc = 1 / ( 1 + exp( C_a * (data$Ti - C_c) ^ 2 + C_b * (data$Ti - C_c) ))
  Rc[1:t0,] = 0
  Rc[t0:nrow(Rc),] = 0
  Sc = apply(Rc,2, cumsum)

  # chilling requirement has to be met before
  # accumulation starts (binary choice)
  k = C_ini + Sc * (1 - C_ini)/C_req
  k[Sc >= C_req] = 1

  # forcing
  Rf = data$Ti - T_base
  Rf[Rf < 0] = 0
  Rf = ((data$Li / 10) ^ k) * Rf
  Rf[1:t0,] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Photothermal Time model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = PTT(data = data, par = par)
#'}

PTT = function(par, data){
  # exit the routine as some parameters are missing
  if (length(par) != 3){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument for readability
  t0 = round(par[1]) # int
  T_base = par[2]
  F_crit = par[3]

  # create forcing/chilling rate vector
  # forcing
  Rf = data$Ti - T_base
  Rf[Rf < 0] = 0
  Rf = (data$Li / 24) * Rf
  Rf[1:t0,] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Photothermal Time model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#' with a sigmoidal temperature response (Kramer 1994)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = PTTs(data = data, par = par)
#'}

PTTs = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 4){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument for readability
  t0 = par[1]
  b = par[2]
  c = par[3]
  F_crit = par[4]

  # create forcing/chilling rate vector
  # forcing
  Rf = 1 / (1 + exp(-b * (data$Ti - c)))
  Rf = (data$Li / 24) * Rf
  Rf[1:t0,] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Standard growing season index model
#' as defined by Xin et al. 2015 (Rem. Sens. Env.)
#'
#' No clear accumulation start dat was set in the above mentioned
#' manuscript, as such we assume a start date of 21th of Dec, or 1th of Jan.
#' depending on the offset used in the generated validation data.
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = AGSI(data = data, par = par)
#'}

SGSI = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 7){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # exit the routine if data is missing
  if (is.null(data$Tmini) |
      is.null(data$Tmaxi) |
      is.null(data$VPDi)  |
      is.null(data$Li)
  ){
    stop("Not all required driver data is available")
  }

  # set start of accumulation period
  t0 = which(data$doy == -11)
  if (length(t0) == 0){
    t0 = 1
  }

  # extract the parameter values from the
  # par argument for readability
  Tmmin = par[1]
  Tmmax = par[2]
  F_crit = par[3]
  VPDmin = par[4]
  VPDmax = par[5]
  photo_min = par[6]
  photo_max = par[7]

  # rescaling all parameters between 0 - 1 for the
  # acceptable ranges, if outside these ranges
  # set to 1 (unity) or 0 respectively
  Tmin = (data$Tmini - Tmmin)/(Tmmax - Tmmin)
  VPD = (data$VPDi - VPDmin)/(VPDmax - VPDmin)
  photo = (data$Li - photo_min)/(photo_max - photo_min)

  # set outliers to 1 or 0 (step function)
  Tmin[which(data$Tmini <= Tmmin)] = 0
  Tmin[which(data$Tmini >= Tmmax)] = 1

  VPD[which(data$VPDi >= VPDmax)] = 0
  VPD[which(data$VPDi <= VPDmin)] = 1

  photo[which(data$Li <= photo_min)] = 0
  photo[which(data$Li >= photo_max)] = 1

  # calculate the index for every value
  # but set values for time t0 to 0
  GSI = Tmin * VPD * photo
  GSI[1:t0,] = 0

  # DOY of budburst criterium as calculated
  # by cummulating the GSI hence AGSI
  doy = apply(GSI,2, function(xt){
    doy = data$doy[which(zoo::rollmean(xt, 21, na.pad = TRUE) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Sequential model (M1 variant) as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model, sequential
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = TT(data = data, par = par)
#'}

SM1 = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 8){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument
  t0 = par[1]
  t0_chill = par[2]
  T_base = par[3]
  T_opt = par[4]
  T_min = par[5]
  T_max = par[6]
  F_crit = par[7]
  C_req = par[8]

  # sanity check
  if (t0 <= t0_chill){
    return(rep(NA,ncol(data$Ti)))
  }

  # chilling
  Rc = triangular_temperature_response(data$Ti,
                                       T_opt = T_opt,
                                       T_min = T_min,
                                       T_max = T_max)
  Rc[1:t0_chill,] = 0
  Rc[t0:nrow(Rc),] = 0
  Sc = apply(Rc,2, cumsum)

  # chilling requirement has to be met before
  # accumulation starts (binary choice)
  k = as.numeric(Sc >= C_req)

  # forcing
  Rf = data$Ti - T_base
  Rf[Rf < 0] = 0
  Rf = (data$Li / 24) ^ k * Rf
  Rf[1:t0,] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Sequential model (M1 variant) as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#' using a bell shaped chilling response
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = SM1b(data = data, par = par)
#'}

SM1b = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 8){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument for readability
  t0 = round(par[1])
  t0_chill = round(par[2])
  T_base = par[3]
  C_a = par[4]
  C_b = par[5]
  C_c = par[6]
  F_crit = par[7]
  C_req = par[8]

  # sanity check
  if (t0 <= t0_chill){
    return(rep(NA,ncol(data$Ti)))
  }

  # chilling
  Rc = 1 / ( 1 + exp( C_a * (data$Ti - C_c) ^ 2 + C_b * (data$Ti - C_c) ))
  Rc[1:t0_chill,] = 0
  Rc[t0:nrow(Rc),] = 0
  Sc = apply(Rc,2, cumsum)

  # chilling requirement has to be met before
  # accumulation starts (binary choice)
  k = as.numeric(Sc >= C_req)

  # forcing
  Rf = data$Ti - T_base
  Rf[Rf < 0] = 0
  Rf = ((data$Li / 24) ^ k) * Rf
  Rf[1:t0,] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Sequential model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
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
    return(rep(NA, ncol(data$Ti)))
  }

  # chilling
  Rc = triangular_temperature_response(data$Ti,
                                       T_opt = T_opt,
                                       T_min = T_min,
                                       T_max = T_max)
  Rc[1:t0_chill,] = 0
  Rc[t0:nrow(Rc),] = 0
  Sc = apply(Rc, 2, cumsum)

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
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Sequential model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#' using a bell shaped chilling response
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = SQb(data = data, par = par)
#'}

SQb = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 8){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument for readability
  t0 = round(par[1])
  t0_chill = round(par[2])
  T_base = par[3]
  C_a = par[4]
  C_b = par[5]
  C_c = par[6]
  F_crit = par[7]
  C_req = par[8]

  # chilling
  Rc = 1 / ( 1 + exp( C_a * (data$Ti - C_c) ^ 2 + C_b * (data$Ti - C_c) ))
  Rc[1:t0_chill,] = 0
  Rc[t0:nrow(Rc),] = 0
  Sc = apply(Rc,2, cumsum)

  # chilling requirement has to be met before
  # accumulation starts (binary choice)
  k = as.numeric(Sc >= C_req)

  # forcing (with bell shaped curve -- only for forcing not chilling?)
  Rf = data$Ti - T_base
  Rf[Rf < 0] = 0
  Rf = Rf * k
  Rf[1:t0,] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Thermal Time model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = TT(data = data, par = par)
#'}

TT = function(par, data ){

  # exit the routine as some parameters are missing
  if (length(par) != 3){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument for readability
  t0 = round(par[1])
  T_base = par[2]
  F_crit = par[3]

  # simple degree day sum setup
  Rf = data$Ti - T_base
  Rf[Rf < 0] = 0
  Rf[1:t0,] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Thermal Time model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#' with a sigmoidal temperature response (Kramer 1994)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = TTs(data = data, par = par)
#'}

TTs = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 4){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument for readability
  t0 = round(par[1])
  b = par[2]
  c = par[3]
  F_crit = par[4]

  # sigmoid temperature response
  Rf = 1 / (1 + exp(-b * (data$Ti - c)))
  Rf[1:t0,] = 0

  # DOY of budburst criterium
  doy = apply(Rf,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Unified M1 model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = UM1(data = data, par = par)
#'}

UM1  = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 8){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument
  t0 = round(par[1])
  T_base = par[2]
  T_opt = par[3]
  T_min = par[4]
  T_max = par[5]
  f = par[6]
  w = par[7]
  C_req = par[8]

  # chilling accumulation using the
  # bell shaped temperature response
  Rc = triangular_temperature_response(data$Ti,
                                       T_opt = T_opt,
                                       T_min = T_min,
                                       T_max = T_max)
  Rc[1:t0,] = 0
  Sc = apply(Rc, 2, cumsum)

  # chilling requirement has to be met before
  # accumulation starts (binary choice)
  k = as.numeric(Sc >= C_req)

  # forcing
  Rf = data$Ti - T_base
  Rf[Rf < 0] = 0
  Rf = ((data$Li / 10) ^ k) * Rf
  Rf[1:t0,] = 0
  Sf = apply(Rf, 2, cumsum)

  # DOY meeting F_crit, subtract the forcing matrix
  # from the F_crit matrix in order to speed things up
  # only the location of transition from - to + is
  # claculated to estimate the transition dates
  Sfc = Sf - (w * exp(f * Sc))

  doy = apply(Sfc, 2, function(x){
    doy = data$doy[which(x > 0)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Unified model as defined in
#' Basler et al. 2016 (Agr. For. Meteorlogy)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = UN(data = data, par = par)
#'}

UN  = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 8){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument
  t0 = round(par[1])
  T_base = par[2]
  T_opt = par[3]
  T_min = par[4]
  T_max = par[5]
  f = par[6]
  w = par[7]
  C_req = par[8]

  # chilling accumulation using the
  # bell shaped temperature response
  Rc = triangular_temperature_response(data$Ti,
                                       T_opt = T_opt,
                                       T_min = T_min,
                                       T_max = T_max)
  Rc[1:t0,] = 0

  # cummulative sum of temp response
  Sc = apply(Rc, 2, cumsum)

  # chilling requirement has to be met before
  # accumulation starts (binary choice)
  k = as.numeric(Sc >= C_req)

  # forcing
  Rf = data$Ti - T_base
  Rf[Rf < 0] = 0
  Rf = Rf * k
  Rf[1:t0,] = 0
  Sf = apply(Rf, 2, cumsum)

  # DOY meeting F_crit, subtract the forcing matrix
  # from the F_crit matrix in order to speed things up
  # only the location of transition from - to + is
  # calculated to estimate the transition dates
  Sfc = Sf - (w * exp(f * Sc))

  doy = apply(Sfc, 2, function(x){
    doy = data$doy[which(x > 0)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' Accumulated growing season index model (1)
#' as defined by Xin et al. 2015 (Rem. Sens. Env.)
#'
#' The starting point of accumulation is not clearly indicated
#' in the publication so we assume December 21.
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = AGSI(data = data, par = par)
#'}

AGSI = function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 7){
    stop(sprintf("model parameter(s) out of range (too many, too few, %s provided)",
                 length(par)))
  }

  # exit the routine if data is missing
  if (is.null(data$Tmini) |
      is.null(data$Tmaxi) |
      is.null(data$VPDi)  |
      is.null(data$Li)
  ){
    stop("Not all required driver data is available")
  }

  # set start of accumulation period
  t0 = which(data$doy == -11)
  if (length(t0)==0){
    t0 = 1
  }

  # extract the parameter values from the
  # par argument for readability
  Tmmin = par[1]
  Tmmax = par[2]
  F_crit = par[3]
  VPDmin = par[4]
  VPDmax = par[5]
  photo_min = par[6]
  photo_max = par[7]

  # rescaling all parameters between 0 - 1 for the
  # acceptable ranges, if outside these ranges
  # set to 1 (unity) or 0 respectively
  Tmin = (data$Tmini - Tmmin)/(Tmmax - Tmmin)
  VPD = (data$VPDi - VPDmin)/(VPDmax - VPDmin)
  photo = (data$Li - photo_min)/(photo_max - photo_min)

  # set outliers to 1 or 0
  Tmin[which(data$Tmini <= Tmmin)] = 0
  Tmin[which(data$Tmini >= Tmmax)] = 1

  VPD[which(data$VPDi >= VPDmax)] = 0
  VPD[which(data$VPDi <= VPDmin)] = 1

  photo[which(data$Li <= photo_min)] = 0
  photo[which(data$Li >= photo_max)] = 1

  # calculate the index for every value
  # but set values for time t0 to 0
  GSI = Tmin * VPD * photo
  GSI[1:t0,] = 0

  # DOY of budburst criterium as calculated
  # by cummulating the GSI hence AGSI
  doy = apply(GSI,2, function(xt){
    doy = data$doy[which(cumsum(xt) >= F_crit)[1]]
    doy[is.na(doy)] = 9999
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}

#' CU chilling degree model
#' Chen et al. 2017 (Journal of Ecology)
#'
#' @param data input data (see reference for detailed description),
#' data should be formatted using flat_format()
#' @param par a vector of parameter values, this is functions specific
#' @return raster or vector with estimated phenophase timing (in DOY)
#' @keywords phenology, model, tropical forest
#' @export
#' @examples
#'
#' \dontrun{
#' estimate = CU(data = data, par = par)
#'}

CU <- function(par, data){

  # exit the routine as some parameters are missing
  if (length(par) != 4){
    stop("model parameter(s) out of range (too many, too few)")
  }

  # extract the parameter values from the
  # par argument
  ni = round(par[1])
  nd = round(par[2])
  T_base = par[3]
  F_crit = par[4]

  # simple chilling degree day sum setup
  # with lagged response
  data$Ti[data$Ti > T_base] = 0
  data$Ti <- abs(data$Ti)

  # calculate floral induction time series
  Fd <- apply(data$Ti, 2, function(x){
    Fi <- zoo::rollapply(x, ni, sum, align = "right", fill = 0, na.rm = TRUE)
    Fd <- c(rep(0,nd),Fi[1:(length(Fi) - nd)])
  })

  # DOY of budburst criterium
  doy = apply(Fd, 2, function(xt){
    doy = data$doy[which(xt >= F_crit)[1]]
    return(doy)
  })

  # set export format, either a rasterLayer
  # or a vector
  shape_model_output(data = data, doy = doy)
}
