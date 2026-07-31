# NoteDroppy

NoteDroppy adiciona uma tarefa à nota diária do NotePlan a partir do Dock, de um Serviço do macOS ou de um atalho global.

## Uso

- Arraste uma URL para o ícone no Dock.
- Arraste um arquivo `.webloc`, `.url`, `.txt`, `.md`, `.rtf` ou `.textclipping`.
- Use o Serviço do macOS para texto selecionado.
- Use o atalho global quando o Serviço não estiver disponível.

Formato enviado:

```text
- [ ] <conteúdo> #capture
```

## Instalação

```zsh
scripts/install-notedroppy.sh
```

Pacote instalável:

```text
releases/NoteDroppy-v1.22.zip
```

## Limite do macOS

O Dock não transmite texto selecionado de forma confiável para apps.

Para texto selecionado, use o Serviço do macOS ou o atalho global.
