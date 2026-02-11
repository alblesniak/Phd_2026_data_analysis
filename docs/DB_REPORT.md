# Raport: struktura bazy danych (PostgreSQL) – forums_scraper

Data raportu: 2026-02-10 (bez strefy czasowej, precyzja do sekund)  
Zakres: **PostgreSQL**, tabele: `forums`, `sections`, `threads`, `users`, `posts`, `post_quotes`, `post_lpmn_tokens`, `stopwords`

> Ten raport opisuje jak dane są zorganizowane, jakie mają typy, jak są wypełniane przez scrapery i pipeline, oraz jak interpretować kolumny.

---

## 1) Kontekst i założenia projektu

Projekt `forums_scraper` scrapuje fora (głównie phpBB / podobne silniki) i zapisuje wyniki w relacyjnej bazie Postgres.

Model logiczny danych:

- **forum** (źródło / domena / „instancja spidera”)
  - ma wiele **sekcji**
    - ma wiele **wątków**
      - ma wiele **postów**
        - post może zawierać **cytowania** innych użytkowników (relacje w `post_quotes`)
        - post może mieć **tokeny LPMN** (analiza morfologiczna w `post_lpmn_tokens`)
- **stopwords** – osobna tabela słownikowa (stop-słowa do analizy tekstów)

Ważne cechy:

- Nazwy użytkowników są przechowywane w **oryginalnej postaci** (bez anonimizacji). Każdy użytkownik jest powiązany z forum (`users.forum_id`).
- `posts.content` przechowuje treść posta **bez cytatów**; relacje cytowań są w `post_quotes`.
- `posts.content_urls` przechowuje listę URL-i wykrytych w treści (po czyszczeniu).

---

## 2) Konwencje formatowania danych

### 2.1 Daty i czasy

W tabelach występują dwa rodzaje „czasów”:

1. `created_at`, `updated_at` – znaczniki czasu **zapisu do bazy**

- Typ: `timestamp(0) without time zone` (sekundy, bez TZ)
- Domyślna wartość: `LOCALTIMESTAMP(0)`

2. Daty pochodzące z forów (np. `posts.post_date`, `threads.last_post_date`, `users.join_date`)

- Typ: `timestamp(0) without time zone` (sekundy, bez TZ)
- Parser normalizuje wejście do postaci `YYYY-MM-DD HH:MM:SS`, a następnie zapisuje jako TIMESTAMP.
- Jeśli parser nie potrafi znormalizować daty, pipeline loguje przypadek do TSV, a w DB trafia `NULL`.

### 2.2 Nazwy użytkowników

Nazwy użytkowników są przechowywane w formie oryginalnej (bez anonimizacji).

Każdy użytkownik jest powiązany z konkretnym forum (`users.forum_id`), więc ten sam nick na dwóch różnych forach to dwa osobne rekordy w tabeli `users` (UNIQUE na `(forum_id, username)`).

---

## 3) Spójność relacji i klucze

### 3.1 Klucze główne

Wszystkie tabele mają `id bigint` jako PK.

### 3.2 Relacje

- `sections.forum_id` → `forums.id` (logicznie; w DB może nie być FK)
- `threads.section_id` → `sections.id` (logicznie; w DB może nie być FK)
- `posts.thread_id` → `threads.id` (logicznie; w DB może nie być FK)
- `posts.user_id` → `users.id` (logicznie; w DB może nie być FK)
- `users.forum_id` → `forums.id` (**FK istnieje**, ON DELETE CASCADE)
- `post_quotes.post_id` → `posts.id` (**FK istnieje**, ON DELETE CASCADE)
- `post_lpmn_tokens.post_id` → `posts.id` (**FK istnieje**, ON DELETE CASCADE)

### 3.3 Unikalność

