# Strategia usuwania danych po 31 grudnia 2025

**Data:** 12 lutego 2026  
**Cel:** Zamknięcie analizy danych na 31 grudnia 2025 dla zachowania spójności czasowej

---

## 1. Kontekst problemu

Część danych w bazie została **napisana** (nie pobrana, ale faktycznie opublikowana na forach) po 1 stycznia 2026. Aby zapewnić spójność analizy i zamknąć badanie na konkretnej dacie cutoff (31 grudnia 2025, 23:59:59), należy usunąć te dane.

### 1.1 Kluczowe rozróżnienie dat

W bazie występują **dwa typy dat**:

- **`created_at` / `updated_at`** - daty zapisu do bazy (kiedy scraper pobrał dane)
- **`post_date`** (w tabeli `posts`) - data faktycznego napisania posta na forum
- **`last_post_date`** (w tabeli `threads`) - data ostatniego posta w wątku
- **`join_date`** (w tabeli `users`) - data dołączenia użytkownika do forum

**Interesuje nas `post_date`** - chcemy usunąć posty napisane po 31 grudnia 2025.

---

## 2. Analiza danych do usunięcia

Na podstawie zapytania z 12 lutego 2026:

| Kategoria                                             | Liczba              |
| ----------------------------------------------------- | ------------------- |
| **Posty napisane po 2025-12-31**                      | 4 989               |
| **Wątki z ostatnim postem po 2025-12-31**             | 230                 |
| **Użytkownicy dołączeni po 2025-12-31**               | 22                  |
| **Wątki CAŁKOWICIE nowe** (wszystkie posty po cutoff) | 85 (1 684 posty)    |
| **Użytkownicy z pierwszym postem po 2025-12-31**      | 24                  |
| **Post quotes** (powiązane z postami po cutoff)       | ~nieznana (CASCADE) |
| **Post LPMN tokens** (powiązane z postami po cutoff)  | ~nieznana (CASCADE) |

---

## 3. Strategia usuwania (zachowanie integralności)

### 3.1 Kluczowe zasady

1. **Nie usuwamy pojedynczych rekordów bez konsekwencji**
   - Jeśli usuwamy post, musimy zaktualizować metadane wątku
   - Jeśli usuwamy wszystkie posty użytkownika, możemy usunąć użytkownika

2. **Respektujemy powiązania CASCADE**
   - `post_quotes` i `post_lpmn_tokens` mają `ON DELETE CASCADE` - usuną się automatycznie
   - `users` ma `ON DELETE CASCADE` z `forums` - ale nie usuwamy forów

3. **Minimalizujemy utratę danych**
   - Wątki częściowe (posty przed i po cutoff) - zachowujemy partie przed cutoff
   - Użytkowników z postami przed cutoff - zachowujemy (nawet jeśli dołączyli później)

### 3.2 Algorytm krok po kroku

#### Krok 1: **Identyfikacja**

- Znajdź wątki całkowicie nowe (wszystkie posty po cutoff) → do usunięcia
- Znajdź wątki częściowe (posty przed i po cutoff) → metadane do aktualizacji
- Znajdź użytkowników bez postów przed cutoff → do usunięcia

#### Krok 2: **Usunięcie postów**

```sql
DELETE FROM posts WHERE post_date > '2025-12-31 23:59:59';
```

- Usunie 4 989 postów
- Automatycznie usunie powiązane `post_quotes` i `post_lpmn_tokens` (CASCADE)

#### Krok 3: **Aktualizacja metadanych wątków**

```sql
UPDATE threads t
SET
  last_post_date = (SELECT MAX(post_date) FROM posts WHERE thread_id = t.id),
  replies = (SELECT COUNT(*) - 1 FROM posts WHERE thread_id = t.id),
  last_post_author = (SELECT username FROM posts WHERE thread_id = t.id ORDER BY post_date DESC LIMIT 1)
WHERE EXISTS (SELECT 1 FROM posts WHERE thread_id = t.id);
```

- Zaktualizuje ~145 wątków częściowych

#### Krok 4: **Usunięcie pustych wątków**

```sql
DELETE FROM threads t
WHERE NOT EXISTS (SELECT 1 FROM posts p WHERE p.thread_id = t.id);
```

- Usunie ~85 wątków całkowicie nowych (wszystkie ich posty zostały usunięte)

#### Krok 5: **Usunięcie użytkowników bez postów**

```sql
DELETE FROM users u
WHERE NOT EXISTS (SELECT 1 FROM posts p WHERE p.user_id = u.id);
```

- Usunie ~24 użytkowników, którzy mieli tylko posty po cutoff

---

## 4. Przypadki brzegowe i obsługa błędów

### 4.1 Co z użytkownikami, którzy dołączyli po 2025-12-31, ale mają starsze posty?

**Decyzja:** Zachowujemy takich użytkowników.

**Uzasadnienie:** `join_date` może być:

- Nieprecyzyjna (pobrana z profilu użytkownika, który założył konto dawno temu)
- NULL (jeśli nie udało się sparsować)

Ważniejszy jest faktyczny `post_date` - jeśli użytkownik ma posty przed cutoff, zachowujemy go.

### 4.2 Co z wątkami, których `last_post_date` jest po cutoff, ale nie mają żadnych postów po cutoff?

**Decyzja:** Takie przypadki nie powinny wystąpić, ale jeśli wystąpią, zaktualizujemy `last_post_date`.

**Zabezpieczenie:** Aktualizacja metadanych wątków w kroku 3 przeliczy wszystko na podstawie rzeczywistych postów.

