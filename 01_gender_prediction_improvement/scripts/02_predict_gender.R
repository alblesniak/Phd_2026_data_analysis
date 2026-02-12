# =============================================================================
# 02_predict_gender.R - Weighted voting algorithm for gender prediction
# =============================================================================
# Loads feature counts from Step 1 and applies a weighted scoring system.
#
# Weights rationale:
#   - Feature A (past tense 1sg): Weight 1.0 (Unambiguous)
#   - Feature B (predicate): Weight 0.8 (POS tagging noise risk)
#   - Feature C (passive): Weight 0.8 (POS tagging noise risk)
#   - Feature D (winien): Weight 1.0 (Strong marker: powinienem/powinnam)
#   - Feature E (future): Weight 1.0 (Strong marker: będę robił/robiła)
#   - Feature F (conditional): Weight 1.0 (Strong marker: zrobiłbym/zrobiłabym)
#   - Feature G (verba sentiendi): Weight 0.8 (Czuję się + adj/ppas)
#
# Output: output/data/new_gender_predictions.csv
# =============================================================================

library(dplyr)
library(readr)
library(here)

# CLI option: write predictions back to users.pred_gender
# Usage examples:
#   Rscript 01_gender_prediction_improvement/scripts/02_predict_gender.R
#   Rscript 01_gender_prediction_improvement/scripts/02_predict_gender.R --overwrite-users-pred-gender
args <- commandArgs(trailingOnly = TRUE)
overwrite_users_pred_gender <- "--overwrite-users-pred-gender" %in% args

message("\n=== PREDYKCJA PŁCI GRAMATYCZNEJ (algorytm głosowania) ===")
message("Start: ", Sys.time())

# =============================================================================
# Configuration
# =============================================================================

# Feature weights
WEIGHT_A <- 1.0   # Past tense verbs (praet + aglt)
WEIGHT_B <- 0.8   # Adjectival predicate (jestem + adj)
WEIGHT_C <- 0.8   # Passive voice
WEIGHT_D <- 1.0   # Winien forms (powinienem)
WEIGHT_E <- 1.0   # Future compound (będę robił)
WEIGHT_F <- 1.0   # Conditional (zrobiłbym)
WEIGHT_G <- 0.8   # Verba sentiendi (czuję się)

# Thresholds
CONFIDENCE_THRESHOLD <- 0.50  # Require > 50% of weighted evidence for one side

# =============================================================================
# 1) Load features
# =============================================================================

features_path <- here::here("01_gender_prediction_improvement", "output", "data", "user_gender_features.csv")

if (!file.exists(features_path)) {
  stop("Brak pliku cech: ", features_path, "\nUruchom najpierw 01_extract_gender_features.R")
}

features <- read_csv(features_path, show_col_types = FALSE)
message("Wczytano cechy dla ", nrow(features), " użytkowników")

# =============================================================================
# 2) Calculate Scores
# =============================================================================

predictions <- features |>
  mutate(
    # Weighted sums (using lowercase column names from Postgres)
    score_m = (feat_a_m * WEIGHT_A) +
              (feat_b_m * WEIGHT_B) +
              (feat_c_m * WEIGHT_C) +
              (feat_d_m * WEIGHT_D) +
              (feat_e_m * WEIGHT_E) +
              (feat_f_m * WEIGHT_F) +
              (feat_g_m * WEIGHT_G),

    score_k = (feat_a_k * WEIGHT_A) +
              (feat_b_k * WEIGHT_B) +
              (feat_c_k * WEIGHT_C) +
              (feat_d_k * WEIGHT_D) +
              (feat_e_k * WEIGHT_E) +
              (feat_f_k * WEIGHT_F) +
              (feat_g_k * WEIGHT_G),

    score_total = score_m + score_k,

    # Confidence ratio (0.0 - 1.0)
    # If total is 0, confidence is 0
    confidence = if_else(score_total > 0,
                         pmax(score_m, score_k) / score_total,
                         0),

    # Prediction Logic
    new_pred_gender = case_when(
      score_total == 0 ~ "unknown",
      confidence < CONFIDENCE_THRESHOLD ~ "unknown",
      score_m > score_k ~ "M",
      score_k > score_m ~ "K",
      TRUE ~ "unknown" # Tie with high confidence (rare)
    )
  )

