# =============================================================================
# 02_predict_gender.R - Weighted voting algorithm for gender prediction
# =============================================================================
# Loads feature counts from Step 1 and applies a weighted scoring system
# to predict each user's grammatical gender.
#
# Weights rationale:
#   - Feature A (past tense 1sg): Weight 1.0 — highest reliability,
#     morphological agreement between praet + aglt is unambiguous.
#   - Feature B (adjectival predicate): Weight 0.8 — slightly less reliable
#     because the adj may refer to a subject other than the speaker, and
#     POS tagging can introduce noise.
#   - Feature C (passive voice with 'zostać'): Weight 0.8 — reliable when
#     found, but rarer; same tagging-error caveat as Feature B.
#
# Output: output/data/new_gender_predictions.csv
# =============================================================================

library(dplyr)
library(readr)
library(here)

message("\n=== PREDYKCJA PLCI GRAMATYCZNEJ (algorytm glosowania) ===")
message("Start: ", Sys.time())

# =============================================================================
# Configuration
# =============================================================================

# Feature weights (adjustable)
WEIGHT_A <- 1.0   # Past tense verbs (praet + aglt) — most reliable
WEIGHT_B <- 0.8   # Adjectival predicate (jestem + adj) — medium reliability
WEIGHT_C <- 0.8   # Passive voice (zostać + ppas) — medium reliability

# Confidence threshold: prediction is made only if the dominant gender
# holds more than this fraction of the total weighted score.
CONFIDENCE_THRESHOLD <- 0.60

message("Wagi cech: A=", WEIGHT_A, ", B=", WEIGHT_B, ", C=", WEIGHT_C)
message("Prog pewnosci: ", CONFIDENCE_THRESHOLD * 100, "%")

# =============================================================================
# Load features
# =============================================================================

features_path <- here::here("01_gender_prediction_improvement", "output",
                             "data", "user_gender_features.csv")

if (!file.exists(features_path)) {
  stop("Brak pliku cech. Uruchom najpierw 01_extract_gender_features.R")
}

features <- read_csv(features_path, show_col_types = FALSE)
message("Wczytano cechy dla ", nrow(features), " uzytkownikow")

# =============================================================================
# Weighted scoring
# =============================================================================

predictions <- features |>
  mutate(
    # Weighted masculine score
    score_m = feat_a_M * WEIGHT_A +
              feat_b_M * WEIGHT_B +
              feat_c_M * WEIGHT_C,

    # Weighted feminine score
    score_k = feat_a_K * WEIGHT_A +
              feat_b_K * WEIGHT_B +
              feat_c_K * WEIGHT_C,

    # Total weighted evidence
    score_total = score_m + score_k,

    # Confidence for the dominant gender
    confidence = case_when(
      score_total == 0 ~ 0,
      TRUE             ~ pmax(score_m, score_k) / score_total
    ),

    # Raw counts (unweighted, for diagnostics)
    total_evidence_raw = (feat_a_M + feat_a_K) +
                         (feat_b_M + feat_b_K) +
                         (feat_c_M + feat_c_K),

    # Final prediction
    new_pred_gender = case_when(
      score_total == 0                        ~ "unknown",
      confidence >= CONFIDENCE_THRESHOLD &
        score_m > score_k                     ~ "male",
      confidence >= CONFIDENCE_THRESHOLD &
        score_k > score_m                     ~ "female",
      TRUE                                    ~ "unknown"
    )
  )

# =============================================================================
# Summary statistics
# =============================================================================

pred_summary <- predictions |>
  count(new_pred_gender, name = "n_users") |>
  mutate(pct = round(n_users / sum(n_users) * 100, 1))

message("\n--- Podsumowanie predykcji ---")
for (i in seq_len(nrow(pred_summary))) {
  message("  ", pred_summary$new_pred_gender[i], ": ",
          pred_summary$n_users[i], " (", pred_summary$pct[i], "%)")
}

coverage <- sum(predictions$new_pred_gender != "unknown") / nrow(predictions) * 100
message("Pokrycie (coverage): ", round(coverage, 1), "%")

# Users who have some evidence but fall below threshold
ambiguous <- predictions |>
  filter(new_pred_gender == "unknown", score_total > 0)
message("Uzytkownicy z niejednoznaczna predykcja (dowody, ale ponizej progu): ",
        nrow(ambiguous))

# =============================================================================
# Feature contribution breakdown
# =============================================================================

contribution <- predictions |>
  filter(new_pred_gender != "unknown") |>
  summarise(
    n_predicted       = n(),
    has_feat_a        = sum((feat_a_M + feat_a_K) > 0),
    has_feat_b        = sum((feat_b_M + feat_b_K) > 0),
    has_feat_c        = sum((feat_c_M + feat_c_K) > 0),
    only_feat_a       = sum((feat_a_M + feat_a_K) > 0 &
                            (feat_b_M + feat_b_K) == 0 &
                            (feat_c_M + feat_c_K) == 0),
    only_new_features = sum((feat_a_M + feat_a_K) == 0 &
                            ((feat_b_M + feat_b_K) > 0 |
                             (feat_c_M + feat_c_K) > 0))
  )

message("\n--- Wklad poszczegolnych cech (wsrod predykowanych) ---")
message("  Ma ceche A (praet+aglt):      ", contribution$has_feat_a,
        " / ", contribution$n_predicted)
message("  Ma ceche B (jestem+adj):       ", contribution$has_feat_b,
        " / ", contribution$n_predicted)
message("  Ma ceche C (zostac+ppas):      ", contribution$has_feat_c,
        " / ", contribution$n_predicted)
message("  Tylko cecha A (baseline-like):  ", contribution$only_feat_a)
message("  Tylko nowe cechy (B lub C):     ", contribution$only_new_features)

# =============================================================================
# Save output
# =============================================================================

output_dir <- here::here("01_gender_prediction_improvement", "output", "data")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

output <- predictions |>
  select(user_id,
         feat_a_M, feat_a_K,
         feat_b_M, feat_b_K,
         feat_c_M, feat_c_K,
         score_m, score_k, score_total,
         confidence, new_pred_gender)

output_path <- file.path(output_dir, "new_gender_predictions.csv")
write_csv(output, output_path)
message("\nZapisano: ", output_path)
message("02_predict_gender.R zakonczone: ", Sys.time())
