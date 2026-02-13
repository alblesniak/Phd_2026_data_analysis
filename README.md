# Phd_2026_data_analysis

Repozytorium z analizami danych do projektu doktorskiego.

## Struktura katalogów

- `00_basic_corpus_statistics/` – statystyki opisowe korpusu.
- `01_gender_prediction_improvement/` – pipeline ulepszonej predykcji płci gramatycznej.
- `database/` – współdzielone skrypty dostępu do bazy danych, wykorzystywane przez wszystkie moduły analiz.
- `docs/` – dokumentacja projektu.

## Wspólne łączenie z bazą danych

Wszystkie skrypty, które wymagają połączenia z PostgreSQL, powinny ładować:

```r
source(here::here("database", "db_connection.R"))

with_db({
  dane <- DBI::dbGetQuery(con, "SELECT 1")
})
```

Dzięki temu logika połączenia jest utrzymywana w jednym miejscu, a połączenie jest zamykane automatycznie (również przy błędzie).
