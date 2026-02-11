# =============================================================================
# run_all.R - Master script: runs the full analysis pipeline
# =============================================================================
# Usage: source this file from the project root, or run:
#   Rscript 00_basic_corpus_statistics/run_all.R
# =============================================================================

library(here)

message("============================================")
message(" Opisowa analiza statystyczna korpusu")
message(" Start: ", Sys.time())
message("============================================\n")

# 0) Theme and helpers
source(here("00_basic_corpus_statistics", "scripts", "00_setup_theme.R"))

# 1) Fetch all data from database
source(here("00_basic_corpus_statistics", "scripts", "01_fetch_data.R"))

# 2) General corpus statistics
source(here("00_basic_corpus_statistics", "scripts", "02_general_stats.R"))

# 3) Temporal / diachronic analysis
source(here("00_basic_corpus_statistics", "scripts", "03_temporal_stats.R"))

# 4) User demographics and activity
source(here("00_basic_corpus_statistics", "scripts", "04_demographic_stats.R"))

# 5) Generate markdown report
source(here("00_basic_corpus_statistics", "scripts", "05_generate_markdown_report.R"))

message("\n============================================")
message(" Pipeline completed: ", Sys.time())
message("============================================")
