# =============================================================================
# 01_extract_gender_features.R - Extract morphological gender features per user
# =============================================================================
# Connects to the database and extracts three sets of gender-indicative
# morphological features from the post_lpmn_tokens table using SQL
# aggregation (no raw token pull into R).
#
# Features extracted:
#   A) Past Tense 1st Person Singular (praet:sg + aglt:sg:pri)
#   B) Adjectival Predicate (adj:sg:nom + być/jestem in present tense)
#   C) Passive Voice (zostać in praet + ppas:sg:nom)
#
# Output: output/data/user_gender_features.csv
# =============================================================================

library(dplyr)
library(readr)
library(here)
library(DBI)

# --- Database connection (reuse shared helper) ---
source(here::here("00_basic_corpus_statistics", "scripts", "db_connection.R"))

message("\n=== EKSTRAKCJA CECH PLCI GRAMATYCZNEJ ===")
message("Start: ", Sys.time())

# =============================================================================
# Helper: Convert Postgres bigint (integer64) to R numeric
# =============================================================================
# Postgres returns user IDs as bigint, which R's RPostgres driver converts
# to integer64. Later joins with CSV-read data (which are numeric/double)
# will fail unless we standardize. Since user IDs safely fit in double
# precision, we convert them early.
# =============================================================================

as_numeric_id <- function(x) {
  as.numeric(x)
}

# =============================================================================
# Feature A: Past Tense 1st Person Singular
# =============================================================================
# Linguistic rule:
#   Polish past tense 1st person singular is formed by combining:
#     - praet:sg:m1 / praet:sg:f  (past participle, e.g. "zrobił" / "zrobiła")
#     - aglt:sg:pri               (agglutinative ending, e.g. "-em" / "-am")
#   Together they form: "zrobiłem" (M) / "zrobiłam" (F).
#
# SQL approach:
#   For each post, we look for an aglt:sg:pri token. Then we check whether
#   a praet:sg:m1 or praet:sg:f token appears in the same post within a
#   small token window (±3 tokens — they are typically adjacent or very close).
#
# NOTE: In R's DBI, wildcards in LIKE are single % (not %% as in Python psycopg2).
# =============================================================================

message("Pobieranie cechy A: Czas przeszly 1os. lp. (praet + aglt)...")

