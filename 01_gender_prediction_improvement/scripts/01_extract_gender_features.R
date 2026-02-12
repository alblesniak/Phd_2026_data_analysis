# =============================================================================
# 01_extract_gender_features.R - Extract morphological gender features per user
# =============================================================================
# Connects to the database and extracts EXTENDED sets of gender-indicative
# morphological features from the post_lpmn_tokens table using SQL aggregation.
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
library(bit64)

# --- Database connection ---
source(here::here("shared", "database", "db_connection.R"))

message("\n=== EKSTRAKCJA CECH PLCI GRAMATYCZNEJ (V2 - STABLE A-G) ===")
message("Start: ", Sys.time())

# Helper to safeguard integer64 -> numeric conversion
as_numeric_id <- function(x) as.numeric(x)

# =============================================================================
# Feature A: Past Tense 1st Person Singular
# =============================================================================
message("Pobieranie cechy A: Czas przeszly (zrobilem)...")
query_a <- "
  WITH target_pairs AS (
    SELECT p.user_id, t1.ctag AS tag
    FROM post_lpmn_tokens t1
    JOIN post_lpmn_tokens t2 ON t2.post_id = t1.post_id AND t2.token_order = t1.token_order + 1
    JOIN posts p ON p.id = t1.post_id
    WHERE (t1.ctag LIKE 'praet:sg:m1:%' OR t1.ctag LIKE 'praet:sg:f:%')
      AND t2.ctag LIKE 'aglt:sg:pri:%'
      AND p.user_id IS NOT NULL
  )
  SELECT user_id,
    SUM(CASE WHEN tag LIKE '%:m1:%' THEN 1 ELSE 0 END) AS feat_a_M,
    SUM(CASE WHEN tag LIKE '%:f:%' THEN 1 ELSE 0 END) AS feat_a_K
  FROM target_pairs GROUP BY user_id
"
feature_a <- dbGetQuery(con, query_a) |> as_tibble() |> mutate(user_id = as_numeric_id(user_id))
message("  Cecha A: ", nrow(feature_a), " uzytkownikow")

# =============================================================================
# Feature B: Adjectival Predicate (jestem + adj)
# =============================================================================
message("Pobieranie cechy B: Orzecznik (jestem zadowolony)...")
query_b <- "
  WITH target_pairs AS (
    SELECT p.user_id, t2.ctag AS adj_tag
    FROM post_lpmn_tokens t1
    JOIN post_lpmn_tokens t2 ON t2.post_id = t1.post_id AND t2.token_order BETWEEN t1.token_order + 1 AND t1.token_order + 5
    JOIN posts p ON p.id = t1.post_id
    WHERE (t1.lemma = 'być' AND (t1.ctag LIKE 'fin:sg:pri:%' OR t1.ctag LIKE 'aglt:sg:pri:%'))
      AND (t2.ctag LIKE 'adj:sg:nom:m1:%' OR t2.ctag LIKE 'adj:sg:nom:f:%')
      AND p.user_id IS NOT NULL
  )
  SELECT user_id,
    SUM(CASE WHEN adj_tag LIKE '%:m1:%' THEN 1 ELSE 0 END) AS feat_b_M,
    SUM(CASE WHEN adj_tag LIKE '%:f:%' THEN 1 ELSE 0 END) AS feat_b_K
  FROM target_pairs GROUP BY user_id
"
feature_b <- dbGetQuery(con, query_b) |> as_tibble() |> mutate(user_id = as_numeric_id(user_id))
message("  Cecha B: ", nrow(feature_b), " uzytkownikow")

# =============================================================================
# Feature C: Passive Voice (zostałem + ppas) - REVERTED TO ORIGINAL
# =============================================================================
message("Pobieranie cechy C: Strona bierna (zostalem zapytany)...")
query_c <- "
  WITH target_pairs AS (
    SELECT p.user_id, t2.ctag AS ppas_tag
    FROM post_lpmn_tokens t1
    JOIN post_lpmn_tokens t2 ON t2.post_id = t1.post_id AND t2.token_order BETWEEN t1.token_order + 1 AND t1.token_order + 5
    JOIN posts p ON p.id = t1.post_id
    WHERE (t1.lemma = 'zostać' AND t1.ctag LIKE 'praet:%')
      AND (t2.ctag LIKE 'ppas:sg:nom:m1:%' OR t2.ctag LIKE 'ppas:sg:nom:f:%')
      AND p.user_id IS NOT NULL
  )
  SELECT user_id,
    SUM(CASE WHEN ppas_tag LIKE '%:m1:%' THEN 1 ELSE 0 END) AS feat_c_M,
    SUM(CASE WHEN ppas_tag LIKE '%:f:%' THEN 1 ELSE 0 END) AS feat_c_K
  FROM target_pairs GROUP BY user_id
