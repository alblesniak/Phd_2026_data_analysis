# =============================================================================
# 03_temporal_stats.R - Diachronic analysis
# =============================================================================
library(dplyr)
library(ggplot2)
library(scales)
library(ggrepel)

source(here::here("00_basic_corpus_statistics", "scripts", "00_setup_theme.R"))

if (!exists("posts_per_year")) {
  source(here::here("00_basic_corpus_statistics", "scripts", "01_fetch_data.R"))
}

# Filtrowanie (do 2025 włącznie)
posts_year_clean <- posts_per_year |>
  filter(rok >= 2003, rok <= 2025)

posts_forum_clean <- posts_per_year_forum |>
  filter(rok >= 2003, rok <= 2025)

# =============================================================================
# 1. Wykres liniowy: Ogólny trend
# =============================================================================
# Styl: delikatna siatka Y (potrzebna do odczytu wartości na wykresie liniowym),
# brak tytułów osi, punkty na danych, etykieta wartości przy szczycie.

peak_year <- posts_year_clean |> slice_max(n_posts, n = 1)

p_trend <- ggplot(posts_year_clean, aes(x = rok, y = n_posts)) +
  geom_line(linewidth = 0.9, colour = "#507088") +
  geom_point(size = 1.5, colour = "#507088") +
  # Etykieta wartości przy szczycie
  geom_text(
    data = peak_year,
    aes(label = fmt_number(n_posts)),
    nudge_y = max(posts_year_clean$n_posts) * 0.06,
    size = 2.5, fontface = "bold",
    family = phd_font_family, colour = text_color_dark
  ) +
  scale_x_continuous(breaks = pretty_breaks(n = 10)) +
  scale_y_continuous(
    labels = fmt_number,
    limits = c(0, NA),
    expand = expansion(mult = c(0, 0.1))
  ) +
  labs(
    title = "Dynamika liczby postów w czasie",
    subtitle = "Ujęcie łączne dla całego korpusu",
    x = NULL, y = NULL
  ) +
  theme_phd() +
  theme(
    panel.grid.major.y = element_line(colour = "grey92", linewidth = 0.25),
    axis.line.x = element_line(colour = line_color, linewidth = 0.3)
  )

save_plot_phd(p_trend, "03_posty_wg_roku")

# =============================================================================
# 2. Wykres liniowy: Wg forum (bezpośrednie etykiety zamiast legendy)
# =============================================================================
# Nazwy forów umieszczone na końcu linii. ggrepel zapobiega nakładaniu.

last_year_labels <- posts_forum_clean |>
  group_by(forum) |>
  filter(rok == max(rok)) |>
  ungroup()

p_trend_forum <- ggplot(posts_forum_clean,
                        aes(x = rok, y = n_posts, colour = forum)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.5) +
  # Bezpośrednie etykiety z ggrepel (unikanie nakładania)
  geom_text_repel(
    data = last_year_labels,
    aes(label = forum),
    hjust = 0, nudge_x = 0.8,
    direction = "y",
    segment.size = 0.3, segment.color = grey_color,
    size = 2.2, fontface = "bold",
    family = phd_font_family,
    xlim = c(2025.5, NA)
  ) +
  scale_colour_manual(values = forum_colors) +
  scale_x_continuous(
    breaks = pretty_breaks(n = 10),
    expand = expansion(mult = c(0.02, 0.15))
  ) +
  scale_y_continuous(labels = fmt_number) +
  labs(
    title = "Aktywność na poszczególnych forach w czasie",
    x = NULL, y = NULL
  ) +
  coord_cartesian(clip = "off") +
  theme_phd() +
  theme(
    panel.grid.major.y = element_line(colour = "grey92", linewidth = 0.25),
    axis.line.x = element_line(colour = line_color, linewidth = 0.3),
    plot.margin = margin(10, 35, 10, 10)
  )

save_plot_phd(p_trend_forum, "04_posty_wg_roku_forum", width_cm = 18)

# =============================================================================
# 3. Wykres warstwowy (Area chart) z bezpośrednimi etykietami
# =============================================================================
# Etykiety forów wewnątrz warstw — każde forum etykietowane w roku,
# w którym ma wystarczająco dużo miejsca.

# Ustal kolejność forów (od najliczniejszego, bottom-up)
forum_order <- posts_forum_clean |>
  group_by(forum) |>
  summarise(total = sum(n_posts)) |>
  arrange(total) |>
  pull(forum)

posts_forum_ordered <- posts_forum_clean |>
  mutate(forum = factor(forum, levels = forum_order))

# Budujemy bazowy wykres, żeby wyciągnąć faktyczne pozycje warstw z ggplot2
max_label_year <- max(posts_forum_clean$rok) - 2

p_area_base <- ggplot(posts_forum_ordered,
                      aes(x = rok, y = n_posts, fill = forum)) +
  geom_area(alpha = 0.85, colour = "white", linewidth = 0.3)

# Wyciągnij pozycje warstw (ymin, ymax) z wewnętrznych danych ggplot2
built_data <- ggplot_build(p_area_base)$data[[1]]
built_data$forum <- levels(posts_forum_ordered$forum)[built_data$group]
built_data$rok <- as.integer(round(built_data$x))

# Dla każdego forum wybierz rok z najszerszym pasmem (nie za blisko krawędzi)
area_label_positions <- built_data |>
  mutate(band_height = ymax - ymin, ymid = (ymin + ymax) / 2) |>
  filter(rok <= max_label_year, band_height > 0) |>
  group_by(forum) |>
  slice_max(band_height, n = 1) |>
  ungroup()

p_area <- p_area_base +
  # Bezpośrednie etykiety wewnątrz warstw
  geom_text(
    data = area_label_positions,
    aes(x = rok, y = ymid, label = forum),
    colour = text_color_light, size = 2.2, fontface = "bold",
    family = phd_font_family,
    inherit.aes = FALSE
  ) +
  scale_fill_manual(values = forum_colors) +
  scale_x_continuous(
    breaks = pretty_breaks(n = 10),
    expand = c(0, 0)
  ) +
  scale_y_continuous(
    labels = fmt_number,
    expand = expansion(mult = c(0, 0.02))
  ) +
  labs(
    title = "Udział forów w produkcji postów (wykres warstwowy)",
    x = NULL, y = NULL
  ) +
  theme_phd() +
  theme(
    axis.line.x = element_line(colour = line_color, linewidth = 0.3)
  )

save_plot_phd(p_area, "05_posty_area_chart")

message("03_temporal_stats.R completed.")
