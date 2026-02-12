# Stopwords dla polskich katolickich forów internetowych

Moduł stopwords opracowany na podstawie analizy **1.66M postów** i **176M tokenów** z forów:
- wiara.pl (968K postów)
- radiokatolik.pl (380K postów)
- z-chrystusem.pl (281K postów)
- dolina-modlitwy.pl (34K postów)

## Statystyki

| Warstwa | Słów (PL) | Słów (ASCII) | Opis |
|---------|-----------|--------------|------|
| CORE | 308 | 423 | Podstawowe słowa funkcyjne (zawsze usuwane) |
| EXTENDED | 523 | 718 | Rozszerzony zestaw ogólnych stopwords |
| DOMAIN | 180 | 236 | Słownictwo religijne/kościelne |
| FORUM | 102 | 138 | Metatekst forumowy |
| **ALL** | **803** | **1089** | Wszystkie powyższe |

### Efektywność filtrowania

Na próbce 50,000 tokenów:

| Metoda | Redukcja |
|--------|----------|
| Tylko CTAG (prep, conj, qub...) | 41.6% |
| Tylko ALL_STOPWORDS (lista) | 45.8% |
| **CTAG + lista (łącznie)** | **65.1%** |

## Użycie

### Import modułu

```python
from analysis.stopwords import (
    # Zestawy słów
    CORE_STOPWORDS,          # podstawowe (z polskimi znakami)
    CORE_STOPWORDS_ASCII,    # podstawowe + warianty ASCII
    EXTENDED_STOPWORDS,
    EXTENDED_STOPWORDS_ASCII,
    DOMAIN_STOPWORDS,        # religijne
    DOMAIN_STOPWORDS_ASCII,
    FORUM_STOPWORDS,         # metatekst forumowy
    FORUM_STOPWORDS_ASCII,
    ALL_STOPWORDS,           # wszystkie
    ALL_STOPWORDS_ASCII,
    
    # Tagi morfologiczne
    STOPWORD_CTAGS,          # tagi do filtrowania (interp, qub, conj, prep:*)
    STOPWORD_CTAG_PREFIXES,  # prefiksy tagów
    
    # Funkcje pomocnicze
    is_stopword,             # sprawdź czy słowo jest stopwordem
    is_stopword_by_ctag,     # sprawdź tag morfologiczny
    normalize_token,         # ASCII → polski
    filter_tokens,           # filtruj listę tokenów
)
```

### Sprawdzanie pojedynczych słów

```python
from analysis.stopwords import is_stopword, is_stopword_by_ctag

# Sprawdź słowo
is_stopword('jednak')  # True
is_stopword('Bóg', stopword_set=CORE_STOPWORDS_ASCII)  # False (nie w CORE)
is_stopword('Bóg', stopword_set=DOMAIN_STOPWORDS_ASCII)  # True

# Sprawdź tag morfologiczny
is_stopword_by_ctag('prep:loc')  # True (przyimek)
is_stopword_by_ctag('subst:sg:nom:m1')  # False (rzeczownik)
is_stopword_by_ctag('qub')  # True (partykuła)
```

### Filtrowanie listy tokenów

```python
from analysis.stopwords import filter_tokens

# Tokeny jako lista krotek (orth, lemma, ctag)
tokens = [
    ('Jednak', 'jednak', 'conj'),
    ('Bóg', 'bóg', 'subst:sg:nom:m3'),
    ('jest', 'być', 'fin:sg:ter:imperf'),
    ('miłosierny', 'miłosierny', 'adj:sg:nom:m3:pos'),
]

# Filtruj
filtered = filter_tokens(
    tokens,
    use_ctag=True,           # używaj filtrowania po tagach
    use_stopwords=True,      # używaj listy stopwords
    stopword_set=ALL_STOPWORDS_ASCII,  # który zestaw
    min_length=2             # minimalna długość
)
# Wynik: [('miłosierny', 'miłosierny', 'adj:sg:nom:m3:pos')]
```

### Normalizacja ASCII → polski

```python
from analysis.stopwords import normalize_token

normalize_token('byc')   # 'być'
normalize_token('jesli') # 'jeśli'
normalize_token('cos')   # 'coś'
normalize_token('kosciol') # 'kościół'
```

