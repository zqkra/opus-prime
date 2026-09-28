<div align="center">

# opus-prime

**`sr-opus`: a senior-engineer output style for Claude Opus 5.5**

One file, [`output-styles/sr-opus.md`](output-styles/sr-opus.md), that turns Opus 5.5 inside Claude Code into a precise senior engineer: answer first, no verbal tics, reference codes, strict scope, no early stops on long runs.

It applies everywhere the `claude` CLI runs: terminal, IDE, desktop, Agent SDK.

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

</div>

## Install

```bash
git clone https://github.com/zqkra/opus-prime.git
cd opus-prime
./install.sh
```

The script copies the style to `~/.claude/output-styles/sr-opus.md`, sets `"outputStyle": "sr-opus"` in `~/.claude/settings.json`, disables the `Co-Authored-By` trailer through `attribution`, keeps a timestamped backup of your previous settings, and verifies with `claude -p "/output-style"`. It refuses to write if your settings.json is not valid JSON, because Claude Code discards a settings file that fails to parse.

| Command | What it does |
| --- | --- |
| `./install.sh` | Install or update, then verify. Run it again after every `git pull`. |
| `./install.sh --check` | Report which style is actually active in the current directory, and warn if a project settings file overrides it. |
| `./install.sh --uninstall` | Remove the style and the `outputStyle` key. Leaves `attribution` in place and tells you. |

Manual equivalent:

```bash
mkdir -p ~/.claude/output-styles
cp output-styles/sr-opus.md ~/.claude/output-styles/
# merge settings.example.json into ~/.claude/settings.json
claude -p "/output-style"   # should list: - sr-opus (current)
```

## Why an output style

