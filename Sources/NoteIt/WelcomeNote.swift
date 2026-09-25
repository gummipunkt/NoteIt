import NoteItCore

/// Content of the note created on the very first launch, in the app language.
enum WelcomeNote {
    static func body(for language: AppLanguage) -> String {
        switch language {
        case .en: return english
        case .de: return german
        case .fr: return french
        case .it: return italian
        case .es: return spanish
        }
    }

    private static let english = """
    Great to have you here! NoteIt works like nvALT: **one field to search and create**.

    ## Creating a note

    1. Click the search field at the top (or press **⌘L**).
    2. Type a title, e.g. `Shopping list`.
    3. Press **⏎** – if the note doesn’t exist yet, it is created and you can start writing right away.

    Alternatively: **⌘N** or the *New Note* button in the toolbar. You can change the title above the text at any time.

    ## Good to know

    - **↑ / ↓** in the search field moves through your notes, **Esc** clears the search.
    - Everything is saved automatically – as a plain `.md` or `.txt` file.
    - **⌘1 · ⌘2 · ⌘3** switch between Write, Split and Preview.
    - Link notes with double square brackets: [[My first note]]

    > Tip: put the notes folder in Dropbox or Google Drive (Settings → Storage) and your notes go wherever you go. Connect Simplenote under Settings → Simplenote.

    - [x] Install NoteIt
    - [ ] Write your first own note
    """

    private static let german = """
    Schön, dass du da bist! NoteIt funktioniert wie nvALT: **ein Feld zum Suchen und Anlegen**.

    ## Neue Notiz anlegen

    1. Oben ins Suchfeld klicken (oder **⌘L**).
    2. Einen Titel tippen, z. B. `Einkaufsliste`.
    3. **⏎** drücken – gibt es die Notiz noch nicht, wird sie angelegt und du schreibst direkt weiter.

    Alternativ: **⌘N** oder der Knopf *Neue Notiz* in der Symbolleiste. Den Titel änderst du jederzeit oben über dem Text.

    ## Nützlich zu wissen

    - **↑ / ↓** im Suchfeld blättert durch die Notizen, **Esc** leert die Suche.
    - Alles wird automatisch gespeichert – als normale `.md`- oder `.txt`-Datei.
    - **⌘1 · ⌘2 · ⌘3** wechseln zwischen Schreiben, geteilter Ansicht und Vorschau.
    - Verlinke Notizen mit doppelten eckigen Klammern: [[Meine erste Notiz]]

    > Tipp: Lege den Notizordner in Dropbox oder Google Drive (Einstellungen → Speicherort), dann sind deine Notizen überall dabei. Simplenote verbindest du unter Einstellungen → Simplenote.

    - [x] NoteIt installiert
    - [ ] Erste eigene Notiz schreiben
    """

    private static let french = """
    Ravi de vous voir ici ! NoteIt fonctionne comme nvALT : **un seul champ pour rechercher et créer**.

    ## Créer une note

    1. Cliquez dans le champ de recherche en haut (ou **⌘L**).
    2. Saisissez un titre, par exemple `Liste de courses`.
    3. Appuyez sur **⏎** : si la note n’existe pas encore, elle est créée et vous pouvez écrire aussitôt.

    Autre possibilité : **⌘N** ou le bouton *Nouvelle note* dans la barre d’outils. Vous pouvez modifier le titre au-dessus du texte à tout moment.

    ## Bon à savoir

    - **↑ / ↓** dans le champ de recherche parcourt les notes, **Échap** efface la recherche.
    - Tout est enregistré automatiquement, sous forme de simple fichier `.md` ou `.txt`.
    - **⌘1 · ⌘2 · ⌘3** passent de Écrire à Partagé et à Aperçu.
    - Reliez vos notes avec des doubles crochets : [[Ma première note]]

    > Astuce : placez le dossier des notes dans Dropbox ou Google Drive (Réglages → Stockage) et vos notes vous suivent partout. Connectez Simplenote dans Réglages → Simplenote.

    - [x] Installer NoteIt
    - [ ] Écrire ma première note
    """

    private static let italian = """
    Che bello averti qui! NoteIt funziona come nvALT: **un unico campo per cercare e creare**.

    ## Creare una nota

    1. Fai clic sul campo di ricerca in alto (oppure **⌘L**).
    2. Digita un titolo, ad esempio `Lista della spesa`.
    3. Premi **⏎**: se la nota non esiste ancora, viene creata e puoi iniziare subito a scrivere.

    In alternativa: **⌘N** o il pulsante *Nuova nota* nella barra degli strumenti. Puoi modificare il titolo sopra il testo in qualsiasi momento.

    ## Buono a sapersi

    - **↑ / ↓** nel campo di ricerca scorre le note, **Esc** cancella la ricerca.
    - Tutto viene salvato automaticamente, come semplice file `.md` o `.txt`.
    - **⌘1 · ⌘2 · ⌘3** passano tra Scrivi, Diviso e Anteprima.
    - Collega le note con doppie parentesi quadre: [[La mia prima nota]]

    > Suggerimento: metti la cartella delle note in Dropbox o Google Drive (Impostazioni → Archiviazione) e avrai le note sempre con te. Collega Simplenote in Impostazioni → Simplenote.

    - [x] Installare NoteIt
    - [ ] Scrivere la mia prima nota
    """

    private static let spanish = """
    ¡Qué bien que estés aquí! NoteIt funciona como nvALT: **un solo campo para buscar y crear**.

    ## Crear una nota

    1. Haz clic en el campo de búsqueda de arriba (o pulsa **⌘L**).
    2. Escribe un título, por ejemplo `Lista de la compra`.
    3. Pulsa **⏎**: si la nota aún no existe, se crea y puedes empezar a escribir enseguida.

    También puedes usar **⌘N** o el botón *Nueva nota* de la barra de herramientas. El título sobre el texto se puede cambiar en cualquier momento.

    ## Conviene saber

    - **↑ / ↓** en el campo de búsqueda recorre las notas, **Esc** borra la búsqueda.
    - Todo se guarda automáticamente como un simple archivo `.md` o `.txt`.
    - **⌘1 · ⌘2 · ⌘3** cambian entre Escribir, Dividido y Vista previa.
    - Enlaza notas con dobles corchetes: [[Mi primera nota]]

    > Consejo: guarda la carpeta de notas en Dropbox o Google Drive (Ajustes → Almacenamiento) y tendrás tus notas en todas partes. Conecta Simplenote en Ajustes → Simplenote.

    - [x] Instalar NoteIt
    - [ ] Escribir mi primera nota
    """
}