## Pliki

```
analysis/stopwords/
├── __init__.py                    # eksporty modułu
├── stopwords_pl.py               # główny moduł ze stopwords
├── validate_stopwords.py         # skrypt walidacyjny
├── README.md                      # ten plik
│
├── core_stopwords.txt            # CORE (z polskimi znakami)
├── core_stopwords_ascii.txt      # CORE + warianty ASCII
├── extended_stopwords.txt        # EXTENDED
├── extended_stopwords_ascii.txt
├── domain_stopwords.txt          # DOMAIN (religijne)
├── domain_stopwords_ascii.txt
├── forum_stopwords.txt           # FORUM (metatekst)
├── forum_stopwords_ascii.txt
├── all_stopwords.txt             # ALL
└── all_stopwords_ascii.txt
```

## Warstwy stopwords

### 1. CORE_STOPWORDS (308 słów)
Podstawowe słowa funkcyjne, które prawie zawsze należy usuwać:
- Partykuły: `nie`, `czy`, `też`, `już`, `jeszcze`
- Spójniki: `i`, `ale`, `że`, `bo`, `jednak`
- Zaimki: `ja`, `ty`, `on`, `ten`, `który`, `co`
- Przyimki: `w`, `na`, `do`, `z`, `od`, `dla`
- Czasowniki posiłkowe: `być`, `mieć`, `móc`, `musieć`

### 2. EXTENDED_STOPWORDS (523 słów)
Rozszerzenie CORE o:
- Przysłówki miejsca/czasu: `tutaj`, `teraz`, `zawsze`, `nigdy`
- Przysłówki stopnia: `bardzo`, `trochę`, `całkiem`
- Liczebniki: `jeden`, `dwa`, `kilka`, `wiele`
- Czasowniki percepcji: `wiedzieć`, `widzieć`, `myśleć`

### 3. DOMAIN_STOPWORDS (180 słów)
Słownictwo dziedzinowe (religijne/kościelne):
- Bóg, Jezus, Chrystus, Pan, Duch
- kościół, katolik, ksiądz, biskup, papież
- wiara, modlitwa, grzech, zbawienie, łaska
- Biblia, Ewangelia, Pismo Święte
- dusza, niebo, piekło, święty

### 4. FORUM_STOPWORDS (102 słów)
Metatekst forumowy:
- Struktura: `post`, `temat`, `wątek`, `forum`, `dyskusja`
- Akcje: `pisać`, `napisać`, `czytać`, `cytować`
- Grzeczności: `pozdrawiam`, `witam`, `dzięki`, `proszę`
- Emotikony: `xD`, `lol`, `haha`

## Tagi morfologiczne (CTAG)

Automatyczne filtrowanie na podstawie tagów LPMN:

| Tag | Opis | Przykłady |
|-----|------|-----------|
| `interp` | Interpunkcja | `.` `,` `!` `?` |
| `qub` | Partykuły | `nie`, `by`, `tylko`, `już` |
| `conj` | Spójniki | `i`, `a`, `ale`, `czy` |
| `comp` | Komparatory | `jak`, `niż` |
| `prep:*` | Przyimki (wszystkie) | `na`, `do`, `w`, `z` |
| `brev:*` | Skróty | `np.`, `itd.`, `itp.` |

## Walidacja

Uruchom skrypt walidacyjny:

```bash
python3 analysis/stopwords/validate_stopwords.py --sample-size 100000
```

Opcje:
- `--sample-size N` - liczba tokenów do analizy (default: 100000)
- `--output FILE` - zapisz raport do pliku

## Rekomendacje

1. **Dla ogólnej analizy tekstu**: użyj `ALL_STOPWORDS_ASCII` + filtrowanie po `CTAG`
2. **Dla analizy tematycznej religijnej**: użyj tylko `CORE + EXTENDED + FORUM` (bez DOMAIN)
3. **Dla analizy sentymentu**: ostrożnie z EXTENDED (przysłówki mogą nieść znaczenie)
4. **Dla klasyfikacji płci**: pamiętaj, że `pozdrawiam` może mieć sygnał płciowy

---
Utworzono: 2026-01-26
