# rename certain symbols in a character vector
# 
# @param names a character vector of names to be renamed
# @param symbols the regular expressions in names to be replaced
# @param subs the replacements
# @param fixed same as for sub, grepl etc
# @param check_dup logical; check for duplications in names after renaming
# 
# @return renamed parameter vector of the same length as names
rename <- function(names, symbols = NULL, subs = NULL, fixed = TRUE, check_dup = FALSE) {
  if (is.null(symbols))
    symbols <- c(" ", "(", ")", "[", "]", ",", "+", "-", "*", "/", "^", "=", "!=")
  if (is.null(subs))
    subs <- c(rep("", 6), "P", "M", "MU", "D", "E", "EQ", "NEQ")
  if (length(symbols) != length(subs)) 
    stop("length(symbols) != length(subs)")
  new.names <- names
  for (i in 1:length(symbols)) 
    new.names <- gsub(symbols[i], subs[i], new.names, fixed = fixed)
  dup <- duplicated(new.names)
  if (check_dup && any(dup)) 
    stop(paste0("Internal renaming of variables led to duplicated names. \n",
                "Occured for variables: ", paste(names[which(new.names %in% new.names[dup])], collapse = ", ")))
  new.names
}

# rename parameters (and possibly change their dimensions) within the stanfit object 
# to ensure reasonable parameter names for summary, plot, launch_shiny etc.
# 
# @param x a brmsfit obejct
#
# @return a brmfit object with adjusted parameter names and dimensions
rename_pars <- function(x) {
  if (!length(x$fit@sim)) return(x)
  chains <- length(x$fit@sim$samples) 
  n_pars <- length(x$fit@sim$fnames_oi)
  n_metapars <- length(x$fit@sim$dims_oi)
  x$fit@sim$fnames_oi[1:(n_pars-1)] <- rename(x$fit@sim$fnames_oi[1:(n_pars-1)], "__", ":")
  names(x$fit@sim$dims_oi)[1:(n_metapars-1)] <- 
    rename(names(x$fit@sim$dims_oi[1:(n_metapars-1)]), "__", ":")
  for (i in 1:chains) names(x$fit@sim$samples[[i]]) <- x$fit@sim$fnames_oi
  pars <- dimnames(x$fit)$parameters
  ee <- extract_effects(x$formula, family = x$family)
  change <- list()
  
  #find positions of parameters and define new names
  f <- colnames(x$data$X)
  if (length(f) && x$family != "categorical") {
    change[[length(change)+1]] <- list(pos = grepl("^b\\[", pars), 
                                       oldname = "b", 
                                       pnames = paste0("b_",f), 
                                       fnames = paste0("b_",f))
    #change prior parameters
    change <- c(change, change_prior_names(class = "b", pars = pars, names = f))
  }
  
  if (is.formula(x$partial) || x$family == "categorical") {
    if (x$family == "categorical") p <- colnames(x$data$X)
    else p <- colnames(x$data$Xp)
    thres <- (max(x$data$max_obs) - 1)
    change[[length(change)+1]] <- list(pos = grepl("^bp\\[", pars), 
                                       oldname = "bp", 
                                       pnames = paste0("b_",p), 
                                       fnames = paste0("b_", sapply(p, function(p) 
                                         sapply(1:thres, function(i) paste0(p,"[",i,"]")))),
                                       dim = thres,
                                       sort = unlist(lapply(1:length(p), function(k) 
                                         seq(k, thres*length(p), length(p)))))
    #change prior parameters 
    change <- c(change, change_prior_names(class = "bp", pars = pars, names = p, new_class = "b"))
  }  
  
  if (length(x$ranef)) {
    group <- names(x$ranef)
    gf <- make_group_frame(x$ranef)
    for (i in 1:length(x$ranef)) {
      change[[length(change)+1]] <- list(pos = grepl(paste0("^sd_",i,"(\\[|$)"), pars),
                                         oldname = paste0("sd_",i),
                                         pnames = paste0("sd_",group[i],"_", x$ranef[[i]]),
                                         fnames = paste0("sd_",group[i],"_", x$ranef[[i]]))
      #change prior parameters
      change <- c(change, change_prior_names(class = paste0("sd_",i), pars = pars, names = x$ranef[[i]],
                                             new_class = paste0("sd_",group[i])))
      
      if (length(x$ranef[[i]]) > 1 && ee$cor[[i]]) {
        cor_names <- get_cornames(x$ranef[[i]], type = paste0("cor_",group[i]), brackets = FALSE)
        change[[length(change)+1]] <- list(pos = grepl(paste0("^cor_",i,"(\\[|$)"), pars),
                                           oldname = paste0("cor_",i),
                                           pnames = cor_names,
                                           fnames = cor_names) 
        #change prior parameters
        change <- c(change, change_prior_names(class = paste0("cor_",i), pars = pars, 
                                               new_class = paste0("cor_",group[i])))
      }
      if (any(grepl("^r_", pars))) {
        lc <- length(change) + 1
        change[[lc]] <- list(pos = grepl(paste0("^r_",i,"(\\[|$)"), pars),
                                         oldname = paste0("r_",i))
        # prepare for removal of redundant parameters r_<i>
        # and for commbining random effects into one paramater matrix
        n_ranefs <- max(gf$last[which(gf$g == group[i])]) #number of total REs for this grouping factor
        old_dim <- x$fit@sim$dims_oi[[change[[lc]]$oldname]]
        indices <- make_indices(rows = 1:old_dim[1], cols = gf$first[i]:gf$last[i], 
                               dim = ifelse(n_ranefs == 1, 1, 2))
        if (match(gf$g[i], group) < i) 
          change[[lc]]$pnames <- NULL 
        else {
          change[[lc]]$pnames <- paste0("r_",group[i])
          change[[lc]]$dim <- if (n_ranefs == 1) old_dim else c(old_dim[1], n_ranefs) 
        } 
        change[[lc]]$fnames <- paste0("r_",group[i], indices)
      }  
    }
  }
  if (x$family %in% c("gaussian", "student", "cauchy") && !is.formula(ee$se)) {
   change[[length(change)+1]] <- list(pos = grepl("^sigma", pars), 
                                      oldname = "sigma",
                                      pnames = paste0("sigma_",ee$response),
                                      fnames = paste0("sigma_",ee$response))
   #change prior parameters
   change <- c(change, change_prior_names(class = "sigma", pars = pars, names = ee$response))
   #rename residual correlation paramaters
   if (x$family == "gaussian" && length(ee$response) > 1) {
      rescor_names <- paste0("rescor_",unlist(lapply(2:length(ee$response), function(j) 
          lapply(1:(j-1), function(k) paste0(ee$response[k],"_",ee$response[j])))))
     change[[length(change)+1]] <- list(pos = grepl("^rescor\\[", pars), 
                                        oldname = "rescor",
                                        pnames = rescor_names,
                                        fnames = rescor_names)
    }
  } 
  
  #rename parameters
  if (length(change)) {
    for (c in 1:length(change)) {
      x$fit@sim$fnames_oi[change[[c]]$pos] <- change[[c]]$fnames
      for (i in 1:chains) {
        names(x$fit@sim$samples[[i]])[change[[c]]$pos] <- change[[c]]$fnames
        if (!is.null(change[[c]]$sort)) x$fit@sim$samples[[i]][change[[c]]$pos] <- 
            x$fit@sim$samples[[i]][change[[c]]$pos][change[[c]]$sort]
      }
      onp <- match(change[[c]]$oldname, names(x$fit@sim$dims_oi))
      if (is.null(change[[c]]$pnames)) 
        x$fit@sim$dims_oi[[onp]] <- NULL #remove this parameter from dims_oi
      else #rename dims_oi 
        x$fit@sim$dims_oi <- c(if (onp > 1) x$fit@sim$dims_oi[1:(onp-1)], 
                               setNames(lapply(change[[c]]$pnames, function(x) 
                                 if (is.null(change[[c]]$dim)) numeric(0)
                                 else change[[c]]$dim), 
                                 change[[c]]$pnames),
                               x$fit@sim$dims_oi[(onp+1):length(x$fit@sim$dims_oi)])
    }
  }
  x$fit@sim$pars_oi <- names(x$fit@sim$dims_oi)
  # combines duplicated grouping factors to appear as if it was only one
  if (length(x$ranef)) x$ranef <- combine_duplicates(x$ranef)
  x
}

