# =============================================================================
# database/preview_cleanup_post_2025_data.R - PODGLĄD usuwania (bez zmian!)
# =============================================================================
# Skrypt NIC NIE USUWA - tylko pokazuje szczegółową analizę danych,
# które zostaną usunięte przez cleanup_post_2025_data.R
#
# Użyj tego skryptu, aby:
# - Zobaczyć dokładne liczby przed cleanup
# - Zidentyfikować przykładowe wątki/użytkowników do usunięcia
# - Sprawdzić, czy strategia jest poprawna
# =============================================================================

library(DBI)
library(dplyr)
library(here)

# Cutoff date
CUTOFF_DATE <- "2025-12-31 23:59:59"

# --- Connect to database ---
source(here::here("database/db_connection.R"))

cat("\n")
cat("=============================================================================\n")
cat("PODGLĄD CLEANUP: Analiza danych po 31 grudnia 2025 (BEZ USUWANIA!)\n")
cat("=============================================================================\n\n")

# --- ANALIZA 1: Posty do usunięcia ---
cat("=" ,"=", rep("=", 75), "\n", sep="")
cat("1. POSTY do usunięcia\n")
cat("=" ,"=", rep("=", 75), "\n", sep="")

posts_summary <- dbGetQuery(con, sprintf("
  SELECT 
    COUNT(*) as n_posts,
    COUNT(DISTINCT thread_id) as n_threads_affected,
    COUNT(DISTINCT user_id) as n_users_affected,
    MIN(post_date) as min_date,
    MAX(post_date) as max_date
  FROM posts 
  WHERE post_date > '%s'
", CUTOFF_DATE))

print(posts_summary)

# Przykłady postów do usunięcia
cat("\nPrzykładowe posty do usunięcia (pierwsze 10):\n")
sample_posts <- dbGetQuery(con, sprintf("
  SELECT p.id, p.post_date, p.username, t.title as thread_title
  FROM posts p
  LEFT JOIN threads t ON t.id = p.thread_id
  WHERE p.post_date > '%s'
  ORDER BY p.post_date
  LIMIT 10
", CUTOFF_DATE))
print(sample_posts)

# --- ANALIZA 2: Wątki całkowicie nowe (do usunięcia) ---
cat("\n")
cat("=" ,"=", rep("=", 75), "\n", sep="")
cat("2. WĄTKI całkowicie nowe (wszystkie posty po cutoff) - DO USUNIĘCIA\n")
cat("=" ,"=", rep("=", 75), "\n", sep="")

threads_fully_new <- dbGetQuery(con, sprintf("
  WITH thread_stats AS (
    SELECT 
      thread_id,
      MIN(post_date) as first_post_date,
      MAX(post_date) as last_post_date,
      COUNT(*) as n_posts
    FROM posts
    WHERE post_date IS NOT NULL
    GROUP BY thread_id
  )
  SELECT 
    t.id, 
    t.title, 
    t.url,
    ts.n_posts,
    ts.first_post_date,
    ts.last_post_date
  FROM thread_stats ts
  JOIN threads t ON t.id = ts.thread_id
  WHERE ts.first_post_date > '%s'
  ORDER BY ts.n_posts DESC
  LIMIT 20
", CUTOFF_DATE))

cat(sprintf("Liczba wątków do usunięcia: %d\n\n", nrow(threads_fully_new)))
if(nrow(threads_fully_new) > 0) {
  cat("Przykładowe wątki (top 20 według liczby postów):\n")
  print(threads_fully_new)
}

# Podsumowanie wątków całkowicie nowych
threads_fully_new_summary <- dbGetQuery(con, sprintf("
  WITH thread_stats AS (
    SELECT 
      thread_id,
      MIN(post_date) as first_post_date,
      COUNT(*) as n_posts
    FROM posts
    WHERE post_date IS NOT NULL
    GROUP BY thread_id
  )
  SELECT 
    COUNT(DISTINCT thread_id) as n_threads,
    COALESCE(SUM(n_posts), 0) as total_posts
  FROM thread_stats
  WHERE first_post_date > '%s'
", CUTOFF_DATE))

cat("\nPodsumowanie:\n")
cat(sprintf("  Wątków do usunięcia: %d\n", as.integer(threads_fully_new_summary$n_threads)))
cat(sprintf("  Postów w tych wątkach: %d\n", as.integer(threads_fully_new_summary$total_posts)))

# --- ANALIZA 3: Wątki częściowe (wymagają aktualizacji metadanych) ---
cat("\n")
cat("=" ,"=", rep("=", 75), "\n", sep="")
cat("3. WĄTKI częściowe (posty przed i po cutoff) - AKTUALIZACJA METADANYCH\n")
cat("=" ,"=", rep("=", 75), "\n", sep="")

threads_partial <- dbGetQuery(con, sprintf("
  WITH thread_stats AS (
    SELECT 
      thread_id,
      MIN(post_date) as first_post_date,
      MAX(post_date) as last_post_date,
      COUNT(*) as total_posts,
      COUNT(*) FILTER (WHERE post_date > '%s') as posts_after_cutoff
    FROM posts
    WHERE post_date IS NOT NULL
    GROUP BY thread_id
  )
  SELECT 
    t.id,
    t.title,
    t.url,
    ts.total_posts,
    ts.posts_after_cutoff,
    ts.first_post_date,
    ts.last_post_date,
    t.last_post_date as current_last_post_date
  FROM thread_stats ts
  JOIN threads t ON t.id = ts.thread_id
  WHERE ts.first_post_date <= '%s' AND ts.last_post_date > '%s'
  ORDER BY ts.posts_after_cutoff DESC
  LIMIT 20
", CUTOFF_DATE, CUTOFF_DATE, CUTOFF_DATE))

cat(sprintf("Liczba wątków do aktualizacji: %d\n\n", nrow(threads_partial)))
if(nrow(threads_partial) > 0) {
  cat("Przykładowe wątki (top 20 według liczby postów po cutoff):\n")
  print(threads_partial)
}

# Podsumowanie wątków częściowych
threads_partial_summary <- dbGetQuery(con, sprintf("
  WITH thread_stats AS (
    SELECT 
      thread_id,
      MIN(post_date) as first_post_date,
      MAX(post_date) as last_post_date,
      COUNT(*) FILTER (WHERE post_date > '%s') as posts_after_cutoff
    FROM posts
    WHERE post_date IS NOT NULL
    GROUP BY thread_id
  )
  SELECT 
    COUNT(DISTINCT thread_id) as n_threads,
    COALESCE(SUM(posts_after_cutoff), 0) as total_posts_to_remove
  FROM thread_stats
  WHERE first_post_date <= '%s' AND last_post_date > '%s'
", CUTOFF_DATE, CUTOFF_DATE, CUTOFF_DATE))

cat("\nPodsumowanie:\n")
cat(sprintf("  Wątków do aktualizacji: %d\n", as.integer(threads_partial_summary$n_threads)))
cat(sprintf("  Postów do usunięcia z tych wątków: %d\n", as.integer(threads_partial_summary$total_posts_to_remove)))

# --- ANALIZA 4: Użytkownicy do usunięcia ---
cat("\n")
cat("=" ,"=", rep("=", 75), "\n", sep="")
cat("4. UŻYTKOWNICY z pierwszym postem po cutoff - DO USUNIĘCIA\n")
cat("=" ,"=", rep("=", 75), "\n", sep="")

users_only_after <- dbGetQuery(con, sprintf("
  WITH user_stats AS (
    SELECT 
      user_id,
      MIN(post_date) as first_post_date,
      MAX(post_date) as last_post_date,
      COUNT(*) as n_posts
    FROM posts
    WHERE post_date IS NOT NULL
    GROUP BY user_id
  )
  SELECT 
    u.id,
    u.username,
    u.forum_id,
    u.join_date,
    us.first_post_date,
    us.last_post_date,
    us.n_posts
  FROM user_stats us
  JOIN users u ON u.id = us.user_id
  WHERE us.first_post_date > '%s'
  ORDER BY us.n_posts DESC
", CUTOFF_DATE))

cat(sprintf("Liczba użytkowników do usunięcia: %d\n\n", nrow(users_only_after)))
if(nrow(users_only_after) > 0) {
  cat("Lista użytkowników:\n")
  print(users_only_after)
}

# --- ANALIZA 5: Użytkownicy z postami przed cutoff (ZACHOWANI) ---
cat("\n")
cat("=" ,"=", rep("=", 75), "\n", sep="")
cat("5. UŻYTKOWNICY z postami przed cutoff - ZACHOWANI (nawet jeśli dołączyli po cutoff)\n")
cat("=" ,"=", rep("=", 75), "\n", sep="")

users_with_posts_before <- dbGetQuery(con, sprintf("
  WITH user_stats AS (
    SELECT 
      user_id,
      MIN(post_date) as first_post_date,
      COUNT(*) as total_posts,
      COUNT(*) FILTER (WHERE post_date > '%s') as posts_after_cutoff
    FROM posts
    WHERE post_date IS NOT NULL
    GROUP BY user_id
  )
  SELECT 
    u.id,
    u.username,
    u.join_date,
    us.first_post_date,
    us.total_posts,
    us.posts_after_cutoff,
    CASE 
      WHEN u.join_date > '%s' THEN 'Dołączył po cutoff' 
      ELSE 'Dołączył przed cutoff' 
    END as join_status
  FROM user_stats us
  JOIN users u ON u.id = us.user_id
  WHERE us.first_post_date <= '%s' AND us.posts_after_cutoff > 0
  ORDER BY us.posts_after_cutoff DESC
  LIMIT 20
", CUTOFF_DATE, CUTOFF_DATE, CUTOFF_DATE))

cat(sprintf("Liczba użytkowników zachowanych (ale stracą część postów): %d\n\n", nrow(users_with_posts_before)))
if(nrow(users_with_posts_before) > 0) {
  cat("Przykładowi użytkownicy (top 20 według liczby postów po cutoff):\n")
  print(users_with_posts_before)
}

# --- ANALIZA 6: Post quotes i tokens (CASCADE) ---
cat("\n")
cat("=" ,"=", rep("=", 75), "\n", sep="")
cat("6. POST_QUOTES i POST_LPMN_TOKENS - usuną się automatycznie (CASCADE)\n")
cat("=" ,"=", rep("=", 75), "\n", sep="")

cascade_summary <- dbGetQuery(con, sprintf("
  SELECT 
    (SELECT COUNT(*) FROM post_quotes pq JOIN posts p ON p.id = pq.post_id WHERE p.post_date > '%s') as n_post_quotes,
    (SELECT COUNT(*) FROM post_lpmn_tokens pt JOIN posts p ON p.id = pt.post_id WHERE p.post_date > '%s') as n_post_tokens
", CUTOFF_DATE, CUTOFF_DATE))

cat(sprintf("Post quotes do usunięcia: %d\n", cascade_summary$n_post_quotes))
cat(sprintf("Post LPMN tokens do usunięcia: %d\n", cascade_summary$n_post_tokens))

# --- PODSUMOWANIE FINALNE ---
cat("\n")
cat("=============================================================================\n")
cat("PODSUMOWANIE FINALNE\n")
cat("=============================================================================\n\n")

cat("Po wykonaniu cleanup_post_2025_data.R:\n\n")
cat(sprintf("  ✗ Usuniętych postów:              %d\n", as.integer(posts_summary$n_posts)))
cat(sprintf("  ✗ Usuniętych wątków:              %d\n", as.integer(threads_fully_new_summary$n_threads)))
cat(sprintf("  ✗ Usuniętych użytkowników:        %d\n", as.integer(nrow(users_only_after))))
cat(sprintf("  ✓ Zaktualizowanych wątków:        %d\n", as.integer(threads_partial_summary$n_threads)))
cat(sprintf("  ✗ Usuniętych post_quotes:         %d (CASCADE)\n", as.integer(cascade_summary$n_post_quotes)))
cat(sprintf("  ✗ Usuniętych post_lpmn_tokens:    %d (CASCADE)\n", as.integer(cascade_summary$n_post_tokens)))

cat("\nZakres dat po cleanup:\n")
date_range <- dbGetQuery(con, "
  SELECT 
    MIN(post_date) as earliest,
    MAX(post_date) as latest_before_cutoff,
    COUNT(*) as total_posts
  FROM posts
  WHERE post_date IS NOT NULL AND post_date <= '2025-12-31 23:59:59'
")
cat(sprintf("  Najwcześniejszy post: %s\n", as.character(date_range$earliest)))
cat(sprintf("  Najpóźniejszy post:   %s\n", as.character(date_range$latest_before_cutoff)))
cat(sprintf("  Postów pozostanie:    %d\n", as.integer(date_range$total_posts)))

cat("\n")
cat("=============================================================================\n")
cat("Aby wykonać cleanup, uruchom:\n")
cat("  Rscript database/cleanup_post_2025_data.R\n")
cat("=============================================================================\n\n")

# --- Disconnect ---
dbDisconnect(con)
