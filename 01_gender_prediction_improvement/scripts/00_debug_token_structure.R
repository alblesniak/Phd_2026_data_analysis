# =============================================================================
# 00_debug_token_structure.R - Inspect actual morphological tag structure
# =============================================================================
# Purpose: Examine the real format of ctag, lemma, and other columns
# in post_lpmn_tokens to understand why features aren't matching.
# =============================================================================

library(dplyr)
library(here)
library(DBI)

# --- Database connection ---
source(here::here("shared", "database", "db_connection.R"))

message("\n=== DEBUG: STRUKTURA TOKENOW W BAZIE ===")
message("Start: ", Sys.time())

# =============================================================================
# 1) Inspect table schema
# =============================================================================

message("\n--- 1) Schema post_lpmn_tokens ---")
info <- dbGetQuery(con, "
  SELECT column_name, data_type
  FROM information_schema.columns
  WHERE table_name = 'post_lpmn_tokens'
  ORDER BY ordinal_position
")
print(info)

# =============================================================================
# 2) Sample tokens - first 50 rows
# =============================================================================

message("\n--- 2) Sample 50 tokens (first 50 rows) ---")
sample_tokens <- dbGetQuery(con, "
  SELECT 
    post_id,
    token_order,
    orth,
    ctag,
    lemma
  FROM post_lpmn_tokens
  LIMIT 50
")
print(sample_tokens)

# =============================================================================
# 3) Check for past tense markers (praet)
# =============================================================================

message("\n--- 3) Tokeny z 'praet' w ctag ---")
praet_sample <- dbGetQuery(con, "
  SELECT 
    orth,
    ctag,
    lemma,
    COUNT(*) as cnt
  FROM post_lpmn_tokens
  WHERE ctag LIKE '%praet%'
  GROUP BY orth, ctag, lemma
  LIMIT 30
")
print(praet_sample)
message("Total praet tokens:", 
        dbGetQuery(con, "SELECT COUNT(*) FROM post_lpmn_tokens WHERE ctag LIKE '%praet%'"))

# =============================================================================
# 4) Check for aglt (agglutinative)
# =============================================================================

message("\n--- 4) Tokeny z 'aglt' w ctag ---")
aglt_sample <- dbGetQuery(con, "
  SELECT 
    orth,
    ctag,
    lemma,
    COUNT(*) as cnt
  FROM post_lpmn_tokens
  WHERE ctag LIKE '%aglt%'
  GROUP BY orth, ctag, lemma
  LIMIT 30
")
print(aglt_sample)
message("Total aglt tokens:", 
        dbGetQuery(con, "SELECT COUNT(*) FROM post_lpmn_tokens WHERE ctag LIKE '%aglt%'"))

# =============================================================================
# 5) Check for adjectives (adj)
# =============================================================================

message("\n--- 5) Tokeny z 'adj' w ctag ---")
adj_sample <- dbGetQuery(con, "
  SELECT 
    orth,
    ctag,
    lemma,
    COUNT(*) as cnt
  FROM post_lpmn_tokens
  WHERE ctag LIKE '%adj%'
  GROUP BY orth, ctag, lemma
  LIMIT 30
")
print(adj_sample)
message("Total adj tokens:", 
        dbGetQuery(con, "SELECT COUNT(*) FROM post_lpmn_tokens WHERE ctag LIKE '%adj%'"))

# =============================================================================
# 6) Check for ppas (passive participles)
# =============================================================================

message("\n--- 6) Tokeny z 'ppas' w ctag ---")
ppas_sample <- dbGetQuery(con, "
  SELECT 
    orth,
    ctag,
    lemma,
    COUNT(*) as cnt
  FROM post_lpmn_tokens
  WHERE ctag LIKE '%ppas%'
  GROUP BY orth, ctag, lemma
  LIMIT 30
")
print(ppas_sample)
message("Total ppas tokens:", 
        dbGetQuery(con, "SELECT COUNT(*) FROM post_lpmn_tokens WHERE ctag LIKE '%ppas%'"))

# =============================================================================
# 7) Check for specific patterns
# =============================================================================

message("\n--- 7) Tokeny z lemma='być' ---")
byc_sample <- dbGetQuery(con, "
  SELECT 
    token,
    ctag,
    lemma,
    COUNT(*) as cnt
  FROM post_lpmn_tokens
  WHERE lemma = 'być'
  GROUP BY token, ctag, lemma
  LIMIT 30
")
print(byc_sample)

message("\n--- 8) Tokeny z lemma='zostać' ---")
zostac_sample <- dbGetQuery(con, "
  SELECT 
    token,
    ctag,
    lemma,
    COUNT(*) as cnt
  FROM post_lpmn_tokens
  WHERE lemma = 'zostać'
  GROUP BY token, ctag, lemma
  LIMIT 30
")
print(zostac_sample)

# =============================================================================
# 9) Check uppercase versions
# =============================================================================

message("\n--- 9) Tokeny z lemma='Być' (capital B) ---")
byc_cap <- dbGetQuery(con, "
  SELECT COUNT(*) as cnt
  FROM post_lpmn_tokens
  WHERE lemma IN ('Być', 'BYĆ')
")
print(byc_cap)

# =============================================================================
# 10) Distinct ctag values (first 100)
# =============================================================================

message("\n--- 10) Wszystkie odrębne wartości ctag (pierwsze 100) ---")
all_ctags <- dbGetQuery(con, "
  SELECT DISTINCT ctag
  FROM post_lpmn_tokens
  ORDER BY ctag
  LIMIT 100
")
print(all_ctags)

# =============================================================================
# 11) Check total token count and basic stats
# =============================================================================

message("\n--- 11) Statystyki ---")
stats <- dbGetQuery(con, "
  SELECT 
    COUNT(*) as total_tokens,
    COUNT(DISTINCT post_id) as n_posts,
    COUNT(DISTINCT lemma) as n_lemmas,
    COUNT(DISTINCT ctag) as n_ctags
  FROM post_lpmn_tokens
")
print(stats)

# =============================================================================
# Clean up
# =============================================================================

dbDisconnect(con)
message("\nPolaczenie z baza zamkniete.")
message("00_debug_token_structure.R zakonczone: ", Sys.time())
