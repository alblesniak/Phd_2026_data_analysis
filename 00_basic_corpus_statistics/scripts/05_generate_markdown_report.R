# =============================================================================
# 05_generate_markdown_report.R - Generate README.md with dynamic stats
# =============================================================================
# Depends on: all previous scripts (run in order)
# Produces: 00_basic_corpus_statistics/README.md
# =============================================================================

library(glue)

# --- Source setup (if not already loaded) ---
source(here::here("00_basic_corpus_statistics", "scripts", "00_setup_theme.R"))

# =============================================================================
# Build report content
# =============================================================================

# Forum summary table in markdown
forum_md_rows <- forum_summary |>
  mutate(row = glue(
    "| {forum} | {fmt_number(n_posts)} | {fmt_number(n_threads)} | ",
    "{fmt_number(n_users)} | {fmt_number(n_tokens)} | {procent_postow}% | ",
    "{procent_tokenow}% |"
  )) |>
  pull(row) |>
  paste(collapse = "\n")

totals_row <- glue(
  "| **RAZEM** | **{fmt_number(total_posts)}** | **{fmt_number(total_threads)}** | ",
  "**{fmt_number(total_users)}** | **{fmt_number(total_tokens)}** | **100%** | **100%** |"
)

# Posts per year table
posts_year_md <- posts_per_year |>
  filter(rok >= 2000, rok <= as.integer(format(Sys.Date(), "%Y"))) |>
  mutate(row = glue("| {rok} | {fmt_number(n_posts)} |")) |>
  pull(row) |>
  paste(collapse = "\n")

# Activity quantiles
activity_md <- activity_quantiles |>
  mutate(row = glue("| {Kwantyl} | {`Liczba postow`} |")) |>
  pull(row) |>
  paste(collapse = "\n")

# Gender declared
gender_decl_md <- gender_declared |>
  mutate(row = glue("| {plec_label} | {fmt_number(n_users)} | {procent}% |")) |>
  pull(row) |>
  paste(collapse = "\n")

# Gender predicted
gender_pred_md <- gender_predicted |>
  mutate(row = glue("| {plec_label} | {fmt_number(n_users)} | {procent}% |")) |>
  pull(row) |>
  paste(collapse = "\n")

# =============================================================================
# Compose markdown
# =============================================================================

report <- glue("
# Opisowa analiza statystyczna korpusu forow internetowych

> Raport wygenerowany automatycznie: {Sys.time()}

---

## 1. Informacje ogolne

Korpus sklada sie z danych zebranych z **{total_forums} for internetowych** o tematyce religijnej.
Lacznie baza zawiera **{fmt_number(total_posts)} postow**, **{fmt_number(total_tokens)} tokenow**
(po analizie morfologicznej LPMN), **{fmt_number(total_threads)} watkow** oraz
**{fmt_number(total_users)} uzytkownikow**.

### 1.1 Podsumowanie korpusu wg forum

| Forum | Posty | Watki | Uzytkownicy | Tokeny | % postow | % tokenow |
|---|---:|---:|---:|---:|---:|---:|
{forum_md_rows}
{totals_row}

### 1.2 Rozklad postow wg forum

![Rozklad postow wg forum](output/plots/01_posty_wg_forum.png)

### 1.3 Rozklad tokenow wg forum

![Rozklad tokenow wg forum](output/plots/02_tokeny_wg_forum.png)

---

## 2. Analiza czasowa (diachronia)

Zakres czasowy korpusu: **{corpus_min_date}** -- **{corpus_max_date}**.

### 2.1 Liczba postow w poszczegolnych latach

| Rok | Liczba postow |
|---:|---:|
{posts_year_md}

### 2.2 Dynamika postow (wykres liniowy)

![Liczba postow wg roku](output/plots/03_posty_wg_roku.png)

### 2.3 Dynamika postow wg forum

![Posty wg roku i forum](output/plots/04_posty_wg_roku_forum.png)

### 2.4 Wykres warstwowy

![Area chart](output/plots/05_posty_area_chart.png)

---

## 3. Analiza demograficzna uzytkownikow

### 3.1 Rozklad aktywnosci (prawo Zipfa)

Aktywnosc uzytkownikow wykazuje typowy rozklad potegowy (prawo Zipfa):
- **Top 1%** uzytkownikow ({fmt_number(top_1_pct_n)}) napisalo **{top_1_pct_share}%** wszystkich postow.
- **Top 10%** uzytkownikow ({fmt_number(top_10_pct_n)}) napisalo **{top_10_pct_share}%** wszystkich postow.

#### Kwantyle aktywnosci (posty na uzytkownika)

| Kwantyl | Liczba postow |
|---|---:|
{activity_md}

#### Wykres log-log (prawo Zipfa)

![Zipf](output/plots/06_zipf_aktywnosc.png)

#### Histogram aktywnosci

![Histogram](output/plots/07_histogram_aktywnosc.png)

### 3.2 Rozklad plci

#### Plec deklarowana (pole `users.gender`)

| Plec | Liczba | % |
|---|---:|---:|
{gender_decl_md}

![Plec deklarowana](output/plots/08_plec_deklarowana.png)

#### Plec predykowana (pole `users.pred_gender`)

| Plec | Liczba | % |
|---|---:|---:|
{gender_pred_md}

![Plec predykowana](output/plots/09_plec_predykowana.png)

#### Struktura plci wg forum

![Plec wg forum](output/plots/10_plec_wg_forum.png)

---

## 4. Pliki zrodlowe

Wszystkie skrypty analityczne znajduja sie w katalogu `scripts/`:

| Skrypt | Opis |
|---|---|
| `00_setup_theme.R` | Motyw graficzny i funkcje pomocnicze |
| `01_fetch_data.R` | Pobranie danych z bazy PostgreSQL |
| `02_general_stats.R` | Statystyki ogolne korpusu |
| `03_temporal_stats.R` | Analiza czasowa (diachronia) |
| `04_demographic_stats.R` | Demografia i aktywnosc uzytkownikow |
| `05_generate_markdown_report.R` | Generacja niniejszego raportu |

Wyniki zapisane sa w:
- `output/tables/` -- tabele CSV i Excel
- `output/plots/` -- wykresy PNG i PDF

---

*Raport wygenerowany na potrzeby rozprawy doktorskiej.*
")

# =============================================================================
# Write to file
# =============================================================================

readme_path <- here::here("00_basic_corpus_statistics", "README.md")
writeLines(report, readme_path)
message("Report saved to: ", readme_path)

message("\n=== ALL SCRIPTS COMPLETED SUCCESSFULLY ===")
