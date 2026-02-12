# =============================================================================
# 04_demographic_stats.R - User demographics and activity analysis
# =============================================================================
# Depends on: 00_setup_theme.R, 01_fetch_data.R (run first)
# Produces: Zipf/power-law plot, gender distribution plot
# =============================================================================

library(dplyr)
library(ggplot2)
library(scales)
library(tidyr)

# --- Source setup (if not already loaded) ---
source(here::here("00_basic_corpus_statistics", "scripts", "00_setup_theme.R"))

# --- Auto-load data if running independently ---
if (!exists("user_activity")) {
  message("Danych nie znaleziono w pamięci. Uruchamiam 01_fetch_data.R...")
  source(here::here("00_basic_corpus_statistics", "scripts", "01_fetch_data.R"))
}

# =============================================================================
# 1) User activity distribution (Zipf's law / Power law)
# =============================================================================

# Rank users by post count
user_ranked <- user_activity |>
  filter(n_posts > 0) |>
  arrange(desc(n_posts)) |>
  mutate(rank = row_number())

# Summary statistics
top_1_pct_n <- ceiling(nrow(user_ranked) * 0.01)
top_1_pct_posts <- user_ranked |>
  slice_head(n = top_1_pct_n) |>
  pull(n_posts) |>
  sum()
total_posts_active <- sum(user_ranked$n_posts)
top_1_pct_share <- round(top_1_pct_posts / total_posts_active * 100, 1)

top_10_pct_n <- ceiling(nrow(user_ranked) * 0.10)
top_10_pct_posts <- user_ranked |>
  slice_head(n = top_10_pct_n) |>
  pull(n_posts) |>
  sum()
top_10_pct_share <- round(top_10_pct_posts / total_posts_active * 100, 1)

message("\n=== AKTYWNOŚĆ UŻYTKOWNIKÓW ===")
message("Użytkownicy z >= 1 postem: ", fmt_number(nrow(user_ranked)))
message("Top 1% użytkowników (", fmt_number(top_1_pct_n), ") napisało ",
        top_1_pct_share, "% postów")
message("Top 10% użytkowników (", fmt_number(top_10_pct_n), ") napisało ",
        top_10_pct_share, "% postów")

# --- Log-log plot (Zipf) ---
p_zipf <- ggplot(user_ranked, aes(x = rank, y = n_posts)) +
  geom_point(alpha = 0.3, size = 0.6, color = "#2C3E50") +
  scale_x_log10(
    labels = label_number(big.mark = " "),
    breaks = c(1, 10, 100, 1000, 10000)
  ) +
  scale_y_log10(
    labels = label_number(big.mark = " "),
    breaks = c(1, 10, 100, 1000, 10000, 100000)
  ) +
  labs(
    title = "Rozkład aktywności użytkowników (prawo Zipfa)",
    subtitle = paste0(
      "Top 1% użytkowników odpowiada za ", top_1_pct_share,
      "% postów; top 10% za ", top_10_pct_share, "%"
    ),
    x       = "Ranga użytkownika (skala logarytmiczna)",
    y       = "Liczba postów (skala logarytmiczna)",
    caption = "Źródło: baza danych forums_scraper"
  ) +
  theme_academic() +
  annotation_logticks(sides = "bl", linewidth = 0.2, color = "grey60")

save_plot(p_zipf, "06_zipf_aktywnosc", width = 10, height = 7)

# --- Histogram: posts per user (truncated for readability) ---
p_hist_activity <- ggplot(
  user_ranked |> filter(n_posts <= 100),
  aes(x = n_posts)
) +
  geom_histogram(
    binwidth = 5,
    fill     = "#2C3E50",
    color    = "white",
    alpha    = 0.85
  ) +
  scale_x_continuous(breaks = seq(0, 100, by = 10)) +
  scale_y_continuous(labels = label_number(big.mark = " ")) +
  labs(
    title    = "Rozkład liczby postów na użytkownika",
    subtitle = "Użytkownicy z <= 100 postami (ogon rozkładu obcięty)",
    x        = "Liczba postów",
    y        = "Liczba użytkowników",
    caption  = "Źródło: baza danych forums_scraper"
  ) +
  theme_academic()

save_plot(p_hist_activity, "07_histogram_aktywnosc", width = 10, height = 6)

# Save user activity summary
activity_quantiles <- tibble(
  Kwantyl = c("Min", "Q1 (25%)", "Mediana", "Średnia",
              "Q3 (75%)", "P90", "P95", "P99", "Max"),
  `Liczba postów` = c(
    min(user_ranked$n_posts),
    quantile(user_ranked$n_posts, 0.25),
    median(user_ranked$n_posts),
    round(mean(user_ranked$n_posts), 1),
    quantile(user_ranked$n_posts, 0.75),
    quantile(user_ranked$n_posts, 0.90),
    quantile(user_ranked$n_posts, 0.95),
    quantile(user_ranked$n_posts, 0.99),
    max(user_ranked$n_posts)
  )
)

save_table(activity_quantiles, "04_kwantyle_aktywnosci")

# =============================================================================
# 2) Gender distribution
# =============================================================================

