# =============================================================================
# 00_setup_theme.R - Custom ggplot2 theme for academic publications
# =============================================================================
# Defines a clean, minimal theme suitable for PhD thesis printing.
# All output labels are in Polish.
# =============================================================================

library(ggplot2)

# --- Color palette for the four forums ---
forum_colors <- c(
  "Z Chrystusem"    = "#2C3E50",
  "radiokatolik.pl" = "#E74C3C",
  "Dolina Modlitwy" = "#27AE60",
  "wiara.pl"        = "#2980B9"
)

# --- Custom academic theme ---
theme_academic <- function(base_size = 12, base_family = "") {
  theme_minimal(base_size = base_size, base_family = base_family) %+replace%
    theme(
      # Text elements
      plot.title       = element_text(size = rel(1.3), face = "bold",
                                      hjust = 0, margin = margin(b = 10)),
      plot.subtitle    = element_text(size = rel(1.0), hjust = 0,
                                      color = "grey30",
                                      margin = margin(b = 12)),
      plot.caption     = element_text(size = rel(0.8), hjust = 1,
                                      color = "grey50",
                                      margin = margin(t = 10)),
      # Axes
      axis.title       = element_text(size = rel(1.0), face = "bold"),
      axis.title.x     = element_text(margin = margin(t = 8)),
      axis.title.y     = element_text(margin = margin(r = 8)),
      axis.text        = element_text(size = rel(0.9), color = "grey20"),
      axis.line        = element_line(color = "grey40", linewidth = 0.4),
      axis.ticks       = element_line(color = "grey40", linewidth = 0.3),
      # Grid
      panel.grid.major = element_line(color = "grey90", linewidth = 0.3),
      panel.grid.minor = element_blank(),
      # Legend
      legend.position  = "bottom",
      legend.title     = element_text(size = rel(0.9), face = "bold"),
      legend.text      = element_text(size = rel(0.85)),
      legend.key.size  = unit(0.9, "lines"),
      # Facets
      strip.text       = element_text(size = rel(1.0), face = "bold",
                                      margin = margin(b = 5, t = 5)),
      strip.background = element_rect(fill = "grey95", color = NA),
      # Plot margins
      plot.margin      = margin(15, 15, 15, 15)
    )
}

# --- Helper: save publication-quality plot ---
save_plot <- function(plot, filename, width = 10, height = 6, dpi = 300) {
  plots_dir <- here::here("00_basic_corpus_statistics", "output", "plots")
  dir.create(plots_dir, recursive = TRUE, showWarnings = FALSE)
  # Save PNG: prefer ragg::agg_png for consistent raster output if available
  png_path <- file.path(plots_dir, paste0(filename, ".png"))
  if (requireNamespace("ragg", quietly = TRUE)) {
    ggsave(
      filename = png_path,
      plot = plot,
      width = width,
      height = height,
      dpi = dpi,
      device = ragg::agg_png
    )
  } else {
    ggsave(
      filename = png_path,
      plot = plot,
      width = width,
      height = height,
      dpi = dpi,
      bg = "white"
    )
  }

  # Save PDF: prefer ragg::agg_pdf if available (no XQuartz dependency).
  pdf_path <- file.path(plots_dir, paste0(filename, ".pdf"))
  if (requireNamespace("ragg", quietly = TRUE) && "agg_pdf" %in% getNamespaceExports("ragg")) {
    ggsave(
      filename = pdf_path,
      plot = plot,
      width = width,
      height = height,
      device = ragg::agg_pdf
    )
  } else if (requireNamespace("ragg", quietly = TRUE) && !("agg_pdf" %in% getNamespaceExports("ragg"))) {
    # Older ragg versions may not export agg_pdf; use cairo if available, else base pdf
    if (capabilities("cairo")) {
      suppressWarnings(tryCatch(
        ggsave(
          filename = pdf_path,
          plot = plot,
          width = width,
          height = height,
          device = cairo_pdf
        ),
        error = function(e) {
          warning("cairo PDF failed (", conditionMessage(e), ") — falling back to base PDF device")
          ggsave(
            filename = pdf_path,
            plot = plot,
            width = width,
            height = height,
            device = "pdf"
          )
        }
      ))
    } else {
      ggsave(
        filename = pdf_path,
        plot = plot,
        width = width,
        height = height,
        device = "pdf"
      )
    }
  } else {
    # No ragg: prefer cairo if system supports it; suppress cairo warning and fall back to base pdf on error
    if (capabilities("cairo")) {
      suppressWarnings(tryCatch(
        ggsave(
          filename = pdf_path,
          plot = plot,
          width = width,
          height = height,
          device = cairo_pdf
        ),
        error = function(e) {
          warning("cairo PDF failed (", conditionMessage(e), ") — falling back to base PDF device")
          ggsave(
            filename = pdf_path,
            plot = plot,
            width = width,
            height = height,
            device = "pdf"
          )
        }
      ))
    } else {
      ggsave(
        filename = pdf_path,
        plot = plot,
        width = width,
        height = height,
        device = "pdf"
      )
    }
  }

  message("Saved: ", filename, " (.png + .pdf)")
}

# --- Helper: save table to CSV and Excel ---
save_table <- function(df, filename) {
  tables_dir <- here::here("00_basic_corpus_statistics", "output", "tables")
  dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

  # Convert integer64 columns (from DB drivers) to numeric to avoid
  # automatic coercion warnings when writing with writexl/readr.
  if (any(vapply(df, function(col) inherits(col, "integer64"), logical(1)))) {
    df <- df |> dplyr::mutate(dplyr::across(dplyr::where(~ inherits(.x, "integer64")), as.numeric))
  }

  readr::write_csv(df, file.path(tables_dir, paste0(filename, ".csv")))
  writexl::write_xlsx(df, file.path(tables_dir, paste0(filename, ".xlsx")))

  message("Saved: ", filename, " (.csv + .xlsx)")
}

# --- Polish number formatting helper ---
fmt_number <- function(x) {
  format(x, big.mark = " ", scientific = FALSE)
}

message("Theme and helpers loaded.")
