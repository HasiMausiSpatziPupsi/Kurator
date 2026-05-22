# Vision: Der "Ein-Hand-Fluss" bei der Bibliotheks-Inventur

Diese Vision beschreibt den idealen Arbeitsablauf eines Nutzers, der eine große, teils nischige Bibliothek systematisch erfassen möchte. Das Hauptziel ist die Balance zwischen der analogen Welt (Bücher im Regal) und der digitalen Welt (Smartphone-App).

## Die User Journey: Schritt für Schritt

### 1. Vorbereitung & Rhythmus
Der User steht vor dem Regal. Das Smartphone liegt in der dominanten Hand, die andere Hand ist frei für die Bücher.
*   **Aktion:** Öffnen der App, Starten des "Scan-Serienmodus".
*   **Balance:** Die App muss so "ruhig" sein, dass sie nicht durch ständige Vibrationen oder Popups ablenkt, während man das nächste Fach fokussiert.

### 2. Der "Glücksfall": Barcode-Scan (Das schnelle Buch)
*   **Aktion:** Buch mit der freien Hand aus dem Regal ziehen, kurz umdrehen, Barcode scannen (Smartphone bleibt in der Hand), Buch zurückstellen oder auf den "Erledigt"-Stapel.
*   **Physische Dynamik:** Das Smartphone wird wie ein Werkzeug geführt. Ein kurzes akustisches Signal (Ping) bestätigt den Erfolg, ohne dass der User auf das Display schauen muss.
*   **Pain Point:** Barcode ist verblasst oder unter einer alten Schutzfolie. Der User muss die Aufmerksamkeit vom Regal weg auf das Display lenken, um den Fokus der Kamera zu kontrollieren.

### 3. Der "Normalfall": ISBN-OCR (Das alte Buch mit Nummer)
Alte deutsche Bücher (ca. 1970-1990) haben oft keinen Barcode, aber eine gedruckte ISBN im Impressum oder auf der Rückseite.
*   **Aktion:** User bemerkt: Kein Barcode. Er schlägt das Buch auf (freie Hand + Smartphone-Hand helfen kurz zusammen). Die Kamera erkennt die gedruckte ISBN-Zahl.
*   **Balance:** Hier kippt die Aufmerksamkeit stark ins Analoge (Suchen der ISBN im Kleingedruckten). Die App muss hier "intelligent warten" und die Zahl sofort greifen, sobald sie im Bild erscheint.

### 4. Der "Härtefall": Visuelle Erkennung / Manuelle Suche (Das nischige/uralte Buch)
Bücher vor 1970 oder Kleinstverlage ohne ISBN.
*   **Aktion:** Der User scannt das Titelblatt. Die App nutzt OCR, um Titel und Autor zu lesen und sucht in der DNB (Deutsche Nationalbibliothek).
*   **Balance:** Dies ist der Moment der höchsten Frustration. Das Smartphone muss jetzt zur Tastatur werden.
*   **Pain Point:** Das Eintippen von langen Titeln mit einer Hand, während man mit der anderen das Buch offen hält, um den Verlag abzulesen.

---

## Identifizierte Pain Points entlang der Journey

| Phase | Pain Point (Schmerzpunkt) | Ursache | Lösungsidee |
| :--- | :--- | :--- | :--- |
| **Physisch** | "Hand-Akrobatik" | Smartphone halten + Buchseiten umblättern. | Sprachsteuerung oder sehr große, einhändig bedienbare Buttons. |
| **Kognitiv** | Fokus-Wechsel | Ständiges Umschalten zwischen Buch (analog) und Display (digital). | Akustisches Feedback (unterschiedliche Töne für "Gefunden", "Nicht gefunden", "DNB-Treffer"). |
| **Technisch** | Fehlende Metadaten | Nischige Titel werden trotz DNB nicht sofort gefunden. | "Später ergänzen"-Modus: Nur Foto vom Cover machen, Metadaten abends am PC/Tablet nachpflegen. |
| **Workflow** | Unterbrechung | Ein Fehler beim Scan zwingt den User, den Serienmodus zu verlassen. | Fehlertolerante Warteschlange: "Scan fehlgeschlagen, Foto gespeichert, weiter zum nächsten Buch." |

---

## Induktive Erkenntnis: Die "Ein-Hand-Doktrin"

Damit die Inventur nicht zur Qual wird, muss die App wie ein **verlängerter Sinn** des Nutzers funktionieren, nicht wie ein Dateneingabegerät.

1.  **Hören statt Sehen:** Der User sollte am Klang erkennen, ob das Buch im System ist.
2.  **Greifen statt Tippen:** Die Kamera muss der primäre Input sein – nicht nur für Barcodes, sondern für jeglichen Text auf dem Buch.
3.  **Verzögerte Perfektion:** Bei nischigen Büchern ist es wichtiger, das Buch *jetzt* zu erfassen (mit einem Foto), als den Fluss im Regal zu stoppen, um mühsam Metadaten zu suchen. Die "elegante" Lösung ist ein Workflow, der erst sammelt und dann (vielleicht später) veredelt.

**Fazit:** Der User sucht keine App, sondern einen "Inventur-Assistenten", der ihm erlaubt, den Blick 90% der Zeit am Regal zu lassen.