### 4.3 Co z postami bez `post_date` (NULL)?

**Decyzja:** Zachowujemy je - brak daty oznacza, że nie da się określić, kiedy powstały.

**Uzasadnienie:** Usuwanie tylko potwierdzone przypadki po cutoff. Jeśli `post_date IS NULL`, nie możemy stwierdzić, że post jest po 2025-12-31.

---

## 5. Weryfikacja po usunięciu

Po wykonaniu skryptu sprawdzamy:

1. **Czy wszystkie posty po cutoff zostały usunięte:**

   ```sql
   SELECT COUNT(*) FROM posts WHERE post_date > '2025-12-31 23:59:59';
   -- Powinno zwrócić: 0
   ```

2. **Czy nie ma wątków z `last_post_date` po cutoff:**

   ```sql
   SELECT COUNT(*) FROM threads WHERE last_post_date > '2025-12-31 23:59:59';
   -- Powinno zwrócić: 0
   ```

3. **Czy nie ma użytkowników bez postów:**

   ```sql
   SELECT COUNT(*) FROM users u
   WHERE NOT EXISTS (SELECT 1 FROM posts p WHERE p.user_id = u.id);
   -- Powinno zwrócić: 0
   ```

4. **Sprawdzenie zakresu dat w bazie:**
   ```sql
   SELECT
     MIN(post_date) as earliest_post,
     MAX(post_date) as latest_post,
     COUNT(*) as total_posts
   FROM posts
   WHERE post_date IS NOT NULL;
   -- latest_post powinno być <= 2025-12-31 23:59:59
   ```

---

## 6. Użycie skryptu

### 6.1 Uruchomienie

```bash
Rscript database/cleanup_post_2025_data.R
```

### 6.2 Bezpieczeństwo

- Skrypt używa **transakcji** - wszystkie zmiany są atomowe
- W przypadku błędu wykonywany jest **ROLLBACK** - baza pozostaje niezmieniona
- Skrypt wymaga **potwierdzenia** przed rozpoczęciem usuwania (readline)

### 6.3 Co robi skrypt (kolejność operacji)

1. **Analiza** - podsumowanie danych do usunięcia
2. **Potwierdzenie** - użytkownik musi nacisnąć Enter
3. **BEGIN TRANSACTION** - rozpoczęcie transakcji
4. **DELETE posts** - usunięcie postów po cutoff
5. **UPDATE threads** - aktualizacja metadanych wątków
6. **DELETE threads** - usunięcie pustych wątków
7. **DELETE users** - usunięcie użytkowników bez postów
8. **COMMIT** - zatwierdzenie zmian
9. **Weryfikacja** - sprawdzenie poprawności operacji

---

## 7. Wpływ na istniejące analizy

### 7.1 Moduły wymagające ponownego uruchomienia

Po wykonaniu cleanup należy przeliczyć:

1. **`00_basic_corpus_statistics/`**
   - Wszystkie statystyki bazują na postach, wątkach, użytkownikach
   - Uruchom: `Rscript 00_basic_corpus_statistics/run_all.R`

2. **`01_gender_prediction_improvement/`**
   - Użytkownicy mogą zostać usunięci
   - Uruchom: `Rscript 01_gender_prediction_improvement/run_all.R --overwrite-users-pred-gender`

3. **Inne moduły analityczne** (jeśli istnieją)
   - Sprawdź, czy bazują na danych z tabel `posts`, `threads`, `users`

### 7.2 Archiwum (`archive/`)

- **Nie wymaga przeliczenia** - to stare eksperymenty/testy
- Pliki `.rds` mogą być nieaktualne, ale to oczekiwane

---

## 8. Podsumowanie

### 8.1 Co zostanie usunięte

- ✓ **4 989 postów** napisanych po 31 grudnia 2025
- ✓ **85 wątków** całkowicie nowych (wszystkie posty po cutoff)
- ✓ **24 użytkowników** z pierwszym postem po cutoff
- ✓ **Wszystkie powiązane `post_quotes` i `post_lpmn_tokens`** (CASCADE)

### 8.2 Co zostanie zachowane

- ✓ **Wątki częściowe** - posty przed cutoff pozostaną, metadane zostaną zaktualizowane
- ✓ **Użytkownicy z postami przed cutoff** - nawet jeśli dołączyli po 2025-12-31
- ✓ **Posty bez `post_date`** - brak daty = brak pewności, że są po cutoff

### 8.3 Gwarancje spójności

- ✓ **Transakcyjność** - albo wszystko, albo nic (ROLLBACK w przypadku błędu)
- ✓ **Integralność referencyjna** - CASCADE DELETE zadba o powiązane tabele
- ✓ **Weryfikacja** - automatyczne sprawdzenie poprawności po operacji

---

## 9. Backup przed cleanup (opcjonalnie)

Jeśli chcesz mieć pewność, że możesz przywrócić dane, zrób backup przed uruchomieniem skryptu:

```bash
# Eksport całej bazy (wymaga dostępu do pg_dump)
pg_dump -h 192.168.18.117 -U neuronas -d neuronDB > backup_before_cleanup_$(date +%Y%m%d).sql

# Lub eksport tylko tabel dotyczących postów
pg_dump -h 192.168.18.117 -U neuronas -d neuronDB -t posts -t threads -t users -t post_quotes -t post_lpmn_tokens > backup_posts_before_cleanup_$(date +%Y%m%d).sql
```

---

**Autor:** GitHub Copilot  
**Data dokumentu:** 12 lutego 2026
