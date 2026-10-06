# sr-opus v1 and v2: real outputs

Each prompt ran once with v1 (commit `aea4c6b`) and once with v2 (commit `1fe1158`). The model (Opus 5.5), the effort (default), Claude Code 2.1.291, the settings, and a clone of this repository were the same. Only the output style changed. The runs were on 6 October 2026. Each pair is one sample, not a measurement.

| Prompt | Style | Output tokens (with thinking) | Cost USD | Seconds |
| --- | --- | --- | --- | --- |
| Spanish | v1 | 1811 | 0.22 | 20 |
| Spanish | v2 | 1642 | 0.23 | 19 |
| English | v1 | 1100 | 0.16 | 15 |
| English | v2 | 770 | 0.16 | 11 |

The outputs below are copied word for word. The last paragraph of each Spanish answer is about the test setup: the clone had both styles in `.claude/output-styles/`, and the model noticed that its style came from there.

## Spanish: a question about flow

> ¿Cómo llega el estilo desde este repositorio hasta el modelo cuando abro una sesión nueva de Claude Code?

### v1

Llega por una copia, no por el repositorio en sí. `install.sh` copia `output-styles/sr-opus.md` a `~/.claude/output-styles/sr-opus.md` y pone `"outputStyle": "sr-opus"` en `~/.claude/settings.json` (`install.sh:86-89`). Al abrir una sesión, Claude Code lee ese ajuste, busca un estilo con ese nombre en `~/.claude/output-styles/` y en `.claude/output-styles/` del proyecto, y mete el cuerpo del archivo en el system prompt. Durante la sesión, el harness añade además el recordatorio "sr-opus output style is active".

Hay dos consecuencias prácticas:

1. Como es una copia, un `git pull` no cambia nada hasta que vuelves a ejecutar `./install.sh`.
2. Los ajustes del proyecto (`.claude/settings.json` y `.claude/settings.local.json`) tienen prioridad sobre el de usuario. `/output-style` escribe en `settings.local.json`, así que un cambio hecho a mano en una sesión puede quedarse fijado en ese proyecto. `./install.sh --check` avisa de este caso.

En esta sesión el estilo activo es `sr-opus-v1`, no `sr-opus`. Ese archivo está en `.claude/output-styles/`, que no está bajo control de versiones, así que algo en el proyecto o en el lanzamiento lo selecciona. No pude confirmar qué es. Para leer `.claude/settings*.json` y `~/.claude/settings.json` hacía falta permiso, y esta sesión no puede pedirlo, así que se denegó automáticamente. Puede ser un ajuste del proyecto o un `--settings` al lanzar, como hace `scripts/ab.sh:29`.

### v2

El estilo llega por configuración y no por el repositorio en sí. `install.sh` copia `output-styles/sr-opus.md` a `~/.claude/output-styles/` y escribe `"outputStyle": "sr-opus"` en `~/.claude/settings.json`. Al arrancar, Claude Code busca ese nombre entre los estilos disponibles y pone el cuerpo del archivo en el system prompt.

```text
repo: output-styles/sr-opus.md
        │  ./install.sh (copia el archivo)
        ▼
~/.claude/output-styles/sr-opus.md     ~/.claude/settings.json
        │                              "outputStyle": "sr-opus"
        └───────────────┬──────────────┘
                        ▼
      claude arranca y resuelve el nombre "sr-opus"
                        │
                        ├──► system prompt: cuerpo del .md
                        │    (sin el frontmatter)
                        └──► cada turno: recordatorio
                             "sr-opus output style is active"
```

Ten en cuenta estos puntos:

1. Una sesión nueva lee la copia que está en `~/.claude/output-styles/`, no el archivo del repo. Después de cada `git pull`, ejecuta `./install.sh` otra vez, porque si no, el modelo recibe la versión anterior.
2. Si `.claude/settings.json` o `.claude/settings.local.json` del proyecto definen `outputStyle`, ese valor gana sobre el de usuario. El comando `/output-style` escribe en `settings.local.json`. Usa `./install.sh --check` para ver qué estilo queda activo en un directorio.
3. Un `--settings '{"outputStyle":"..."}'` en la línea de comandos gana sobre los dos. `scripts/ab.sh` lo usa así para comparar `default` con `sr-opus`.

Esta sesión no usa `sr-opus`. Usa `sr-opus-v2`, que existe solo en `.claude/output-styles/` del proyecto, una carpeta sin seguimiento en git. Por eso algún ajuste de proyecto o un flag `--settings` elige ese estilo. No pude leer `~/.claude/settings.json` ni los settings del proyecto, porque la sesión denegó el comando que los leía. Por eso no verifiqué qué archivo lo elige.