- `forums.spider_name` – UNIQUE (`forums_spider_name_key`)
- `sections.url` – UNIQUE (`sections_url_key`)
- `threads.url` – UNIQUE (`threads_url_key`)
- `users(forum_id, username)` – UNIQUE (`users_forum_id_username_key`)
- `posts(thread_id, post_number)` – UNIQUE (`posts_thread_id_post_number_key`)
- `post_quotes(post_id, from_user, to_user)` – UNIQUE (indeks `idx_post_quotes_unique`)
- `post_lpmn_tokens(post_id, token_order)` – UNIQUE (`post_lpmn_tokens_post_id_token_order_key`)
- `stopwords.lemma` – PRIMARY KEY (`stopwords_pkey`)

### 3.4 Indeksy (najważniejsze)

- `posts`: `idx_posts_thread_id`, `idx_posts_user_id`, `idx_posts_created_at` + UNIQUE `posts_thread_id_post_number_key`
- `post_quotes`: `idx_post_quotes_post_id` + UNIQUE `idx_post_quotes_unique`
- `post_lpmn_tokens`: `idx_post_lpmn_tokens_post_id` + UNIQUE `post_lpmn_tokens_post_id_token_order_key`
- `stopwords`: `idx_stopwords_category`, `idx_stopwords_active`

---

## 4) Tabela: `forums`

### 4.1 Rola

Reprezentuje źródło danych na poziomie spidera/serwisu.

### 4.2 Kolumny

- `id` (`bigint`, PK)
- `spider_name` (`text`, NOT NULL, UNIQUE)
- `title` (`text`, NULL)
- `created_at` (`timestamp(0) without time zone`, NOT NULL, default `LOCALTIMESTAMP(0)`)
- `updated_at` (`timestamp(0) without time zone`, NOT NULL, default `LOCALTIMESTAMP(0)`)

---

## 5) Tabela: `sections`

### 5.1 Rola

Sekcje/działy w obrębie forum (np. `viewforum.php?f=<id>`).

### 5.2 Kolumny

- `id` (`bigint`, PK)
- `forum_id` (`bigint`, NULL)
- `title` (`text`, NULL)
- `url` (`text`, NOT NULL, UNIQUE)
- `created_at` / `updated_at` (`timestamp(0) without time zone`, NOT NULL)

---

## 6) Tabela: `threads`

### 6.1 Rola

Wątki/dyskusje w sekcji (np. `viewtopic.php?...&t=<id>`).

### 6.2 Kolumny

- `id` (`bigint`, PK)
- `section_id` (`bigint`, NOT NULL)
- `title` (`text`, NULL)
- `url` (`text`, NOT NULL, UNIQUE)
- `author` (`text`, NULL)
- `replies` (`integer`, NULL)
- `views` (`integer`, NULL)
- `last_post_date` (`timestamp(0) without time zone`, NULL)
- `last_post_author` (`text`, NULL)
- `created_at` / `updated_at` (`timestamp(0) without time zone`, NOT NULL)

### 6.3 Przykładowe dane

```json
{
  "id": 1,
  "section_id": 45,
  "title": "Wątpliwości",
  "url": "https://zchrystusem.pl/viewtopic.php?t=17448",
  "author": "Człowiek1",
  "replies": 5,
  "views": 0,
  "last_post_date": "2026-01-21 12:36:00",
  "last_post_author": "Człowiek1",
  "created_at": "2026-02-03 14:55:52",
  "updated_at": "2026-02-03 14:55:52"
}
```

(W JSON `last_post_date` jest tekstową reprezentacją TIMESTAMP.)

---

## 7) Tabela: `users`

### 7.1 Rola

Słownik użytkowników widzianych w postach, powiązanych z konkretnym forum.

### 7.2 Kolumny

- `id` (`bigint`, PK)
- `forum_id` (`bigint`, NOT NULL, FK → `forums.id` ON DELETE CASCADE)
- `username` (`text`, NOT NULL; UNIQUE razem z `forum_id`)
- `join_date` (`timestamp(0) without time zone`, NULL)
- `posts_count` (`integer`, NULL)
- `religion` (`text`, NULL)
- `gender` (`text`, NULL)
- `localization` (`text`, NULL)
- `created_at` / `updated_at` (`timestamp(0) without time zone`, NOT NULL)
- `pred_gender` (`text`, NULL; przewidywana płeć z klasyfikatora)

