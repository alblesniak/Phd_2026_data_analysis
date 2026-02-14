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

bar_width <- 0.75

# =============================================================================
# 1. Prawo Zipfa (Log-Log)
# =============================================================================
# Styl: subtelna siatka (kluczowa przy skali logarytmicznej),
# czyste etykiety osi, delikatne log-ticki.

user_ranked <- user_activity |>
  group_by(user_id) |>
  summarise(n_posts = sum(n_posts)) |>
  filter(n_posts > 0) |>
  arrange(desc(n_posts)) |>
  mutate(rank = row_number())

p_zipf <- ggplot(user_ranked, aes(x = rank, y = n_posts)) +
  geom_line(colour = "#507088", linewidth = 0.9) +
  scale_x_log10(
    breaks = trans_breaks("log10", function(x) 10^x),
    labels = trans_format("log10", math_format(10^.x))
  ) +
  scale_y_log10(
    breaks = trans_breaks("log10", function(x) 10^x),
    labels = trans_format("log10", math_format(10^.x))
  ) +
  annotation_logticks(colour = grey_color, linewidth = 0.25) +
  labs(
    title = "Rozkład aktywności użytkowników (Prawo Zipfa)",
    subtitle = "Zależność rangi użytkownika od liczby napisanych postów",
    x = NULL, y = NULL
  ) +
  theme_phd() +
  theme(
    panel.grid.major = element_line(colour = "grey92", linewidth = 0.25),
    axis.line = element_line(colour = line_color, linewidth = 0.3)
  )

save_plot_phd(p_zipf, "06_zipf_aktywnosc")

# =============================================================================
# 2. Histogram (użytkownicy < 100 postów)
# =============================================================================
# Styl: etykiety na słupkach, brak siatki i brak etykiet osi Y
# (wartości odczytywane z bezpośrednich etykiet).

hist_data <- user_ranked |> filter(n_posts <= 100)

# Oblicz biny ręcznie, żeby móc etykietować
hist_binned <- hist_data |>
  mutate(bin = cut(n_posts, breaks = seq(0, 100, 5), right = TRUE)) |>
  count(bin, name = "n_users") |>
  mutate(
    bin_mid = seq(2.5, 97.5, 5)[seq_len(n())],
    label = ifelse(n_users > 0, fmt_number(n_users), "")
  )

p_hist <- ggplot(hist_binned, aes(x = bin_mid, y = n_users)) +
  geom_col(fill = "#507088", width = 4.5) +
  geom_text(
    aes(label = label),
    vjust = -0.3, size = 2, fontface = "bold",
    family = phd_font_family, colour = text_color_dark
  ) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  scale_x_continuous(breaks = seq(0, 100, 10)) +
  labs(
    title = "Rozkład liczby postów (ogon rozkładu)",
    subtitle = "Dla użytkowników z maksymalnie 100 postami",
    x = NULL, y = NULL
  ) +
  theme_phd() +
  theme(
    axis.text.y = element_blank(),
    axis.line.x = element_line(colour = line_color, linewidth = 0.3)
  )

save_plot_phd(p_hist, "07_histogram_aktywnosc")

# =============================================================================
# 3. Płeć (Deklarowana) — słupki poziome z bezpośrednimi etykietami
# =============================================================================

gender_clean <- gender_distribution |>
  group_by(plec_deklarowana) |>
  summarise(n = sum(n_users)) |>
  mutate(
    plec = case_match(plec_deklarowana,
      "M" ~ "Mężczyzna", "K" ~ "Kobieta", "brak danych" ~ "Brak danych",
      .default = "Inne"),
    pct = n / sum(n)
  )

p_gender <- ggplot(gender_clean,
                   aes(x = reorder(plec, n), y = n, fill = plec)) +
  geom_col(width = bar_width) +
  geom_text(
    aes(label = paste0(fmt_number(n), " (", percent(pct, 0.1), ")")),
    hjust = -0.05, size = 2.5, fontface = "bold",
    family = phd_font_family, colour = text_color_dark
  ) +
  scale_fill_manual(values = gender_colors) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.3))) +
  coord_flip() +
  labs(
    title = "Struktura płci użytkowników (dane deklaratywne)",
    x = NULL, y = NULL
  ) +
  theme_phd() +
  theme(axis.text.x = element_blank())

save_plot_phd(p_gender, "08_plec_deklarowana", height_cm = 7)

# =============================================================================
# 3b. Płeć (Predykowana) — słupki poziome z bezpośrednimi etykietami
# =============================================================================

gender_pred <- gender_distribution |>
  group_by(plec_predykowana) |>
  summarise(n = sum(n_users)) |>
  mutate(
    plec = case_match(plec_predykowana,
      "M" ~ "Mężczyzna", "K" ~ "Kobieta", .default = "Nieokreślona"),
    pct = n / sum(n)
  )

p_gender_pred <- ggplot(gender_pred,
                        aes(x = reorder(plec, n), y = n, fill = plec)) +
  geom_col(width = bar_width) +
  geom_text(
    aes(label = paste0(fmt_number(n), " (", percent(pct, 0.1), ")")),
    hjust = -0.05, size = 2.5, fontface = "bold",
    family = phd_font_family, colour = text_color_dark
  ) +
  scale_fill_manual(values = gender_colors) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.3))) +
  coord_flip() +
  labs(
    title = "Struktura płci użytkowników (predykowana przez klasyfikator)",
    subtitle = paste0("Łącznie: ", fmt_number(sum(gender_pred$n)), " użytkowników"),
    x = NULL, y = NULL
  ) +
  theme_phd() +
  theme(axis.text.x = element_blank())

