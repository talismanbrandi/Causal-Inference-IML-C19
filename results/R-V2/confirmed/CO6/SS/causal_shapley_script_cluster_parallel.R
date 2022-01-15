#!/usr/bin/env Rscript
args <- commandArgs(trailingOnly = TRUE)

now <- Sys.time()
library(data.table)
library(xgboost)
library(shapr)
library(rjson)
library(foreach)
library(iterators)
library(parallel)
library(doParallel)


`%notin%` <- Negate(`%in%`)

# stagger the start
Sys.sleep(runif(1, 1, 5))

##############################
# Read from configuration file
##############################
filename <- if (length(args) == 0) "configurations.json" else args[1]

# load configurations
if (file.exists(filename)) {
  config <- fromJSON(file = filename)
} else {
  stop(paste(filename, "does not exist."))
}

# list x variables
x_var <- config$x_var

# list y variable
y_var <- config$y_var

# n_comb combinations for SHAP
n_comb <- if (config$n_comb == 0) 2**length(x_var) else config$n_comb

# Define partial order, i.e. the tau groups in the paper
partial_order <- config$partial_order

# Define which of the tau groups have confounding variables
confound_list <- config$confound_list

output_dir <- if (config$output_dir == '') '' else paste(config$output_dir, "/", sep = '')

# Load data
rate <- read.csv(config$filename)

# set the number of cores
num_cores <- if ("num_cores" %in% names(config)) config$num_cores else 10

# set the number of ensembles
ensemble_size <- if ("ensemble_size" %in% names(config)) config$ensemble_size else 10

# get the output format
output_format <- if ("output_format" %in% names(config)) config$output_format else "csv"

if (output_format %notin% c("rds", "csv")) stop(paste(output_format, " not supported."))


#####################################
# Start the cluster
#####################################

registerDoParallel(num_cores)


#####################################
# Train the ensemble and compute shap
#####################################

combined_results <- foreach(i = 1:ensemble_size, .combine = rbind) %do% {

  ##############################
  # xgboost
  ##############################
  # Random split into train and test data
  train_index <- caret::createDataPartition(rate$confirmed.rate, p = .7, list = FALSE, times = 1)

  x_train <- as.matrix(rate[train_index, x_var])
  y_train_nc <- as.matrix(rate[train_index, y_var]) # not centered
  y_train <- y_train_nc - mean(y_train_nc)

  x_test <- as.matrix(rate[-train_index, x_var])
  y_test_nc <- as.matrix(rate[-train_index, y_var]) # not centered
  y_test <- y_test_nc - mean(y_train_nc)


  # Fit XGBoost model
  model <- xgboost(
    data = x_train,
    label = y_train,
    nround = 100,
    verbose = FALSE,
    nthread = 1,
    max.depth = 3,
    subsample = 1.,
    colsample_bytree = 1.,
    eta = 0.1
  )

  predicted <- predict(model, x_test)
  residuals <- y_test - predicted
  y_test_mean <- mean(y_test)

  # Calculate total sum of squares
  tss <-  sum((y_test - y_test_mean)^2)

  # Calculate residual sum of squares
  rss <-  sum(residuals^2)

  # Calculate R-squared
  rsq  <-  1 - (rss / tss)


  ##############################
  # SHAP
  ##############################

  # Compute SHAP values
  explainer_symmetric <- shapr(x_train, model, n_combinations = n_comb)

  # take only a part of the data to reduce computational burden
  index <- sample(seq_len(nrow(x_test)), 40, replace = TRUE)

  # TODO: Check if this should take y_train or y_test
  p <- mean(y_test[index, ])

  results <- foreach(i = 1:20, .combine = rbind) %dopar% {
    j <- 2 * i - 1
    k <- 2 * i
    x_test_shap <- x_test[index[j:k], ]
    y_test_shap <- y_test[index[j:k], ]

    explanation_causal <- explain(
      x_test_shap,
      approach = "causal",
      explainer = explainer_symmetric,
      prediction_zero = p,
      ordering = partial_order,
      confounding = confound_list,
      #seed = 2020
    )

    data.frame(explanation_causal[-2])
  }

  results <- data.frame(results, y_select = y_test[index, ], rsq = rsq)

}

then <- Sys.time()

print(then - now)

##############################
# save to file
##############################

# create UUID
set.seed(as.numeric(then - now) * 1e6)
pool <- c(letters, LETTERS, 0:9)
uuid <- paste0(sample(pool, 6, replace = TRUE), collapse = "")

# save to file
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
filename <- paste(output_dir, "shap_values_", uuid, ".", output_format, sep = '')

if (output_format == "rds") {
  saveRDS(combined_results, file = filename)
} else if (output_format == "csv") {
  write.csv(combined_results, filename)
} else {

}

tmp <- file.copy(filename, output_dir)


##############################
# clean up the cluster
##############################
stopImplicitCluster()