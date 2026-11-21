# The iOS app's App Store listing

The text of Treewise's listing in App Store Connect, per locale (ADR 0118). Change it here,
check it with `python3 tools/appstore/listing.py check`, and upload it with the uploader;
what is typed in App Store Connect's pages is overwritten by the next upload.

Each field is a `##` heading with a `###` heading per locale, or `### all` for a value
every locale shares, and the value in a fenced block. The limits are Apple's, checked by
`listing.py`. The name and the subtitle are searched as well as the keywords, so a
keyword repeats neither.

## Subtitle

### en-US

```
Desktop-style file manager
```

### nl-NL

```
Bestandsbeheer als op desktop
```

### de-DE

```
Dateimanager wie am Desktop
```

## Promotional text

Can change between versions without a review.

### en-US

```
Give Treewise the folders you work in and handle your files as on a desktop, on the iPad and the iPhone: columns to sort by, drag to move or copy, cut and paste, undo.
```

### nl-NL

```
Beheer je bestanden op de iPad en de iPhone als op een desktop: kolommen om op te sorteren, slepen om te verplaatsen of te kopiëren, knippen en plakken, ongedaan maken.
```

### de-DE

```
Verwalte deine Dateien auf iPad und iPhone wie am Desktop: Spalten zum Sortieren, Ziehen zum Bewegen oder Kopieren, Ausschneiden und Einsetzen, Widerrufen.
```

## Description

### en-US

```
Treewise is a file manager for the iPad and the iPhone that works the way a file manager on a desktop computer does: your files in a table with columns you sort by, folders you drag them onto, and cut, copy and paste for files.

Give Treewise the folders you work in, on your device, in iCloud Drive or Dropbox, or on a drive you plug in, and it keeps them in the sidebar. One top folder is enough: everything beneath it is within reach.

FEATURES
• A table with name, date modified, size and kind; tap a heading to sort, with folders always first
• Back, forward and the enclosing folder, and the path above the list, to go to any folder in it
• Drag files onto a folder in the list, the sidebar or the path: on the same drive they move, to another drive they are copied
• Cut, copy and paste, rename, new folder, Move to… and move to the trash, from the context menu or after Select
• When a name is already taken: replace, keep both or stop, for one file or for all of them
• Undo and redo for all of it, with ⌘Z on a keyboard or a three-finger swipe
• Drag files to and from other apps, such as Files and Mail
• Quick Look to look at a file, and Share from there
• Search the folder, and show hidden files and file extensions
• Favorites for the folders you use most
• On the iPad, two folders side by side in two windows
• On the iPhone, a list as in the Files app, each file with its date and size beneath its name; on iPhone Duo, the table with its columns when you open it

NAMES AND FOLDERS
• Rename with Suggestions: a name in the pattern of the other files in the folder, such as the date a photo was taken
• Suggest Names: new names for a whole folder at once, to check and change before any is used
• Folder templates: save a folder's structure as a template and make it again, for a new year for instance, and rename a folder in all years at once
• Your naming settings, saved patterns and templates follow you to your other iPads, iPhones and Macs through the cloud drives you use; you can turn this off

In English, Dutch and German.

PRIVACY
Treewise collects nothing: no account, no tracking, no analytics. It sees only the folders you give it, and your files stay where they are. Its settings travel through your own cloud drive, never through a server of ours.

Requires iPadOS 18 or iOS 18 or later.
```

### nl-NL

```
Treewise is een bestandsbeheerder voor de iPad en de iPhone die werkt zoals bestandsbeheer op een desktopcomputer: je bestanden in een tabel met kolommen om op te sorteren, mappen om ze op te slepen, en knippen, kopiëren en plakken voor bestanden.

Geef Treewise de mappen waarin je werkt, op je apparaat, in iCloud Drive of Dropbox, of op een schijf die je aansluit, en het bewaart ze in de navigatiekolom. Eén bovenste map is genoeg: alles daaronder is binnen bereik.

KENMERKEN
• Een tabel met naam, wijzigingsdatum, grootte en soort; tik op een kop om te sorteren, met mappen altijd bovenaan
• Terug, vooruit en de bovenliggende map, en het pad boven de lijst, om naar elke map daarin te gaan
• Sleep bestanden op een map in de lijst, de navigatiekolom of het pad: op dezelfde schijf worden ze verplaatst, naar een andere schijf gekopieerd
• Knippen, kopiëren en plakken, de naam wijzigen, een nieuwe map, Verplaats naar… en verplaatsen naar de prullenmand, vanuit het contextmenu of na Selecteer
• Als een naam al bestaat: vervangen, beide bewaren of stoppen, voor één bestand of voor allemaal
• Ongedaan maken en opnieuw voor alles, met ⌘Z op een toetsenbord of een veeg met drie vingers
• Sleep bestanden van en naar andere apps, zoals Bestanden en Mail
• Snel bekijken om een bestand te zien, en delen vanuit daar
• Zoek in de map, en toon verborgen bestanden en extensies
• Favorieten voor de mappen die je het meest gebruikt
• Op de iPad twee mappen naast elkaar in twee vensters
• Op de iPhone een lijst zoals in Bestanden, met bij elk bestand de datum en de grootte onder de naam; op de iPhone Duo de tabel met kolommen als je hem openvouwt

NAMEN EN MAPPEN
• Wijzig naam met voorstellen: een naam in het patroon van de andere bestanden in de map, zoals de datum waarop een foto is gemaakt
• Stel namen voor: nieuwe namen voor een hele map tegelijk, om na te kijken en aan te passen voordat er een wordt gebruikt
• Mapsjablonen: bewaar de opbouw van een map als sjabloon en maak hem opnieuw, bijvoorbeeld voor een nieuw jaar, en wijzig de naam van een map in alle jaren tegelijk
• Je naaminstellingen, bewaarde patronen en sjablonen gaan mee naar je andere iPads, iPhones en Macs via de clouddrives die je gebruikt; dat kun je uitzetten

In het Engels, Nederlands en Duits.

PRIVACY
Treewise verzamelt niets: geen account, geen tracking, geen analytics. Het ziet alleen de mappen die je het geeft, en je bestanden blijven waar ze zijn. De instellingen reizen via je eigen clouddrive, nooit via een server van ons.

Vereist iPadOS 18 of iOS 18 of hoger.
```

