# Tierton

Eine Spieleapp, mit der man Tiergeräusche kennenlernen und raten kann. Für iPhone und iPad, für Kinder und Erwachsene.

## Spielmodi

- **Entdecken:** Ein durchgehender Scroll durch alle Lebensräume, von der Arktis bis zur Antarktis. Tier antippen, um das Geräusch zu hören. Mit „i“ öffnet sich die Quartett-Karte mit Größe, Gewicht, Alter, Nachwuchs, Tragzeit, Nahrung, Tempo, Rote-Liste-Status und einem Fakt. Oben gibt es Sprungmarken zu den Lebensräumen und den Filter „Nur Vögel“.
- **Rätsel zu zweit:** Eine Person spielt ein Geräusch ab, zufällig oder heimlich ausgesucht, die anderen raten. Dann wird aufgelöst.
- **Quiz:** 10 Runden. Ein Geräusch ertönt, und man tippt so schnell wie möglich auf das richtige Foto. Schnelle Antworten und Serien geben mehr Punkte. Es gibt drei Stufen: 4, 6 oder 9 Bilder. Auf „Schwer“ kommen die falschen Antworten aus demselben Lebensraum.

## Inhalte und Lizenzen

- Fotos und Töne kommen von **Wikimedia Commons** und sind nur gemeinfrei, CC0, CC BY oder CC BY-SA. Autor und Lizenz stehen in `Content/media.json` und in der App unter „Bild- und Tonnachweise“.
- Der Rote-Liste-Status kommt von **Wikidata** (CC0).
- Die Quartett-Werte in `Content/facts.json` sind typische Richtwerte.

## Neues Tier hinzufügen

1. Das Tier in `Content/catalog.json` eintragen: `id`, `name`, `category`, wissenschaftlicher Name `sci`, englischer Suchbegriff `en`, Titel des deutschen Wikipedia-Artikels `dewiki` und optional `"bird": true`. Ein Foto oder Ton lässt sich mit `"image": "Dateiname.jpg"` bzw. `"sound": "Dateiname.ogg"` erzwingen (Dateinamen von Commons).
2. Die Werte in `Content/facts.json` ergänzen.
3. Medien laden, dafür braucht man `ffmpeg`:
   ```bash
   python3 tools/fetch_media.py all
   ```
4. Das Projekt neu erzeugen, dafür braucht man `xcodegen`:
   ```bash
   xcodegen generate
   ```

Tiere ohne Ton blendet die App automatisch aus. Mit `"hidden": true` lässt sich ein Tier ausblenden, ohne es zu löschen. Eine neue Kategorie wird einfach in `categories` ergänzt. Die Reihenfolge dort ist auch die Scroll-Reihenfolge.

## Bauen

`Tierton.xcodeproj` wird aus `project.yml` erzeugt. In Xcode unter *Signing & Capabilities* das eigene Team wählen und dann auf dem iPhone oder iPad starten.
