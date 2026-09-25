import Foundation

/// Languages NoteIt is translated into.
public enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case en, de, fr, it, es

    public var id: String { rawValue }

    /// The language's name in that language, for the language picker.
    public var nativeName: String {
        switch self {
        case .en: return "English"
        case .de: return "Deutsch"
        case .fr: return "Français"
        case .it: return "Italiano"
        case .es: return "Español"
        }
    }

    public var locale: Locale {
        Locale(identifier: rawValue)
    }

    /// The first supported language in the user's preference list (English if none matches).
    public static func preferred(from preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        for identifier in preferredLanguages {
            let code = identifier.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)?.lowercased()
            if let code, let language = AppLanguage(rawValue: code) {
                return language
            }
        }
        return .en
    }
}

/// Translated UI strings. Placeholders are written `{0}`, `{1}`, … so each language can order them freely.
public enum L10n {
    /// The language used for all UI texts. Set once at launch (and when the user picks another language).
    public static var language: AppLanguage = .preferred()

    public static func tr(_ key: L10nKey, _ arguments: CustomStringConvertible...) -> String {
        format(key.text(in: language), arguments)
    }

    public static func tr(_ key: L10nKey, in language: AppLanguage, _ arguments: CustomStringConvertible...) -> String {
        format(key.text(in: language), arguments)
    }

    static func format(_ template: String, _ arguments: [CustomStringConvertible]) -> String {
        var result = template
        for (index, argument) in arguments.enumerated() {
            result = result.replacingOccurrences(of: "{\(index)}", with: argument.description)
        }
        return result
    }
}

private let nbsp = "\u{00A0}"

/// Every UI text of the app. The exhaustive `switch` in `translations` makes the compiler
/// insist on all five languages for each key.
public enum L10nKey: CaseIterable, Sendable {
    // Notes and actions
    case newNote, newNoteHelp, search, rename, moveToTrash, moveToTrashButton, showInFinder
    case sync, syncWithSimplenote, syncHelp, menuNote, menuAbout, menuWebsite, sourceCodeOnGitHub, contactFormat
    case viewEdit, viewSplit, viewPreview, view, viewModeHelp
    case confirmTrashFormat, cancel, error, ok
    // Sidebar and editor
    case noNotesTitle, noNotesDescription, noMatchesTitle, noMatchesDescriptionFormat, createFormat
    case noteCountOne, noteCountOther, filteredCountFormat, noAdditionalText
    case noSelectionTitle, noSelectionDescription, titlePlaceholder, wordCountOne, wordCountOther
    case yesterday, todayAtFormat, yesterdayAtFormat, searchPlaceholder
    case fontSystem, fontSerif, fontMono
    // Settings
    case settingsGeneral, settingsStorage, settingsAbout
    case newNotesAs, formatMarkdown, formatText, viewLabel, fontLabel, fontSizeFormat, narrowColumn
    case languageLabel, languageSystem, languageRestartHint
    case notesFolder, chooseOtherFolder, storeInFormat, cloudSyncTitle, cloudSyncExplanation, noCloudFolderFound
    case choose, chooseFolderMessage
    case signedInAs, autoSync, syncNow, signOut, connectSimplenote, email, password, signIn, simplenoteExplanation
    case versionFormat, versionBuildFormat, freeSoftwareGPL, freeSoftwarePrefix, readLicense, tagline
    // Sync and errors
    case syncing, syncStatusFormat, syncSessionExpired, syncErrorFormat, keychainErrorFormat
    case welcomeTitle, untitled
    case noteNotFoundFormat, titleExistsFormat, unreadableFileFormat
    case simplenoteInvalidCredentials, simplenoteUnauthorized, simplenoteServerErrorFormat, simplenoteInvalidResponse
    case syncReceivedFormat, syncSentFormat, syncDeletedFormat, syncConflictsFormat, syncErrorsFormat, syncUpToDate
    case conflictSuffix, changedDuringSyncFormat

