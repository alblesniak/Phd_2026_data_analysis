# Usuwanie danych po 31 grudnia 2025

## Szybki start

```bash
# 1. PODGLĄD (nie usuwa niczego)
Rscript database/preview_cleanup_post_2025_data.R

# 2. CLEANUP (usuwa dane)
Rscript database/cleanup_post_2025_data.R
```

---

## Kontekst

Po scrapowaniu forów w bazie znalazły się **posty napisane po 31 grudnia 2025**. Aby zamknąć analizę na konkretnej dacie (dla spójności badania), należy usunąć te dane.

**Czego dotyczy:** Data **napisania** posta (`posts.post_date`), nie data pobrania przez scraper.

---

## Statystyki (stan na 12 lutego 2026)

| Element                                               | Liczba          |
| ----------------------------------------------------- | --------------- |
| **Posty do usunięcia**                                | 4 989           |
| **Wątki całkowicie nowe** (wszystkie posty po cutoff) | 85 (1684 posty) |
| **Wątki częściowe** (wymagają aktualizacji)           | ~145            |
| **Użytkownicy do usunięcia**                          | 24              |
| **Post quotes** (CASCADE)                             | automatycznie   |
| **Post tokens** (CASCADE)                             | automatycznie   |

---

## Pliki

1. **`preview_cleanup_post_2025_data.R`** - podgląd bez usuwania
   - Wyświetla szczegółową analizę danych do usunięcia
   - Pokazuje przykłady wątków i użytkowników
   - Nic nie modyfikuje w bazie

2. **`cleanup_post_2025_data.R`** - właściwy cleanup
   - Usuwa posty po 31 grudnia 2025
   - Usuwa całkowicie nowe wątki (wszystkie posty po cutoff)
   - Aktualizuje metadane wątków częściowych
   - Usuwa użytkowników bez postów
   - Używa transakcji (ROLLBACK w razie błędu)
   - Wymaga potwierdzenia przed wykonaniem

3. **`docs/DATA_CLEANUP_2025_STRATEGY.md`** - pełna dokumentacja strategii
   - Szczegółowy opis algorytmu
   - Przypadki brzegowe
   - Weryfikacja po cleanup
   - Instrukcje backup

---

## Strategia (w skrócie)

### Co zostanie usunięte

✗ Posty napisane po 31.12.2025 23:59:59  
✗ Wątki, w których **wszystkie** posty są po tej dacie  
✗ Użytkownicy, którzy mają **tylko** posty po tej dacie  
✗ Powiązane `post_quotes` i `post_lpmn_tokens` (CASCADE)

### Co zostanie zachowane

✓ Wątki z postami przed cutoff (tylko nowe posty zostaną usunięte)  
✓ Użytkownicy z przynajmniej jednym postem przed cutoff  
✓ Posty bez `post_date` (NULL - nie można określić daty)

### Jak to działa

1. **DELETE posts** - usuwa posty po cutoff
2. **UPDATE threads** - przelicza `last_post_date`, `replies` dla wątków częściowych
3. **DELETE threads** - usuwa puste wątki (wszystkie posty zostały usunięte)
4. **DELETE users** - usuwa użytkowników bez żadnych postów

Wszystko w **transakcji** - w razie błędu: ROLLBACK.

---

## Krok po kroku

### 1. Podgląd (zalecane przed cleanup)

```bash
Rscript database/preview_cleanup_post_2025_data.R
```

Sprawdź wyniki:

- Ile postów zostanie usuniętych
- Jakie wątki całkowicie znikną
- Jakie wątki będą częściowo przycięte
- Którzy użytkownicy zostaną usunięci

### 2. Opcjonalnie: Backup

```bash
# Backup całej bazy (wymaga pg_dump)
pg_dump -h 192.168.18.117 -U neuronas -d neuronDB > backup_$(date +%Y%m%d).sql
```

### 3. Cleanup

```bash
Rscript database/cleanup_post_2025_data.R
```

Skrypt:

1. Wyświetli podsumowanie
2. Zapyta o potwierdzenie (Enter = kontynuuj, Ctrl+C = przerwij)
3. Wykona operacje w transakcji
4. Sprawdzi poprawność po wykonaniu

### 4. Weryfikacja

Po cleanup sprawdź:

```r
source("database/db_connection.R")

# Czy są posty po cutoff? (powinno być 0)
dbGetQuery(con, "SELECT COUNT(*) FROM posts WHERE post_date > '2025-12-31 23:59:59'")

# Zakres dat w bazie
dbGetQuery(con, "SELECT MIN(post_date) as min, MAX(post_date) as max FROM posts WHERE post_date IS NOT NULL")
```

### 5. Przelicz statystyki

Po cleanup należy przeliczyć moduły analityczne:

```bash
# Podstawowe statystyki korpusu
Rscript 00_basic_corpus_statistics/run_all.R

# Predykcja płci
Rscript 01_gender_prediction_improvement/run_all.R --overwrite-users-pred-gender
```

---

## Bezpieczeństwo

- ✓ **Transakcje** - wszystkie operacje atomowe (albo wszystko, albo nic)
- ✓ **ROLLBACK** w razie błędu - baza pozostanie niezmieniona
- ✓ **Potwierdzenie** - wymaga ręcznego Enter przed wykonaniem
- ✓ **Weryfikacja** - automatyczne sprawdzenie poprawności po cleanup
- ✓ **Integralnść** - CASCADE DELETE zadba o powiązane tabele

---

## FAQ

**Q: Czy mogę cofnąć cleanup?**  
A: Tylko jeśli zrobiłeś backup. Cleanup jest operacją nieodwracalną.

**Q: Co z użytkownikami, którzy dołączyli po 2025-12-31, ale mają starsze posty?**  
A: Zachowamy ich - `join_date` może być nieprecyzyjna. Ważniejsza jest data postów.

**Q: Co z postami bez `post_date`?**  
A: Zachowamy je - brak daty = brak pewności, że są po cutoff.

**Q: Dlaczego nie usuwać po prostu wszystkich danych z `created_at > 2026-01-01`?**  
A: Bo `created_at` to data **pobrania** przez scraper, nie data **napisania** posta. Post mógł być napisany w 2020, a pobrany w 2026.

---

**Autor:** GitHub Copilot  
**Data:** 12 lutego 2026
