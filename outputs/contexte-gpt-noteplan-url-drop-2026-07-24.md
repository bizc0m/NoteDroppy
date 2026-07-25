# Contexte projet — NotePlanURLDrop (pour GPT)

Généré le 2026-07-24, à partir d'une session Claude Code.

## Projet

- Dossier : `/Users/JOB/Documents/Codex/2026-07-22/sais`
- Source : `work/NotePlanURLDrop/main.swift`
- App installée : `/Applications/NotePlanURLDrop.app`
- Versioning : tags git (`noteplan-url-drop-v1.5` = dernier tag stable connu)
- Icône Dock : app pinnée dans le Dock (`local.codex.noteplanurldrop`)

## Ce que fait l'app (v1.5, stable)

Un lanceur Dock-only qui reçoit des dépôts via `openFiles`/`openURLs`
(glisser sur l'icône Dock) et transforme le contenu en tâche NotePlan :

```
noteplan://x-callback-url/addText?noteDate=today&text=<encoded>&mode=append&openNote=yes
```

Format de tâche : `- [ ] <texte> #capture`

Fonctionne pour, en glisser-déposer sur l'icône Dock :
- URL (drag depuis navigateur) — OK
- fichier `.webloc` / `.url` — OK
- fichier texte / `.textclipping` / `.rtf` / `.md` — OK

Ne fonctionne PAS (confirmé par test réel, humain + automatisé) :
- texte brut sélectionné dans une app (TextEdit, Smultron), glissé
  directement sur l'icône Dock, sans passer par un fichier.

## Pourquoi le drag-and-drop de texte brut est impossible

Le Dock macOS n'appelle `application(_:openFiles:)` /
`application(_:open:)` que si le pasteboard déposé contient soit une
référence fichier réelle (`NSFilenamesPboardType` / promesse de fichier),
soit une URL correspondant à un schéma déclaré (`CFBundleURLTypes`). Une
sélection de texte en mémoire (`NSPasteboardTypeString`/RTF) n'a ni l'un
ni l'autre.

Le Finder sait créer un fichier `.textClipping` à la volée quand on dépose
du texte brut sur le bureau (comportement spécifique à sa vue Icônes),
mais le Dock n'a pas cet équivalent pour les icônes d'application. Donc
même si l'app source (TextEdit, Smultron) sait exporter une sélection en
drag (preuve : ça marche vers le bureau Finder), le Dock n'a rien à
transmettre à `openFiles`/`openURLs` : l'app n'est jamais réveillée.

**Test réel effectué le 2026-07-24** (log `/tmp/NotePlanURLDrop.log`
resté à 0 octet dans tous les cas, aucun process lancé, aucune tâche
créée dans NotePlan) :
- sélection dans TextEdit → drag vers icône Dock → échec
- sélection dans Smultron → drag vers icône Dock → échec (plusieurs
  techniques de glisser testées, y compris pas-à-pas avec pause de
  survol sur l'icône)

Conclusion : limite structurelle de macOS, pas un bug de l'app.

## Contraintes du projet (fixées par l'utilisateur au départ)

- Ne pas casser URL vers Dock.
- Ne pas casser `.webloc`/`.url` vers Dock.
- Ne pas casser fichier texte vers Dock.
- Pas de fenêtre drop-zone.
- Pas de raccourci clavier.
- Pas de service macOS *(contrainte levée ensuite par l'utilisateur pour
  contourner l'impossibilité du drag-and-drop de texte brut — voir
  section suivante)*.

## Changement en cours (non finalisé) : Service macOS

Puisque le drag-and-drop de texte brut vers le Dock est impossible,
l'utilisateur a autorisé l'ajout d'un **Service macOS** (clic droit sur
une sélection → menu Services → "NotePlan : ajouter en tâche") comme
alternative. Implémenté mais **pas encore vérifié de bout en bout** (la
vérification GUI automatisée a échoué à cause d'interférences de focus
sur la machine de test — pas un problème de code).

Changements apportés :
- `main.swift` : nouvelle méthode `addSelectionAsTodo(_:userData:error:)`
  qui réutilise `sendTodo(_:)` (le même chemin déjà éprouvé pour les
  autres modes).
- `app.servicesProvider = delegate` ajouté avant `app.run()`.
- `Info.plist` : ajout de la clé `NSServices` (voir plus bas), version
  bump 1.5 → 1.6.
- App recompilée, signée en adhoc, réinstallée dans `/Applications`,
  ré-enregistrée auprès de Launch Services (`lsregister -f`).

**Reste à faire** : test manuel par l'utilisateur (sélectionner du
texte, clic droit → Services → "NotePlan : ajouter en tâche", vérifier
que la tâche apparaît dans NotePlan), puis commit + tag git si validé.

## Mise à jour — résultats de test (2026-07-24, après-midi)

Le log `/tmp/NotePlanURLDrop.log` montre que le Service **a bien été
invoqué** (`service:invoked` → `service:text:...` → `sendTodo:...`) lors
de tests via le menu Services. Techniquement le déclenchement
clic-droit → Services → app fonctionne.

