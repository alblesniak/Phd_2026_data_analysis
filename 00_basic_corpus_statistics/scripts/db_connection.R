# =============================================================================
# db_connection.R - Centralized Database Connection
# =============================================================================
# Handles loading environment variables and establishing connection to PostgreSQL.
# Creates a 'con' object in the environment.
# =============================================================================

library(DBI)
library(RPostgres)
library(dotenv)
library(here)

# --- Load environment variables ---
# Using here() ensures we find the .env file in the project root
dotenv::load_dot_env(here::here(".env"))

# --- Helper: Get first non-empty environment variable ---
get_env_first <- function(names, default = "") {
  for (nm in names) {
    val <- Sys.getenv(nm, unset = "")
    if (!identical(val, "")) return(val)
  }
  default
}

# --- Connect to database ---
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
      stop("Failed to connect to Postgres. Check DB_* or POSTGRES_* env vars. Error: ", e$message)
    }
  )
}

# Establish connection immediately when sourced
con <- connect_db()
message("Connected to database: ", get_env_first(c("DB_NAME", "POSTGRES_DB", "PGDATABASE")))