### de-DE

```
Treewise ist ein Dateimanager für iPad und iPhone, der so arbeitet wie ein Dateimanager auf einem Desktop-Computer: deine Dateien in einer Tabelle mit Spalten zum Sortieren, Ordner, auf die du sie ziehst, und Ausschneiden, Kopieren und Einsetzen für Dateien.

Gib Treewise die Ordner, in denen du arbeitest, auf deinem Gerät, in iCloud Drive oder Dropbox, oder auf einem angeschlossenen Laufwerk, und es behält sie in der Seitenleiste. Ein oberster Ordner genügt: alles darunter ist in Reichweite.

FUNKTIONEN
• Eine Tabelle mit Name, Änderungsdatum, Größe und Art; tippe auf eine Überschrift zum Sortieren, Ordner stehen immer zuerst
• Zurück, vorwärts und der übergeordnete Ordner, und der Pfad über der Liste, um zu jedem Ordner darin zu gehen
• Ziehe Dateien auf einen Ordner in der Liste, der Seitenleiste oder dem Pfad: auf demselben Laufwerk werden sie bewegt, auf ein anderes kopiert
• Ausschneiden, Kopieren und Einsetzen, Umbenennen, neuer Ordner, Bewegen nach… und In den Papierkorb legen, aus dem Kontextmenü oder nach Auswählen
• Wenn ein Name schon vergeben ist: ersetzen, beide behalten oder stoppen, für eine Datei oder für alle
• Widerrufen und Wiederholen für alles, mit ⌘Z auf einer Tastatur oder einem Wischen mit drei Fingern
• Ziehe Dateien zu und aus anderen Apps, etwa Dateien und Mail
• Übersicht, um eine Datei anzusehen, und Teilen von dort
• Suche im Ordner, und zeige unsichtbare Dateien und Dateiendungen
• Favoriten für die Ordner, die du am meisten nutzt
• Auf dem iPad zwei Ordner nebeneinander in zwei Fenstern
• Auf dem iPhone eine Liste wie in der Dateien-App, bei jeder Datei Datum und Größe unter dem Namen; auf dem iPhone Duo die Tabelle mit ihren Spalten, wenn du es aufklappst

NAMEN UND ORDNER
• Mit Vorschlägen umbenennen: ein Name im Muster der anderen Dateien im Ordner, etwa mit dem Datum, an dem ein Foto aufgenommen wurde
• Namen vorschlagen: neue Namen für einen ganzen Ordner auf einmal, zum Prüfen und Ändern, bevor einer verwendet wird
• Ordnervorlagen: sichere den Aufbau eines Ordners als Vorlage und lege ihn neu an, etwa für ein neues Jahr, und benenne einen Ordner in allen Jahren auf einmal um
• Deine Namenseinstellungen, gesicherten Muster und Vorlagen folgen dir auf deine anderen iPads, iPhones und Macs über die Cloud-Laufwerke, die du nutzt; das lässt sich ausschalten

Auf Englisch, Niederländisch und Deutsch.

DATENSCHUTZ
Treewise sammelt nichts: kein Konto, kein Tracking, keine Analysen. Es sieht nur die Ordner, die du ihm gibst, und deine Dateien bleiben, wo sie sind. Die Einstellungen reisen über dein eigenes Cloud-Laufwerk, nie über einen Server von uns.

Erfordert iPadOS 18 oder iOS 18 oder neuer.
```

## Keywords

Comma-separated, without spaces.

### en-US

```
files,folders,copy,move,rename,drag,drop,usb,icloud,dropbox,documents,organize,undo,templates
```

### nl-NL

```
bestanden,mappen,kopiëren,verplaatsen,hernoemen,slepen,usb,icloud,dropbox,documenten,sjablonen
```

### de-DE

```
Dateien,Ordner,kopieren,verschieben,umbenennen,ziehen,USB,iCloud,Dropbox,Dokumente,Vorlagen
```

## Support URL

### all

```
https://github.com/mag243/treewise/issues
```

## Marketing URL

### all

```
https://treewise.m-domain.me/
```

## Privacy policy URL

### all

```
https://treewise.m-domain.me/privacy.html
```

## Copyright

### all

```
2026 Maarten Ghijsen
```
