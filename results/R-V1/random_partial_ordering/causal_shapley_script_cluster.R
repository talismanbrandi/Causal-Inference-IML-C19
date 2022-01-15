#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

now <- Sys.time()
library(data.table)
library(xgboost)
library(shapr)
library("rjson")

# stagger the start
Sys.sleep(runif(1, 1, 5))

##############################
# Read from configuration file
##############################
filename <- if (length(args)==0) "configurations.json" else args[1]

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

output_dir <- if (config$output_dir == '') '' else paste(config$output_dir, "/", sep='')

# Load data
rate <- read.csv(config$filename)


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


##############################
# SHAP
##############################

# Compute SHAP values
explainer_symmetric <- shapr(x_train, model, n_combinations=n_comb)

# TODO: Check if this should take y_train or y_test
p <- mean(y_test)


explanation_causal <- explain(
  x_test,
  approach = "causal",
  explainer = explainer_symmetric,
  prediction_zero = p,
  ordering = partial_order,
  confounding = confound_list,
  #seed = 2020
)

then <- Sys.time()


##############################
# save to file
##############################

# create UUID
set.seed(as.numeric(then - now)*1e6)
pool <- c(letters, LETTERS, 0:9)
uuid <- paste0(sample(pool, 6, replace = TRUE), collapse = "")

# save to file
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
filename <- paste(output_dir, "shap_values_", uuid, ".rds", sep='')
saveRDS(explanation_causal, file=filename)
tmp <- file.copy("configurations.json", output_dir)
