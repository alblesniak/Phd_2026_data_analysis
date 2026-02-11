# =============================================================================
# 03_evaluate_comparison.R - Evaluate and compare gender prediction models
# =============================================================================
# FIX: Detaches 'bit64' package after data loading to prevent masking of
# comparison operators (==, %in%) which caused 0% accuracy in text comparisons.
# =============================================================================

library(dplyr)
library(readr)
library(tidyr)
library(ggplot2)
library(scales)
library(here)
library(DBI)
# Do not load bit64 explicitly here, it's loaded by dependency but we must manage it

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

# CRITICAL FIX: Detach bit64/bit from search path to restore base '==' and '%in%'
# NOTE: Do not unload namespace because it may be imported by readr/vroom/RPostgres.
detach_if_attached <- function(pkg) {
  pkg_search_name <- paste0("package:", pkg)
  if (pkg_search_name %in% search()) {
    message("Detaching ", pkg, " from search path to restore base comparison operators...")
    detach(pkg_search_name, unload = FALSE, character.only = TRUE)
  }
}

detach_if_attached("bit64")
detach_if_attached("bit")

# Load New predictions
new_preds_path <- here::here("01_gender_prediction_improvement", "output", "data", "new_gender_predictions.csv")

if (!file.exists(new_preds_path)) {
  stop("Brak pliku z nowymi predykcjami: ", new_preds_path)
}

new_preds <- read_csv(new_preds_path, show_col_types = FALSE) |>
  select(user_id, new_pred_gender, confidence, score_total)

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
    new_pred_gender = coalesce(new_pred_gender, "unknown")
  ) |>
  # Keep only valid Ground Truth for accuracy metrics (M or K)
  mutate(
    has_gt = ground_truth %in% c("M", "K")
  )

message("Polaczono dane. Liczba uzytkownikow z GT: ", sum(eval_data$has_gt))

# DEBUG: Print sample to verify alignment
message("\n--- DEBUG: Próbka danych (GT vs New) ---")
print(eval_data |>
        filter(has_gt, new_pred_gender != "unknown") |>
        select(user_id, gt=ground_truth, new=new_pred_gender) |>
        head(5))

# =============================================================================
# 3) Calculate Metrics
# =============================================================================

calc_metrics <- function(df, pred_col, gt_col = "ground_truth") {
  # Filter only where GT is known (M/K)
  df_filtered <- df |> filter(.data[[gt_col]] %in% c("M", "K"))
  total_gt <- nrow(df_filtered)

  # Confusion Matrix elements
  # Note: using base operators now that bit64 is detached
  tp_m <- sum(df_filtered[[gt_col]] == "M" & df_filtered[[pred_col]] == "M", na.rm = TRUE)
  tp_k <- sum(df_filtered[[gt_col]] == "K" & df_filtered[[pred_col]] == "K", na.rm = TRUE)

  # FP/FN needed for Precision/Recall
  fp_m <- sum(df_filtered[[gt_col]] == "K" & df_filtered[[pred_col]] == "M", na.rm = TRUE)
  fn_m <- sum(df_filtered[[gt_col]] == "M" & df_filtered[[pred_col]] != "M", na.rm = TRUE)

  fp_k <- sum(df_filtered[[gt_col]] == "M" & df_filtered[[pred_col]] == "K", na.rm = TRUE)
  fn_k <- sum(df_filtered[[gt_col]] == "K" & df_filtered[[pred_col]] != "K", na.rm = TRUE)

  # Only count users that the model actually attempted to classify
  classified <- df_filtered |> filter(.data[[pred_col]] %in% c("M", "K"))
  n_predicted <- nrow(classified)

  accuracy <- if(n_predicted > 0) (tp_m + tp_k) / n_predicted else 0
  coverage <- if(total_gt > 0) n_predicted / total_gt else 0

  # Per-class metrics
  prec_m <- if((tp_m + fp_m) > 0) tp_m / (tp_m + fp_m) else 0
  rec_m  <- if((tp_m + fn_m) > 0) tp_m / (tp_m + fn_m) else 0
  f1_m   <- if((prec_m + rec_m) > 0) 2 * prec_m * rec_m / (prec_m + rec_m) else 0

  prec_k <- if((tp_k + fp_k) > 0) tp_k / (tp_k + fp_k) else 0
  rec_k  <- if((tp_k + fn_k) > 0) tp_k / (tp_k + fn_k) else 0
  f1_k   <- if((prec_k + rec_k) > 0) 2 * prec_k * rec_k / (prec_k + rec_k) else 0

  list(
    n_ground_truth = total_gt,
    n_predicted = n_predicted,
    coverage = coverage * 100,
    accuracy = accuracy * 100,
    precision_m = prec_m * 100, recall_m = rec_m * 100, f1_m = f1_m * 100,
    precision_k = prec_k * 100, recall_k = rec_k * 100, f1_k = f1_k * 100,
    macro_precision = (prec_m + prec_k)/2 * 100,
    macro_recall = (rec_m + rec_k)/2 * 100,
    macro_f1 = (f1_m + f1_k)/2 * 100
  )
}

