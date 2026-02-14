# System estetyczny wykresow — wytyczne dla agentow

> Plik referencyjny dla agentow Claude Code pracujacych z wykresami w tym projekcie.
> Zrodlo stylu: [Albert Rapp — Diverging Bar Plots](https://albert-rapp.de/posts/ggplot2-tips/22_diverging_bar_plot)

---

## 1. Filozofia

Radykalny minimalizm. Kazdy element wizualny musi "zarabiac" na swoja obecnosc.
Jesli cos mozna usunac bez utraty informacji — usun.

**Zasady nadrzedne:**

- **Brak legend** — zawsze etykietowanie bezposrednie (tekst na/przy danych)
- **Brak siatki** — chyba ze jest kluczowa do odczytu (wykresy liniowe, log-log)
- **Brak tytulow osi** — kontekst powinien wynikac z tytulu i etykiet danych
- **Brak tickow** — osie minimalne lub niewidoczne
- **Celowy kolor** — kolor sluzy identyfikacji, nie dekoracji
- **Bezposrednie etykiety** — wartosci na/przy slupkach, nazwy na koncu linii, procenty w segmentach

---

## 2. Plik tematu: `00_setup_theme.R`

Centralny plik konfiguracyjny. Kazdy skrypt plotujacy musi zaczac od:

```r
source(here::here("00_basic_corpus_statistics", "scripts", "00_setup_theme.R"))
```

Dostarcza:

| Element               | Wartosc/Funkcja                                  |
|----------------------|--------------------------------------------------|
| `theme_phd()`        | Bazowy motyw ggplot2 (minimalistyczny)             |
| `save_plot_phd()`    | Dual-export: PDF (bez tytulow) + PNG (z tytulami)  |
| `save_table()`       | Export CSV + XLSX                                  |
| `fmt_number()`       | Formater z separatorem tysiecy (spacja)            |
| `forum_colors`       | Named vector kolorow forow                         |
| `gender_colors`      | Named vector kolorow plci                          |
| `phd_font_family`    | Czcionka (Source Sans Pro / fallback: sans)         |
| Stale kolorow        | `text_color_dark`, `text_color_light`, `grey_color`, `line_color` |

---

## 3. Paleta kolorow

### 3.1 Kolory forow (`forum_colors`)

```r
forum_colors <- c(
  "Z Chrystusem"    = "#507088",  # stonowany stalowy blekit
  "radiokatolik.pl" = "#d2a940",  # cieple zloto
  "Dolina Modlitwy" = "#6a8e6e",  # wyciszony szalwiowy zielony
  "wiara.pl"        = "#a05a5a"   # wyciszony ceglasty / dusty rose
)
```

### 3.2 Kolory plci (`gender_colors`)

```r
gender_colors <- c(
  "Mezczyzna"    = "#507088",  # stalowy blekit
  "Kobieta"      = "#d2a940",  # cieple zloto
  "Nieokreslona" = "#bdbfc1",  # jasny szary (identyczny z "Brak danych")
  "Brak danych"  = "#bdbfc1"   # jasny szary
)
```

### 3.3 Kolory tekstowe i akcentowe

```r
text_color_dark  <- "#333333"   # tekst na jasnym tle
text_color_light <- "white"     # tekst na ciemnym tle
grey_color       <- "#bdbfc1"   # delikatny akcent / segmenty linii
line_color       <- "grey25"    # osie
```

### 3.4 Zasada doboru koloru tekstu etykiet

| Tlo wypelnienia        | Kolor tekstu         | Przyklady                |
|------------------------|---------------------|--------------------------|
| Ciemne (blekit, rose)  | `text_color_light`  | Mezczyzna, wiara.pl      |
| Srednie (zloto)        | `text_color_dark`   | Kobieta, radiokatolik.pl |
| Jasne (szary, brak)    | `text_color_dark`   | Brak danych, Nieokreslona|

**Uwaga:** Jesli etykieta kategorii pojawia sie POZA wykresem (np. `annotate("text")` na bialym tle), nie uzywaj `#bdbfc1` — jest nieczytelny. Uzyj `#8a8c8e` lub ciemniejszego szarego.

---

## 4. Czcionka

- **Glowna:** Source Sans Pro (Google Fonts via `showtext`)
- **Fallback:** `sans` (gdy Source Sans Pro niedostepny)
- Ladowanie odbywa sie automatycznie w `00_setup_theme.R`

### Rozmiary (w `theme_phd()`)

| Element          | Rozmiar | Styl          |
|-----------------|---------|---------------|
| `plot.title`    | 12pt    | bold          |
| `plot.subtitle` | 8pt     | italic        |
| `plot.caption`  | 6pt     | markdown      |
| `axis.text`     | 7pt     | normal        |
| Etykiety danych | 2–2.5pt | bold          |
| Etykiety repel  | 2.2pt   | bold          |

---

## 5. Motyw (`theme_phd()`)

Bazuje na `theme_minimal()` z agresywnym usunieciem dekoracji:

```r
theme_phd <- function(base_size = 8, base_family = phd_font_family) {
  theme_minimal(base_size, base_family) %+replace% theme(
    plot.title    = element_text(size = 12, face = "bold", hjust = 0, ...),
    plot.subtitle = element_text(size = 8, face = "italic", ...),
    plot.caption  = element_markdown(size = 6, ...),
    axis.title    = element_blank(),
    axis.text     = element_text(size = 7, colour = text_color_dark),
    axis.line     = element_blank(),
    axis.ticks    = element_blank(),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    legend.position  = "none",
    ...
  )
}
```

### Kiedy DODAC elementy z powrotem

Nie wszystkie wykresy moga byc calkowicie nagie. Dodawaj selektywnie:

| Typ wykresu        | Dodatkowe elementy                                              |
|-------------------|-----------------------------------------------------------------|
| Liniowy           | `panel.grid.major.y` (grey92, 0.25), `axis.line.x` (grey25)    |
| Log-log (Zipf)    | `panel.grid.major` (grey92, 0.25), `axis.line` (grey25), `annotation_logticks` |
| Area chart        | `axis.line.x` (grey25)                                         |
| Histogram         | `axis.line.x` (grey25), `axis.text.y = element_blank()`        |
| Slupkowy poziomy  | `axis.text.x = element_blank()` (wartosci sa na etykietach)    |
| Stacked 100%      | `axis.text.y = element_blank()` (etykiety kategorii po lewej)  |

---

## 6. Eksport: `save_plot_phd()`

Kazdy wykres zapisywany jest podwojnie:

| Format | Cel              | Tytul/Subtitle | Tlo   |
|--------|-----------------|----------------|-------|
| PDF    | LaTeX `\caption{}` | **usuniete**   | brak  |
| PNG    | Podglad / review | zachowane      | biale |

### Domyslne wymiary

| Parametr     | Domyslna | Typowe uzucia                              |
|-------------|----------|---------------------------------------------|
| `width_cm`  | 16       | 18 dla wykresow z etykietami po prawej      |
| `height_cm` | 10       | 7 dla wykresow slupkowych (3–4 slupki)      |
| `dpi`       | 300      | stale                                       |

---

## 7. Receptury na typy wykresow

### 7.1 Slupkowy poziomy (bar chart)

Uzycie: porownanie kategorii (fora, plec). Najprostszy i najczestszy typ.

```r
bar_width <- 0.75

ggplot(data, aes(x = reorder(category, value), y = value, fill = category)) +
  geom_col(width = bar_width) +
  geom_text(
    aes(label = label_txt),
    hjust = -0.05, size = 2.5, fontface = "bold",
    family = phd_font_family, colour = text_color_dark
  ) +
  scale_fill_manual(values = color_palette) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.35))) +
  coord_flip() +
  labs(title = "...", x = NULL, y = NULL) +
  theme_phd() +
  theme(axis.text.x = element_blank())
```

**Kluczowe parametry:**
- `bar_width = 0.75`
- `hjust = -0.05` (etykieta tuz za koncem slupka)
- `expansion(mult = c(0, 0.35))` (miejsce na etykiety)
- `height_cm = 7` (dla 3–4 slupkow)

### 7.2 Liniowy (line chart)

Uzycie: trend w czasie, jeden lub wiele serii.

**Jedna seria:**
```r
ggplot(data, aes(x = rok, y = value)) +
  geom_line(linewidth = 0.9, colour = "#507088") +
  geom_point(size = 1.5, colour = "#507088") +
  geom_text(data = peak, aes(label = fmt_number(value)),
            nudge_y = max_val * 0.06, size = 2.5, fontface = "bold", ...) +
  scale_y_continuous(labels = fmt_number, limits = c(0, NA)) +
  theme_phd() +
  theme(
    panel.grid.major.y = element_line(colour = "grey92", linewidth = 0.25),
    axis.line.x = element_line(colour = line_color, linewidth = 0.3)
  )
```

**Wiele serii (z ggrepel):**
```r
library(ggrepel)

# Etykiety na koncu linii (zamiast legendy)
last_points <- data |> group_by(group) |> filter(x == max(x))

ggplot(data, aes(x, y, colour = group)) +
  geom_line(linewidth = 0.9) +
  geom_point(size = 1.5) +
  geom_text_repel(
    data = last_points, aes(label = group),
    hjust = 0, nudge_x = 0.8, direction = "y",
    segment.size = 0.3, segment.color = grey_color,
    size = 2.2, fontface = "bold", family = phd_font_family,
    xlim = c(max_x + 0.5, NA)
  ) +
  scale_colour_manual(values = color_palette) +
  coord_cartesian(clip = "off") +
  theme_phd() +
  theme(
    panel.grid.major.y = element_line(colour = "grey92", linewidth = 0.25),
    axis.line.x = element_line(colour = line_color, linewidth = 0.3),
    plot.margin = margin(10, 35, 10, 10)  # prawy margines na etykiety
  )
```

**Kluczowe:**
- `direction = "y"` w ggrepel (etykiety rozpychane pionowo)
- `coord_cartesian(clip = "off")` (etykiety poza obszarem wykresu)
- `plot.margin` z prawym marginesem 35+ (miejsce na etykiety)

### 7.3 Area chart (wykres warstwowy)

Uzycie: udzial grup w calkowitej wartosci na osi czasu.

**Pozycjonowanie etykiet — metoda `ggplot_build()`:**

Nie obliczaj pozycji Y recznie (cumsum). Uzyj `ggplot_build()`, ktory zwraca faktyczne pozycje warstw z wewnetrznych obliczen ggplot2:

```r
# 1. Zbuduj bazowy wykres
p_base <- ggplot(data, aes(x, y, fill = group)) +
  geom_area(alpha = 0.85, colour = "white", linewidth = 0.3)

# 2. Wyciagnij pozycje warstw
built <- ggplot_build(p_base)$data[[1]]
built$group_name <- levels(data$group)[built$group]
built$x_int <- as.integer(round(built$x))

# 3. Dla kazdej grupy wybierz rok z najszerszym pasmem
max_label_x <- max(data$x) - 2  # nie za blisko prawej krawedzi

label_positions <- built |>
  mutate(band = ymax - ymin, ymid = (ymin + ymax) / 2) |>
  filter(x_int <= max_label_x, band > 0) |>
  group_by(group_name) |>
  slice_max(band, n = 1) |>
  ungroup()

# 4. Dodaj etykiety do bazowego wykresu
p_base +
  geom_text(data = label_positions,
            aes(x = x_int, y = ymid, label = group_name),
            colour = text_color_light, size = 2.2, fontface = "bold",
            family = phd_font_family, inherit.aes = FALSE)
```

**Dlaczego NIE cumsum:**
Reczne `cumsum()` nie uwzglednia brakujacych danych (fora bez postow w danym roku), co powoduje przesuniecie etykiet do zlych warstw.

### 7.4 Log-log (prawo Zipfa)

Uzycie: rozklady potegowe, prawo Zipfa.

```r
ggplot(data, aes(x = rank, y = value)) +
  geom_line(colour = "#507088", linewidth = 0.9) +
  scale_x_log10(
    breaks = trans_breaks("log10", function(x) 10^x),
    labels = trans_format("log10", math_format(10^.x))
  ) +
  scale_y_log10(...) +
  annotation_logticks(colour = grey_color, linewidth = 0.25) +
  theme_phd() +
  theme(
    panel.grid.major = element_line(colour = "grey92", linewidth = 0.25),
    axis.line = element_line(colour = line_color, linewidth = 0.3)
  )
```

### 7.5 Histogram z etykietami

Uzycie: rozklad wartosci ciaglej (np. aktywnosc uzytkownikow).

```r
# Biny obliczane recznie (zeby moc etykietowac)
binned <- data |>
  mutate(bin = cut(value, breaks = seq(0, max_val, step))) |>
  count(bin) |>
  mutate(bin_mid = ..., label = ifelse(n > 0, fmt_number(n), ""))

ggplot(binned, aes(x = bin_mid, y = n)) +
  geom_col(fill = "#507088", width = step - 0.5) +
  geom_text(aes(label = label), vjust = -0.3, size = 2, fontface = "bold", ...) +
  theme_phd() +
  theme(
    axis.text.y = element_blank(),        # wartosci na etykietach, os Y zbedna
    axis.line.x = element_line(colour = line_color, linewidth = 0.3)
  )
```

### 7.6 Stacked 100% z bezposrednimi etykietami

Uzycie: struktura procentowa kategorii wg grup (np. plec wg forum).

```r
# Dane: oblicz pct, cumsum, label_y (srodek segmentu)
stacked_data <- data |>
  mutate(category = factor(category, levels = c(...))) |>
  arrange(group, category) |>
  group_by(group) |>
  mutate(
    pct = n / sum(n),
    cum_pct = cumsum(pct),
    label_y = cum_pct - pct / 2,
    label_txt = percent(pct, 0.1)
  ) |> ungroup()

# Kolor tekstu: ciemny na jasnych, bialy na ciemnych
stacked_data <- stacked_data |> mutate(
  label_color = case_when(
    category == "jasna_kat" ~ text_color_dark,
    TRUE ~ text_color_light
  ),
  label_txt = ifelse(pct < 0.06, "", label_txt)  # ukryj w waskich segmentach
)

# Pozycje etykiet kategorii po lewej (z pierwszej grupy)
cat_labels <- stacked_data |>
  filter(group == first(group)) |>
  select(category, label_y) |>
  mutate(cat_color = ...)  # kolor etykiety = kolor wypelnienia
  # UWAGA: jesli kolor fill jest jasny (#bdbfc1), uzyj ciemniejszego (#8a8c8e)

ggplot(stacked_data, aes(x = group, y = pct, fill = category)) +
  geom_col(width = 0.75) +
  geom_text(aes(y = label_y, label = label_txt, colour = label_color),
            size = 2.5, fontface = "bold", family = phd_font_family) +
  scale_colour_identity() +
  scale_fill_manual(values = ...) +
  annotate("text", x = 0.4, y = cat_labels$label_y,
           label = cat_labels$category, colour = cat_labels$cat_color,
           hjust = 1, size = 2.5, fontface = "bold", family = phd_font_family) +
  coord_cartesian(clip = "off", xlim = c(0.5, NA)) +
  theme_phd() +
  theme(axis.text.y = element_blank(), plot.margin = margin(10, 10, 10, 30))
```

---

## 8. Formatowanie liczb

Polska typografia — spacja jako separator tysiecy:

```r
fmt_number <- function(x) {
  format(x, big.mark = " ", scientific = FALSE, trim = TRUE)
}
```

Uzycie:
- Na osiach: `scale_y_continuous(labels = fmt_number)`
- W etykietach: `paste0(fmt_number(n), " (", round(pct, 1), "%)")`
- Procenty: `scales::percent(pct, 0.1)` (z dokladnoscia 0.1%)

---

## 9. Mapowanie danych z bazy na etykiety

Dane z PostgreSQL uzywaja skrotow. Mapowanie odbywa sie przez `case_match()`:

```r
# Plec deklarowana (pole: users.gender)
case_match(plec_deklarowana,
  "M" ~ "Mezczyzna", "K" ~ "Kobieta",
  "brak danych" ~ "Brak danych", .default = "Inne")

# Plec predykowana (pole: users.pred_gender)
case_match(plec_predykowana,
  "M" ~ "Mezczyzna", "K" ~ "Kobieta", .default = "Nieokreslona")
```

**Zasada:** kategorie musza pasowac do named vectors kolorow (`gender_colors`, `forum_colors`). Jesli nie pasuja — slupki dostana domyslne kolory ggplot2.

---

## 10. Checklist przed zapisaniem wykresu

- [ ] `theme_phd()` jest uzyty jako bazowy motyw
- [ ] Brak legendy (dane etykietowane bezposrednio)
- [ ] Brak tytulow osi (`x = NULL, y = NULL`)
- [ ] Kolory z named vectora (`forum_colors` / `gender_colors`)
- [ ] Etykiety danych: `fontface = "bold"`, `family = phd_font_family`, `colour = text_color_dark`
- [ ] `save_plot_phd()` (dual export PDF + PNG)
- [ ] Tytul i subtitle w `labs()` (PNG je pokaze; PDF je usunie)
- [ ] Separator tysiecy: `fmt_number()` (NIE `comma()` ani `format()`)
- [ ] Kontrast tekstu: bialy na ciemnym, ciemny na jasnym/srednim
- [ ] Etykiety w waskich segmentach ukryte (prog ~6%)

---

## 11. Znane pulapki i rozwiazania

| Problem | Rozwiazanie |
|---------|------------|
| Etykiety area chart w zlych warstwach | Uzyj `ggplot_build()` zamiast recznego `cumsum()` |
| Etykiety linii nakladaja sie | `ggrepel::geom_text_repel(direction = "y")` |
| Etykieta poza prawym brzegiem | `coord_cartesian(clip = "off")` + `plot.margin` |
| Etykieta area chart ucieta z prawej | `max_label_x <- max(x) - 2` |
| Kolor `#bdbfc1` nieczytelny na bialym | Uzyj `#8a8c8e` dla etykiet POZA wykresem |
| Tekst bialy na zlotym (#d2a940) | Uzyj `text_color_dark` — zloto jest za jasne na bialy tekst |
| `fmt_number` nie dziala na osiach | Podaj jako `labels = fmt_number` (bez nawiasow) |
| Source Sans Pro niedostepny | Fallback na `sans` — brak blokujacego bledu |
| Slupki za szerokie (4 slupki) | `height_cm = 7` zamiast domyslnego 10 |

---

## 12. Zaleznosci R

```r
# Bazowe (ladowane w 00_setup_theme.R)
library(ggplot2)
library(dplyr)
library(scales)
library(grid)
library(ggtext)      # element_markdown() w caption
library(showtext)    # Google Fonts

# Dodatkowe (ladowane w skryptach wg potrzeby)
library(ggrepel)     # geom_text_repel() — wykresy liniowe wieloseryjne
library(readr)       # write_csv
library(writexl)     # write_xlsx
```

---

## 13. Struktura plikow

```
00_basic_corpus_statistics/
  scripts/
    00_setup_theme.R          # <-- CENTRALNY PLIK TEMATU
    01_fetch_data.R           # zapytania SQL, zmienne globalne
    02_general_stats.R        # wykresy 01-02 (slupkowe: posty, tokeny)
    03_temporal_stats.R       # wykresy 03-05 (liniowe, area)
    04_demographic_stats.R    # wykresy 06-10 (Zipf, histogram, plec)
    05_generate_markdown_report.R
  output/
    plots/                    # *.pdf + *.png (dual export)
    tables/                   # *.csv + *.xlsx (cache)
  run_all.R                   # runner calego pipeline
```