save_plot_phd(p_gender_pred, "09_plec_predykowana", height_cm = 7)

# =============================================================================
# 4a. Struktura płci DEKLAROWANEJ wg forum (Stacked 100%)
# =============================================================================

gender_forum_decl <- gender_distribution |>
  mutate(
    plec = case_match(plec_deklarowana,
      "M" ~ "Mężczyzna", "K" ~ "Kobieta", .default = "Brak danych")
  ) |>
  group_by(forum, plec) |>
  summarise(n = sum(n_users), .groups = "drop") |>
  mutate(plec = factor(plec, levels = c("Mężczyzna", "Kobieta", "Brak danych"))) |>
  arrange(forum, plec) |>
  group_by(forum) |>
  mutate(
    pct = n / sum(n),
    cum_pct = cumsum(pct),
    label_y = cum_pct - pct / 2,
    label_txt = percent(pct, 0.1)
  ) |>
  ungroup() |>
  mutate(
    label_color = case_when(
      plec == "Brak danych" ~ text_color_dark,
      plec == "Kobieta"     ~ text_color_dark,
      TRUE                  ~ text_color_light
    ),
    label_txt = ifelse(pct < 0.06, "", label_txt)
  )

cat_labels_decl <- gender_forum_decl |>
  filter(forum == first(forum)) |>
  select(plec, label_y) |>
  mutate(
    cat_color = case_match(as.character(plec),
      "Mężczyzna"  ~ unname(gender_colors["Mężczyzna"]),
      "Kobieta"    ~ unname(gender_colors["Kobieta"]),
      "Brak danych" ~ "#8a8c8e"
    )
  )

p_gender_decl_stack <- ggplot(gender_forum_decl,
                              aes(x = forum, y = pct, fill = plec)) +
  geom_col(width = bar_width, position = position_stack(reverse = TRUE)) +
  geom_text(
    aes(y = label_y, label = label_txt, colour = label_color),
    size = 2.5, fontface = "bold", family = phd_font_family
  ) +
  scale_colour_identity() +
  scale_fill_manual(values = gender_colors) +
  scale_y_continuous(labels = percent, expand = expansion()) +
  annotate("text", x = 0.4, y = cat_labels_decl$label_y,
           label = cat_labels_decl$plec, colour = cat_labels_decl$cat_color,
           hjust = 1, size = 2.5, fontface = "bold", family = phd_font_family) +
  coord_cartesian(clip = "off", xlim = c(0.5, NA)) +
  labs(
    title = "Płeć deklarowana wg forum",
    x = NULL, y = NULL
  ) +
  theme_phd() +
  theme(axis.text.y = element_blank(), plot.margin = margin(10, 10, 10, 30))

save_plot_phd(p_gender_decl_stack, "10a_plec_deklarowana_wg_forum")

# =============================================================================
# 4b. Struktura płci PREDYKOWANEJ wg forum (Stacked 100%)
# =============================================================================

gender_forum_pred <- gender_distribution |>
  mutate(
    plec = case_match(plec_predykowana,
      "M" ~ "Mężczyzna", "K" ~ "Kobieta", .default = "Nieokreślona")
  ) |>
  group_by(forum, plec) |>
  summarise(n = sum(n_users), .groups = "drop") |>
  mutate(plec = factor(plec, levels = c("Mężczyzna", "Kobieta", "Nieokreślona"))) |>
  arrange(forum, plec) |>
  group_by(forum) |>
  mutate(
    pct = n / sum(n),
    cum_pct = cumsum(pct),
    label_y = cum_pct - pct / 2,
    label_txt = percent(pct, 0.1)
  ) |>
  ungroup() |>
  mutate(
    label_color = case_when(
      plec == "Nieokreślona" ~ text_color_dark,
      plec == "Kobieta"      ~ text_color_dark,
      TRUE                   ~ text_color_light
    ),
    label_txt = ifelse(pct < 0.06, "", label_txt)
  )

cat_labels_pred <- gender_forum_pred |>
  filter(forum == first(forum)) |>
  select(plec, label_y) |>
  mutate(
    cat_color = case_match(as.character(plec),
      "Mężczyzna"    ~ unname(gender_colors["Mężczyzna"]),
      "Kobieta"      ~ unname(gender_colors["Kobieta"]),
      "Nieokreślona" ~ "#8a8c8e"
    )
  )

p_gender_pred_stack <- ggplot(gender_forum_pred,
                              aes(x = forum, y = pct, fill = plec)) +
  geom_col(width = bar_width, position = position_stack(reverse = TRUE)) +
  geom_text(
    aes(y = label_y, label = label_txt, colour = label_color),
    size = 2.5, fontface = "bold", family = phd_font_family
  ) +
  scale_colour_identity() +
  scale_fill_manual(values = gender_colors) +
  scale_y_continuous(labels = percent, expand = expansion()) +
  annotate("text", x = 0.4, y = cat_labels_pred$label_y,
           label = cat_labels_pred$plec, colour = cat_labels_pred$cat_color,
           hjust = 1, size = 2.5, fontface = "bold", family = phd_font_family) +
  coord_cartesian(clip = "off", xlim = c(0.5, NA)) +
  labs(
    title = "Płeć predykowana wg forum",
    subtitle = "Na podstawie klasyfikatora płci",
    x = NULL, y = NULL
  ) +
  theme_phd() +
  theme(axis.text.y = element_blank(), plot.margin = margin(10, 10, 10, 30))

save_plot_phd(p_gender_pred_stack, "10b_plec_predykowana_wg_forum")

message("04_demographic_stats.R completed.")