# --- Declared gender (users.gender) ---
gender_declared <- gender_distribution |>
  group_by(plec_deklarowana) |>
  summarise(n_users = sum(n_users), .groups = "drop") |>
  mutate(
    plec_label = case_match(
      plec_deklarowana,
      "M"           ~ "Mężczyzna",
      "K"           ~ "Kobieta",
      "brak danych" ~ "Brak danych",
      .default      = plec_deklarowana
    ),
    procent = round(n_users / sum(n_users) * 100, 1)
  )

p_gender_declared <- ggplot(
  gender_declared,
  aes(x = reorder(plec_label, n_users), y = n_users, fill = plec_label)
) +
  geom_col(width = 0.6, show.legend = FALSE) +
  geom_text(
    aes(label = paste0(fmt_number(n_users), " (", procent, "%)")),
    hjust = -0.05,
    size  = 3.5,
    fontface = "bold"
  ) +
  coord_flip() +
  scale_fill_manual(values = c(
    "Mężczyzna"  = "#2980B9",
    "Kobieta"     = "#E74C3C",
    "Brak danych" = "#95A5A6"
  )) +
  scale_y_continuous(
    labels = label_number(big.mark = " "),
    expand = expansion(mult = c(0, 0.25))
  ) +
  labs(
    title    = "Rozkład płci użytkowników (deklarowana)",
    subtitle = paste0("Łącznie: ", fmt_number(sum(gender_declared$n_users)),
                      " użytkowników"),
    x        = "Płeć",
    y        = "Liczba użytkowników",
    caption  = "Źródło: pole users.gender"
  ) +
  theme_academic()

save_plot(p_gender_declared, "08_plec_deklarowana", width = 9, height = 5)

# --- Predicted gender (users.pred_gender) ---
gender_predicted <- gender_distribution |>
  group_by(plec_predykowana) |>
  summarise(n_users = sum(n_users), .groups = "drop") |>
  mutate(
    plec_label = case_match(
      plec_predykowana,
      "male"        ~ "Mężczyzna",
      "female"      ~ "Kobieta",
      "unknown"     ~ "Nieokreślona",
      "brak danych" ~ "Brak danych",
      .default      = plec_predykowana
    ),
    procent = round(n_users / sum(n_users) * 100, 1)
  )

p_gender_predicted <- ggplot(
  gender_predicted,
  aes(x = reorder(plec_label, n_users), y = n_users, fill = plec_label)
) +
  geom_col(width = 0.6, show.legend = FALSE) +
  geom_text(
    aes(label = paste0(fmt_number(n_users), " (", procent, "%)")),
    hjust = -0.05,
    size  = 3.5,
    fontface = "bold"
  ) +
  coord_flip() +
  scale_fill_manual(values = c(
    "Mężczyzna"    = "#2980B9",
    "Kobieta"       = "#E74C3C",
    "Nieokreślona"  = "#F39C12",
    "Brak danych"   = "#95A5A6"
  )) +
  scale_y_continuous(
    labels = label_number(big.mark = " "),
    expand = expansion(mult = c(0, 0.25))
  ) +
  labs(
    title    = "Rozkład płci użytkowników (predykowana przez klasyfikator)",
    subtitle = paste0("Łącznie: ", fmt_number(sum(gender_predicted$n_users)),
                      " użytkowników"),
    x        = "Płeć (predykowana)",
    y        = "Liczba użytkowników",
    caption  = "Źródło: pole users.pred_gender"
  ) +
  theme_academic()

save_plot(p_gender_predicted, "09_plec_predykowana", width = 9, height = 5)

# --- Gender by forum (declared) ---
gender_by_forum <- gender_distribution |>
  mutate(
    plec_label = case_match(
      plec_deklarowana,
      "M"           ~ "Mężczyzna",
      "K"           ~ "Kobieta",
      "brak danych" ~ "Brak danych",
      .default      = plec_deklarowana
    )
  ) |>
  group_by(forum, plec_label) |>
  summarise(n_users = sum(n_users), .groups = "drop")

p_gender_forum <- ggplot(
  gender_by_forum,
  aes(x = forum, y = n_users, fill = plec_label)
) +
  geom_col(position = "fill", width = 0.7) +
  scale_fill_manual(values = c(
    "Mężczyzna"  = "#2980B9",
    "Kobieta"     = "#E74C3C",
    "Brak danych" = "#95A5A6"
  )) +
  scale_y_continuous(labels = label_percent()) +
  labs(
    title   = "Struktura płci użytkowników wg forum (deklarowana)",
    x       = "Forum",
    y       = "Udział procentowy",
    fill    = "Płeć",
    caption = "Źródło: pole users.gender"
  ) +
  theme_academic() +
  theme(axis.text.x = element_text(angle = 15, hjust = 1))

save_plot(p_gender_forum, "10_plec_wg_forum", width = 10, height = 6)

# Save gender tables
save_table(
  gender_declared |> rename(Płeć = plec_label, `Liczba` = n_users, `%` = procent),
  "05_plec_deklarowana"
)
save_table(
  gender_predicted |> rename(Płeć = plec_label, `Liczba` = n_users, `%` = procent),
  "06_plec_predykowana"
)

message("04_demographic_stats.R completed.")