### 7.3 Przykładowe dane

```json
{
  "id": 568084,
  "forum_id": 3,
  "username": "Caliah",
  "join_date": "2008-12-28 17:13:00",
  "posts_count": 3,
  "religion": "katolik",
  "gender": "K",
  "localization": "Lublin",
  "created_at": "2026-02-03 23:58:41",
  "updated_at": "2026-02-03 23:58:41",
  "pred_gender": "unknown"
}
```

---

## 8) Tabela: `posts`

### 8.1 Rola

Główna tabela treści: pojedynczy post w ramach wątku.

### 8.2 Kolumny

- `id` (`bigint`, PK)
- `thread_id` (`bigint`, NULL; docelowo `threads.id`)
- `user_id` (`bigint`, NULL; `users.id`)
- `post_number` (`integer`, NULL)
- `content` (`text`, NULL; bez cytatów)
- `content_urls` (`jsonb`, NULL)
- `post_date` (`timestamp(0) without time zone`, NULL)
- `url` (`text`, NULL)
- `username` (`text`, NULL)
- `created_at` / `updated_at` (`timestamp(0) without time zone`, NOT NULL)

### 8.3 Przykładowe dane

```json
{
  "id": 1,
  "thread_id": 109,
  "user_id": 1,
  "post_number": 735,
  "content": "Jak zauważyliście mamy na forum nowy styl, testowy3. Mi się on nawet podoba...",
  "content_urls": [],
  "post_date": "2015-10-18 17:11:00",
  "url": "https://zchrystusem.pl/viewtopic.php?p=735#p735",
  "username": "Czernin",
  "created_at": "2026-02-03 14:56:04",
  "updated_at": "2026-02-03 14:56:04"
}
```

---

## 9) Tabela: `post_quotes`

### 9.1 Rola

Relacje cytowania: kto cytuje kogo w obrębie posta.

### 9.2 Kolumny

- `id` (`bigint`, PK)
- `post_id` (`bigint`, NOT NULL) – FK do `posts.id` (ON DELETE CASCADE)
- `from_user` (`text`, NULL)
- `to_user` (`text`, NULL)
- `created_at` (`timestamp(0) without time zone`, NOT NULL)

---

## 10) Tabela: `post_lpmn_tokens`

### 10.1 Rola

Tokeny językowe (LPMN) przypisane do postów. Każdy token to jedno słowo/znak przestankowy z treści posta, wzbogacone o lematyzację i tagi morfologiczne z analizy LPMN.

### 10.2 Kolumny

- `id` (`bigint`, PK)
- `post_id` (`bigint`, NOT NULL, FK → `posts.id` ON DELETE CASCADE)
- `token_order` (`integer`, NOT NULL) – pozycja tokenu w treści posta (globalny numer)
- `sentence_order` (`integer`, NULL) – numer zdania
- `orth` (`text`, NOT NULL) – forma ortograficzna (tekst oryginalny)
- `lemma` (`text`, NULL) – lemat (forma bazowa)
- `ctag` (`text`, NULL) – tag morfologiczny (np. `subst:sg:nom:m1`)
- `lexemes_json` (`text`, NULL) – pełna lista leksemów z LPMN (JSON jako tekst)
- `created_at` (`timestamp(0) without time zone`, NOT NULL)

### 10.3 Unikalnie

- UNIQUE `(post_id, token_order)`
- Indeks: `idx_post_lpmn_tokens_post_id`

### 10.4 Przykładowe dane

```json
{
  "id": 153947735,
  "post_id": 1503459,
  "token_order": 67,
  "sentence_order": 5,
  "orth": "istnienie",
  "lemma": "istnieć",
  "ctag": "ger:sg:nom:n:imperf:aff",
  "lexemes_json": "[{\"base\": \"istnieć\", \"ctag\": \"ger:sg:nom:n:imperf:aff\", \"disamb\": \"1\"}]",
  "created_at": "2026-02-07 02:37:25"
}
```