# make a little data.frame helping to rename and combine random effects
# @param ranef a named list containing the random effects. The names are taken as grouping factors
# @return a data.frame with length(ranef) rows and 3 columns: 
#   \code{g}: the grouping factor of each terms 
#   \code{first} a number corresponding to the first column for this term in the final r_<gf> matrices
#   \code{last} a number corresponding to the last column for this term in the final r_<gf> matrices
make_group_frame <- function(ranef) {
  group <- names(ranef)
  out <- data.frame(g = group, first = NA, last = NA)
  out[1,2:3] <- c(1, length(ranef[[1]]))
  if (length(group) > 1) {
    for (i in 2:length(group)) {
      matches <- which(out$g[1:(i-1)] == group[i])
      if (length(matches))
        out[i,2:3] <- c(out$last[max(matches)] + 1, out$last[max(matches)] + length(ranef[[i]]))
      else out[i,2:3] <- c(1, length(ranef[[i]]))
    }
  }
  out
}

# make indices in square brackets for indexing stan parameters
# @param rows a vector of rows
# @param cols a vector of columns
# @param dim The number of dimensions of the output either 1 or 2
# @return all index (pairs) for rows and cols
make_indices <- function(rows, cols = NULL, dim = 1) {
  if (!dim %in% c(1,2))
    stop("dim must be 1 or 2")
  if (dim == 1) indices <- paste0("[",rows,"]")
  else {
    indices <- expand.grid(rows, cols)
    indices <- unlist(lapply(1:nrow(indices), function(i)
      paste0("[",paste0(indices[i,], collapse = ","),"]")))
  }
  indices
}

