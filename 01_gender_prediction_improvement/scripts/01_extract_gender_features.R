# =============================================================================
# 01_extract_gender_features.R - Extract morphological gender features per user
# =============================================================================
# Connects to the database and extracts sets of gender-indicative
# morphological features from post_lpmn_tokens in one SQL pass.
#
# Features extracted:
#   A) Past Tense 1sg: "zrobiłem" (praet:sg + aglt:sg:pri)
#   B) Predicate: "jestem zadowolony" (być + adj)
#   C) Passive Voice: "zostałem zapytany" (zostać + ppas)
#   D) Winien: "powinienem" (winien + aglt)
#   E) Future Cmp: "będę robił" (będę + praet)
#   F) Conditional: "zrobiłbym" (praet + by + aglt)
#   G) Verba Sentiendi: "czuję się zmęczona"
#
# Output: output/data/user_gender_features.csv
# =============================================================================

library(dplyr)
library(readr)
library(here)
library(DBI)

# --- Database connection ---
source(here::here("database", "db_connection.R"))

with_db({

message("\n=== EKSTRAKCJA CECH PŁCI GRAMATYCZNEJ (V3 - ONE-PASS SQL) ===")
message("Start: ", Sys.time())

as_numeric_id <- function(x) as.numeric(x)

message("Pobieranie cech A-G jednym zapytaniem (LEAD/LAG)...")

query_features <- "
WITH relevant_posts AS (
  SELECT id AS post_id, user_id
  FROM posts
  WHERE user_id IS NOT NULL
),
tokens_with_context AS (
  SELECT
    t.post_id,
    rp.user_id,
    t.token_order,
    t.lemma,
    t.ctag,
    LEAD(t.ctag, 1)  OVER w AS next1_ctag,
    LEAD(t.lemma, 1) OVER w AS next1_lemma,
    LEAD(t.ctag, 2)  OVER w AS next2_ctag,
    LEAD(t.lemma, 2) OVER w AS next2_lemma,
    LEAD(t.ctag, 3)  OVER w AS next3_ctag,
    LEAD(t.lemma, 3) OVER w AS next3_lemma,
    LEAD(t.ctag, 4)  OVER w AS next4_ctag,
    LEAD(t.lemma, 4) OVER w AS next4_lemma,
    LEAD(t.ctag, 5)  OVER w AS next5_ctag,
    LEAD(t.lemma, 5) OVER w AS next5_lemma,
    LAG(t.lemma, 1)  OVER w AS prev1_lemma
  FROM post_lpmn_tokens t
  JOIN relevant_posts rp ON rp.post_id = t.post_id
  WINDOW w AS (PARTITION BY t.post_id ORDER BY t.token_order)
),
feature_counts AS (
  SELECT
    user_id,

    -- A) praet + aglt
    SUM(CASE WHEN ctag LIKE 'praet:sg:m1:%' AND next1_ctag LIKE 'aglt:sg:pri:%' THEN 1 ELSE 0 END) AS feat_a_m,
    SUM(CASE WHEN ctag LIKE 'praet:sg:f:%'  AND next1_ctag LIKE 'aglt:sg:pri:%' THEN 1 ELSE 0 END) AS feat_a_k,

    -- B) być + adj in window +1..+5
    SUM(CASE WHEN lemma = 'być' AND (ctag LIKE 'fin:sg:pri:%' OR ctag LIKE 'aglt:sg:pri:%')
                  AND next1_ctag LIKE 'adj:sg:nom:m1:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'być' AND (ctag LIKE 'fin:sg:pri:%' OR ctag LIKE 'aglt:sg:pri:%')
                  AND next2_ctag LIKE 'adj:sg:nom:m1:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'być' AND (ctag LIKE 'fin:sg:pri:%' OR ctag LIKE 'aglt:sg:pri:%')
                  AND next3_ctag LIKE 'adj:sg:nom:m1:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'być' AND (ctag LIKE 'fin:sg:pri:%' OR ctag LIKE 'aglt:sg:pri:%')
                  AND next4_ctag LIKE 'adj:sg:nom:m1:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'być' AND (ctag LIKE 'fin:sg:pri:%' OR ctag LIKE 'aglt:sg:pri:%')
                  AND next5_ctag LIKE 'adj:sg:nom:m1:%' THEN 1 ELSE 0 END) AS feat_b_m,

    SUM(CASE WHEN lemma = 'być' AND (ctag LIKE 'fin:sg:pri:%' OR ctag LIKE 'aglt:sg:pri:%')
                  AND next1_ctag LIKE 'adj:sg:nom:f:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'być' AND (ctag LIKE 'fin:sg:pri:%' OR ctag LIKE 'aglt:sg:pri:%')
                  AND next2_ctag LIKE 'adj:sg:nom:f:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'być' AND (ctag LIKE 'fin:sg:pri:%' OR ctag LIKE 'aglt:sg:pri:%')
                  AND next3_ctag LIKE 'adj:sg:nom:f:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'być' AND (ctag LIKE 'fin:sg:pri:%' OR ctag LIKE 'aglt:sg:pri:%')
                  AND next4_ctag LIKE 'adj:sg:nom:f:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'być' AND (ctag LIKE 'fin:sg:pri:%' OR ctag LIKE 'aglt:sg:pri:%')
                  AND next5_ctag LIKE 'adj:sg:nom:f:%' THEN 1 ELSE 0 END) AS feat_b_k,

    -- C) zostać + ppas in window +1..+5
    SUM(CASE WHEN lemma = 'zostać' AND ctag LIKE 'praet:%' AND next1_ctag LIKE 'ppas:sg:nom:m1:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'zostać' AND ctag LIKE 'praet:%' AND next2_ctag LIKE 'ppas:sg:nom:m1:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'zostać' AND ctag LIKE 'praet:%' AND next3_ctag LIKE 'ppas:sg:nom:m1:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'zostać' AND ctag LIKE 'praet:%' AND next4_ctag LIKE 'ppas:sg:nom:m1:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'zostać' AND ctag LIKE 'praet:%' AND next5_ctag LIKE 'ppas:sg:nom:m1:%' THEN 1 ELSE 0 END) AS feat_c_m,

    SUM(CASE WHEN lemma = 'zostać' AND ctag LIKE 'praet:%' AND next1_ctag LIKE 'ppas:sg:nom:f:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'zostać' AND ctag LIKE 'praet:%' AND next2_ctag LIKE 'ppas:sg:nom:f:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'zostać' AND ctag LIKE 'praet:%' AND next3_ctag LIKE 'ppas:sg:nom:f:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'zostać' AND ctag LIKE 'praet:%' AND next4_ctag LIKE 'ppas:sg:nom:f:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'zostać' AND ctag LIKE 'praet:%' AND next5_ctag LIKE 'ppas:sg:nom:f:%' THEN 1 ELSE 0 END) AS feat_c_k,

    -- D) winien + aglt
    SUM(CASE WHEN ctag LIKE 'winien:sg:m1:%' AND next1_ctag LIKE 'aglt:sg:pri:%' THEN 1 ELSE 0 END) AS feat_d_m,
    SUM(CASE WHEN ctag LIKE 'winien:sg:f:%'  AND next1_ctag LIKE 'aglt:sg:pri:%' THEN 1 ELSE 0 END) AS feat_d_k,

    -- E) być:bedzie + praet in window +1..+3
    SUM(CASE WHEN lemma = 'być' AND ctag LIKE 'bedzie:sg:pri:%' AND next1_ctag LIKE 'praet:sg:m1:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'być' AND ctag LIKE 'bedzie:sg:pri:%' AND next2_ctag LIKE 'praet:sg:m1:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'być' AND ctag LIKE 'bedzie:sg:pri:%' AND next3_ctag LIKE 'praet:sg:m1:%' THEN 1 ELSE 0 END) AS feat_e_m,

    SUM(CASE WHEN lemma = 'być' AND ctag LIKE 'bedzie:sg:pri:%' AND next1_ctag LIKE 'praet:sg:f:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'być' AND ctag LIKE 'bedzie:sg:pri:%' AND next2_ctag LIKE 'praet:sg:f:%' THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'być' AND ctag LIKE 'bedzie:sg:pri:%' AND next3_ctag LIKE 'praet:sg:f:%' THEN 1 ELSE 0 END) AS feat_e_k,

    -- F) praet + by/qub + aglt
    SUM(CASE WHEN ctag LIKE 'praet:sg:m1:%'
                  AND (next1_ctag LIKE 'qub%' OR next1_lemma = 'by')
                  AND next2_ctag LIKE 'aglt:sg:pri:%' THEN 1 ELSE 0 END) AS feat_f_m,
    SUM(CASE WHEN ctag LIKE 'praet:sg:f:%'
                  AND (next1_ctag LIKE 'qub%' OR next1_lemma = 'by')
                  AND next2_ctag LIKE 'aglt:sg:pri:%' THEN 1 ELSE 0 END) AS feat_f_k,

    -- G) czuć + się (+/-1) + adj/ppas in window +1..+5
    SUM(CASE WHEN lemma = 'czuć' AND ctag LIKE 'fin:sg:pri:%'
                  AND (prev1_lemma = 'się' OR next1_lemma = 'się')
                  AND (next1_ctag LIKE 'adj:sg:nom:m1:%' OR next1_ctag LIKE 'ppas:sg:nom:m1:%') THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'czuć' AND ctag LIKE 'fin:sg:pri:%'
                  AND (prev1_lemma = 'się' OR next1_lemma = 'się')
                  AND (next2_ctag LIKE 'adj:sg:nom:m1:%' OR next2_ctag LIKE 'ppas:sg:nom:m1:%') THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'czuć' AND ctag LIKE 'fin:sg:pri:%'
                  AND (prev1_lemma = 'się' OR next1_lemma = 'się')
                  AND (next3_ctag LIKE 'adj:sg:nom:m1:%' OR next3_ctag LIKE 'ppas:sg:nom:m1:%') THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'czuć' AND ctag LIKE 'fin:sg:pri:%'
                  AND (prev1_lemma = 'się' OR next1_lemma = 'się')
                  AND (next4_ctag LIKE 'adj:sg:nom:m1:%' OR next4_ctag LIKE 'ppas:sg:nom:m1:%') THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'czuć' AND ctag LIKE 'fin:sg:pri:%'
                  AND (prev1_lemma = 'się' OR next1_lemma = 'się')
                  AND (next5_ctag LIKE 'adj:sg:nom:m1:%' OR next5_ctag LIKE 'ppas:sg:nom:m1:%') THEN 1 ELSE 0 END) AS feat_g_m,

    SUM(CASE WHEN lemma = 'czuć' AND ctag LIKE 'fin:sg:pri:%'
                  AND (prev1_lemma = 'się' OR next1_lemma = 'się')
                  AND (next1_ctag LIKE 'adj:sg:nom:f:%' OR next1_ctag LIKE 'ppas:sg:nom:f:%') THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'czuć' AND ctag LIKE 'fin:sg:pri:%'
                  AND (prev1_lemma = 'się' OR next1_lemma = 'się')
                  AND (next2_ctag LIKE 'adj:sg:nom:f:%' OR next2_ctag LIKE 'ppas:sg:nom:f:%') THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'czuć' AND ctag LIKE 'fin:sg:pri:%'
                  AND (prev1_lemma = 'się' OR next1_lemma = 'się')
                  AND (next3_ctag LIKE 'adj:sg:nom:f:%' OR next3_ctag LIKE 'ppas:sg:nom:f:%') THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'czuć' AND ctag LIKE 'fin:sg:pri:%'
                  AND (prev1_lemma = 'się' OR next1_lemma = 'się')
                  AND (next4_ctag LIKE 'adj:sg:nom:f:%' OR next4_ctag LIKE 'ppas:sg:nom:f:%') THEN 1 ELSE 0 END)
    +
    SUM(CASE WHEN lemma = 'czuć' AND ctag LIKE 'fin:sg:pri:%'
                  AND (prev1_lemma = 'się' OR next1_lemma = 'się')
                  AND (next5_ctag LIKE 'adj:sg:nom:f:%' OR next5_ctag LIKE 'ppas:sg:nom:f:%') THEN 1 ELSE 0 END) AS feat_g_k
  FROM tokens_with_context
  GROUP BY user_id
)
SELECT *
FROM feature_counts
"

feature_counts <- dbGetQuery(con, query_features) |>
  as_tibble() |>
  mutate(user_id = as_numeric_id(user_id))

message("  Cechy A-G: ", nrow(feature_counts), " użytkowników")

all_users <- dbGetQuery(con, "SELECT id AS user_id FROM users") |>
  as_tibble() |>
  mutate(user_id = as_numeric_id(user_id))

features_combined <- all_users |>
  left_join(feature_counts, by = "user_id") |>
  mutate(across(starts_with("feat_"), as.numeric)) |>
  mutate(across(starts_with("feat_"), ~ coalesce(.x, 0)))

message("\nŁączna tabela cech: ", nrow(features_combined), " użytkowników")
message("  Z co najmniej 1 cechą: ",
        sum(rowSums(features_combined |> select(starts_with("feat_"))) > 0))

output_dir <- here::here("01_gender_prediction_improvement", "output", "data")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

output_path <- file.path(output_dir, "user_gender_features.csv")
write_csv(features_combined, output_path)

message("Zapisano: ", output_path)
message("01_extract_gender_features.R zakończone: ", Sys.time())
})