---

## 11) Tabela: `stopwords`

### 11.1 Rola

Słownik stop-słów (lematyzowanych) używany w analizie tekstów. Importowany z pliku `analysis/stopwords/stopwords_pl.py` skryptem `scripts/setup_stopwords_db.py`.

### 11.2 Kolumny

- `lemma` (`text`, PRIMARY KEY)
- `category` (`text`, NOT NULL) – kategoria: `CORE`, `EXTENDED`, `DOMAIN`, `FORUM`
- `is_active` (`boolean`, NULL, default `true`) – czy stop-słowo jest aktywne
- `source` (`text`, NULL, default `'manual'`) – źródło importu (np. `manual_import`)
- `created_at` (`timestamp`, NULL, default `CURRENT_TIMESTAMP`)

### 11.3 Indeksy

- `idx_stopwords_category` (na `category`)
- `idx_stopwords_active` (na `is_active`)

### 11.4 Przykładowe dane

```json
{
  "lemma": "swój",
  "category": "CORE",
  "is_active": true,
  "source": "manual_import",
  "created_at": "2026-02-07 16:39:48"
}
```

---

## 12) Statystyki (stan na 2026-02-10)

| Tabela             | Liczba rekordów |
| ------------------ | --------------: |
| `forums`           |               4 |
| `sections`         |             130 |
| `threads`          |          38 841 |
| `users`            |          21 609 |
| `posts`            |       1 662 942 |
| `post_quotes`      |         397 987 |
| `post_lpmn_tokens` |     176 108 499 |
| `stopwords`        |           1 160 |

Fora w bazie:

|  id | spider_name       | title           |
| --: | ----------------- | --------------- |
|   1 | `z_chrystusem`    | Z Chrystusem    |
|   3 | `radio_katolik`   | radiokatolik.pl |
|   4 | `dolina_modlitwy` | Dolina Modlitwy |
|   7 | `wiara`           | wiara.pl        |

---

## 13) Przykładowe zapytania

### 13.1 Posty w wątku wraz z metadanymi wątku i sekcji

```sql
SELECT
  p.id AS post_id,
  p.post_number,
  to_char(p.post_date, 'YYYY-MM-DD HH24:MI:SS') AS post_date,
  p.username,
  t.title AS thread_title,
  s.url AS section_url,
  f.title AS forum_title
FROM posts p
JOIN threads t ON t.id = p.thread_id
JOIN sections s ON s.id = t.section_id
JOIN forums f ON f.id = s.forum_id
ORDER BY p.id DESC
LIMIT 100;
```

---

## 14) Źródła (implementacja)

- DDL i zapisy do Postgresa: `pipelines/database.py`
- Modele itemów: `items.py`
- Ekstrakcja treści/URL/cytowań: `utils/` (pakiet: `html.py`, `dates.py`, `text.py`) + logika w `spiders/*.py`
- Tokenizacja LPMN: `scripts/lpmn/lpmn_batches.py`, `db/schema.py`
- Stop-słowa: `scripts/setup_stopwords_db.py`, `analysis/stopwords/stopwords_pl.py`

---

## 15) ETL: jak dane trafiają do DB (ekstrakcja + normalizacja + mapowanie)

Poniżej opis „od strony praktycznej”: skąd biorą się wartości poszczególnych kolumn i jakie są ważne heurystyki.

### 15.1 Przepływ danych (wysoki poziom)

1. **Spider** pobiera HTML i tworzy itemy (`ForumItem`, `ForumSectionItem`, `ForumThreadItem`, `ForumUserItem`, `ForumPostItem`).
2. **Utils** pomaga w normalizacji treści:
   - usuwanie cytatów z HTML (`strip_quotes_from_html`),
   - czyszczenie treści posta do tekstu (`clean_post_content` / `clean_dolina_modlitwy_post_content`),
   - ekstrakcja URL-i z treści (`extract_urls_from_html`),
   - wykrywanie cytowanych użytkowników (`extract_quoted_usernames`),
