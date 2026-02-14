# =============================================================================
# 02_general_stats.R - Corpus size and volume statistics
# =============================================================================
library(dplyr)
library(ggplot2)
library(scales)

source(here::here("00_basic_corpus_statistics", "scripts", "00_setup_theme.R"))

if (!exists("posts_per_forum")) {
  source(here::here("00_basic_corpus_statistics", "scripts", "01_fetch_data.R"))
}

# 1. Tabela podsumowująca (bez zmian w logice, tylko zapis)
forum_summary <- posts_per_forum |>
  left_join(threads_per_forum, by = "forum") |>
  left_join(users_per_forum, by = "forum") |>
  left_join(tokens_per_forum, by = "forum") |>
  mutate(
    procent_postow = round(n_posts / sum(n_posts) * 100, 2),
    procent_tokenow = round(n_tokens / sum(n_tokens) * 100, 2)
  )

forum_summary_total <- forum_summary |>
  summarise(
    forum          = "RAZEM",
    n_posts        = sum(n_posts),
    n_threads      = sum(n_threads),
    n_users        = sum(n_users),
    n_tokens       = sum(n_tokens),
    procent_postow = 100,
    procent_tokenow = 100
  )

forum_summary_full <- bind_rows(forum_summary, forum_summary_total)
save_table(forum_summary_full, "01_podsumowanie_korpusu")

# =============================================================================
# 2. Wykres słupkowy: Posty wg forum
# =============================================================================
# Styl: bezpośrednie etykiety na słupkach, brak siatki, brak osi x,
# brak tytułów osi, brak legendy (kolor = identyfikator forum).

bar_width <- 0.75

plot_data <- posts_per_forum |>
  mutate(
    procent = n_posts / sum(n_posts) * 100,
    label_txt = paste0(fmt_number(n_posts), " (", round(procent, 1), "%)")
  )

p_posts <- ggplot(plot_data,
                  aes(x = reorder(forum, n_posts), y = n_posts, fill = forum)) +
  geom_col(width = bar_width) +
  geom_text(
    aes(label = label_txt),
    hjust = -0.05, size = 2.5,
    family = phd_font_family, fontface = "bold",
    colour = text_color_dark
  ) +
  scale_fill_manual(values = forum_colors) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.35))) +
  coord_flip() +
  labs(
    title = "Rozkład postów w korpusie wg forum",
    subtitle = paste0("Łącznie: ", fmt_number(total_posts)),
    x = NULL, y = NULL
  ) +
  theme_phd() +
  theme(axis.text.x = element_blank())

save_plot_phd(p_posts, "01_posty_wg_forum", height_cm = 7)

# =============================================================================
# 3. Wykres słupkowy: Tokeny wg forum
# =============================================================================

plot_data_tok <- tokens_per_forum |>
  mutate(
    procent = n_tokens / sum(n_tokens) * 100,
    label_txt = paste0(fmt_number(n_tokens), " (", round(procent, 1), "%)")
  )

p_tokens <- ggplot(plot_data_tok,
                   aes(x = reorder(forum, n_tokens), y = n_tokens, fill = forum)) +
  geom_col(width = bar_width) +
  geom_text(
    aes(label = label_txt),
    hjust = -0.05, size = 2.5,
    family = phd_font_family, fontface = "bold",
    colour = text_color_dark
  ) +
  scale_fill_manual(values = forum_colors) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.35))) +
  coord_flip() +
  labs(
    title = "Rozkład tokenów w korpusie wg forum",
    subtitle = paste0("Łącznie: ", fmt_number(total_tokens)),
    x = NULL, y = NULL
  ) +
  theme_phd() +
  theme(axis.text.x = element_blank())

save_plot_phd(p_tokens, "02_tokeny_wg_forum", height_cm = 7)

message("02_general_stats.R completed.")
