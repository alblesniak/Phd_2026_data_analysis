# =============================================================================
# config.R - Shared configuration for gender prediction pipeline
# =============================================================================

# Reproducibility
PIPELINE_SEED <- 2026

# Feature weights used in scoring
FEATURE_WEIGHTS <- c(
  a = 1.0, # Past tense verbs (praet + aglt)
  b = 0.8, # Adjectival predicate (jestem + adj)
  c = 0.8, # Passive voice
  d = 1.0, # Winien forms (powinienem)
  e = 1.0, # Future compound (będę robił)
  f = 1.0, # Conditional (zrobiłbym)
  g = 0.8  # Verba sentiendi (czuję się)
)

# Decision thresholds
CONFIDENCE_THRESHOLD <- 0.50
MIN_SCORE_TOTAL <- 1

# Evaluation options
RUN_THRESHOLD_ANALYSIS <- TRUE
THRESHOLD_GRID <- seq(0.1, 0.9, by = 0.1)
MIN_SCORE_GRID <- c(1, 3, 5, 7)
