# =============================================================================
# 03_temporal_stats.R - Diachronic analysis
# =============================================================================
library(dplyr)
library(ggplot2)
library(scales)

source(here::here("00_basic_corpus_statistics", "scripts", "00_setup_theme.R"))

if (!exists("posts_per_year")) {
  source(here::here("00_basic_corpus_statistics", "scripts", "01_fetch_data.R"))
}

# Filtrowanie (do 2025 włącznie, jak ustaliłeś)
posts_year_clean <- posts_per_year |>
  filter(rok >= 2003, rok <= 2025)

posts_forum_clean <- posts_per_year_forum |>
  filter(rok >= 2003, rok <= 2025)

# 1. Wykres liniowy: Ogólny trend
p_trend <- ggplot(posts_year_clean, aes(x = rok, y = n_posts)) +
  geom_line(linewidth = 1.0, colour = "#2C3E50") +
  geom_point(size = 2.2, colour = "#2C3E50") +
  scale_x_continuous(breaks = pretty_breaks(n = 10)) +
  scale_y_continuous(labels = fmt_pl_num, limits = c(0, NA), expand = expansion(mult = c(0, 0.05))) +
  labs(
    title = "Dynamika liczby postów w czasie",
    subtitle = "Ujęcie łączne dla całego korpusu",
    x = "Rok",
    y = "Liczba postów"
  ) +
  theme_phd()

save_plot_phd(p_trend, "03_posty_wg_roku")

# 2. Wykres liniowy: Wg forum
p_trend_forum <- ggplot(posts_forum_clean, aes(x = rok, y = n_posts, colour = forum)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 2.0) +
  scale_colour_manual(values = forum_colors) +
  scale_x_continuous(breaks = pretty_breaks(n = 10)) +
  scale_y_continuous(labels = fmt_pl_num) +
  labs(
    title = "Aktywność na poszczególnych forach w czasie",
    x = "Rok",
    y = "Liczba postów"
  ) +
  theme_phd()

save_plot_phd(p_trend_forum, "04_posty_wg_roku_forum")

# 3. Wykres warstwowy (Area chart)
p_area <- ggplot(posts_forum_clean, aes(x = rok, y = n_posts, fill = forum)) +
  geom_area(alpha = 0.8, colour = "white", linewidth = 0.3) +
  scale_fill_manual(values = forum_colors) +
  scale_x_continuous(breaks = pretty_breaks(n = 10), expand = c(0,0)) +
  scale_y_continuous(labels = fmt_pl_num, expand = expansion(mult = c(0, 0.05))) +
  labs(
    title = "Udział forów w produkcji postów (wykres warstwowy)",
    x = "Rok",
    y = "Liczba postów"
  ) +
  theme_phd() +
  theme(panel.grid.minor = element_blank())

save_plot_phd(p_area, "05_posty_area_chart")

message("03_temporal_stats.R completed.")
