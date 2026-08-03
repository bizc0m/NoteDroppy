#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/outputs/NoteDroppy.app/Contents/Info.plist")}"
APP="$ROOT_DIR/outputs/NoteDroppy.app"
RELEASE_DIR="$ROOT_DIR/releases"
PACKAGE_DIR="$RELEASE_DIR/NoteDroppy-v${VERSION}"
ZIP="$RELEASE_DIR/NoteDroppy-v${VERSION}.zip"
SIGN_IDENTITY="${NOTEDROPPY_CODESIGN_IDENTITY:-NoteDroppy Local Code Signing}"

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  SIGN_IDENTITY="-"
fi

if [[ ! -d "$APP" ]]; then
  echo "App introuvable: $APP" >&2
  exit 1
fi

mkdir -p "$RELEASE_DIR"
rm -rf "$PACKAGE_DIR" "$ZIP" "$RELEASE_DIR/NoteDroppy-v${VERSION}.sha256"
xattr -cr "$APP" 2>/dev/null || true
codesign --force --deep --options runtime -s "$SIGN_IDENTITY" "$APP"

mkdir -p "$PACKAGE_DIR"
ditto --norsrc --noextattr "$APP" "$PACKAGE_DIR/NoteDroppy.app"
if [[ -d "$ROOT_DIR/examples" ]]; then
  ditto --norsrc --noextattr "$ROOT_DIR/examples" "$PACKAGE_DIR/examples"
fi
cat > "$PACKAGE_DIR/install-notedroppy.sh" <<'EOF'
#!/bin/zsh
set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_SRC="$PACKAGE_DIR/NoteDroppy.app"
APP_DST="/Applications/NoteDroppy.app"
BACKUP_DIR="$HOME/Library/Application Support/NoteDroppy/backups"
SIGN_IDENTITY="${NOTEDROPPY_CODESIGN_IDENTITY:-NoteDroppy Local Code Signing}"

if [[ ! -d "$APP_SRC" ]]; then
  echo "NoteDroppy.app introuvable dans le paquet: $APP_SRC" >&2
  exit 1
fi

if ! security find-identity -v -p codesigning | grep -Fq "\"$SIGN_IDENTITY\""; then
  SIGN_IDENTITY="-"
fi

if [[ -d "$APP_DST" ]]; then
  mkdir -p "$BACKUP_DIR"
  mv "$APP_DST" "$BACKUP_DIR/NoteDroppy.app.previous-$(date +%Y%m%d-%H%M%S).bundle-backup"
fi

ditto --norsrc --noextattr "$APP_SRC" "$APP_DST"
xattr -cr "$APP_DST" 2>/dev/null || true
codesign --force --deep --options runtime -s "$SIGN_IDENTITY" "$APP_DST"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP_DST"
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
/System/Library/CoreServices/pbs -update 2>/dev/null || true

echo "Installed: $APP_DST"
EOF
chmod +x "$PACKAGE_DIR/install-notedroppy.sh"

cat > "$PACKAGE_DIR/INSTALL.md" <<'EOF'
# NoteDroppy Install

## Install

Double-click `NoteDroppy.app`, or copy it to `/Applications`.

For a scripted install, run:

```zsh
./install-notedroppy.sh
```

The app is installed here:

```text
/Applications/NoteDroppy.app
```

## macOS Gatekeeper

This package is signed locally or ad-hoc. It is not Apple-notarized.

If macOS blocks the first launch:

1. Open System Settings.
2. Go to Privacy & Security.
3. Approve opening NoteDroppy, or right-click `NoteDroppy.app` and choose Open.

## Accessibility

The global shortcut needs Accessibility permission:

System Settings -> Privacy & Security -> Accessibility -> enable `NoteDroppy`.

Dock URL/file drops and NotePlan URL sending do not need Accessibility. Selected-text capture with the global shortcut does.
EOF

cat > "$PACKAGE_DIR/INSTALL.fr.md" <<'EOF'
# Installation NoteDroppy

## Installer

Double-cliquer `NoteDroppy.app`, ou copier l'app dans `/Applications`.

Pour installer par script:

```zsh
./install-notedroppy.sh
```

L'app est installee ici:

```text
/Applications/NoteDroppy.app
```

## Gatekeeper macOS

Ce paquet est signe localement ou en ad-hoc. Il n'est pas notarise par Apple.

Si macOS bloque le premier lancement:

1. Ouvrir Reglages Systeme.
2. Aller dans Confidentialite et securite.
3. Autoriser l'ouverture de NoteDroppy, ou clic droit sur `NoteDroppy.app` puis Ouvrir.

## Accessibilite

Le raccourci global a besoin de l'autorisation Accessibilite:

Reglages Systeme -> Confidentialite et securite -> Accessibilite -> activer `NoteDroppy`.

Les drops URL/fichiers vers le Dock et l'envoi NotePlan n'ont pas besoin d'Accessibilite. La capture du texte selectionne par raccourci global en a besoin.
EOF

COPYFILE_DISABLE=1 ditto -c -k --norsrc --noextattr "$PACKAGE_DIR" "$ZIP"
(cd "$RELEASE_DIR" && shasum -a 256 "NoteDroppy-v${VERSION}.zip" > "NoteDroppy-v${VERSION}.sha256")

echo "$ZIP"
