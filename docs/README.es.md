# NoteDroppy

NoteDroppy añade una tarea a la nota diaria de NotePlan desde el Dock, un Servicio de macOS o un atajo global.

## Uso

- Arrastra una URL al icono del Dock.
- Arrastra un archivo `.webloc`, `.url`, `.txt`, `.md`, `.rtf` o `.textclipping`.
- Usa el Servicio de macOS para texto seleccionado.
- Usa el atajo global cuando el Servicio no esté disponible.

Formato enviado:

```text
- [ ] <contenido> #capture
```

## Instalación

```zsh
scripts/install-notedroppy.sh
```

Paquete instalable:

```text
releases/NoteDroppy-v1.22.zip
```

## Límite de macOS

El Dock no transmite de forma fiable el texto seleccionado a las apps.

Para texto seleccionado, usa el Servicio de macOS o el atajo global.