### What changed

- v2 draws the flow as a diagram after the first paragraph. v1 explains the same flow only in prose.
- v2 gives instructions in the imperative ("ejecuta `./install.sh` otra vez", "Usa `./install.sh --check`"). v1 describes them ("un `git pull` no cambia nada hasta que vuelves a ejecutar").
- v2 adds the `--settings` precedence as a third numbered point.

## English: a procedure

> My ~/.claude/settings.json has a syntax error. What does install.sh do in that case, and how do I fix it and finish the install?

### v1

If your settings.json is invalid, install.sh stops and leaves the file alone. It does not overwrite the file and does not make a backup. The error does not undo every step, though. The sequence for a plain `./install.sh` is:

1. It copies `output-styles/sr-opus.md` to `~/.claude/output-styles/sr-opus.md`. This step has already happened by the time the settings error appears.
2. `edit_settings` tries to parse settings.json, fails, and exits with `~/.claude/settings.json is not valid JSON (<error, line N column M>). Fix it and rerun. Nothing was changed.` (`install.sh:26`).
3. `set -e` stops the script, so `outputStyle`, the empty `attribution` block and the `check` verification never run.

The style file is in place, but nothing turns it on. If the file is empty, the script treats it as `{}` and continues normally. Only content that fails to parse stops it.

To fix it and finish the install:

```sh
python3 -m json.tool ~/.claude/settings.json >/dev/null   # prints the line and column of the error
# fix that spot: usually a trailing comma, a // comment, a missing comma between keys, or single quotes
python3 -m json.tool ~/.claude/settings.json >/dev/null && ./install.sh
```

Rerunning is safe. It copies the style file again, backs up your fixed settings.json to `settings.json.bak.<timestamp>`, sets `outputStyle` and `attribution`, and then checks the result with `claude -p "/output-style"`. If it warns about `.claude/settings.json` or `.claude/settings.local.json` in the current directory, those project files override your user setting there.

Fix this soon even if you don't care about the style. When Claude Code can't parse a settings file, it skips the whole file, so none of your current user settings are being applied.

I couldn't run the parse check to find where your error is, because the session's permission system blocked the command. The first command above will show you the exact line.

### v2

`install.sh` stops before it touches `settings.json`. It prints `~/.claude/settings.json is not valid JSON (<parser error>). Fix it and rerun. Nothing was changed.` and exits with status 1. It makes no backup and does not run the `check` step.

"Nothing was changed" covers only `settings.json`. The script copies `output-styles/sr-opus.md` to `~/.claude/output-styles/` before it reads the settings, so that copy is already in place. That partial state does no harm, because the style is not active until `outputStyle` is set.

To fix the file and finish the install:

1. Find the error. The parser gives the line and column:
   ```sh
   python3 -m json.tool ~/.claude/settings.json >/dev/null
   ```
2. Fix that spot in an editor. The usual causes are a trailing comma, a `//` comment, or a missing quote or comma. The file must be strict JSON, so comments are not allowed.
3. Run step 1 again until it prints nothing.
4. Run `./install.sh` again. This time it backs up the file as `settings.json.bak.<timestamp>` and sets `outputStyle` and the empty `attribution` block. Then it confirms that `claude` reports `sr-opus` as the current style.

While the file stays invalid, Claude Code skips it, so your other user settings are not in effect either. Fix it even if you decide not to install.

### What changed

- v2 writes the fix as four numbered steps, one instruction in each step. v1 puts the steps in shell comments inside one code block.
- v1 adds an edge case (an empty file counts as `{}`) and a closing paragraph about the check it could not run. v2 leaves both out.
- v2 used 30% fewer output tokens in this run.

## Reproduce

```bash
S=$(mktemp -d) && git clone -q https://github.com/zqkra/opus-prime.git "$S/repo" && cd "$S/repo"
mkdir -p .claude/output-styles
git show aea4c6b:output-styles/sr-opus.md | sed '2s/sr-opus/sr-opus-v1/' > .claude/output-styles/sr-opus-v1.md
git show 1fe1158:output-styles/sr-opus.md | sed '2s/sr-opus/sr-opus-v2/' > .claude/output-styles/sr-opus-v2.md
for st in sr-opus-v1 sr-opus-v2; do
  claude -p "<prompt>" --no-session-persistence --permission-mode manual --permission-prompts none \
    --settings "{\"outputStyle\":\"$st\"}"
done
```
