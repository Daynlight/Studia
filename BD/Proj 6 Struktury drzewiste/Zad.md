6. Proj. algorytmiczny: Struktury drzewiaste w SQL – specyfikacja wymagań
Wymagania zaliczenia
Autorzy: dr inż. Anna Stachowiak, dr Andrzej Wójtowicz

Opis zadania
Zadanie polega na zaimplementowaniu w języku SQL struktury hierarchicznej (drzewiastej) w relacyjnej bazie danych w przynajmniej dwóch spośród czterech modeli:

lista sąsiedztwa (Adjacency List),
enumeracja ścieżki (Path Enumeration),
zbiory zagnieżdżone (Nested Sets),
tabela domknięcia (Closure Table).
Wynikiem projektów jest zestawy skryptów SQL (dla każdego z modeli) tworzących tabele do przechowywania drzew, wypełniających danymi, oraz procedury i funkcje SQL (wraz z ich wywołaniem), umożliwiające:

dodanie nowego elementu do drzewa,
usunięcie dowolnego elementu drzewa,
przeniesienie elementu w strukturze drzewa,
odczytanie wszystkich potomków danego węzła drzewa (bezpośrednich oraz pośrednich),
odczytanie potomków na wybranym poziomie (np. wnuków),
odczytanie bezpośredniego przodka danego węzła,
odczytanie wszystkich przodków danego węzła,
odczytanie przodków danego węzła na wybranym poziomie,
odczytanie "rodzeństwa" (innych węzłów na tym samym poziomie),
zweryfikowanie, czy drzewo nie zawiera cykli,
zweryfikowanie, czy drzewo jest spójne.
Wymaganiem minimalnym jest zaimplementowanie przynajmniej trzech spośród wymienionych funkcjonalności, dla obu modeli.

Wskazówki
Do realizacji zadania można użyć następujących materiałów:

Karwin, B. (2012). Naiwne drzewa  (pp. 37-59). W: Antywzorce języka SQL. Jak unikać pułapek podczas programowania baz danych. Helion.
Karwin, B. (2010). Naive Trees  (pp. 34-53). W: SQL Antipatterns: Avoiding the Pitfalls of Database Programming. Pragmatic Programmers, LLC.
Pytania i odpowiedzi
...

Punktacja
Punkty przyznawane są następująco:

Punkty	Obowiązkowe
1.	Stworzenie schematów tabel do przechowania drzew (CREATE)	1	✓
2.	Wypełnienie tabel przykładowymi danymi	2	✓
3.	Przygotowanie demonstracji projektu (wywołanie procedur i funkcji)	1	✓
4.	Zadanie a.–k. dla obu modeli:	11	Min. 3 wybrane
a.	– dodanie nowego elementu do drzewa	1	
b.	– usunięcie dowolnego elementu drzewa	1	
c.	– przeniesienie elementu w strukturze drzewa	1	
d.	– odczytanie wszystkich potomków danego węzła drzewa (bezpośrednich oraz pośrednich)	1	
e.	– odczytanie potomków na wybranym poziomie (np. wnuków)	1	
f.	– odczytanie bezpośredniego przodka danego węzła	1	
g.	– odczytanie wszystkich przodków danego węzła	1	
h.	– odczytanie przodków danego węzła na wybranym poziomie	1	
i.	– odczytanie "rodzeństwa" (innych węzłów na tym samym poziomie)	1	
j.	– zweryfikowanie, czy drzewo nie zawiera cykli	1	
k.	– zweryfikowanie, czy drzewo jest spójne	1	
Łączna liczba punktów do zdobycia	15	
Sposób zaliczenia
Termin oddania projektu podany jest na stronie Harmonogram zajęć.

Projekt można skonsultować wcześniej i go ewentualnie poprawić.

Po umieszczeniu plików na Moodle, projekt należy rozliczyć poprzez jego prezentację, tj. pokazanie działania oraz omówienie kodu.

Pliki do przesłania
Jako rozwiązanie umieść na Moodle pliki SQL:

adjacency-list.sql,
path-enumeration.sql,
nested-sets.sql,
closure-table.sql.
Pliki zapisz w kodowaniu UTF-8.