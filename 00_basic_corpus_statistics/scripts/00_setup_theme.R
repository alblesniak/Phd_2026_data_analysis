# =============================================================================
# 00_setup_theme.R - Academic Theme for PhD Thesis (LaTeX/Overleaf)
# =============================================================================
# System wizualny wzorowany na stylistyce Alberta Rappa
# (https://albert-rapp.de/posts/ggplot2-tips/22_diverging_bar_plot)
# Zasady: radykalny minimalizm, bezpośrednie etykietowanie danych,
# brak legend, celowe użycie koloru, czysta typografia.
# Konwencja: tytuły i opisy umieszczane w \caption{} w LaTeX,
# dlatego eksport PDF automatycznie usuwa tytuł, podtytuł i adnotację.
# =============================================================================

library(ggplot2)
library(dplyr)
library(scales)
library(grid)
library(ggtext)

# --- Czcionki (showtext + Google Fonts) ---
library(showtext)
tryCatch({
  font_add_google("Source Sans Pro", "Source Sans Pro")
  phd_font_family <- "Source Sans Pro"
}, error = function(e) {
  phd_font_family <<- "sans"
  message("Source Sans Pro unavailable, using system sans-serif")
})
showtext_auto()
showtext_opts(dpi = 300)

message("Font for plots: ", phd_font_family)

# --- 1. Kolory ---
# Kolory tekstu i akcentów
text_color_dark  <- "#333333"
text_color_light <- "white"
grey_color       <- "#bdbfc1"
line_color       <- "grey25"

# Paleta forów — inspirowana stylistyką A. Rappa: stonowane, wyciszone tony,
# zróżnicowana luminancja, czytelne w druku czarno-białym.
forum_colors <- c(
  "Z Chrystusem"    = "#507088",  # stonowany stalowy błękit (z tutorialu Rappa)
  "radiokatolik.pl" = "#d2a940",  # ciepłe złoto (z tutorialu Rappa)
  "Dolina Modlitwy" = "#6a8e6e",  # wyciszony szałwiowy zielony
  "wiara.pl"        = "#a05a5a"   # wyciszony ceglasty/dusty rose
)

gender_colors <- c(
  "Mężczyzna"       = "#507088",  # stalowy błękit
  "Kobieta"         = "#d2a940",  # ciepłe złoto
  "Nieokreślona"    = "#bdbfc1",
  "Brak danych"     = "#bdbfc1"   # szary z tutorialu
)

# --- 2. Motyw graficzny ---
# Wzorowany na Albert Rapp: theme_minimal z agresywnym usuwaniem dekoracji.
# Domyślnie: brak siatki, brak legend, brak tytułów osi, brak ticków.
theme_phd <- function(base_size = 8, base_family = phd_font_family) {
  theme_minimal(base_size = base_size, base_family = base_family) %+replace%
    theme(
      # --- Tytuły (widoczne w PNG; PDF je usuwa — por. save_plot_phd) ---
      plot.title    = element_text(
        size = 12, face = "bold", hjust = 0,
        margin = margin(t = 2, b = 2, unit = "mm")
      ),
      plot.subtitle = element_text(
        size = 8, colour = text_color_dark, face = "italic",
        hjust = 0, margin = margin(b = 2, unit = "mm")
      ),
      plot.caption  = element_markdown(
        size = 6, colour = text_color_dark,
        hjust = 0, margin = margin(t = 2, b = 2, unit = "mm"),
        lineheight = 1.1
      ),

      # --- Osie: minimalne ---
      axis.title       = element_blank(),
      axis.text        = element_text(size = 7, colour = text_color_dark),
      axis.line        = element_blank(),
      axis.ticks       = element_blank(),
      axis.ticks.length = unit(0, "pt"),

      # --- Siatka: usunięta całkowicie ---
      panel.grid.major = element_blank(),
      panel.grid.minor = element_blank(),
      panel.border     = element_blank(),
      panel.spacing    = unit(0, "pt"),

      # --- Legenda: domyślnie ukryta (etykietowanie bezpośrednie) ---
      legend.position = "none",

      # --- Marginesy ---
      plot.margin = margin(10, 10, 10, 10),

      # --- Facety ---
      strip.text = element_blank()
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

message("Theme loaded: PhD-Rapp (Source Sans Pro, minimalist aesthetic)")
