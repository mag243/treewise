# The iPad app's App Store listing

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
Give Treewise the folders you work in and handle your files as on a desktop: columns to sort by, drag to move or copy, cut and paste, and undo for all of it.
```

### nl-NL

```
Beheer je bestanden op de iPad als op een desktop: kolommen om op te sorteren, slepen om te verplaatsen of te kopiëren, knippen en plakken, en ongedaan maken voor alles.
```

### de-DE

```
Verwalte deine Dateien auf dem iPad wie am Desktop: Spalten zum Sortieren, Ziehen zum Bewegen oder Kopieren, Ausschneiden und Einsetzen, und alles widerrufbar.
```

## Description

### en-US

```
Treewise is a file manager for the iPad that works the way a file manager on a desktop computer does: your files in a table with columns you sort by, folders you drag them onto, and cut, copy and paste for files.

Give Treewise the folders you work in, on your iPad, in iCloud Drive or on a drive you plug in, and it keeps them in the sidebar. One top folder is enough: everything beneath it is within reach.

FEATURES
• A table with name, date modified, size and kind; tap a heading to sort, with folders always first
• Back, forward and the enclosing folder, and the path above the list, to go to any folder in it
• Drag files onto a folder in the list, the sidebar or the path: on the same drive they move, to another drive they are copied
• Cut, copy and paste, rename, new folder and move to the trash, from the context menu
• When a name is already taken: replace, keep both or stop, for one file or for all of them
• Undo and redo for all of it, with ⌘Z on a keyboard or a three-finger swipe
• Drag files to and from other apps, such as Files and Mail
• Quick Look to look at a file, and Share from there
• Search the folder, and show hidden files and file extensions
• On a narrow screen, in portrait or beside another app, each file shows its date and size beneath its name
• In English, Dutch and German

PRIVACY
Treewise collects nothing: no account, no tracking, no analytics. It sees only the folders you give it, and your files stay where they are.

Requires iPadOS 18 or later.
```

### nl-NL

```
Treewise is een bestandsbeheerder voor de iPad die werkt zoals bestandsbeheer op een desktopcomputer: je bestanden in een tabel met kolommen om op te sorteren, mappen om ze op te slepen, en knippen, kopiëren en plakken voor bestanden.

Geef Treewise de mappen waarin je werkt, op je iPad, in iCloud Drive of op een schijf die je aansluit, en het bewaart ze in de navigatiekolom. Eén bovenste map is genoeg: alles daaronder is binnen bereik.

KENMERKEN
• Een tabel met naam, wijzigingsdatum, grootte en soort; tik op een kop om te sorteren, met mappen altijd bovenaan
• Terug, vooruit en de bovenliggende map, en het pad boven de lijst, om naar elke map daarin te gaan
• Sleep bestanden op een map in de lijst, de navigatiekolom of het pad: op dezelfde schijf worden ze verplaatst, naar een andere schijf gekopieerd
• Knippen, kopiëren en plakken, de naam wijzigen, een nieuwe map en verplaatsen naar de prullenmand, vanuit het contextmenu
• Als een naam al bestaat: vervangen, beide bewaren of stoppen, voor één bestand of voor allemaal
• Ongedaan maken en opnieuw voor alles, met ⌘Z op een toetsenbord of een veeg met drie vingers
• Sleep bestanden van en naar andere apps, zoals Bestanden en Mail
• Snelle weergave om een bestand te bekijken, en delen vanuit daar
• Zoek in de map, en toon verborgen bestanden en extensies
• Op een smal scherm, staand of naast een andere app, staan bij elk bestand de datum en de grootte onder de naam
• In het Engels, Nederlands en Duits

PRIVACY
Treewise verzamelt niets: geen account, geen tracking, geen analytics. Het ziet alleen de mappen die je het geeft, en je bestanden blijven waar ze zijn.

Vereist iPadOS 18 of hoger.
```

### de-DE

```
Treewise ist ein Dateimanager für das iPad, der so arbeitet wie ein Dateimanager auf einem Desktop-Computer: deine Dateien in einer Tabelle mit Spalten zum Sortieren, Ordner, auf die du sie ziehst, und Ausschneiden, Kopieren und Einsetzen für Dateien.

Gib Treewise die Ordner, in denen du arbeitest, auf deinem iPad, in iCloud Drive oder auf einem angeschlossenen Laufwerk, und es behält sie in der Seitenleiste. Ein oberster Ordner genügt: alles darunter ist in Reichweite.

FUNKTIONEN
• Eine Tabelle mit Name, Änderungsdatum, Größe und Art; tippe auf eine Überschrift zum Sortieren, Ordner stehen immer zuerst
• Zurück, vorwärts und der übergeordnete Ordner, und der Pfad über der Liste, um zu jedem Ordner darin zu gehen
• Ziehe Dateien auf einen Ordner in der Liste, der Seitenleiste oder dem Pfad: auf demselben Laufwerk werden sie bewegt, auf ein anderes kopiert
• Ausschneiden, Kopieren und Einsetzen, Umbenennen, neuer Ordner und In den Papierkorb legen, aus dem Kontextmenü
• Wenn ein Name schon vergeben ist: ersetzen, beide behalten oder stoppen, für eine Datei oder für alle
• Widerrufen und Wiederholen für alles, mit ⌘Z auf einer Tastatur oder einem Wischen mit drei Fingern
• Ziehe Dateien zu und aus anderen Apps, etwa Dateien und Mail
• Übersicht, um eine Datei anzusehen, und Teilen von dort
• Suche im Ordner, und zeige unsichtbare Dateien und Dateiendungen
• Auf einem schmalen Bildschirm, im Hochformat oder neben einer anderen App, stehen bei jeder Datei Datum und Größe unter dem Namen
• Auf Englisch, Niederländisch und Deutsch

DATENSCHUTZ
Treewise sammelt nichts: kein Konto, kein Tracking, keine Analysen. Es sieht nur die Ordner, die du ihm gibst, und deine Dateien bleiben, wo sie sind.

Erfordert iPadOS 18 oder neuer.
```

## Keywords

Comma-separated, without spaces.

### en-US

```
files,folders,copy,move,rename,drag,drop,usb,icloud,drive,documents,organize,columns,undo,sort
```

### nl-NL

```
bestanden,mappen,kopiëren,verplaatsen,hernoemen,slepen,usb,icloud,documenten,ordenen,sorteren
```

### de-DE

```
Dateien,Ordner,kopieren,verschieben,umbenennen,ziehen,USB,iCloud,Dokumente,Dateiverwaltung
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