"
feature_c <- dbGetQuery(con, query_c) |> as_tibble() |> mutate(user_id = as_numeric_id(user_id))
message("  Cecha C: ", nrow(feature_c), " uzytkownikow")

# =============================================================================
# Feature D: Winien (Powinienem)
# =============================================================================
message("Pobieranie cechy D: Winien (powinienem)...")
query_d <- "
  WITH target_pairs AS (
    SELECT p.user_id, t1.ctag AS tag
    FROM post_lpmn_tokens t1
    JOIN post_lpmn_tokens t2 ON t2.post_id = t1.post_id AND t2.token_order = t1.token_order + 1
    JOIN posts p ON p.id = t1.post_id
    WHERE (t1.ctag LIKE 'winien:sg:m1:%' OR t1.ctag LIKE 'winien:sg:f:%')
      AND t2.ctag LIKE 'aglt:sg:pri:%'
      AND p.user_id IS NOT NULL
  )
  SELECT user_id,
    SUM(CASE WHEN tag LIKE '%:m1:%' THEN 1 ELSE 0 END) AS feat_d_M,
    SUM(CASE WHEN tag LIKE '%:f:%' THEN 1 ELSE 0 END) AS feat_d_K
  FROM target_pairs GROUP BY user_id
"
feature_d <- dbGetQuery(con, query_d) |> as_tibble() |> mutate(user_id = as_numeric_id(user_id))
message("  Cecha D: ", nrow(feature_d), " uzytkownikow")

# =============================================================================
# Feature E: Future Compound (Będę robił)
# =============================================================================
message("Pobieranie cechy E: Czas przyszly zlozony (bede robil)...")
query_e <- "
  WITH target_pairs AS (
    SELECT p.user_id, t2.ctag AS tag
    FROM post_lpmn_tokens t1
    JOIN post_lpmn_tokens t2 ON t2.post_id = t1.post_id AND t2.token_order BETWEEN t1.token_order + 1 AND t1.token_order + 3
    JOIN posts p ON p.id = t1.post_id
    WHERE (t1.lemma = 'być' AND t1.ctag LIKE 'bedzie:sg:pri:%')
      AND (t2.ctag LIKE 'praet:sg:m1:%' OR t2.ctag LIKE 'praet:sg:f:%')
      AND p.user_id IS NOT NULL
  )
  SELECT user_id,
    SUM(CASE WHEN tag LIKE '%:m1:%' THEN 1 ELSE 0 END) AS feat_e_M,
    SUM(CASE WHEN tag LIKE '%:f:%' THEN 1 ELSE 0 END) AS feat_e_K
  FROM target_pairs GROUP BY user_id
"
feature_e <- dbGetQuery(con, query_e) |> as_tibble() |> mutate(user_id = as_numeric_id(user_id))
message("  Cecha E: ", nrow(feature_e), " uzytkownikow")

# =============================================================================
# Feature F: Conditional (Zrobiłbym)
# =============================================================================
message("Pobieranie cechy F: Tryb przypuszczajacy (zrobilbym)...")
query_f <- "
  WITH target_pairs AS (
    SELECT p.user_id, t1.ctag AS tag
    FROM post_lpmn_tokens t1
    JOIN post_lpmn_tokens t2 ON t2.post_id = t1.post_id AND t2.token_order = t1.token_order + 1
    JOIN post_lpmn_tokens t3 ON t3.post_id = t1.post_id AND t3.token_order = t1.token_order + 2
    JOIN posts p ON p.id = t1.post_id
    WHERE (t1.ctag LIKE 'praet:sg:m1:%' OR t1.ctag LIKE 'praet:sg:f:%') -- zrobił
      AND (t2.ctag LIKE 'qub%' OR t2.lemma = 'by')  -- by
      AND t3.ctag LIKE 'aglt:sg:pri:%'              -- m
      AND p.user_id IS NOT NULL
  )
  SELECT user_id,
    SUM(CASE WHEN tag LIKE '%:m1:%' THEN 1 ELSE 0 END) AS feat_f_M,
    SUM(CASE WHEN tag LIKE '%:f:%' THEN 1 ELSE 0 END) AS feat_f_K
  FROM target_pairs GROUP BY user_id
