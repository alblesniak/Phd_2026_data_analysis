# =============================================================================
# 04_demographic_stats.R - Demographics and Zipf
# =============================================================================
library(dplyr)
library(ggplot2)
library(scales)

source(here::here("00_basic_corpus_statistics", "scripts", "00_setup_theme.R"))

if (!exists("user_activity")) {
  source(here::here("00_basic_corpus_statistics", "scripts", "01_fetch_data.R"))
}

# 1. Prawo Zipfa (Log-Log)
user_ranked <- user_activity |>
  group_by(user_id) |>
  summarise(n_posts = sum(n_posts)) |>
  filter(n_posts > 0) |>
  arrange(desc(n_posts)) |>
  mutate(rank = row_number())

p_zipf <- ggplot(user_ranked, aes(x = rank, y = n_posts)) +
  geom_line(colour = "#2C3E50", linewidth = 1) +
  scale_x_log10(
    breaks = trans_breaks("log10", function(x) 10^x),
    labels = trans_format("log10", math_format(10^.x))
  ) +
  scale_y_log10(
    breaks = trans_breaks("log10", function(x) 10^x),
    labels = trans_format("log10", math_format(10^.x))
  ) +
  annotation_logticks(colour = "grey40") +
  labs(
    title = "Rozkład aktywności użytkowników (Prawo Zipfa)",
    subtitle = "Zależność rangi użytkownika od liczby napisanych postów",
    x = "Ranga (skala log)",
    y = "Liczba postów (skala log)"
  ) +
  theme_phd()

save_plot_phd(p_zipf, "06_zipf_aktywnosc")

# 2. Histogram (użytkownicy < 100 postów)
p_hist <- ggplot(user_ranked |> filter(n_posts <= 100), aes(x = n_posts)) +
  geom_histogram(binwidth = 5, fill = "#2C3E50", colour = "white", linewidth = 0.3) +
  scale_y_continuous(labels = fmt_pl_num, expand = expansion(mult = c(0, 0.1))) +
  scale_x_continuous(breaks = seq(0, 100, 10)) +
  labs(
    title = "Rozkład liczby postów (ogon rozkładu)",
    subtitle = "Dla użytkowników z maksymalnie 100 postami",
    x = "Liczba postów",
    y = "Liczba użytkowników"
  ) +
  theme_phd()

save_plot_phd(p_hist, "07_histogram_aktywnosc")

# 3. Płeć (Deklarowana)
gender_clean <- gender_distribution |>
  group_by(plec_deklarowana) |>
  summarise(n = sum(n_users)) |>
  mutate(
    plec = case_match(plec_deklarowana,
      "M" ~ "Mężczyzna", "K" ~ "Kobieta", "brak danych" ~ "Brak danych", .default = "Inne"),
    pct = n / sum(n)
  )

p_gender <- ggplot(gender_clean, aes(x = reorder(plec, n), y = n, fill = plec)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  geom_text(aes(label = paste0(fmt_pl_num(n), " (", percent(pct, 0.1), ")")),
            hjust = -0.1, size = 3.2, family = phd_font_family) +
  scale_fill_manual(values = gender_colors) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  coord_flip() +
  labs(
    title = "Struktura płci użytkowników (dane deklaratywne)",
    x = NULL,
    y = "Liczba użytkowników"
  ) +
  theme_phd() +
  theme(panel.grid.major.y = element_blank())

save_plot_phd(p_gender, "08_plec_deklarowana")

# 4. Struktura płci wg forum (Stacked 100%)
gender_forum <- gender_distribution |>
  mutate(
    plec = case_match(plec_deklarowana,
      "M" ~ "Mężczyzna", "K" ~ "Kobieta", .default = "Brak danych")
  ) |>
  group_by(forum, plec) |>
  summarise(n = sum(n_users), .groups = "drop")

p_gender_stack <- ggplot(gender_forum, aes(x = forum, y = n, fill = plec)) +
  geom_col(position = "fill", width = 0.7) +
  scale_fill_manual(values = gender_colors) +
  scale_y_continuous(labels = percent) +
  labs(
    title = "Udział płci w strukturze użytkowników poszczególnych forów",
    x = NULL,
    y = "Udział",
    fill = "Płeć"
  ) +
  theme_phd() +
  theme(legend.position = "bottom")

save_plot_phd(p_gender_stack, "10_plec_wg_forum")

message("04_demographic_stats.R completed.")
