# =============================================================================
# 02_predict_gender.R - Weighted voting algorithm for gender prediction
# =============================================================================

library(dplyr)
library(readr)
library(here)

source(here::here("01_gender_prediction_improvement", "scripts", "config.R"))

message("\n=== PREDYKCJA PŁCI GRAMATYCZNEJ (algorytm głosowania) ===")
message("Start: ", Sys.time())

features_path <- here::here("01_gender_prediction_improvement", "output", "data", "user_gender_features.csv")

if (!file.exists(features_path)) {
  stop("Brak pliku cech: ", features_path, "\nUruchom najpierw 01_extract_gender_features.R")
}

features <- read_csv(features_path, show_col_types = FALSE)
message("Wczytano cechy dla ", nrow(features), " użytkowników")

expected_cols <- c(
  "user_id",
  as.vector(outer(paste0("feat_", letters[1:7]), c("m", "k"), paste, sep = "_"))
)
missing_cols <- setdiff(expected_cols, names(features))
if (length(missing_cols) > 0) {
  stop("Brak wymaganych kolumn wejściowych: ", paste(missing_cols, collapse = ", "))
}

predictions <- features |>
  mutate(
    score_m = (feat_a_m * FEATURE_WEIGHTS[["a"]]) +
              (feat_b_m * FEATURE_WEIGHTS[["b"]]) +
              (feat_c_m * FEATURE_WEIGHTS[["c"]]) +
              (feat_d_m * FEATURE_WEIGHTS[["d"]]) +
              (feat_e_m * FEATURE_WEIGHTS[["e"]]) +
              (feat_f_m * FEATURE_WEIGHTS[["f"]]) +
              (feat_g_m * FEATURE_WEIGHTS[["g"]]),

    score_k = (feat_a_k * FEATURE_WEIGHTS[["a"]]) +
              (feat_b_k * FEATURE_WEIGHTS[["b"]]) +
              (feat_c_k * FEATURE_WEIGHTS[["c"]]) +
              (feat_d_k * FEATURE_WEIGHTS[["d"]]) +
              (feat_e_k * FEATURE_WEIGHTS[["e"]]) +
              (feat_f_k * FEATURE_WEIGHTS[["f"]]) +
              (feat_g_k * FEATURE_WEIGHTS[["g"]]),

    score_total = score_m + score_k,

    confidence = if_else(score_total > 0,
                         pmax(score_m, score_k) / score_total,
                         0),

    new_pred_gender = case_when(
      score_total < MIN_SCORE_TOTAL ~ "unknown",
      confidence < CONFIDENCE_THRESHOLD ~ "unknown",
      score_m > score_k ~ "M",
      score_k > score_m ~ "K",
      TRUE ~ "unknown"
    )
  )

summary_counts <- predictions |>
  count(new_pred_gender) |>
  mutate(pct = n / sum(n) * 100)

message("\n--- Podsumowanie predykcji ---")
print(summary_counts)

classified_count <- sum(predictions$new_pred_gender != "unknown")
total_count <- nrow(predictions)
message("Pokrycie (coverage): ", round(classified_count / total_count * 100, 1), "%")

ambiguous <- predictions |>
  filter(new_pred_gender == "unknown", score_total >= MIN_SCORE_TOTAL) |>
  nrow()
message("Użytkownicy z niejednoznaczną predykcją (dowody, ale poniżej progu): ", ambiguous)

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

output_dir <- here::here("01_gender_prediction_improvement", "output", "data")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

output <- predictions |>
  select(user_id,
         starts_with("feat_"),
         score_m, score_k, score_total,
         confidence, new_pred_gender)

output_path <- file.path(output_dir, "new_gender_predictions.csv")
write_csv(output, output_path)

config_used <- tibble(
  key = c(
    paste0("weight_", names(FEATURE_WEIGHTS)),
    "confidence_threshold",
    "min_score_total"
  ),
  value = c(unname(FEATURE_WEIGHTS), CONFIDENCE_THRESHOLD, MIN_SCORE_TOTAL)
)
write_csv(config_used, file.path(output_dir, "prediction_config_used.csv"))

message("Zapisano: ", output_path)
message("02_predict_gender.R zakończone: ", Sys.time())