metrics_bl <- calc_metrics(eval_data, "baseline_pred")
metrics_nw <- calc_metrics(eval_data, "new_pred_gender")

# Combine results
metrics_comparison <- bind_rows(
  bind_cols(model = "Baseline (Python)", as_tibble(metrics_bl)),
  bind_cols(model = "New R Algorithm", as_tibble(metrics_nw))
)

message("\n--- POROWNANIE METRYK (na uzytkownikach z ground truth) ---")
print(metrics_comparison |> select(model, n_ground_truth, n_predicted, coverage, accuracy))
print(metrics_comparison |> select(model, precision_m, recall_m, f1_m, precision_k, recall_k, f1_k))

# =============================================================================
# 4) Analysis of Coverage Gain
# =============================================================================

# Users where Baseline was unknown, but New is M/K
gain_users <- eval_data |>
  filter(baseline_pred == "unknown", new_pred_gender %in% c("M", "K"))

# Users where Baseline was known, but New is unknown (loss)
loss_users <- eval_data |>
  filter(baseline_pred %in% c("M", "K"), new_pred_gender == "unknown")

# Agreement analysis
both_predicted <- eval_data |>
  filter(baseline_pred %in% c("M", "K"), new_pred_gender %in% c("M", "K"))

agreement <- both_predicted |>
  summarise(
    n = n(),
    agree = sum(baseline_pred == new_pred_gender),
    disagree = sum(baseline_pred != new_pred_gender)
  )

coverage_analysis <- tibble(
  Metric = c("Lacznie uzytkownikow",
             "Baseline predykowane", "Nowy algorytm predykowane",
             "Przyrost pokrycia (gain)", "Utrata pokrycia",
             "Oba modele predykuja", "Zgodnosc", "Niezgodnosc"),
  Value = c(nrow(eval_data),
            sum(eval_data$baseline_pred %in% c("M", "K")),
            sum(eval_data$new_pred_gender %in% c("M", "K")),
            nrow(gain_users),
            nrow(loss_users),
            agreement$n, agreement$agree, agreement$disagree)
)

message("\n--- ANALIZA POKRYCIA ---")
print(coverage_analysis)

# Validation of GAIN on Ground Truth
gain_validation <- gain_users |>
  filter(has_gt) |>
  summarise(
    n_gain_with_gt = n(),
    correct = sum(new_pred_gender == ground_truth),
    accuracy = if(n() > 0) correct/n()*100 else 0
  )

message("\nPrzyrost pokrycia z ground truth: ", gain_validation$n_gain_with_gt, " uzytkownikow")
message("  Dokladnosc na tych uzytkownikach: ", round(gain_validation$accuracy, 1), "%")


# =============================================================================
# 5) Visualizations
# =============================================================================

plot_dir <- here::here("01_gender_prediction_improvement", "output", "plots")
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)

