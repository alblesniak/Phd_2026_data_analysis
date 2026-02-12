# =============================================================================
# 01_fetch_data.R - Fetch aggregated data from PostgreSQL
# =============================================================================
# Connects to DB via database/db_connection.R and retrieves pre-aggregated summaries.
# =============================================================================

library(dplyr)
library(readr)
library(here)

# --- 1) Setup Database Connection ---
# This script loads libs (DBI, RPostgres), .env, and creates 'con' object
source(here::here("database", "db_connection.R"))

# =============================================================================
# 2) General counts
# =============================================================================

total_posts <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM posts")$n
total_threads <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM threads")$n
total_users <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM users")$n
total_tokens <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM post_lpmn_tokens")$n
total_sections <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM sections")$n
total_forums <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM forums")$n

general_counts <- tibble(
  metryka = c("Fora", "Sekcje", "Wątki", "Użytkownicy", "Posty", "Tokeny LPMN"),
  wartosc = c(total_forums, total_sections, total_threads,
              total_users, total_posts, total_tokens)
)

message("General counts fetched.")

# =============================================================================
# 3) Posts per forum (with forum names)
# =============================================================================

posts_per_forum <- dbGetQuery(con, "
  SELECT
    f.title AS forum,
    COUNT(p.id) AS n_posts
  FROM posts p
  JOIN threads t ON t.id = p.thread_id
  JOIN sections s ON s.id = t.section_id
  JOIN forums f ON f.id = s.forum_id
  GROUP BY f.title
  ORDER BY n_posts DESC
") |> as_tibble()

message("Posts per forum fetched.")

# =============================================================================
# 4) Threads per forum
# =============================================================================

threads_per_forum <- dbGetQuery(con, "SELECT
    f.title AS forum,
    COUNT(t.id) AS n_threads
  FROM threads t
  JOIN sections s ON s.id = t.section_id
  JOIN forums f ON f.id = s.forum_id
  GROUP BY f.title
  ORDER BY n_threads DESC
") |> as_tibble()

# =============================================================================
# 5) Users per forum
# =============================================================================

users_per_forum <- dbGetQuery(con, "SELECT
    f.title AS forum,
    COUNT(u.id) AS n_users
  FROM users u
  JOIN forums f ON f.id = u.forum_id
  GROUP BY f.title
  ORDER BY n_users DESC
") |> as_tibble()

# =============================================================================
# 6) Tokens per forum
# =============================================================================

tokens_per_forum <- dbGetQuery(con, "SELECT
    f.title AS forum,
    COUNT(tk.id) AS n_tokens
  FROM post_lpmn_tokens tk
  JOIN posts p ON p.id = tk.post_id
  JOIN threads t ON t.id = p.thread_id
  JOIN sections s ON s.id = t.section_id
  JOIN forums f ON f.id = s.forum_id
  GROUP BY f.title
  ORDER BY n_tokens DESC
") |> as_tibble()

message("Tokens per forum fetched.")

# =============================================================================
# 7) Posts per year (temporal analysis)
# =============================================================================

posts_per_year <- dbGetQuery(con, "SELECT
    EXTRACT(YEAR FROM post_date)::integer AS rok,
    COUNT(*) AS n_posts
  FROM posts
  WHERE post_date IS NOT NULL
  GROUP BY rok
  ORDER BY rok
") |> as_tibble()

message("Posts per year fetched.")

# =============================================================================
# 8) Posts per year per forum
# =============================================================================

posts_per_year_forum <- dbGetQuery(con, "SELECT
    f.title AS forum,
    EXTRACT(YEAR FROM p.post_date)::integer AS rok,
    COUNT(*) AS n_posts
  FROM posts p
  JOIN threads t ON t.id = p.thread_id
  JOIN sections s ON s.id = t.section_id
  JOIN forums f ON f.id = s.forum_id
  WHERE p.post_date IS NOT NULL
  GROUP BY f.title, rok
  ORDER BY rok, f.title
") |> as_tibble()

# =============================================================================
# 9) Date range
# =============================================================================

date_range <- dbGetQuery(con, "SELECT
    MIN(post_date) AS min_date,
    MAX(post_date) AS max_date
  FROM posts
  WHERE post_date IS NOT NULL
")

corpus_min_date <- as.Date(date_range$min_date)
corpus_max_date <- as.Date(date_range$max_date)
message("Zakres dat: ", corpus_min_date, " to ", corpus_max_date)

# =============================================================================
# 10) User activity distribution (posts per user)
# =============================================================================

user_activity <- dbGetQuery(con, "SELECT
    u.id AS user_id,
    f.title AS forum,
    COUNT(p.id) AS n_posts
  FROM users u
  JOIN forums f ON f.id = u.forum_id
  LEFT JOIN posts p ON p.user_id = u.id
  GROUP BY u.id, f.title
  ORDER BY n_posts DESC
") |> as_tibble()

message("User activity fetched.")

# =============================================================================
# 11) Gender distribution
# =============================================================================

gender_distribution <- dbGetQuery(con, "SELECT
    f.title AS forum,
    COALESCE(NULLIF(gender, ''), 'brak danych') AS plec_deklarowana,
    COALESCE(NULLIF(pred_gender, ''), 'brak danych') AS plec_predykowana,
    COUNT(*) AS n_users
  FROM users u
  JOIN forums f ON f.id = u.forum_id
  GROUP BY f.title, plec_deklarowana, plec_predykowana
  ORDER BY f.title, n_users DESC
") |> as_tibble()

message("Gender distribution fetched.")

# =============================================================================
# Disconnect
# =============================================================================

dbDisconnect(con)
message("Database connection closed. All data fetched successfully.")
