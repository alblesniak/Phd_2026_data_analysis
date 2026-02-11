# =============================================================================
# 01_fetch_data.R - Fetch aggregated data from PostgreSQL
# =============================================================================
# Connects to DB via .env credentials and retrieves pre-aggregated summaries.
# No raw text is pulled -- all heavy lifting is done in SQL.
# =============================================================================

library(DBI)
library(RPostgres)
library(dotenv)
library(dplyr)
library(readr)

# --- Load environment variables ---
dotenv::load_dot_env(here::here(".env"))

# --- Connect to database ---
# Helper to try multiple environment variable names (first non-empty returned)
get_env_first <- function(names, default = "") {
  for (nm in names) {
    val <- Sys.getenv(nm, unset = "")
    if (!identical(val, "")) return(val)
  }
  default
}

connect_db <- function() {
  host <- get_env_first(c("DB_HOST", "POSTGRES_HOST", "PGHOST"))
  dbname <- get_env_first(c("DB_NAME", "POSTGRES_DB", "PGDATABASE"))
  user <- get_env_first(c("DB_USER", "POSTGRES_USER", "PGUSER"))
  password <- get_env_first(c("DB_PASS", "POSTGRES_PASSWORD", "PGPASSWORD"))
  port <- as.integer(get_env_first(c("DB_PORT", "POSTGRES_PORT", "PGPORT"), "5432"))

  info_msg <- paste0("DB connection parameters -> host='", ifelse(host=="","(socket/local)",host), "', dbname='", dbname, "', user='", user, "', port=", port)
  message(info_msg)

  tryCatch(
    dbConnect(
      Postgres(),
      host = ifelse(host == "", NULL, host),
      dbname = dbname,
      user = user,
      password = password,
      port = port
    ),
    error = function(e) {
      stop("Failed to connect to Postgres. Check DB_* or POSTGRES_* env vars and that the server is reachable. Original error: ", e$message)
    }
  )
}

con <- connect_db()
message("Connected to database: ", get_env_first(c("DB_NAME", "POSTGRES_DB", "PGDATABASE")))

# =============================================================================
# 1) General counts
# =============================================================================

total_posts <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM posts")$n
total_threads <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM threads")$n
total_users <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM users")$n
total_tokens <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM post_lpmn_tokens")$n
total_sections <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM sections")$n
total_forums <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM forums")$n

general_counts <- tibble(
  metryka = c("Fora", "Sekcje", "Watki", "Uzytkownicy", "Posty", "Tokeny LPMN"),
  wartosc = c(total_forums, total_sections, total_threads,
              total_users, total_posts, total_tokens)
)

message("General counts fetched.")

# =============================================================================
# 2) Posts per forum (with forum names)
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
# 3) Threads per forum
# =============================================================================

threads_per_forum <- dbGetQuery(con, "
  SELECT
    f.title AS forum,
    COUNT(t.id) AS n_threads
  FROM threads t
  JOIN sections s ON s.id = t.section_id
  JOIN forums f ON f.id = s.forum_id
  GROUP BY f.title
  ORDER BY n_threads DESC
") |> as_tibble()

# =============================================================================
# 4) Users per forum
# =============================================================================

users_per_forum <- dbGetQuery(con, "
  SELECT
    f.title AS forum,
    COUNT(u.id) AS n_users
  FROM users u
  JOIN forums f ON f.id = u.forum_id
  GROUP BY f.title
  ORDER BY n_users DESC
") |> as_tibble()

# =============================================================================
# 5) Tokens per forum
# =============================================================================

tokens_per_forum <- dbGetQuery(con, "
  SELECT
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
# 6) Posts per year (temporal analysis)
# =============================================================================

posts_per_year <- dbGetQuery(con, "
  SELECT
    EXTRACT(YEAR FROM post_date)::integer AS rok,
    COUNT(*) AS n_posts
  FROM posts
  WHERE post_date IS NOT NULL
  GROUP BY rok
  ORDER BY rok
") |> as_tibble()

message("Posts per year fetched.")

# =============================================================================
# 7) Posts per year per forum
# =============================================================================

posts_per_year_forum <- dbGetQuery(con, "
  SELECT
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
# 8) Date range
# =============================================================================

date_range <- dbGetQuery(con, "
  SELECT
    MIN(post_date) AS min_date,
    MAX(post_date) AS max_date
  FROM posts
  WHERE post_date IS NOT NULL
")

corpus_min_date <- as.Date(date_range$min_date)
corpus_max_date <- as.Date(date_range$max_date)
message("Date range: ", corpus_min_date, " to ", corpus_max_date)

# =============================================================================
# 9) User activity distribution (posts per user)
# =============================================================================

user_activity <- dbGetQuery(con, "
  SELECT
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
# 10) Gender distribution
# =============================================================================

gender_distribution <- dbGetQuery(con, "
  SELECT
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