# A) Confusion Matrices Comparison
cm_data_bl <- eval_data |> filter(has_gt, baseline_pred %in% c("M", "K")) |>
  count(ground_truth, predicted = baseline_pred) |> mutate(model = "Baseline")
cm_data_nw <- eval_data |> filter(has_gt, new_pred_gender %in% c("M", "K")) |>
  count(ground_truth, predicted = new_pred_gender) |> mutate(model = "New R Algo")

cm_combined <- bind_rows(cm_data_bl, cm_data_nw)

p_cm <- ggplot(cm_combined, aes(x = predicted, y = ground_truth, fill = n)) +
  geom_tile() +
  geom_text(aes(label = fmt_number(n)), color = "white", fontface = "bold") +
  facet_wrap(~model) +
  scale_fill_gradient(low = "#3498DB", high = "#2C3E50") +
  labs(title = "Macierz pomyłek (Confusion Matrix)",
       subtitle = "Porownanie Baseline vs Nowy Algorytm",
       x = "Predykcja", y = "Rzeczywista plec (Ground Truth)") +
  theme_academic()

save_plot(p_cm, "01_confusion_matrix_comparison", width = 10, height = 5)

# B) Coverage Venn-like Bar
cov_data <- tibble(
  Group = c("Baseline Only", "Intersection", "New Only", "Unknown"),
  Count = c(
    nrow(loss_users),
    agreement$n,
    nrow(gain_users),
    nrow(eval_data) - nrow(loss_users) - agreement$n - nrow(gain_users)
  )
) |>
  mutate(Pct = Count / sum(Count))

p_cov <- ggplot(cov_data, aes(x = "", y = Count, fill = reorder(Group, Count))) +
  geom_col(width = 0.5) +
  geom_text(aes(label = paste0(fmt_number(Count), "\n(", percent(Pct, 0.1), ")")),
            position = position_stack(vjust = 0.5), size = 3) +
  scale_fill_brewer(palette = "Pastel1") +
  labs(title = "Analiza pokrycia bazy uzytkownikow",
       fill = "Status") +
  theme_academic() +
  theme(axis.title = element_blank(), axis.text = element_blank(), panel.grid = element_blank())

save_plot(p_cov, "02_coverage_comparison", width = 8, height = 6)

# C) Metrics Bar Chart
metrics_long <- metrics_comparison |>
  select(model, accuracy, coverage, macro_f1) |>
  pivot_longer(cols = -model, names_to = "metric", values_to = "value")

p_metrics <- ggplot(metrics_long, aes(x = metric, y = value, fill = model)) +
  geom_col(position = "dodge") +
  geom_text(aes(label = round(value, 1)), position = position_dodge(0.9), vjust = -0.5) +
  scale_fill_manual(values = c("gray50", "#27AE60")) +
  ylim(0, 105) +
  labs(title = "Porownanie skutecznosci modeli",
       y = "Wartosc (%)", x = "Metryka") +
  theme_academic()

save_plot(p_metrics, "03_metrics_comparison", width = 8, height = 5)

# =============================================================================
# 6) Save tables
# =============================================================================

tables_dir <- here::here("01_gender_prediction_improvement", "output", "tables")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

write_csv(metrics_comparison, file.path(tables_dir, "01_metrics_comparison.csv"))
write_csv(coverage_analysis, file.path(tables_dir, "02_coverage_analysis.csv"))

disagreements <- eval_data |>
  filter(baseline_pred != "unknown", new_pred_gender != "unknown", baseline_pred != new_pred_gender) |>
  select(user_id, ground_truth, baseline = baseline_pred, new_algorithm = new_pred_gender)

write_csv(disagreements, file.path(tables_dir, "03_disagreements.csv"))
write_csv(gain_users |> select(user_id, ground_truth, new_pred_gender), file.path(tables_dir, "04_coverage_gain_users.csv"))

message("Zapisano tabele wynikowe.")
message("03_evaluate_comparison.R zakonczone: ", Sys.time())
