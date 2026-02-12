# =============================================================================
# run_all.R - Master script: gender prediction improvement pipeline
# =============================================================================
# Usage: source this file from the project root, or run:
#   Rscript 01_gender_prediction_improvement/run_all.R
# Optional DB overwrite:
#   Rscript 01_gender_prediction_improvement/run_all.R --overwrite-users-pred-gender
#
# Steps:
#   1) Extract morphological gender features from DB (SQL aggregation)
#   2) Apply weighted voting algorithm to predict gender
#   3) Evaluate and compare against baseline + ground truth
# =============================================================================

library(here)

args <- commandArgs(trailingOnly = TRUE)
overwrite_users_pred_gender <- "--overwrite-users-pred-gender" %in% args

message("============================================")
message(" Predykcja płci gramatycznej - ulepszenie")
message(" Start: ", Sys.time())
message(" Nadpisanie users.pred_gender: ", ifelse(overwrite_users_pred_gender, "TAK", "NIE"))
message("============================================\n")

# 1) Extract features from database
source(here("01_gender_prediction_improvement", "scripts",
            "01_extract_gender_features.R"))

# 2) Predict gender using weighted voting
source(here("01_gender_prediction_improvement", "scripts",
            "02_predict_gender.R"))

# 3) Evaluate and compare with baseline
source(here("01_gender_prediction_improvement", "scripts",
            "03_evaluate_comparison.R"))

message("\n============================================")
message(" Pipeline zakończony: ", Sys.time())
message("============================================")
