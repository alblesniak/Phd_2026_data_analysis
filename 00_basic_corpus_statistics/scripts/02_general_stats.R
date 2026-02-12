# =============================================================================
# 02_general_stats.R - Corpus size and volume statistics
# =============================================================================
# Depends on: 00_setup_theme.R, 01_fetch_data.R (run first)
# Produces: summary table + bar chart of posts distribution per forum
# =============================================================================

library(dplyr)
library(ggplot2)
library(scales)

# --- Source setup (if not already loaded) ---
source(here::here("00_basic_corpus_statistics", "scripts", "00_setup_theme.R"))

# --- Auto-load data if running independently ---
if (!exists("posts_per_forum")) {
  message("Danych nie znaleziono w pamięci. Uruchamiam 01_fetch_data.R...")
  source(here::here("00_basic_corpus_statistics", "scripts", "01_fetch_data.R"))
}

# =============================================================================
# 1) Summary table: corpus dimensions
# =============================================================================

# Build a comprehensive summary by forum
forum_summary <- posts_per_forum |>
  left_join(threads_per_forum, by = "forum") |>
  left_join(users_per_forum, by = "forum") |>
  left_join(tokens_per_forum, by = "forum") |>
  mutate(
    procent_postow = round(n_posts / sum(n_posts) * 100, 2),
    procent_tokenow = round(n_tokens / sum(n_tokens) * 100, 2)
  )

# Add totals row
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

# Rename columns to Polish for output
forum_summary_output <- forum_summary_full |>
  rename(
    Forum              = forum,
    `Liczba postów`    = n_posts,
    `Liczba wątków`    = n_threads,
    `Liczba użytk.`    = n_users,
    `Liczba tokenów`   = n_tokens,
    `% postów`         = procent_postow,
    `% tokenów`        = procent_tokenow
  )

save_table(forum_summary_output, "01_podsumowanie_korpusu")

message("\n=== PODSUMOWANIE KORPUSU ===")
message("Posty:        ", fmt_number(total_posts))
message("Tokeny LPMN:  ", fmt_number(total_tokens))
message("Wątki:        ", fmt_number(total_threads))
message("Użytkownicy:  ", fmt_number(total_users))
message("Sekcje:       ", fmt_number(total_sections))
message("Fora:         ", fmt_number(total_forums))

# =============================================================================
# 2) Bar chart: posts distribution per forum
# =============================================================================

plot_data <- posts_per_forum |>
  mutate(
    procent = n_posts / sum(n_posts) * 100,
    label   = paste0(fmt_number(n_posts), "\n(", round(procent, 1), "%)")
  )

p_posts_forum <- ggplot(plot_data, aes(
  x    = reorder(forum, n_posts),
  y    = n_posts,
  fill = forum
)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  geom_text(
    aes(label = label),
    hjust = -0.05,
    size  = 3.5,
    fontface = "bold"
  ) +
  coord_flip() +
  scale_fill_manual(values = forum_colors) +
  scale_y_continuous(
    labels = label_number(big.mark = " "),
    expand = expansion(mult = c(0, 0.25))
  ) +
  labs(
    title    = "Rozkład postów w korpusie wg forum",
    subtitle = paste0("Łącznie: ", fmt_number(total_posts), " postów"),
    x        = "Forum",
    y        = "Liczba postów",
    caption  = "Źródło: baza danych forums_scraper"
  ) +
  theme_academic()

save_plot(p_posts_forum, "01_posty_wg_forum", width = 10, height = 5)

# =============================================================================
# 3) Bar chart: tokens distribution per forum
# =============================================================================

plot_data_tokens <- tokens_per_forum |>
  mutate(
    procent = n_tokens / sum(n_tokens) * 100,
    label   = paste0(fmt_number(n_tokens), "\n(", round(procent, 1), "%)")
  )

p_tokens_forum <- ggplot(plot_data_tokens, aes(
  x    = reorder(forum, n_tokens),
  y    = n_tokens,
  fill = forum
)) +
  geom_col(width = 0.7, show.legend = FALSE) +
  geom_text(
    aes(label = label),
    hjust = -0.05,
    size  = 3.5,
    fontface = "bold"
  ) +
  coord_flip() +
  scale_fill_manual(values = forum_colors) +
  scale_y_continuous(
    labels = label_number(big.mark = " "),
    expand = expansion(mult = c(0, 0.25))
  ) +
  labs(
    title    = "Rozkład tokenów w korpusie wg forum",
    subtitle = paste0("Łącznie: ", fmt_number(total_tokens), " tokenów (analiza LPMN)"),
    x        = "Forum",
    y        = "Liczba tokenów",
    caption  = "Źródło: baza danych forums_scraper"
  ) +
  theme_academic()

save_plot(p_tokens_forum, "02_tokeny_wg_forum", width = 10, height = 5)

message("02_general_stats.R completed.")