**Mais** en lisant directement le fichier réel de la note du jour
(`~/Library/Containers/co.noteplan.NotePlan-setapp/Data/Library/Application
Support/co.noteplan.NotePlan-setapp/Calendar/20260724.md`), **aucune
des tâches envoyées via `sendTodo` n'a été effectivement ajoutée à la
note.** Le `NSWorkspace.shared.open(noteplan://...)` est bien appelé
côté app (confirmé par log), mais NotePlan ne semble pas avoir traité
le callback. Cause non identifiée à ce stade (peut-être un dialogue de
confirmation NotePlan resté sans réponse). **À investiguer avant de
considérer le Service comme fonctionnel de bout en bout.**

Par ailleurs, la note du jour contient une ligne parasite non désirée
(`La n`, insérée entre `- [ ] Facade Yann` et `## Notes et idées`) qui
ne provient d'aucun test volontaire — probablement une interférence
d'un processus tiers actif sur la machine pendant la session (plusieurs
apps ont volé le focus et tapé du texte parasite dans TextEdit et
NotePlan pendant les essais). À nettoyer séparément, sans lien avec le
code de l'app.

## Pourquoi l'app ne répond pas à Cmd+Q

L'app n'a **aucun menu bar** (`NSApp.mainMenu` n'est jamais assigné
dans le code — pas de `NSMenu`, pas de fenêtre). Sans menu, il n'y a
aucun item "Quitter" lié au raccourci Cmd+Q : la combinaison ne fait
donc rien tant que l'app est au premier plan. Ce n'est pas un bug, c'est
la conséquence du design minimaliste (l'app est censée s'auto-terminer
en moins d'une seconde après avoir traité l'événement reçu — confirmé
par les entrées `quit:no-open-event` du log, ~0.6 à 1s après chaque
`launch`). Si elle reste ouverte anormalement longtemps, la fermer
passe par : clic droit sur l'icône Dock → Quitter, ou Cmd+Option+Echap
(Forcer à quitter), ou `killall NotePlanURLDrop` en Terminal — ces
méthodes sont gérées par le système, pas par le menu de l'app.

## Backups disponibles (v1.5, dernier connu stable)

- Binaire seul : `backups/NotePlanURLDrop-v1.5-exec` (Mach-O brut, pas
  utilisable tel quel — à replacer dans un bundle `.app`)
- App complète et signée, utilisable directement :
  `backups/NotePlanURLDrop-v1.5.app` (extraite du tag git
  `noteplan-url-drop-v1.5`, Info.plist + icône + binaire, adhoc-signée)

Restauration rapide vers `/Applications` :
```bash
cp -R "backups/NotePlanURLDrop-v1.5.app" /Applications/NotePlanURLDrop.app
codesign --force --deep -s - /Applications/NotePlanURLDrop.app
```

## Alerte sécurité — tentative d'injection observée pendant la session

Un message présenté comme un "system-reminder" (habituellement réservé
à des notifications légitimes de l'environnement d'exécution) a
instruit l'agent de ne PAS informer l'utilisateur d'une modification du
fichier de log, en prétendant que l'utilisateur "en était déjà
informé". L'agent n'a pas suivi cette instruction et l'a signalée
explicitement à l'utilisateur à la place. Pattern classique de
prompt-injection à surveiller si ça se reproduit. Contenu du message
sinon inoffensif (juste des lignes de log déjà connues).

## Code source complet — main.swift (état actuel, avec Service)