    public func text(in language: AppLanguage) -> String {
        let t = translations
        switch language {
        case .en: return t.en
        case .de: return t.de
        case .fr: return t.fr
        case .it: return t.it
        case .es: return t.es
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    var translations: (en: String, de: String, fr: String, it: String, es: String) {
        switch self {
        case .newNote:
            return ("New Note", "Neue Notiz", "Nouvelle note", "Nuova nota", "Nueva nota")
        case .newNoteHelp:
            return ("New note (⌘N)", "Neue Notiz (⌘N)", "Nouvelle note (⌘N)", "Nuova nota (⌘N)", "Nueva nota (⌘N)")
        case .search:
            return ("Search", "Suchen", "Rechercher", "Cerca", "Buscar")
        case .rename:
            return ("Rename", "Umbenennen", "Renommer", "Rinomina", "Cambiar nombre")
        case .moveToTrash:
            return ("Move to Trash…", "In den Papierkorb legen …", "Placer dans la corbeille…", "Sposta nel Cestino…", "Mover a la papelera…")
        case .moveToTrashButton:
            return ("Move to Trash", "In den Papierkorb", "Placer dans la corbeille", "Sposta nel Cestino", "Mover a la papelera")
        case .showInFinder:
            return ("Show in Finder", "Im Finder zeigen", "Afficher dans le Finder", "Mostra nel Finder", "Mostrar en el Finder")
        case .sync:
            return ("Sync", "Synchronisieren", "Synchroniser", "Sincronizza", "Sincronizar")
        case .syncWithSimplenote:
            return ("Sync with Simplenote", "Mit Simplenote synchronisieren", "Synchroniser avec Simplenote", "Sincronizza con Simplenote", "Sincronizar con Simplenote")
        case .syncHelp:
            return ("Sync with Simplenote (⌘⇧S)", "Mit Simplenote synchronisieren (⌘⇧S)", "Synchroniser avec Simplenote (⌘⇧S)", "Sincronizza con Simplenote (⌘⇧S)", "Sincronizar con Simplenote (⌘⇧S)")
        case .menuNote:
            return ("Note", "Notiz", "Note", "Nota", "Nota")
        case .menuAbout:
            return ("About NoteIt", "Über NoteIt", "À propos de NoteIt", "Informazioni su NoteIt", "Acerca de NoteIt")
        case .menuWebsite:
            return ("NoteIt Website", "NoteIt-Website", "Site web de NoteIt", "Sito web di NoteIt", "Sitio web de NoteIt")
        case .sourceCodeOnGitHub:
            return ("Source Code on GitHub", "Quellcode auf GitHub", "Code source sur GitHub", "Codice sorgente su GitHub", "Código fuente en GitHub")
        case .contactFormat:
            return ("Contact: {0}", "Kontakt: {0}", "Contact\(nbsp): {0}", "Contatto: {0}", "Contacto: {0}")
        case .viewEdit:
            return ("Write", "Schreiben", "Écrire", "Scrivi", "Escribir")
        case .viewSplit:
            return ("Split", "Geteilt", "Partagé", "Diviso", "Dividido")
        case .viewPreview:
            return ("Preview", "Vorschau", "Aperçu", "Anteprima", "Vista previa")
        case .view:
            return ("View", "Ansicht", "Présentation", "Vista", "Vista")
        case .viewModeHelp:
            return ("Write · Split · Preview (⌘1 · ⌘2 · ⌘3)", "Schreiben · Geteilt · Vorschau (⌘1 · ⌘2 · ⌘3)", "Écrire · Partagé · Aperçu (⌘1 · ⌘2 · ⌘3)", "Scrivi · Diviso · Anteprima (⌘1 · ⌘2 · ⌘3)", "Escribir · Dividido · Vista previa (⌘1 · ⌘2 · ⌘3)")
        case .confirmTrashFormat:
            return ("Move “{0}” to the Trash?", "„{0}“ in den Papierkorb legen?", "Placer «\(nbsp){0}\(nbsp)» dans la corbeille\(nbsp)?", "Spostare “{0}” nel Cestino?", "¿Mover “{0}” a la papelera?")
        case .cancel:
            return ("Cancel", "Abbrechen", "Annuler", "Annulla", "Cancelar")
        case .error:
            return ("Error", "Fehler", "Erreur", "Errore", "Error")
        case .ok:
            return ("OK", "OK", "OK", "OK", "OK")

        case .noNotesTitle:
            return ("No Notes Yet", "Noch keine Notizen", "Aucune note pour l’instant", "Ancora nessuna nota", "Aún no hay notas")
        case .noNotesDescription:
            return ("Type a title above and press ⏎ – or click “New Note”.",
                    "Tippe oben einen Titel und drücke ⏎ – oder klicke auf „Neue Notiz“.",
                    "Saisissez un titre en haut et appuyez sur ⏎, ou cliquez sur «\(nbsp)Nouvelle note\(nbsp)».",
                    "Digita un titolo in alto e premi ⏎, oppure fai clic su “Nuova nota”.",
                    "Escribe un título arriba y pulsa ⏎, o haz clic en “Nueva nota”.")
        case .noMatchesTitle:
            return ("No Matches", "Keine Treffer", "Aucun résultat", "Nessun risultato", "Sin resultados")
        case .noMatchesDescriptionFormat:
            return ("Press ⏎ to create “{0}” as a new note.", "Mit ⏎ legst du „{0}“ als neue Notiz an.", "Appuyez sur ⏎ pour créer la note «\(nbsp){0}\(nbsp)».", "Premi ⏎ per creare la nota “{0}”.", "Pulsa ⏎ para crear la nota “{0}”.")
        case .createFormat:
            return ("Create “{0}”", "„{0}“ anlegen", "Créer «\(nbsp){0}\(nbsp)»", "Crea “{0}”", "Crear “{0}”")
        case .noteCountOne:
            return ("1 note", "1 Notiz", "1 note", "1 nota", "1 nota")
        case .noteCountOther:
            return ("{0} notes", "{0} Notizen", "{0} notes", "{0} note", "{0} notas")
        case .filteredCountFormat:
            return ("{0} of {1}", "{0} von {1}", "{0} sur {1}", "{0} di {1}", "{0} de {1}")
        case .noAdditionalText:
            return ("No additional text", "Kein weiterer Text", "Aucun texte supplémentaire", "Nessun altro testo", "Sin texto adicional")
        case .noSelectionTitle:
            return ("No Note Selected", "Keine Notiz ausgewählt", "Aucune note sélectionnée", "Nessuna nota selezionata", "Ninguna nota seleccionada")
        case .noSelectionDescription:
            return ("Select a note on the left or create a new one with ⌘N.",
                    "Wähle links eine Notiz aus oder lege mit ⌘N eine neue an.",
                    "Sélectionnez une note à gauche ou créez-en une avec ⌘N.",
                    "Seleziona una nota a sinistra o creane una nuova con ⌘N.",
                    "Selecciona una nota a la izquierda o crea una nueva con ⌘N.")
        case .titlePlaceholder:
            return ("Title", "Titel", "Titre", "Titolo", "Título")
        case .wordCountOne:
            return ("1 word", "1 Wort", "1 mot", "1 parola", "1 palabra")
        case .wordCountOther:
            return ("{0} words", "{0} Wörter", "{0} mots", "{0} parole", "{0} palabras")
        case .yesterday:
            return ("Yesterday", "Gestern", "Hier", "Ieri", "Ayer")
        case .todayAtFormat:
            return ("Today, {0}", "Heute, {0}", "Aujourd’hui, {0}", "Oggi, {0}", "Hoy, {0}")
        case .yesterdayAtFormat:
            return ("Yesterday, {0}", "Gestern, {0}", "Hier, {0}", "Ieri, {0}", "Ayer, {0}")
        case .searchPlaceholder:
            return ("Search, or type a title and press ⏎", "Suchen oder Titel eingeben und ⏎ drücken", "Rechercher, ou saisir un titre et appuyer sur ⏎", "Cerca, o digita un titolo e premi ⏎", "Busca, o escribe un título y pulsa ⏎")
        case .fontSystem:
            return ("System (SF Pro)", "System (SF Pro)", "Système (SF Pro)", "Sistema (SF Pro)", "Sistema (SF Pro)")
        case .fontSerif:
            return ("Serif (New York)", "Serif (New York)", "Serif (New York)", "Serif (New York)", "Serif (New York)")
        case .fontMono:
            return ("Monospaced (SF Mono)", "Festbreite (SF Mono)", "Chasse fixe (SF Mono)", "Monospaziato (SF Mono)", "Monoespaciada (SF Mono)")

        case .settingsGeneral:
            return ("General", "Allgemein", "Général", "Generali", "General")
        case .settingsStorage:
            return ("Storage", "Speicherort", "Stockage", "Archiviazione", "Almacenamiento")
        case .settingsAbout:
            return ("About", "Über", "À propos", "Info", "Acerca de")
        case .newNotesAs:
            return ("New notes as:", "Neue Notizen als:", "Nouvelles notes en\(nbsp):", "Nuove note come:", "Notas nuevas como:")
        case .formatMarkdown:
            return ("Markdown (.md)", "Markdown (.md)", "Markdown (.md)", "Markdown (.md)", "Markdown (.md)")
        case .formatText:
            return ("Plain text (.txt)", "Text (.txt)", "Texte brut (.txt)", "Testo semplice (.txt)", "Texto sin formato (.txt)")
        case .viewLabel:
            return ("View:", "Ansicht:", "Présentation\(nbsp):", "Vista:", "Vista:")
        case .fontLabel:
            return ("Font:", "Schrift:", "Police\(nbsp):", "Font:", "Fuente:")
        case .fontSizeFormat:
            return ("Font size: {0} pt", "Schriftgröße: {0} pt", "Taille de police\(nbsp): {0} pt", "Dimensione font: {0} pt", "Tamaño de fuente: {0} pt")
        case .narrowColumn:
            return ("Narrow text column (easier to read)", "Schmale Textspalte (angenehmer zu lesen)", "Colonne de texte étroite (plus lisible)", "Colonna di testo stretta (più leggibile)", "Columna de texto estrecha (más legible)")
        case .languageLabel:
            return ("Language:", "Sprache:", "Langue\(nbsp):", "Lingua:", "Idioma:")
        case .languageSystem:
            return ("System default", "Wie System", "Langue du système", "Lingua di sistema", "Idioma del sistema")
        case .languageRestartHint:
            return ("Some menus update after restarting NoteIt.", "Manche Menüs ändern sich erst nach einem Neustart von NoteIt.", "Certains menus sont mis à jour après le redémarrage de NoteIt.", "Alcuni menu si aggiornano dopo il riavvio di NoteIt.", "Algunos menús se actualizan tras reiniciar NoteIt.")
        case .notesFolder:
            return ("Notes Folder", "Notizordner", "Dossier des notes", "Cartella delle note", "Carpeta de notas")
        case .chooseOtherFolder:
            return ("Choose Another Folder…", "Anderen Ordner wählen …", "Choisir un autre dossier…", "Scegli un’altra cartella…", "Elegir otra carpeta…")
        case .storeInFormat:
            return ("Store in {0}", "In {0} speichern", "Enregistrer dans {0}", "Salva in {0}", "Guardar en {0}")
        case .cloudSyncTitle:
            return ("Sync with Dropbox and Google Drive", "Sync mit Dropbox und Google Drive", "Synchronisation avec Dropbox et Google Drive", "Sincronizzazione con Dropbox e Google Drive", "Sincronización con Dropbox y Google Drive")
        case .cloudSyncExplanation:
            return ("Every note is a plain .md or .txt file. Put the notes folder inside your Dropbox or Google Drive folder and the respective desktop app keeps your notes in sync with your other devices. NoteIt picks up outside changes immediately.",
                    "Jede Notiz ist eine normale .md- oder .txt-Datei. Legst du den Notizordner in deinen Dropbox- oder Google-Drive-Ordner, synchronisiert die jeweilige Desktop-App die Notizen automatisch mit deinen anderen Geräten. NoteIt erkennt Änderungen von außen sofort.",
                    "Chaque note est un simple fichier .md ou .txt. Placez le dossier des notes dans votre dossier Dropbox ou Google Drive\(nbsp): l’application de bureau correspondante synchronise vos notes avec vos autres appareils. NoteIt détecte immédiatement les modifications externes.",
                    "Ogni nota è un semplice file .md o .txt. Metti la cartella delle note nella cartella di Dropbox o Google Drive: l’app desktop corrispondente sincronizza le note con gli altri dispositivi. NoteIt rileva subito le modifiche esterne.",
                    "Cada nota es un simple archivo .md o .txt. Coloca la carpeta de notas dentro de tu carpeta de Dropbox o Google Drive y la app de escritorio correspondiente sincronizará tus notas con tus otros dispositivos. NoteIt detecta los cambios externos al instante.")
        case .noCloudFolderFound:
            return ("No Dropbox or Google Drive folder found. Install the service’s desktop app, then choose the folder.",
                    "Kein Dropbox- oder Google-Drive-Ordner gefunden. Installiere die Desktop-App des Dienstes und wähle dann den Ordner aus.",
                    "Aucun dossier Dropbox ou Google Drive trouvé. Installez l’application de bureau du service, puis choisissez le dossier.",
                    "Nessuna cartella Dropbox o Google Drive trovata. Installa l’app desktop del servizio e poi scegli la cartella.",
                    "No se encontró ninguna carpeta de Dropbox o Google Drive. Instala la app de escritorio del servicio y luego elige la carpeta.")
        case .choose:
            return ("Choose", "Auswählen", "Choisir", "Scegli", "Elegir")
        case .chooseFolderMessage:
            return ("Choose a folder for your notes", "Ordner für deine Notizen wählen", "Choisissez un dossier pour vos notes", "Scegli una cartella per le tue note", "Elige una carpeta para tus notas")
        case .signedInAs:
            return ("Signed in as", "Angemeldet als", "Connecté en tant que", "Accesso effettuato come", "Sesión iniciada como")
        case .autoSync:
            return ("Sync automatically (every 3 minutes and after changes)", "Automatisch synchronisieren (alle 3 Minuten und nach Änderungen)", "Synchroniser automatiquement (toutes les 3 minutes et après chaque modification)", "Sincronizza automaticamente (ogni 3 minuti e dopo le modifiche)", "Sincronizar automáticamente (cada 3 minutos y tras los cambios)")
        case .syncNow:
            return ("Sync Now", "Jetzt synchronisieren", "Synchroniser maintenant", "Sincronizza ora", "Sincronizar ahora")
        case .signOut:
            return ("Sign Out", "Abmelden", "Se déconnecter", "Esci", "Cerrar sesión")
        case .connectSimplenote:
            return ("Connect to Simplenote", "Mit Simplenote verbinden", "Se connecter à Simplenote", "Collega a Simplenote", "Conectar con Simplenote")
        case .email:
            return ("Email", "E-Mail", "E-mail", "E-mail", "Correo electrónico")
        case .password:
            return ("Password", "Passwort", "Mot de passe", "Password", "Contraseña")
        case .signIn:
            return ("Sign In", "Anmelden", "Se connecter", "Accedi", "Iniciar sesión")
        case .simplenoteExplanation:
            return ("The first line of a Simplenote note becomes the title (file name), the rest becomes the content. Your password is not stored – only an access token in the Keychain. Notes deleted in Simplenote are moved to the macOS Trash.",
                    "Die erste Zeile einer Simplenote-Notiz wird zum Titel (Dateiname), der Rest zum Inhalt. Das Passwort wird nicht gespeichert, nur ein Zugriffstoken im Schlüsselbund. In Simplenote gelöschte Notizen landen hier im Papierkorb von macOS.",
                    "La première ligne d’une note Simplenote devient le titre (nom du fichier), le reste devient le contenu. Votre mot de passe n’est pas enregistré\(nbsp): seul un jeton d’accès est conservé dans le trousseau. Les notes supprimées dans Simplenote sont placées dans la corbeille de macOS.",
                    "La prima riga di una nota di Simplenote diventa il titolo (nome del file), il resto diventa il contenuto. La password non viene salvata: nel portachiavi viene conservato solo un token di accesso. Le note eliminate in Simplenote vengono spostate nel Cestino di macOS.",
                    "La primera línea de una nota de Simplenote se convierte en el título (nombre del archivo) y el resto en el contenido. Tu contraseña no se guarda; solo se almacena un token de acceso en el llavero. Las notas eliminadas en Simplenote se mueven a la papelera de macOS.")
        case .versionFormat:
            return ("Version {0}", "Version {0}", "Version {0}", "Versione {0}", "Versión {0}")
        case .versionBuildFormat:
            return ("Version {0} ({1})", "Version {0} ({1})", "Version {0} ({1})", "Versione {0} ({1})", "Versión {0} ({1})")
        case .freeSoftwareGPL:
            return ("Free software under the GNU General Public License v3.0.", "Freie Software unter der GNU General Public License v3.0.", "Logiciel libre sous licence GNU General Public License v3.0.", "Software libero distribuito con licenza GNU General Public License v3.0.", "Software libre bajo la GNU General Public License v3.0.")
        case .freeSoftwarePrefix:
            return ("Free software ·", "Freie Software ·", "Logiciel libre ·", "Software libero ·", "Software libre ·")
        case .readLicense:
            return ("Read the license", "Lizenztext lesen", "Lire la licence", "Leggi la licenza", "Leer la licencia")
        case .tagline:
            return ("Fast notes in the spirit of nvALT.", "Schnelle Notizen im Stil von nvALT.", "Des notes rapides dans l’esprit de nvALT.", "Note veloci nello stile di nvALT.", "Notas rápidas al estilo de nvALT.")

        case .syncing:
            return ("Syncing…", "Synchronisiere …", "Synchronisation…", "Sincronizzazione…", "Sincronizando…")
        case .syncStatusFormat:
            return ("Simplenote: {0} · {1}", "Simplenote: {0} · {1}", "Simplenote\(nbsp): {0} · {1}", "Simplenote: {0} · {1}", "Simplenote: {0} · {1}")
        case .syncSessionExpired:
            return ("Simplenote: session expired – please sign in again in Settings", "Simplenote: Sitzung abgelaufen – bitte in den Einstellungen neu anmelden", "Simplenote\(nbsp): session expirée, veuillez vous reconnecter dans les réglages", "Simplenote: sessione scaduta, accedi di nuovo nelle impostazioni", "Simplenote: la sesión ha caducado, vuelve a iniciar sesión en los ajustes")
        case .syncErrorFormat:
            return ("Simplenote: {0}", "Simplenote: {0}", "Simplenote\(nbsp): {0}", "Simplenote: {0}", "Simplenote: {0}")
        case .keychainErrorFormat:
            return ("Keychain error: {0}", "Schlüsselbund-Fehler: {0}", "Erreur du trousseau\(nbsp): {0}", "Errore del portachiavi: {0}", "Error del llavero: {0}")
        case .welcomeTitle:
            return ("Welcome to NoteIt", "Willkommen bei NoteIt", "Bienvenue dans NoteIt", "Benvenuto in NoteIt", "Bienvenido a NoteIt")
        case .untitled:
            return ("Untitled", "Unbenannt", "Sans titre", "Senza titolo", "Sin título")
        case .noteNotFoundFormat:
            return ("The note “{0}” could not be found.", "Die Notiz „{0}“ wurde nicht gefunden.", "La note «\(nbsp){0}\(nbsp)» est introuvable.", "Impossibile trovare la nota “{0}”.", "No se encontró la nota “{0}”.")
        case .titleExistsFormat:
            return ("A note titled “{0}” already exists.", "Eine Notiz mit dem Titel „{0}“ existiert bereits.", "Une note intitulée «\(nbsp){0}\(nbsp)» existe déjà.", "Esiste già una nota con il titolo “{0}”.", "Ya existe una nota con el título “{0}”.")
        case .unreadableFileFormat:
            return ("The file “{0}” could not be read.", "Die Datei „{0}“ konnte nicht gelesen werden.", "Impossible de lire le fichier «\(nbsp){0}\(nbsp)».", "Impossibile leggere il file “{0}”.", "No se pudo leer el archivo “{0}”.")
        case .simplenoteInvalidCredentials:
            return ("Signing in to Simplenote failed. Please check your email and password.", "Anmeldung bei Simplenote fehlgeschlagen. Bitte E-Mail und Passwort prüfen.", "La connexion à Simplenote a échoué. Vérifiez votre e-mail et votre mot de passe.", "Accesso a Simplenote non riuscito. Controlla e-mail e password.", "No se pudo iniciar sesión en Simplenote. Comprueba tu correo electrónico y tu contraseña.")
        case .simplenoteUnauthorized:
            return ("Your Simplenote session has expired. Please sign in again.", "Die Simplenote-Sitzung ist abgelaufen. Bitte erneut anmelden.", "Votre session Simplenote a expiré. Veuillez vous reconnecter.", "La sessione di Simplenote è scaduta. Accedi di nuovo.", "Tu sesión de Simplenote ha caducado. Vuelve a iniciar sesión.")
        case .simplenoteServerErrorFormat:
            return ("Simplenote server error ({0}){1}", "Simplenote-Serverfehler ({0}){1}", "Erreur du serveur Simplenote ({0}){1}", "Errore del server Simplenote ({0}){1}", "Error del servidor de Simplenote ({0}){1}")
        case .simplenoteInvalidResponse:
            return ("Unexpected response from the Simplenote server.", "Unerwartete Antwort vom Simplenote-Server.", "Réponse inattendue du serveur Simplenote.", "Risposta inattesa dal server Simplenote.", "Respuesta inesperada del servidor de Simplenote.")
        case .syncReceivedFormat:
            return ("{0} received", "{0} empfangen", "{0} reçue(s)", "{0} ricevute", "{0} recibidas")
        case .syncSentFormat:
            return ("{0} sent", "{0} gesendet", "{0} envoyée(s)", "{0} inviate", "{0} enviadas")
        case .syncDeletedFormat:
            return ("{0} deleted", "{0} gelöscht", "{0} supprimée(s)", "{0} eliminate", "{0} eliminadas")
        case .syncConflictsFormat:
            return ("{0} conflict(s)", "{0} Konflikt(e)", "{0} conflit(s)", "{0} conflitti", "{0} conflictos")
        case .syncErrorsFormat:
            return ("{0} error(s)", "{0} Fehler", "{0} erreur(s)", "{0} errori", "{0} errores")
        case .syncUpToDate:
            return ("Up to date", "Alles aktuell", "À jour", "Tutto aggiornato", "Todo al día")
        case .conflictSuffix:
            return (" (Conflict)", " (Konflikt)", " (conflit)", " (conflitto)", " (conflicto)")
        case .changedDuringSyncFormat:
            return ("“{0}” was changed during sync and will be reconciled next time.", "„{0}“ wurde während der Synchronisation geändert und wird beim nächsten Mal abgeglichen.", "«\(nbsp){0}\(nbsp)» a été modifiée pendant la synchronisation et sera rapprochée la prochaine fois.", "“{0}” è stata modificata durante la sincronizzazione e verrà allineata la prossima volta.", "“{0}” se modificó durante la sincronización y se conciliará la próxima vez.")
        }
    }
}