feature_a <- dbGetQuery(con, "
  WITH aglt_tokens AS (
    -- All 1st person singular agglutinative endings
    SELECT post_id, token_order
    FROM post_lpmn_tokens
    WHERE ctag LIKE 'aglt:sg:pri%'
  ),
  praet_gendered AS (
    -- Past tense participles with masculine (m1) or feminine (f) gender
    SELECT post_id, token_order,
           CASE
             WHEN ctag LIKE 'praet:sg:m1%'
               OR ctag LIKE 'praet:sg:%:m1%' THEN 'M'
             WHEN ctag LIKE 'praet:sg:f%'
               OR ctag LIKE 'praet:sg:%:f%'  THEN 'K'
           END AS gender_marker
    FROM post_lpmn_tokens
    WHERE ctag LIKE 'praet:sg:m1%'
       OR ctag LIKE 'praet:sg:%:m1%'
       OR ctag LIKE 'praet:sg:f%'
       OR ctag LIKE 'praet:sg:%:f%'
  ),
  -- Join: find praet token near (~3 tokens) an aglt token in the same post
  matched AS (
    SELECT p.post_id, p.gender_marker
    FROM praet_gendered p
    JOIN aglt_tokens a
      ON a.post_id = p.post_id
     AND ABS(a.token_order - p.token_order) <= 3
  ),
  -- Map posts to users
  post_user AS (
    SELECT id AS post_id, user_id
    FROM posts
  )
  SELECT
    pu.user_id,
    m.gender_marker,
    COUNT(*) AS cnt
  FROM matched m
  JOIN post_user pu ON pu.post_id = m.post_id
  GROUP BY pu.user_id, m.gender_marker
") |> as_tibble() |>
  mutate(user_id = as_numeric_id(user_id))

# Pivot: one row per user with counts for M and K
feature_a_wide <- feature_a |>
  tidyr::pivot_wider(
    names_from  = gender_marker,
    values_from = cnt,
    values_fill = 0L,
    names_prefix = "feat_a_"
  )

# Ensure both columns exist
if (!"feat_a_M" %in% names(feature_a_wide)) feature_a_wide$feat_a_M <- 0L
if (!"feat_a_K" %in% names(feature_a_wide)) feature_a_wide$feat_a_K <- 0L

feature_a_wide <- feature_a_wide |>
  select(user_id, feat_a_M, feat_a_K)

message("  Cecha A: ", nrow(feature_a_wide), " uzytkownikow z dopasowaniami")

# =============================================================================
# Feature B: Adjectival Predicate (Jestem + adj:sg:nom)
# =============================================================================
# Linguistic rule:
#   Present tense copula "być" (1st person = "jestem") + nominative singular
#   adjective marked for gender:
#     "Jestem zadowolony" (M) vs "Jestem zadowolona" (F)
#     "Jestem zmęczony"   (M) vs "Jestem zmęczona"   (F)
#
#   The copula can appear as:
#     - aglt:sg:pri (agglutinative "jestem" form)
#     - lemma 'być' with a present-tense tag (fin:sg:pri)
#     - literal token "jestem"
#   The adjective is adj:sg:nom:m1 or adj:sg:nom:f.
#   Window: ±5 tokens (adjective may precede or follow the verb).
#
# NOTE: Single % for wildcards in R DBI.
# =============================================================================

message("Pobieranie cechy B: Orzecznik przymiotnikowy (jestem + adj)...")

feature_b <- dbGetQuery(con, "
  WITH copula_tokens AS (
    -- 'Jestem' or any 1sg present form of 'być'
    SELECT post_id, token_order
    FROM post_lpmn_tokens
    WHERE ctag LIKE 'aglt:sg:pri%'
       OR (lemma = 'być' AND ctag LIKE 'fin:sg:pri%')
  ),
  adj_gendered AS (
    -- Nominative singular adjectives with gender marking
    SELECT post_id, token_order,
           CASE
             WHEN ctag LIKE 'adj:sg:nom:m1%'
               OR ctag LIKE 'adj:sg:nom:%:m1%' THEN 'M'
             WHEN ctag LIKE 'adj:sg:nom:f%'
               OR ctag LIKE 'adj:sg:nom:%:f%'  THEN 'K'
           END AS gender_marker
    FROM post_lpmn_tokens
    WHERE ctag LIKE 'adj:sg:nom:m1%'
       OR ctag LIKE 'adj:sg:nom:%:m1%'
       OR ctag LIKE 'adj:sg:nom:f%'
       OR ctag LIKE 'adj:sg:nom:%:f%'
  ),
  -- Join: adjective within 5 tokens of copula in the same post
  matched AS (
    SELECT a.post_id, a.gender_marker
    FROM adj_gendered a
    JOIN copula_tokens c
      ON c.post_id = a.post_id
     AND ABS(c.token_order - a.token_order) BETWEEN 1 AND 5
  ),
  post_user AS (
    SELECT id AS post_id, user_id
    FROM posts
  )
  SELECT
    pu.user_id,
    m.gender_marker,
    COUNT(*) AS cnt
  FROM matched m
  JOIN post_user pu ON pu.post_id = m.post_id
  GROUP BY pu.user_id, m.gender_marker
") |> as_tibble() |>
  mutate(user_id = as_numeric_id(user_id))

feature_b_wide <- feature_b |>
  tidyr::pivot_wider(
    names_from  = gender_marker,
    values_from = cnt,
    values_fill = 0L,
    names_prefix = "feat_b_"
  )

if (!"feat_b_M" %in% names(feature_b_wide)) feature_b_wide$feat_b_M <- 0L
if (!"feat_b_K" %in% names(feature_b_wide)) feature_b_wide$feat_b_K <- 0L

feature_b_wide <- feature_b_wide |>
  select(user_id, feat_b_M, feat_b_K)

message("  Cecha B: ", nrow(feature_b_wide), " uzytkownikow z dopasowaniami")

# =============================================================================
# Feature C: Passive Voice with 'zostać'
# =============================================================================
# Linguistic rule:
#   Passive constructions with "zostać" in 1st person past tense:
#     "Zostałem atakowany" (M) vs "Zostałam atakowana" (F)
#
#   Structure:
#     - praet:sg:{m1|f} with lemma 'zostać' (the auxiliary)
#     - ppas:sg:nom:{m1|f} (passive adjectival participle, gendered)
#   Window: ±5 tokens (participle follows zostać, but there can be adverbs).
#
#   We use the gender from BOTH the auxiliary AND the participle for extra
#   reliability — they must agree. If they disagree, we skip the match.
#
# NOTE: Single % for wildcards in R DBI.
# =============================================================================

message("Pobieranie cechy C: Strona bierna z 'zostac' (praet + ppas)...")

feature_c <- dbGetQuery(con, "
  WITH zostac_tokens AS (
    -- Past tense forms of 'zostać' in 1st person sg, gendered
    SELECT post_id, token_order,
           CASE
             WHEN ctag LIKE 'praet:sg:m1%'
               OR ctag LIKE 'praet:sg:%:m1%' THEN 'M'
             WHEN ctag LIKE 'praet:sg:f%'
               OR ctag LIKE 'praet:sg:%:f%'  THEN 'K'
           END AS gender_marker
    FROM post_lpmn_tokens
    WHERE lemma = 'zostać'
      AND (
        ctag LIKE 'praet:sg:m1%'
        OR ctag LIKE 'praet:sg:%:m1%'
        OR ctag LIKE 'praet:sg:f%'
        OR ctag LIKE 'praet:sg:%:f%'
      )
  ),
  ppas_gendered AS (
    -- Passive participles in nominative singular, gendered
    SELECT post_id, token_order,
           CASE
             WHEN ctag LIKE 'ppas:sg:nom:m1%'
               OR ctag LIKE 'ppas:sg:nom:%:m1%' THEN 'M'
             WHEN ctag LIKE 'ppas:sg:nom:f%'
               OR ctag LIKE 'ppas:sg:nom:%:f%'  THEN 'K'
           END AS gender_marker
    FROM post_lpmn_tokens
    WHERE ctag LIKE 'ppas:sg:nom:m1%'
       OR ctag LIKE 'ppas:sg:nom:%:m1%'
       OR ctag LIKE 'ppas:sg:nom:f%'
       OR ctag LIKE 'ppas:sg:nom:%:f%'
  ),
  -- Join: ppas within 5 tokens of zostać, genders must agree
  matched AS (
    SELECT z.post_id, z.gender_marker
    FROM zostac_tokens z
    JOIN ppas_gendered pp
      ON pp.post_id = z.post_id
     AND ABS(pp.token_order - z.token_order) BETWEEN 1 AND 5
     AND pp.gender_marker = z.gender_marker   -- gender agreement required
  ),
  post_user AS (
    SELECT id AS post_id, user_id
    FROM posts
  )
  SELECT
    pu.user_id,
    m.gender_marker,
    COUNT(*) AS cnt
  FROM matched m
  JOIN post_user pu ON pu.post_id = m.post_id
  GROUP BY pu.user_id, m.gender_marker
") |> as_tibble() |>
  mutate(user_id = as_numeric_id(user_id))

feature_c_wide <- feature_c |>
  tidyr::pivot_wider(
    names_from  = gender_marker,
    values_from = cnt,
    values_fill = 0L,
    names_prefix = "feat_c_"
  )

if (!"feat_c_M" %in% names(feature_c_wide)) feature_c_wide$feat_c_M <- 0L
if (!"feat_c_K" %in% names(feature_c_wide)) feature_c_wide$feat_c_K <- 0L

feature_c_wide <- feature_c_wide |>
  select(user_id, feat_c_M, feat_c_K)

message("  Cecha C: ", nrow(feature_c_wide), " uzytkownikow z dopasowaniami")

# =============================================================================
# Merge all features into a single table
# =============================================================================

# Get all users
all_users <- dbGetQuery(con, "SELECT id AS user_id FROM users") |>
  as_tibble() |>
  mutate(user_id = as_numeric_id(user_id))

features_combined <- all_users |>
  left_join(feature_a_wide, by = "user_id") |>
  left_join(feature_b_wide, by = "user_id") |>
  left_join(feature_c_wide, by = "user_id") |>
  mutate(across(starts_with("feat_"), ~ replace_na(.x, 0L)))

message("\nLaczna tabela cech: ", nrow(features_combined), " uzytkownikow")
message("  Z co najmniej 1 cecha: ",
        sum(rowSums(features_combined |> select(starts_with("feat_"))) > 0))

# =============================================================================
# Save output
# =============================================================================

output_dir <- here::here("01_gender_prediction_improvement", "output", "data")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

output_path <- file.path(output_dir, "user_gender_features.csv")
write_csv(features_combined, output_path)
message("Zapisano: ", output_path)

# --- Disconnect ---
dbDisconnect(con)
message("Polaczenie z baza zamkniete.")
message("01_extract_gender_features.R zakonczone: ", Sys.time())