This repo is an evolution of [`disler/fixing-smartass-opus-5`](https://github.com/disler/fixing-smartass-opus-5) (MIT, IndyDevDan). It keeps that structure (Positive/Negative Patterns, Reference Points, Hard Boundaries, Aliases, Examples) and updates it with what Anthropic documents about Opus 5.5 behavior and what Claude Code 2.1.283 actually sends to the model.

The original runs through `claude --append-system-prompt-file` from a `justfile`, so it only applies to sessions you launch with that command. The Claude Code docs assign output styles exactly this job ("every response in a certain voice, length, or format"), keep CLAUDE.md for what Claude should know about the project, and describe `--append-system-prompt` as something you pass at launch. The documented way to make a style your default in every project is `outputStyle` in `~/.claude/settings.json`, which is what the installer sets.

| | `--append-system-prompt-file` (original) | User output style (this repo) |
| --- | --- | --- |
| Where it applies | Only sessions launched with the flag | Terminal, IDE, desktop, Agent SDK, and Zeron, through one settings.json key |
| Zeron | Zeron does not pass the flag. You would need a `CLAUDE_CODE_EXECUTABLE` wrapper in the daemon's launchd or systemd unit | Works untouched, verified against its exact flags |
| Long sessions | The text goes into the system prompt once | The harness adds "sr-opus output style is active" as a reminder |
| Turn it off or compare | Remove the flag | `/output-style default` in a session, or `--settings '{"outputStyle":"default"}'` on one command |

To try it in a single session without installing anything, `claude --append-system-prompt-file output-styles/sr-opus.md` works with this same file, though the model also receives the frontmatter lines as text. Do not combine it with the installed style or the model gets the rules twice.

## Zeron

Zeron has no system prompt of its own for Claude. It spawns the real binary as `claude --print --input-format stream-json --output-format stream-json ...` (see `crates/harness/src/claude/mod.rs` in `zeronsh/zeron`) with no `--setting-sources`, `--system-prompt`, or `--append-system-prompt`. That means it loads `~/.claude/settings.json` and `~/.claude/output-styles/` like any terminal session, so running `./install.sh` on the machine where the Zeron daemon runs covers every Claude session it launches. On a VPS or several synced machines, install it on each machine that runs agents.

1. Run `./install.sh` on every machine where Zeron executes Claude Code.
2. Restart open sessions. Claude Code reads styles at startup, and switching styles mid-session invalidates the prompt cache.
3. Verify inside Zeron by sending `/output-style`. The list must show `- sr-opus (current)`. The first line (`Output style: ...`) echoes the configured value even when no style matches it, so it is not proof. From a terminal, `./install.sh --check` in the project directory runs the same check.

## Verified traps

- The name is case-sensitive. `"outputStyle": "Sr-Opus"` silently falls back to Default. `./install.sh --check` catches it.
- Project settings beat user settings, and `/output-style` writes to the project's `.claude/settings.local.json`. If you ever used it in a repo, that repo ignores your global style. Find offenders with `grep -rl '"outputStyle"' --include='settings*.json' ~/code`.
- Output styles do not apply to subagents (only to forks). If you run your own subagents, put the critical rules in the agent body.
- `CLAUDE_CODE_SIMPLE=1` or `--bare` skips user configuration.

## Measure the effect on your account

`scripts/ab.sh` runs the same prompt twice, once with Default and once with sr-opus, and compares output tokens, thinking tokens, cost, time, and text. Everything else (model, settings, CLAUDE.md, tools) stays identical, so the style is the only variable. It runs read-only in the current directory: anything that would ask for permission is denied.

```bash
cd ~/code/your-project
~/opus-prime/scripts/ab.sh "Is legacy-config.json still referenced?"
RUNS=3 EFFORT=high ~/opus-prime/scripts/ab.sh "Should we add Redis here?"
```

Each run bills to your normal Claude Code account. Output tokens include adaptive thinking, which varies a lot between runs, so use `RUNS=3` or more before drawing conclusions. Test with questions from your real work; a toy prompt measures little.

## Recommended settings (outside the prompt)

- Effort: `medium`, the Opus 5.5 default, for daily work. Go up to `xhigh` only for migrations or long audits where you measured an improvement. Avoid `max`: Anthropic reserves it for measured gains, and Simon Willison documented Opus 5.5 burning through its 128k output tokens thinking on `max`. In Zeron you pick it with the reasoning selector, which passes `--effort`.
- Long unsupervised runs: `/goal <verifiable condition>` makes an evaluator model check the condition at the end of each turn. It is available in stream-json mode, so it shows up in Zeron too.
- Check that your CLAUDE.md has no "think carefully" or "double-check". `/doctor prompt-audit` finds instructions written for older models.

## Why each change

| Change from the original | Evidence |
| --- | --- |
| "Turn endings" section naming the 4 premature stops | The Opus 5.5 guide documents that it ends turns with summaries, offers, or decision lists, and that it "is responsive to instructions that name the specific kinds of early stop". The claude.dev post asks for the same in Claude Code. |
| First sentence is the outcome, `Needs you:` last | Anthropic: "Lead with the outcome". claude.dev: read what it needs from you first. The original asked for the important part at the end, which conflicts with that. |
| F1/D1 codes carry a short gloss when cited | Some Claude Code prompt variants ask the model not to force the reader to decode invented labels. The gloss keeps the codes without that conflict. |
| Scope rewritten with Anthropic's recommended wording | The Opus 5 guide warns that it follows restrictive instructions literally and recommends "Deliver what was asked, at the scope intended". Banning "documentation" wholesale left stale docs. |
| Every negative comes with its replacement | Anthropic best practice: say what to do instead of what to avoid. The Opus 5.5 launch notes say it "follows the writing rules you give it". |
| No "think hard", no "double-check", no aggressive caps | Opus 5.5 always thinks, and removing those lines did not lower quality. Verification instructions cause over-verification, and aggressive wording causes overactivation. |
| Examples reduced to shape and tone | Anthropic cut over 80% of the Claude Code prompt because examples constrain newer models. The original's long example also contained an em dash, the tic it bans. |
| The prompt itself uses no em dashes or semicolons | Anthropic: the prompt's style influences the output's style. |
| Subagent rule and `chk`, `go`, `pair` aliases | The Opus 5 guide documents over-delegation. claude.dev recommends flagging the unconfirmed, answering "continue", and a pair-programming mode. |
| Co-author disabled in settings on top of the prompt | Claude Code 2.1.283 injects a `Co-Authored-By: Claude Opus 5.5` reminder. With empty `attribution` the reminder disappears and no conflict remains. |

Sources: [Prompting Claude Opus 5.5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5-5), [Prompting Claude Opus 5](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-opus-5), [Getting the most out of Opus 5.5](https://claude.dev/blog/getting-the-most-out-of-opus-5-5/), [The new rules of context engineering](https://archive.ph/uotBG), [Prompting best practices](https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices), [Output styles](https://code.claude.com/docs/en/output-styles), [Settings reference](https://code.claude.com/docs/en/settings-reference), [Simon Willison on Opus 5.5](https://simonwillison.net/2026/sep/22/opus-and-sol-and-luna/).

## Verified against Claude Code 2.1.283

The CLI's real API requests were intercepted with a local server, both in interactive mode and with the exact flags Zeron uses:

- The style is discovered from `~/.claude/output-styles`, the frontmatter parses, and `init.output_style` is `sr-opus`.
- The full text reaches the model right after the environment block, and the harness adds the "sr-opus output style is active" reminder.
- For Opus 5.5 the Claude Code base prompt is minimal (about 6 KB): no communication section, no scope section, no "keep working". The output style is, in practice, the entire behavior contract. Your account's feature flags can add sections, which is why the prompt resolves known conflicts explicitly.
- `--settings '{"outputStyle":"default"}'` overrides the user style for a single run, which is what `scripts/ab.sh` uses. Verified with a mock API that answers differently depending on whether the sr-opus text arrives in the request.
- In this version `keep-coding-instructions: true` does not change the request. It stays because the docs say a custom style without it drops the engineering instructions from the full prompt.

## Size

| | Original (disler) | sr-opus |
| --- | --- | --- |
| Lines | 153 | 120 |
| Words | 984 | 1326 |
| Tokens (cl100k, approx.) | 1330 | 1817 |

About 490 extra tokens, spent on premature stops, final-report format, conflict resolution, and three aliases. Since the system prompt is cached, that costs around $0.0001 per request at Opus 5.5's $0.20/M cache-read price.

## Where it can fail

- It is an instruction, not a guarantee. For anything that must always happen, use hooks or permissions.
- The keep-working rule never overrides confirmation before destructive actions. Keep permission prompts on for those.
- If a new verbal tic appears, add it to Negative Patterns with its replacement.

## License

MIT. Based on [`disler/fixing-smartass-opus-5`](https://github.com/disler/fixing-smartass-opus-5), Copyright (c) 2026 IndyDevDan.
