# GRAPH — a disciplined workflow for Claude Code

**A coding agent's most expensive failure is not writing bad code. It is
confidently solving the wrong problem, or declaring success without evidence.**

GRAPH is a Claude Code plugin that puts one human approval gate between "what
you asked for" and "anything gets written" — and makes that gate concrete:
you approve *executable examples* of what you want, not a paragraph of prose.
After the gate, the agent converges on those examples and cannot quietly
redefine success.

> **Language:** GRAPH answers in **the language you wrote your request in** —
> ask in English, get English. What it *writes to disk* (the `.graph/`
> knowledge base and task records) follows a language pinned per repository,
> declared as `Idioma:` in `.graph/INDEX.md` and set when you run
> `/graph:init`. That is pinned rather than per-session on purpose: the
> knowledge base is shared across sessions and people, and one file per
> language would stop being readable as a single thing. Repositories
> initialized before this existed keep Spanish.

## The problem it addresses

Turn a capable model loose on a repository and, when the task is ambiguous or
the test suite is weak, characteristic failures show up:

- it **edits the tests** until they pass, instead of fixing the code
- it **improvises** around a missing credential or config rather than asking
- it declares a criterion met **without running anything** ("this should work")
- it **widens the scope** past what you had in mind, silently

None of these are model incompetence — they are the natural consequence of an
underspecified request. GRAPH's answer is to force the specification to become
executable *before* the first mutation, and to verify mechanically afterwards.

**Honest scope.** In the author's own benchmarks (a private research repo; the
data is not published here), the benefit is *conditional*: it is substantial on
tasks with ambiguity, tempting oracles, or missing preconditions, and it mostly
just adds cost on clean, well-specified tasks in repositories that already have
a strong test suite. If your repo has excellent tests and your requests are
unambiguous, you may not need this.

## Requirements

Claude Code (authenticated), `git`, `bash`, and `python3` (standard library
only). The plugin itself has **zero runtime dependencies** — every tool it
ships is plain bash or stdlib Python.

## Install

For a single session:

```
claude --plugin-dir <path-to-clone>
```

Permanently, from inside a Claude Code session:

```
/plugin marketplace add <path-to-clone>
/plugin install graph@graph-marketplace
```

## Use

**Once per repository:**

```
/graph:init
```

It scans the repo, *runs* the build and test commands to verify they actually
work, and writes a `.graph/` knowledge base: an index, a map of the code, the
conventions it found, the verified commands, past decisions, and a task log.
Later sessions read this instead of rediscovering the repo every time.

**Then, for any piece of work:**

```
/graph:do I want the cart total to include per-item tax
```

What happens next:

1. **It reads before it writes.** Nothing in the repository is modified during
   analysis — that is enforced, not merely intended.
2. **It routes.** Cheap, unambiguous work with a strong existing test takes a
   short path with a mechanical safety net. Ambiguous or high-consequence work
   takes the full pipeline.
3. **It shows you a gate** and stops: what it understood, the executable
   examples that capture it, the scope it will touch, and — importantly —
   **the questions it cannot answer on its own**. Anything it could not turn
   into an executable example becomes a question here rather than a guess.
4. **You approve** (or correct it). Only then does anything get written.
5. **It converges** on the approved criteria and verifies each one by actually
   running it, quoting the real output.
6. **It closes**: a task record with the evidence, what it learned about your
   repo, and an explicit list of what was *not* verified.

Useful flags: `--tier S|M|L` to force the ceremony level (`--quick` = S,
`--full` = L), `--budget <tokens>` to cap the work (it asks instead of
silently stopping when exhausted), and `--gate-aprobado <file>` to pre-sign
the approval for non-interactive runs.

## What makes it different

- **The gate approves code, not prose.** A criterion that cannot be turned
  into an executable example is treated as a *gap* and becomes a question.
  This is the core idea; the rest is machinery around it.
- **No retry counters.** The loop exits on criteria met, never on "3 attempts".
  Getting stuck triggers escalation, never a silent stop.
- **Evidence or it did not happen.** Every criterion is verified by running its
  method and quoting the output.
- **Reversible by construction.** Every side effect is recorded with its
  inverse, so an escalation can roll back cleanly.
- **A distinction between an error and a divergence.** If a check goes red, the
  same suite is re-run against the untouched baseline. New failures mean *you*
  broke something — roll back. The same failures mean the change is not the
  cause: that is recorded as an open divergence rather than reverted, because
  discarding it would destroy the evidence. It also means GRAPH works in
  repositories whose suite is already failing for unrelated reasons.

## Layout

```
skills/do/       the orchestrator: phases, rules, record templates
skills/init/     the repo scan that produces .graph/
tools/           zero-dependency bash/python tools (see below)
tests/           deterministic unit tests + end-to-end scenarios
docs/            design specs and plans (in Spanish), one per round
.graph/          this repo's own knowledge base — GRAPH applied to itself
```

The tools are usable on their own: `red.sh` gives a mechanical verdict on
whether a change touched tests, broke the suite, or left its declared scope;
`oraculo-map.sh` maps which behaviours actually have executable checks;
`symbol-map.sh` extracts a symbol map; `exploracion.sh` maintains a graph of
hypotheses and refutations.

## Tests

```
tests/test-red.sh            # deterministic, free
tests/test-oraculo-map.sh    # deterministic, free
tests/test-symbol-map.sh     # deterministic, free
tests/test-exploracion.sh    # deterministic, free
tests/test-hook.sh           # deterministic, free
tests/test-manifiestos.sh    # deterministic, free
tests/run-scenarios.sh       # end-to-end: spawns real headless sessions
```

The end-to-end scenarios launch actual Claude sessions and therefore **cost
tokens**. They use `--dangerously-skip-permissions` only inside throwaway
fixtures created outside the repository tree, under `GRAPH_FIXTURES_DIR`
(default `${XDG_CACHE_HOME:-$HOME/.cache}/graph-plugin/fixtures`).

## Status

Working and used on real repositories, but young: version 0.1.0, one author,
and the interactive UX scenarios are not yet exercised automatically. The
design history lives in `docs/superpowers/` — each round documents what was
built, what was measured, and what the measurement refuted, including the
rounds that failed.

## License

MIT — see [LICENSE](LICENSE).
