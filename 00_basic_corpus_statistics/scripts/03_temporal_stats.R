# =============================================================================
# 03_temporal_stats.R - Diachronic analysis of corpus
# =============================================================================
# Depends on: 00_setup_theme.R, 01_fetch_data.R (run first)
# Produces: temporal distribution plots (posts per year, per year+forum)
# =============================================================================

library(dplyr)
library(ggplot2)
library(scales)
library(tidyr)

# --- Source setup (if not already loaded) ---
source(here::here("00_basic_corpus_statistics", "scripts", "00_setup_theme.R"))

# =============================================================================
# 1) Summary: date range
# =============================================================================

message("\n=== ANALIZA CZASOWA ===")
message("Najwczesniejszy post: ", corpus_min_date)
message("Najpozniejszy post:   ", corpus_max_date)
message("Zakres:               ",
        as.numeric(difftime(corpus_max_date, corpus_min_date, units = "days")),
        " dni")

# =============================================================================
# 2) Table: posts per year
# =============================================================================

# Filter out implausible years (before ~2000 or after current year)
posts_per_year_clean <- posts_per_year |>
  filter(rok >= 2000, rok <= as.integer(format(Sys.Date(), "%Y")))

save_table(
  posts_per_year_clean |> rename(Rok = rok, `Liczba postow` = n_posts),
  "02_posty_wg_roku"
)

# =============================================================================
# 3) Line chart: posts per year (aggregate)
# =============================================================================

p_temporal <- ggplot(posts_per_year_clean, aes(x = rok, y = n_posts)) +
  geom_line(linewidth = 1, color = "#2C3E50") +
  geom_point(size = 2.5, color = "#2C3E50") +
  geom_text(
    aes(label = format(n_posts, big.mark = " ")),
    vjust = -1,
    size  = 3,
    color = "grey30"
  ) +
  scale_x_continuous(breaks = seq(
    min(posts_per_year_clean$rok),
    max(posts_per_year_clean$rok),
    by = 2
  )) +
  scale_y_continuous(
    labels = label_number(big.mark = " "),
    expand = expansion(mult = c(0.05, 0.15))
  ) +
  labs(
    title    = "Liczba postow w poszczegolnych latach",
    subtitle = paste0(
      "Zakres czasowy korpusu: ", corpus_min_date, " - ", corpus_max_date
    ),
    x       = "Rok",
    y       = "Liczba postow",
    caption = "Zrodlo: baza danych forums_scraper"
  ) +
  theme_academic()

save_plot(p_temporal, "03_posty_wg_roku", width = 12, height = 6)

# =============================================================================
# 4) Line chart: posts per year, broken down by forum
# =============================================================================

posts_per_year_forum_clean <- posts_per_year_forum |>
  filter(rok >= 2000, rok <= as.integer(format(Sys.Date(), "%Y")))

save_table(
  posts_per_year_forum_clean |>
    rename(Forum = forum, Rok = rok, `Liczba postow` = n_posts),
  "03_posty_wg_roku_i_forum"
)

p_temporal_forum <- ggplot(
  posts_per_year_forum_clean,
  aes(x = rok, y = n_posts, color = forum)
) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2) +
  scale_color_manual(values = forum_colors) +
  scale_x_continuous(breaks = seq(
    min(posts_per_year_forum_clean$rok),
    max(posts_per_year_forum_clean$rok),
    by = 2
  )) +
  scale_y_continuous(
    labels = label_number(big.mark = " "),
    expand = expansion(mult = c(0.05, 0.10))
  ) +
  labs(
    title    = "Dynamika postow w poszczegolnych latach wg forum",
    subtitle = paste0(
      "Zakres: ", corpus_min_date, " - ", corpus_max_date
    ),
    x       = "Rok",
    y       = "Liczba postow",
    color   = "Forum",
    caption = "Zrodlo: baza danych forums_scraper"
  ) +
  theme_academic()

save_plot(p_temporal_forum, "04_posty_wg_roku_forum", width = 12, height = 6)

# =============================================================================
# 5) Stacked area chart: cumulative posts per year per forum
# =============================================================================

p_stacked <- ggplot(
  posts_per_year_forum_clean,
  aes(x = rok, y = n_posts, fill = forum)
) +
  geom_area(alpha = 0.8, color = "white", linewidth = 0.3) +
  scale_fill_manual(values = forum_colors) +
  scale_x_continuous(breaks = seq(
    min(posts_per_year_forum_clean$rok),
    max(posts_per_year_forum_clean$rok),
    by = 2
  )) +
  scale_y_continuous(
    labels = label_number(big.mark = " "),
    expand = expansion(mult = c(0, 0.05))
  ) +
  labs(
    title    = "Udzial for w produkcji postow w kolejnych latach",
    subtitle = "Wykres warstwowy (area chart)",
    x       = "Rok",
    y       = "Liczba postow",
    fill    = "Forum",
    caption = "Zrodlo: baza danych forums_scraper"
  ) +
  theme_academic()

save_plot(p_stacked, "05_posty_area_chart", width = 12, height = 6)

message("03_temporal_stats.R completed.")
