# =============================================================================
# 03_evaluate_comparison.R - Evaluate and compare gender prediction models
# =============================================================================
# Compares:
#   1) Baseline (Python script) — stored in users.pred_gender
#   2) New R algorithm — from 02_predict_gender.R output
# Against Ground Truth — users.gender (where 'M' or 'K')
#
# NEW: Includes Optional Threshold Sensitivity Analysis (0.1 - 0.9)
# FIX: Detaches bit64 with unload=FALSE to prevent dependency warnings
# =============================================================================

library(dplyr)
library(readr)
library(tidyr)
library(ggplot2)
library(scales)
library(here)
library(DBI)
library(purrr) # For map_dfr

# --- Configuration ---
RUN_THRESHOLD_ANALYSIS <-   FALSE  # Set to FALSE to skip the loop

# --- Reuse shared helpers ---
source(here::here("00_basic_corpus_statistics", "scripts", "00_setup_theme.R"))

# --- Database connection ---
source(here::here("00_basic_corpus_statistics", "scripts", "db_connection.R"))

message("\n=== EWALUACJA I POROWNANIE MODELI PREDYKCJI PLCI === ")
message("Start: ", Sys.time())

# =============================================================================
# 1) Load data
# =============================================================================

# Ground truth + baseline from database
users_db_raw <- dbGetQuery(con, "
  SELECT
    id AS user_id,
    gender AS ground_truth,
    pred_gender AS baseline_pred
  FROM users
")

dbDisconnect(con)
message("Dane z bazy pobrane (", nrow(users_db_raw), " wierszy).")

# FIX: Convert integer64 to numeric immediately
users_db <- users_db_raw |>
  as_tibble() |>
  mutate(user_id = as.numeric(user_id))

# CRITICAL FIX: Detach bit64/bit if loaded to restore base '==' and '%in%' operators
# We use unload=FALSE because readr/RPostgres might need the namespace loaded.
if ("package:bit64" %in% search()) {
  message("Detaching bit64 to restore base comparison operators...")
  detach("package:bit64", unload = FALSE)
}
if ("package:bit" %in% search()) {
  detach("package:bit", unload = FALSE)
}

# Load New predictions
new_preds_path <- here::here("01_gender_prediction_improvement", "output", "data", "new_gender_predictions.csv")

if (!file.exists(new_preds_path)) {
  stop("Brak pliku z nowymi predykcjami: ", new_preds_path)
}

# We load confidence and score_total for the threshold simulation
new_preds <- read_csv(new_preds_path, show_col_types = FALSE) |>
  select(user_id, new_pred_gender, confidence, score_total, score_m, score_k)

message("Nowe predykcje wczytane.")

# =============================================================================
# 2) Merge and Clean
# =============================================================================

eval_data <- users_db |>
  left_join(new_preds, by = "user_id") |>
  mutate(
    # Normalize gender labels
    ground_truth  = trimws(toupper(ground_truth)),
    baseline_pred = trimws(baseline_pred),
    # Default 'new_pred_gender' comes from the fixed threshold in step 02
    new_pred_gender_fixed = coalesce(new_pred_gender, "unknown")
  ) |>
  # Keep only valid Ground Truth for accuracy metrics (M or K)
  mutate(
    has_gt = ground_truth %in% c("M", "K")
  )

message("Polaczono dane. Liczba uzytkownikow z GT: ", sum(eval_data$has_gt))

# =============================================================================
# 3) Standard Comparison (Baseline vs Fixed Threshold from Step 02)
# =============================================================================

calc_metrics <- function(df, pred_col, gt_col = "ground_truth") {
  df_filtered <- df |> filter(.data[[gt_col]] %in% c("M", "K"))
  total_gt <- nrow(df_filtered)

  tp_m <- sum(df_filtered[[gt_col]] == "M" & df_filtered[[pred_col]] == "M", na.rm = TRUE)
  tp_k <- sum(df_filtered[[gt_col]] == "K" & df_filtered[[pred_col]] == "K", na.rm = TRUE)

  classified <- df_filtered |> filter(.data[[pred_col]] %in% c("M", "K"))
  n_predicted <- nrow(classified)

  accuracy <- if(n_predicted > 0) (tp_m + tp_k) / n_predicted else 0
  coverage <- if(total_gt > 0) n_predicted / total_gt else 0

  # F1 Scores
  fp_m <- sum(df_filtered[[gt_col]] == "K" & df_filtered[[pred_col]] == "M", na.rm = TRUE)
  fn_m <- sum(df_filtered[[gt_col]] == "M" & df_filtered[[pred_col]] != "M", na.rm = TRUE)
  prec_m <- if((tp_m + fp_m) > 0) tp_m / (tp_m + fp_m) else 0
  rec_m  <- if((tp_m + fn_m) > 0) tp_m / (tp_m + fn_m) else 0
  f1_m   <- if((prec_m + rec_m) > 0) 2 * prec_m * rec_m / (prec_m + rec_m) else 0

  tp_k_f1 <- tp_k # symmetry
  fp_k <- sum(df_filtered[[gt_col]] == "M" & df_filtered[[pred_col]] == "K", na.rm = TRUE)
  fn_k <- sum(df_filtered[[gt_col]] == "K" & df_filtered[[pred_col]] != "K", na.rm = TRUE)
  prec_k <- if((tp_k + fp_k) > 0) tp_k / (tp_k + fp_k) else 0
  rec_k  <- if((tp_k + fn_k) > 0) tp_k / (tp_k + fn_k) else 0
  f1_k   <- if((prec_k + rec_k) > 0) 2 * prec_k * rec_k / (prec_k + rec_k) else 0

  list(
    n_ground_truth = total_gt,
    n_predicted = n_predicted,
    coverage = coverage * 100,
    accuracy = accuracy * 100,
    precision_m = prec_m * 100, recall_m = rec_m * 100, f1_m = f1_m * 100,
    precision_k = prec_k * 100, recall_k = rec_k * 100, f1_k = f1_k * 100
  )
}

metrics_bl <- calc_metrics(eval_data, "baseline_pred")
metrics_nw <- calc_metrics(eval_data, "new_pred_gender_fixed")

metrics_comparison <- bind_rows(
  bind_cols(model = "Baseline (Python)", as_tibble(metrics_bl)),
  bind_cols(model = "New R Algorithm", as_tibble(metrics_nw))
)

message("\n--- POROWNANIE METRYK (Fixed Threshold) ---")
print(metrics_comparison |> select(model, n_ground_truth, n_predicted, coverage, accuracy))

# Save standard outputs
tables_dir <- here::here("01_gender_prediction_improvement", "output", "tables")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)
write_csv(metrics_comparison, file.path(tables_dir, "01_metrics_comparison.csv"))

