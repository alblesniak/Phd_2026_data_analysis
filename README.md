# Phd_2026_data_analysis

Repozytorium z analizami danych do projektu doktorskiego.

## Struktura katalogów

- `00_basic_corpus_statistics/` – statystyki opisowe korpusu.
- `01_gender_prediction_improvement/` – pipeline ulepszonej predykcji płci gramatycznej.
- `shared/database/` – współdzielone skrypty dostępu do bazy danych, wykorzystywane przez wszystkie moduły analiz.
- `docs/` – dokumentacja projektu.

## Wspólne łączenie z bazą danych

Wszystkie skrypty, które wymagają połączenia z PostgreSQL, powinny ładować:

```r
source(here::here("shared", "database", "db_connection.R"))
```

Dzięki temu logika połączenia jest utrzymywana w jednym miejscu i łatwo skalowalna dla kolejnych modułów (`03_*`, `04_*`, itd.).
