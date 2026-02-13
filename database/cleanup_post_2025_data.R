# =============================================================================
# database/cleanup_post_2025_data.R - Usuwanie danych po 31 grudnia 2025
# =============================================================================
# Skrypt usuwa wszystkie dane napisane (nie pobrane!) po 31 grudnia 2025,
# zachowując integralność bazy danych i powiązania między tabelami.
#
# Strategia:
# 1. Identyfikacja wątków i użytkowników do usunięcia
# 2. Usunięcie postów po 2025-12-31  
# 3. Aktualizacja metadanych wątków (last_post_date, replies)
# 4. Usunięcie całkowicie pustych wątków
# 5. Usunięcie użytkowników bez żadnych postów przed 2026-01-01
# =============================================================================

library(DBI)
library(dplyr)
library(here)

# Cutoff date
CUTOFF_DATE <- "2025-12-31 23:59:59"

# --- Connect to database ---
source(here::here("database/db_connection.R"))

with_db({

cat("\n")
cat("=============================================================================\n")
cat("CLEANUP: Usuwanie danych po 31 grudnia 2025\n")
cat("=============================================================================\n\n")

# --- KROK 1: Analiza przed usunięciem ---
cat("KROK 1: Analiza danych do usunięcia\n")
cat("-------------------------------------\n")

# Posty po cutoff
posts_to_delete <- dbGetQuery(con, sprintf("
  SELECT COUNT(*) as n
  FROM posts 
  WHERE post_date > '%s'
", CUTOFF_DATE))
cat(sprintf("Posty do usunięcia: %d\n", as.integer(posts_to_delete$n)))

# Wątki całkowicie nowe (wszystkie posty po cutoff)
threads_fully_new <- dbGetQuery(con, sprintf("
  WITH thread_stats AS (
    SELECT thread_id,
           MIN(post_date) as first_post_date,
           COUNT(*) as n_posts
    FROM posts
    WHERE post_date IS NOT NULL
    GROUP BY thread_id
  )
  SELECT thread_id
  FROM thread_stats
  WHERE first_post_date > '%s'
", CUTOFF_DATE))
cat(sprintf("Wątki całkowicie nowe (do usunięcia): %d\n", as.integer(nrow(threads_fully_new))))

# Wątki częściowo nowe (mają też posty przed cutoff)
threads_partial <- dbGetQuery(con, sprintf("
  WITH thread_stats AS (
    SELECT thread_id,
           MIN(post_date) as first_post_date,
           MAX(post_date) as last_post_date
    FROM posts
    WHERE post_date IS NOT NULL
    GROUP BY thread_id
  )
  SELECT thread_id
  FROM thread_stats
  WHERE first_post_date <= '%s' AND last_post_date > '%s'
", CUTOFF_DATE, CUTOFF_DATE))
cat(sprintf("Wątki częściowo nowe (wymagają aktualizacji metadanych): %d\n", as.integer(nrow(threads_partial))))

# Użytkownicy z pierwszym postem po cutoff
users_only_after <- dbGetQuery(con, sprintf("
  WITH user_stats AS (
    SELECT user_id,
           MIN(post_date) as first_post_date
    FROM posts
    WHERE post_date IS NOT NULL
    GROUP BY user_id
  )
  SELECT user_id
  FROM user_stats
  WHERE first_post_date > '%s'
", CUTOFF_DATE))
cat(sprintf("Użytkownicy z pierwszym postem po cutoff (do usunięcia): %d\n", as.integer(nrow(users_only_after))))

# Post quotes do usunięcia (CASCADE)
post_quotes_to_delete <- dbGetQuery(con, sprintf("
  SELECT COUNT(*) as n
  FROM post_quotes pq
  JOIN posts p ON p.id = pq.post_id
  WHERE p.post_date > '%s'
", CUTOFF_DATE))
cat(sprintf("Post quotes (usuną się automatycznie CASCADE): %d\n", as.integer(post_quotes_to_delete$n)))

# Post tokens do usunięcia (CASCADE)
post_tokens_to_delete <- dbGetQuery(con, sprintf("
  SELECT COUNT(*) as n
  FROM post_lpmn_tokens pt
  JOIN posts p ON p.id = pt.post_id
  WHERE p.post_date > '%s'
", CUTOFF_DATE))
cat(sprintf("Post LPMN tokens (usuną się automatycznie CASCADE): %d\n", as.integer(post_tokens_to_delete$n)))

cat("\n")
cat("Naciśnij Enter, aby kontynuować usuwanie, lub Ctrl+C aby przerwać...\n")
readline()

# --- KROK 2: BEGIN TRANSACTION ---
cat("\nKROK 2: Rozpoczęcie transakcji\n")
cat("-------------------------------------\n")
dbBegin(con)

tryCatch({
  
  # --- KROK 3: Usunięcie postów po cutoff ---
  cat("\nKROK 3: Usuwanie postów po", CUTOFF_DATE, "\n")
  cat("-------------------------------------\n")
  
  deleted_posts <- dbExecute(con, sprintf("
    DELETE FROM posts 
    WHERE post_date > '%s'
  ", CUTOFF_DATE))
  cat(sprintf("Usunięto postów: %d\n", as.integer(deleted_posts)))
  
  # --- KROK 4: Aktualizacja metadanych wątków częściowych ---
  cat("\nKROK 4: Aktualizacja metadanych wątków\n")
  cat("-------------------------------------\n")
  
  # Aktualizacja last_post_date i liczby replies dla wątków, które mają pozostałe posty
  updated_threads <- dbExecute(con, sprintf("
    WITH thread_stats AS (
      SELECT DISTINCT ON (thread_id)
        thread_id,
        post_date as new_last_post_date,
        username as new_last_author
      FROM posts
      WHERE post_date IS NOT NULL AND post_date <= '%s'
      ORDER BY thread_id, post_date DESC
    ),
    thread_counts AS (
      SELECT 
        thread_id,
        COUNT(*) - 1 as new_replies_count
      FROM posts
      WHERE post_date IS NOT NULL AND post_date <= '%s'
      GROUP BY thread_id
    )
    UPDATE threads t
    SET 
      last_post_date = ts.new_last_post_date,
      replies = tc.new_replies_count,
      last_post_author = ts.new_last_author,
      updated_at = LOCALTIMESTAMP(0)
    FROM thread_stats ts
    JOIN thread_counts tc ON tc.thread_id = ts.thread_id
    WHERE t.id = ts.thread_id
  ", CUTOFF_DATE, CUTOFF_DATE))
  cat(sprintf("Zaktualizowano metadanych wątków: %d\n", as.integer(updated_threads)))
  
  # --- KROK 5: Usunięcie całkowicie pustych wątków ---
  cat("\nKROK 5: Usuwanie pustych wątków\n")
  cat("-------------------------------------\n")
  
  deleted_empty_threads <- dbExecute(con, "
    DELETE FROM threads t
    WHERE NOT EXISTS (
      SELECT 1 FROM posts p WHERE p.thread_id = t.id
    )
  ")
  cat(sprintf("Usunięto pustych wątków: %d\n", as.integer(deleted_empty_threads)))
  
  # --- KROK 6: Usunięcie użytkowników bez żadnych postów ---
  cat("\nKROK 6: Usuwanie użytkowników bez postów\n")
  cat("-------------------------------------\n")
  
  deleted_users <- dbExecute(con, "
    DELETE FROM users u
    WHERE NOT EXISTS (
      SELECT 1 FROM posts p WHERE p.user_id = u.id
    )
  ")
  cat(sprintf("Usunięto użytkowników: %d\n", as.integer(deleted_users)))
  
  # --- COMMIT ---
  cat("\nKROK 7: Zatwierdzanie zmian (COMMIT)\n")
  cat("-------------------------------------\n")
  dbCommit(con)
  cat("✓ Transakcja zakończona pomyślnie\n")
  
}, error = function(e) {
  cat("\n✗ BŁĄD podczas wykonywania operacji:\n")
  cat(sprintf("  %s\n", e$message))
  cat("\nWycofywanie zmian (ROLLBACK)...\n")
  dbRollback(con)
  cat("✓ Zmiany wycofane. Baza danych niezmieniona.\n")
  stop("Operacja przerwana z powodu błędu.")
})

# --- KROK 8: Weryfikacja po usunięciu ---
cat("\nKROK 8: Weryfikacja po usunięciu\n")
cat("-------------------------------------\n")

posts_after_cleanup <- dbGetQuery(con, sprintf("
  SELECT COUNT(*) as n
  FROM posts 
  WHERE post_date > '%s'
", CUTOFF_DATE))
cat(sprintf("Posty po cutoff (powinno być 0): %d\n", as.integer(posts_after_cleanup$n)))

threads_after_cleanup <- dbGetQuery(con, sprintf("
  SELECT COUNT(*) as n
  FROM threads 
  WHERE last_post_date > '%s'
", CUTOFF_DATE))
cat(sprintf("Wątki z last_post_date po cutoff (powinno być 0): %d\n", as.integer(threads_after_cleanup$n)))

users_without_posts <- dbGetQuery(con, "
  SELECT COUNT(*) as n
  FROM users u
  WHERE NOT EXISTS (SELECT 1 FROM posts p WHERE p.user_id = u.id)
")
cat(sprintf("Użytkownicy bez żadnych postów (powinno być 0): %d\n", as.integer(users_without_posts$n)))

# Statystyki końcowe
cat("\n")
cat("=============================================================================\n")
cat("PODSUMOWANIE\n")
cat("=============================================================================\n")

final_stats <- dbGetQuery(con, sprintf("
  SELECT 
    COUNT(*) as total_posts,
    COUNT(*) FILTER (WHERE post_date IS NOT NULL) as posts_with_date,
    MIN(post_date) as earliest_post,
    MAX(post_date) as latest_post
  FROM posts
"))

cat(sprintf("Całkowita liczba postów w bazie: %d\n", as.integer(final_stats$total_posts)))
cat(sprintf("Postów z datą: %d\n", as.integer(final_stats$posts_with_date)))
cat(sprintf("Najwcześniejszy post: %s\n", as.character(final_stats$earliest_post)))
cat(sprintf("Najpóźniejszy post: %s\n", as.character(final_stats$latest_post)))

cat("\n✓ Cleanup zakończony pomyślnie!\n")
cat("  Wszystkie dane po 31 grudnia 2025 zostały usunięte.\n\n")

})
