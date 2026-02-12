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
  mutate(row = glue("| {Kwantyl} | {`Liczba postów`} |")) |>
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
# Opisowa analiza statystyczna korpusu forów internetowych

> Raport wygenerowany automatycznie: {Sys.time()}

---

## 1. Informacje ogólne

Korpus składa się z danych zebranych z **{total_forums} forów internetowych** o tematyce religijnej.
Łącznie baza zawiera **{fmt_number(total_posts)} postów**, **{fmt_number(total_tokens)} tokenów**
(po analizie morfologicznej LPMN), **{fmt_number(total_threads)} wątków** oraz
**{fmt_number(total_users)} użytkowników**.

### 1.1 Podsumowanie korpusu wg forum

| Forum | Posty | Wątki | Użytkownicy | Tokeny | % postów | % tokenów |
|---|---:|---:|---:|---:|---:|---:|
{forum_md_rows}
{totals_row}

### 1.2 Rozkład postów wg forum

![Rozkład postów wg forum](output/plots/01_posty_wg_forum.png)

### 1.3 Rozkład tokenów wg forum

![Rozkład tokenów wg forum](output/plots/02_tokeny_wg_forum.png)

---

## 2. Analiza czasowa (diachronia)

Zakres czasowy korpusu: **{corpus_min_date}** -- **{corpus_max_date}**.

### 2.1 Liczba postów w poszczególnych latach

| Rok | Liczba postów |
|---:|---:|
{posts_year_md}

### 2.2 Dynamika postów (wykres liniowy)

![Liczba postów wg roku](output/plots/03_posty_wg_roku.png)

### 2.3 Dynamika postów wg forum

![Posty wg roku i forum](output/plots/04_posty_wg_roku_forum.png)

### 2.4 Wykres warstwowy

![Area chart](output/plots/05_posty_area_chart.png)

---

## 3. Analiza demograficzna użytkowników

### 3.1 Rozkład aktywności (prawo Zipfa)

Aktywność użytkowników wykazuje typowy rozkład potęgowy (prawo Zipfa):
- **Top 1%** użytkowników ({fmt_number(top_1_pct_n)}) napisało **{top_1_pct_share}%** wszystkich postów.
- **Top 10%** użytkowników ({fmt_number(top_10_pct_n)}) napisało **{top_10_pct_share}%** wszystkich postów.

#### Kwantyle aktywności (posty na użytkownika)

| Kwantyl | Liczba postów |
|---|---:|
{activity_md}

#### Wykres log-log (prawo Zipfa)

![Zipf](output/plots/06_zipf_aktywnosc.png)

#### Histogram aktywności

![Histogram](output/plots/07_histogram_aktywnosc.png)

### 3.2 Rozkład płci

#### Płeć deklarowana (pole `users.gender`)

| Płeć | Liczba | % |
|---|---:|---:|
{gender_decl_md}

![Płeć deklarowana](output/plots/08_plec_deklarowana.png)

#### Płeć predykowana (pole `users.pred_gender`)

| Płeć | Liczba | % |
|---|---:|---:|
{gender_pred_md}

![Płeć predykowana](output/plots/09_plec_predykowana.png)

#### Struktura płci wg forum

![Płeć wg forum](output/plots/10_plec_wg_forum.png)

---

## 4. Pliki źródłowe

Wszystkie skrypty analityczne znajdują się w katalogu `scripts/`:

| Skrypt | Opis |
|---|---|
| `00_setup_theme.R` | Motyw graficzny i funkcje pomocnicze |
| `01_fetch_data.R` | Pobranie danych z bazy PostgreSQL |
| `02_general_stats.R` | Statystyki ogólne korpusu |
| `03_temporal_stats.R` | Analiza czasowa (diachronia) |
| `04_demographic_stats.R` | Demografia i aktywność użytkowników |
| `05_generate_markdown_report.R` | Generacja niniejszego raportu |

Wyniki zapisane są w:
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