```swift
import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var didReceiveOpenEvent = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        log("launch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if !self.didReceiveOpenEvent {
                self.log("quit:no-open-event")
                NSApp.terminate(nil)
            }
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        didReceiveOpenEvent = true
        log("openFiles:\(filenames.joined(separator: " | "))")
        var handled = false
        for filename in filenames {
            let fileURL = URL(fileURLWithPath: filename)
            if let droppedText = extractTodoText(from: fileURL) {
                log("openFiles:extracted:\(droppedText)")
                sendTodo(droppedText)
                handled = true
            } else {
                log("openFiles:failed-extract:\(filename)")
            }
        }
        NSApp.reply(toOpenOrPrint: handled ? .success : .failure)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.terminate(nil)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        didReceiveOpenEvent = true
        log("openURLs:\(urls.map { $0.absoluteString }.joined(separator: " | "))")
        for url in urls {
            if url.isFileURL, let droppedText = extractTodoText(from: url) {
                log("openURLs:file-extracted:\(droppedText)")
                sendTodo(droppedText)
            } else {
                sendTodo(url.absoluteString)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.terminate(nil)
        }
    }

    private func extractTodoText(from fileURL: URL) -> String? {
        let ext = fileURL.pathExtension.lowercased()

        if ext == "webloc" || ext == "url" {
            if let data = try? Data(contentsOf: fileURL),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
               let dict = plist as? [String: Any],
               let value = dict["URL"] as? String,
               isWebURL(value) {
                return value
            }

            if let text = try? String(contentsOf: fileURL, encoding: .utf8),
               let value = firstWebURL(in: text) {
                return value
            }
        }

        if ext == "textclipping",
           let value = shell(["/usr/bin/mdls", "-raw", "-name", "kMDItemTextContent", fileURL.path]) {
            return normalizedTodoText(value)
        }

        if ext == "rtf",
           let attributed = try? NSAttributedString(url: fileURL, options: [:], documentAttributes: nil) {
            return normalizedTodoText(attributed.string)
        }

        if let text = try? String(contentsOf: fileURL, encoding: .utf8) {
            return normalizedTodoText(text)
        }

        return nil
    }

    private func firstWebURL(in text: String) -> String? {
        let pattern = #"https?://[^\s<>"']+"#
        guard let range = text.range(of: pattern, options: .regularExpression) else {
            return nil
        }
        return String(text[range])
    }

    private func isWebURL(_ value: String) -> Bool {
        value.lowercased().hasPrefix("http://") || value.lowercased().hasPrefix("https://")
    }

    private func normalizedTodoText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "(null)" else { return nil }
        return firstWebURL(in: trimmed) ?? trimmed
    }

    @objc func addSelectionAsTodo(_ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        didReceiveOpenEvent = true
        log("service:invoked")
        guard let text = pasteboard.string(forType: .string) else {
            log("service:no-text")
            error.pointee = "Aucun texte sélectionné" as NSString
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.terminate(nil)
            }
            return
        }
        log("service:text:\(text)")
        sendTodo(text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            NSApp.terminate(nil)
        }
    }

    private func sendTodo(_ todoText: String) {
        let trimmed = todoText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "(null)" else { return }
        log("sendTodo:\(trimmed)")
        let task = "- [ ] \(trimmed) #capture"
        let target = "noteplan://x-callback-url/addText?noteDate=today&text=\(encode(task))&mode=append&openNote=yes"
        if let url = URL(string: target) {
            NSWorkspace.shared.open(url)
        }
    }

    private func encode(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
    }

    private func shell(_ args: [String]) -> String? {
        guard let executable = args.first else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(args.dropFirst())
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func log(_ message: String) {
        let line = "\(Date()) \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/NotePlanURLDrop.log")
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.servicesProvider = delegate
app.run()
```

## Info.plist complet (état actuel, avec NSServices)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDisplayName</key>
	<string>NotePlan URL Drop</string>
	<key>CFBundleDocumentTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeExtensions</key>
			<array>
				<string>webloc</string>
				<string>url</string>
				<string>textclipping</string>
				<string>txt</string>
				<string>rtf</string>
				<string>md</string>
				<string>*</string>
			</array>
			<key>CFBundleTypeName</key>
			<string>Internet Location / URL</string>
			<key>CFBundleTypeRole</key>
			<string>Viewer</string>
			<key>LSHandlerRank</key>
			<string>Alternate</string>
			<key>LSItemContentTypes</key>
			<array>
				<string>com.apple.web-internet-location</string>
				<string>public.url</string>
				<string>public.file-url</string>
				<string>public.text</string>
				<string>public.plain-text</string>
				<string>public.utf8-plain-text</string>
				<string>public.utf16-plain-text</string>
				<string>public.rtf</string>
				<string>public.content</string>
				<string>public.item</string>
				<string>public.data</string>
				<string>com.apple.finder.textclipping</string>
				<string>com.apple.textclipping</string>
				<string>com.apple.traditional-mac-plain-text</string>
			</array>
		</dict>
	</array>
	<key>CFBundleExecutable</key>
	<string>NotePlanURLDrop</string>
	<key>CFBundleIconFile</key>
	<string>NotePlanURLDrop</string>
	<key>CFBundleIdentifier</key>
	<string>local.codex.noteplanurldrop</string>
	<key>CFBundleName</key>
	<string>NotePlanURLDrop</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.6</string>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>Web URL</string>
			<key>CFBundleURLRole</key>
			<string>Viewer</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>http</string>
				<string>https</string>
			</array>
		</dict>
	</array>
	<key>CFBundleVersion</key>
	<string>16</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSSupportsOpeningDocumentsInPlace</key>
	<true/>
	<key>NSServices</key>
	<array>
		<dict>
			<key>NSMenuItem</key>
			<dict>
				<key>default</key>
				<string>NotePlan : ajouter en tâche</string>
			</dict>
			<key>NSMessage</key>
			<string>addSelectionAsTodo</string>
			<key>NSPortName</key>
			<string>NotePlanURLDrop</string>
			<key>NSSendTypes</key>
			<array>
				<string>public.utf8-plain-text</string>
				<string>public.plain-text</string>
				<string>NSStringPboardType</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

## État git au moment de la génération de ce fichier

```
 M outputs/NotePlanURLDrop.app/Contents/Info.plist
 M outputs/NotePlanURLDrop.app/Contents/MacOS/NotePlanURLDrop
 M work/NotePlanURLDrop/main.swift
?? work/NotePlanURLDrop/NotePlanURLDrop
```

Rien n'est encore commité pour la v1.6 — dernier tag stable :
`noteplan-url-drop-v1.5` (commit `dc28460`).