# =============================================================================
# 4) OPTIONAL: Threshold Sensitivity Analysis (0.1 - 0.9)
# =============================================================================

if (RUN_THRESHOLD_ANALYSIS) {
  message("\n--- ANALIZA WRAZLIWOSCI PROGU (Threshold Sensitivity) ---")
  
  # Sequence from 0.1 to 0.9
  thresholds <- seq(0.1, 0.9, by = 0.1)
  
  simulate_threshold <- function(th, df) {
    # Logic matches 02_predict_gender.R but with dynamic threshold
    df_sim <- df |>
      mutate(
        sim_gender = case_when(
          score_total == 0 ~ "unknown",
          confidence < th ~ "unknown",
          score_m > score_k ~ "M",
          score_k > score_m ~ "K",
          TRUE ~ "unknown"
        )
      )
    
    # Accuracy on GT subset
    gt_subset <- df_sim |> filter(has_gt, sim_gender != "unknown")
    n_correct <- sum(gt_subset$sim_gender == gt_subset$ground_truth)
    accuracy <- if(nrow(gt_subset) > 0) n_correct / nrow(gt_subset) else 0
    
    # Coverage on Total Population
    n_classified_total <- sum(df_sim$sim_gender != "unknown")
    coverage_total <- n_classified_total / nrow(df)
    
    tibble(
      threshold = th,
      accuracy_on_gt = accuracy,
      coverage_total = coverage_total,
      n_classified = n_classified_total
    )
  }
  
  message("Symulacja dla progow: ", paste(thresholds, collapse=", "))
  sensitivity_results <- map_dfr(thresholds, ~ simulate_threshold(.x, eval_data))
  
  # Print results
  print(sensitivity_results |> 
          mutate(across(c(accuracy_on_gt, coverage_total), ~ percent(.x, 0.1))))
  
  # Save Table
  write_csv(sensitivity_results, file.path(tables_dir, "05_threshold_sensitivity.csv"))
  
  # Plot
  plot_dir <- here::here("01_gender_prediction_improvement", "output", "plots")
  dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
  
  results_long <- sensitivity_results |>
    pivot_longer(cols = c(accuracy_on_gt, coverage_total), 
                 names_to = "metric", values_to = "value") |>
    mutate(metric_label = if_else(metric == "accuracy_on_gt", "Accuracy (na GT)", "Coverage (Cala baza)"))
  
  p_sens <- ggplot(results_long, aes(x = threshold, y = value, color = metric_label)) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 3) +
    scale_y_continuous(labels = percent_format(accuracy = 1), limits = c(0, 1)) +
    scale_x_continuous(breaks = thresholds) +
    scale_color_manual(values = c("Accuracy (na GT)" = "#27AE60", "Coverage (Cala baza)" = "#E74C3C")) +
    labs(
      title = "Analiza wrazliwosci progu (Threshold Sensitivity)",
      subtitle = "Jak prog pewnosci wplywa na Jakosc vs Ilosc",
      x = "Prog pewnosci (Threshold)",
      y = "Wartosc",
      color = "Metryka"
    ) +
    theme_academic() +
    theme(legend.position = "bottom")
  
  save_plot(p_sens, "05_threshold_sensitivity", width = 8, height = 6)
  message("Zapisano wykres: 05_threshold_sensitivity.png")
}

message("03_evaluate_comparison.R zakonczone: ", Sys.time())
