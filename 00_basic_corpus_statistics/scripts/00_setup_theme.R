# =============================================================================
# 00_setup_theme.R - Academic Theme for PhD Thesis (LaTeX/Overleaf)
# =============================================================================
# System wizualny "PhD-Modern" — zoptymalizowany pod skład w LaTeX.
# Konwencja: tytuły i opisy umieszczane w \caption{} w LaTeX,
# dlatego eksport PDF automatycznie usuwa tytuł, podtytuł i adnotację.
# =============================================================================

library(ggplot2)
library(dplyr)
library(scales)
library(grid)

# Renderowanie czcionek przez showtext (umożliwia użycie LMR/CMR)
library(showtext)
showtext_auto()
showtext_opts(dpi = 300)

# Use the default system serif font family available in R for reproducible plots.
# Avoid registering local OTFs or forcing LaTeX-specific fonts; plots will use
# the standard `serif` family which is portable across environments.
phd_font_family <- "serif"
message("Font for plots: ", phd_font_family)
# --- 1. Paleta "Academic Slate" ---
# Kolory o zróżnicowanej luminancji — czytelne również w druku czarno-białym.
forum_colors <- c(
  "Z Chrystusem"    = "#2C3E50",  # Głęboki granat
  "radiokatolik.pl" = "#A93226",  # Ceglana czerwień
  "Dolina Modlitwy" = "#1E8449",  # Ciemna zieleń
  "wiara.pl"        = "#2E86C1"   # Stalowy niebieski
)

gender_colors <- c(
  "Mężczyzna"       = "#2E86C1",
  "Kobieta"         = "#A93226",
  "Nieokreślona"    = "#7F8C8D",
  "Brak danych"     = "#BDC3C7"
)

# --- 2. Motyw graficzny (PhD-Modern) ---
# Zoptymalizowany pod skład w LaTeX/Overleaf.
# Konwencja: tytuły i opisy w \caption{}, PDF eksportowany bez nich.
theme_phd <- function(base_size = 11, base_family = phd_font_family) {
  theme_minimal(base_size = base_size, base_family = base_family) %+replace%
    theme(
      # Tytuły (widoczne w PNG; PDF je usuwa — por. save_plot_phd)
      plot.title       = element_text(size = rel(1.15), face = "bold",
                                      hjust = 0, margin = margin(b = 8)),
      plot.subtitle    = element_text(size = rel(0.85), colour = "grey30",
                                      hjust = 0, margin = margin(b = 12)),
      plot.caption     = element_text(size = rel(0.75), colour = "grey50",
                                      hjust = 1, margin = margin(t = 8)),

      # Osie — bez bolda w tytułach (mniej dominujące)
      axis.title       = element_text(size = rel(0.95)),
      axis.title.y     = element_text(margin = margin(r = 12), angle = 90),
      axis.title.x     = element_text(margin = margin(t = 12)),

      # Etykiety osi
      axis.text        = element_text(size = rel(0.85), colour = "grey15"),
      axis.text.x      = element_text(margin = margin(t = 4)),
      axis.text.y      = element_text(margin = margin(r = 4), hjust = 1),

      # Linie i kreski osi — delikatny grafit zamiast czystej czerni
      axis.line        = element_line(colour = "grey25", linewidth = 0.4),
      axis.ticks       = element_line(colour = "grey25", linewidth = 0.35),
      axis.ticks.length = unit(3, "pt"),

      # Siatka — bardzo subtelna
      panel.grid.major = element_line(colour = "grey92", linewidth = 0.25),
      panel.grid.minor = element_blank(),
      panel.border     = element_blank(),
      panel.spacing    = unit(1.2, "lines"),

      # Legenda — większe klucze, lepsze odstępy
      legend.position  = "bottom",
      legend.title     = element_blank(),
      legend.text      = element_text(size = rel(0.88)),
      legend.key.size  = unit(1.1, "lines"),
      legend.key.width = unit(1.6, "lines"),
      legend.margin    = margin(t = 6),
      legend.box.margin = margin(t = 0),

      # Marginesy wykresu — więcej „oddechu"
      plot.margin      = margin(15, 15, 15, 15)
    )
}

# --- 3. Zapis PDF + PNG ---
save_plot_phd <- function(plot, filename,
                          width_cm = 16, height_cm = 10,
                          dpi = 300) {
  plots_dir <- here::here("00_basic_corpus_statistics", "output", "plots")
  dir.create(plots_dir, recursive = TRUE, showWarnings = FALSE)

  # PDF (do LaTeXa) — bez tytułu/podtytułu (trafi do \caption{})
  clean_plot <- plot +
    labs(title = NULL, subtitle = NULL, caption = NULL)

  pdf_path <- file.path(plots_dir, paste0(filename, ".pdf"))
  pdf_device <- if (capabilities("cairo")) cairo_pdf else "pdf"
  ggsave(pdf_path, clean_plot,
         width = width_cm, height = height_cm, units = "cm",
         device = pdf_device)

  # PNG (podgląd) — z tytułami, białe tło
  png_path <- file.path(plots_dir, paste0(filename, ".png"))
  ggsave(png_path, plot,
         width = width_cm, height = height_cm, units = "cm",
         dpi = dpi, bg = "white")

  message("  \u2713 ", filename, " (.pdf + .png)")
}

# --- 4. Formatery ---
save_table <- function(df, filename) {
  tables_dir <- here::here("00_basic_corpus_statistics", "output", "tables")
  dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

  if (any(vapply(df, function(col) inherits(col, "integer64"), logical(1)))) {
    df <- df |>
      dplyr::mutate(dplyr::across(
        dplyr::where(~ inherits(.x, "integer64")), as.numeric
      ))
  }

  readr::write_csv(df, file.path(tables_dir, paste0(filename, ".csv")))
  writexl::write_xlsx(df, file.path(tables_dir, paste0(filename, ".xlsx")))
  message("  \u2713 table: ", filename)
}

# Separator tysięcy — spacja (polska typografia)
fmt_number <- function(x) {
  format(x, big.mark = " ", scientific = FALSE, trim = TRUE)
}

message("Theme loaded: PhD-Modern (serif, Academic Slate palette)")