# =============================================================================
# 3) Summary stats
# =============================================================================

summary_counts <- predictions |>
  count(new_pred_gender) |>
  mutate(pct = n / sum(n) * 100)

message("\n--- Podsumowanie predykcji ---")
print(summary_counts)

classified_count <- sum(predictions$new_pred_gender != "unknown")
total_count <- nrow(predictions)
message("Pokrycie (coverage): ", round(classified_count / total_count * 100, 1), "%")

# Ambiguous cases (evidence exists but conflicting or weak)
ambiguous <- predictions |>
  filter(new_pred_gender == "unknown", score_total > 0) |>
  nrow()
message("Użytkownicy z niejednoznaczną predykcją (dowody, ale poniżej progu): ", ambiguous)

# Feature contribution analysis (how many predicted users rely on which feature)
# We check if a user has non-zero count for a feature group
contribution <- predictions |>
  filter(new_pred_gender != "unknown") |>
  summarise(
    n_predicted = n(),
    has_feat_a = sum(feat_a_m + feat_a_k > 0),
    has_feat_b = sum(feat_b_m + feat_b_k > 0),
    has_feat_c = sum(feat_c_m + feat_c_k > 0),
    has_feat_d = sum(feat_d_m + feat_d_k > 0),
    has_feat_e = sum(feat_e_m + feat_e_k > 0),
    has_feat_f = sum(feat_f_m + feat_f_k > 0),
    has_feat_g = sum(feat_g_m + feat_g_k > 0)
  )

message("\n--- Wkład poszczególnych cech (wśród predykowanych) ---")
message("  Ma cechę A (praet+aglt):      ", contribution$has_feat_a, " / ", contribution$n_predicted)
message("  Ma cechę B (jestem+adj):       ", contribution$has_feat_b, " / ", contribution$n_predicted)
message("  Ma cechę C (zostać+ppas):      ", contribution$has_feat_c, " / ", contribution$n_predicted)
message("  Ma cechę D (winien):           ", contribution$has_feat_d, " / ", contribution$n_predicted)
message("  Ma cechę E (future):           ", contribution$has_feat_e, " / ", contribution$n_predicted)
message("  Ma cechę F (conditional):      ", contribution$has_feat_f, " / ", contribution$n_predicted)
message("  Ma cechę G (czuć się+adj):     ", contribution$has_feat_g, " / ", contribution$n_predicted)

# =============================================================================
# Save output
# =============================================================================

output_dir <- here::here("01_gender_prediction_improvement", "output", "data")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

output <- predictions |>
  select(user_id,
         starts_with("feat_"),
         score_m, score_k, score_total,
         confidence, new_pred_gender)

output_path <- file.path(output_dir, "new_gender_predictions.csv")
write_csv(output, output_path)

message("Zapisano: ", output_path)

# =============================================================================
# Optional: overwrite users.pred_gender in DB
# =============================================================================

if (overwrite_users_pred_gender) {
  message("\nTryb DB overwrite: aktualizacja users.pred_gender...")

  library(DBI)

  source(here::here("database", "db_connection.R"))

  update_df <- output |>
    transmute(
      id = as.numeric(user_id),
      pred_gender = if_else(new_pred_gender == "unknown", NA_character_, new_pred_gender)
    )

  dbWithTransaction(con, {
    dbExecute(con, "DROP TABLE IF EXISTS tmp_gender_predictions")

    dbWriteTable(
      con,
      name = "tmp_gender_predictions",
      value = update_df,
      temporary = TRUE,
      overwrite = TRUE
    )

    updated_rows <- dbExecute(con, "
      UPDATE users u
      SET pred_gender = t.pred_gender
      FROM tmp_gender_predictions t
      WHERE u.id = t.id
    ")

    message("Zaktualizowano users.pred_gender dla ", updated_rows, " użytkowników")
  })

  dbDisconnect(con)
  message("Połączenie z bazą zamknięte po aktualizacji users.pred_gender")
}

message("02_predict_gender.R zakończone: ", Sys.time())