# combine elements of a list that have the same name
#
# @param x a list
#
# @return a list of possibly reducte length.
# 
# @examples
# combine_duplicates(list(a = 1, a = c(2,3)))
# #becomes list(a = c(1,2,3)) 
combine_duplicates <- function(x) {
  if (!is.list(x)) stop("x must be a list")
  if (is.null(names(x))) stop("elements of x must be named")
  unique_names <- unique(names(x))
  new_list <- setNames(do.call(list, as.list(rep(NA, length(unique_names)))), nm = unique_names)
  for (i in 1:length(unique_names)) {
    pos <- which(names(x) %in% unique_names[i])
    new_list[[unique_names[i]]] <- unname(unlist(x[pos]))
  }
  new_list
}

# helps in renaming priors
#
# @param class the class of the parameters for which prior names should be changed
# @param pars all parameters in the model
# @param names names to replace digits at the end of parameter names
# @param new_class replacment of the orginal class name
#
# @returns a list whose elements can be interpreted by rename_pars
change_prior_names <- function(class, pars, names = NULL, new_class = class) {
  change <- list()
  pos_priors <- which(grepl(paste0("^prior_",class,"(_|$)"), pars))
  if (length(pos_priors)) {
    priors <- gsub(paste0("^prior_",class), paste0("prior_",new_class), pars[pos_priors])
    digits <- sapply(priors, function(prior) {
      d <- regmatches(prior, gregexpr("_[[:digit:]]+$", prior))[[1]]
      if (length(d)) as.numeric(substr(d, 2, nchar(d))) else 0
    })
    if (sum(abs(digits)) > 0 && is.null(names)) stop("argument names is missing")
    for (i in 1:length(priors)) {
      if (digits[i]) priors[i] <- gsub("[[:digit:]]+$", names[digits[i]], priors[i])
      if (pars[pos_priors[i]] != priors[i])
        change[[length(change)+1]] <- list(pos = pos_priors[i], 
                                           oldname = pars[pos_priors[i]],
                                           pnames = priors[i],
                                           fnames = priors[i])
    }
  }
  change
}  