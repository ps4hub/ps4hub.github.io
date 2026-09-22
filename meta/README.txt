Fișiere de text pentru paginile hub-ului.

meta/index.json     -> index.html   (hub: tile-uri, hint-uri, dialog GoldHEN)
meta/packages.json  -> packages.html
meta/payloads.json  -> payloads.html
meta/readme.json    -> readme.html
meta/404.json       -> 404.html

Cum funcționează
- Fiecare pagină citește fișierul ei la încărcare (fetch, fără cache) și
  înlocuiește textele. Nu trebuie să atingi HTML-ul.
- Orice cheie lipsă cade automat pe textul implicit din pagină, deci poți
  păstra în fișier doar cheile pe care vrei să le schimbi.
- Dacă fișierul lipsește sau are JSON invalid, pagina merge mai departe cu
  textele implicite.
- Fișierul trebuie servit prin HTTP (nginx), salvat UTF-8.

Note pe chei
- index.json "tiles": listă în ordinea de pe ecran. Fiecare intrare acceptă
  label (textul de sub icon), title și sub (titlul/descrierea de sus) și
  opțional href (unde duce butonul).
- payloads.json "tiles": butoanele de pe pagina Payloads, in ordinea de pe ecran.
  Adaugi o intrare in lista = apare un buton nou; stergi o intrare = dispare.
  Ordinea din fisier este ordinea de pe rail. Nu exista limita de butoane.
  Fiecare intrare:
    icon  - optional; implicit stiva (ca WebKitty).
            variante: stack | flask | folder | cat | book | payload
    label - textul de sub icon
    title - titlul mare afisat cand butonul e selectat
    sub   - descrierea de sub titlu
    href  - unde duce butonul. Cale libera, relativa la radacina site-ului:
            "payload1/index.html", "exploit/gold/index.html", "ceva.html",
            chiar si un link extern. Nu exista folder obligatoriu; folosesti
            ce nume de folder vrei, atat timp cat href-ul il indica.
- index.json "tiles" functioneaza la fel pentru hub.
- 404.json "links": butoanele de ieșire, fiecare cu label și href.