"
feature_f <- dbGetQuery(con, query_f) |> as_tibble() |> mutate(user_id = as_numeric_id(user_id))
message("  Cecha F: ", nrow(feature_f), " uzytkownikow")

# =============================================================================
# Feature G: Verba Sentiendi (Czuję się + Adj)
# =============================================================================
message("Pobieranie cechy G: Czuć się + przymiotnik...")

query_g <- "
  WITH target_pairs AS (
    SELECT p.user_id, t3.ctag AS adj_tag
    FROM post_lpmn_tokens t1
    -- Szukamy 'się' w oknie -1 do +1 względem czasownika 'czuję'
    JOIN post_lpmn_tokens t2 ON t2.post_id = t1.post_id 
      AND t2.token_order BETWEEN t1.token_order - 1 AND t1.token_order + 1
      AND t2.token_order != t1.token_order
    -- Szukamy przymiotnika w oknie +1 do +5
    JOIN post_lpmn_tokens t3 ON t3.post_id = t1.post_id 
      AND t3.token_order BETWEEN t1.token_order + 1 AND t1.token_order + 5
    JOIN posts p ON p.id = t1.post_id
    WHERE 
      -- 1. Czasownik 'czuć' w 1 os. lp. czasu teraźniejszego (czuję)
      (t1.lemma = 'czuć' AND t1.ctag LIKE 'fin:sg:pri:%')
      
      -- 2. Partykuła 'się'
      AND t2.lemma = 'się'
      
      -- 3. Przymiotnik lub Imiesłów w mianowniku (zmęczony/zmęczona)
      AND (
           (t3.ctag LIKE 'adj:sg:nom:m1:%' OR t3.ctag LIKE 'adj:sg:nom:f:%')
        OR (t3.ctag LIKE 'ppas:sg:nom:m1:%' OR t3.ctag LIKE 'ppas:sg:nom:f:%')
      )
      AND p.user_id IS NOT NULL
  )
  SELECT user_id,
    SUM(CASE WHEN adj_tag LIKE '%:m1:%' THEN 1 ELSE 0 END) AS feat_g_M,
    SUM(CASE WHEN adj_tag LIKE '%:f:%' THEN 1 ELSE 0 END) AS feat_g_K
  FROM target_pairs GROUP BY user_id
"

feature_g <- dbGetQuery(con, query_g) |> as_tibble() |> mutate(user_id = as_numeric_id(user_id))
message("  Cecha G: ", nrow(feature_g), " uzytkownikow")

# =============================================================================
# Merge all features into a single table
# =============================================================================

# Get all users (base list)
all_users <- dbGetQuery(con, "SELECT id AS user_id FROM users") |>
  as_tibble() |>
  mutate(user_id = as_numeric_id(user_id))

features_combined <- all_users |>
  left_join(feature_a, by = "user_id") |>
  left_join(feature_b, by = "user_id") |>
  left_join(feature_c, by = "user_id") |>
  left_join(feature_d, by = "user_id") |>
  left_join(feature_e, by = "user_id") |>
  left_join(feature_f, by = "user_id") |>
  left_join(feature_g, by = "user_id") |>
  # FIX: Convert integer64 columns to numeric BEFORE coalescing
  # This prevents "Can't combine integer64 and double" error
  mutate(across(starts_with("feat_"), as.numeric)) |>
  # Replace NA with 0
  mutate(across(starts_with("feat_"), ~ coalesce(.x, 0)))

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

# Clean up
dbDisconnect(con)
message("Polaczenie z baza zamkniete.")
message("01_extract_gender_features.R zakonczone: ", Sys.time())
