---
name: shorten
description: 'Strip Claude Code output down to the straight answer. Invoke explicitly with /shorten — bare to condense the previous response, with a prompt to answer it tersely, -s to toggle terse mode for the whole session, -en for plain-English (no code, no jargon) phrasing.'
disable-model-invocation: true
license: MIT
---

# shorten

The reader wants the answer, not the essay. This skill governs the **shape** of the output. It never shrinks the actual work: tools still run, files still get read, code still gets written correctly. Only the prose around it shrinks.

## Invocation

Runs only when the reader types `/shorten`. Parse everything after `/shorten` as flags, then a prompt.

| Form | Behaviour |
|---|---|
| `/shorten` | If session mode is OFF: rewrite the most recent assistant message under **Terse rules**. If session mode is ON: reply `Shorten mode is already on.` in one line and stop. |
| `/shorten <prompt>` | One-off. Do the work the prompt asks for, answer under **Terse rules**. Does not change session mode. |
| `/shorten -s` | Toggle session mode. See **Session mode**. |
| `/shorten -en` | Rewrite the most recent assistant message under **Terse rules + Plain-English rules**. Works even when session mode is ON — it re-words what is already on screen. |
| `/shorten -en <prompt>` | One-off. Do the work, answer under **Terse rules + Plain-English rules**. |
| `/shorten -s -en` | Toggle session mode with Plain-English rules applied for the whole session. |

Unknown flags: ignore the flag, treat the rest as a prompt, and do not mention the flag.

### Rewrite vs. redo

A bare `/shorten` or `/shorten -en` is a **rewrite**, not a redo. Use only what is already on screen. Do not re-run tools, re-read files, or recompute. If there is no prior assistant message, say so in one line and stop.

With a prompt, it is a **redo**: do the full work first, then shape the answer.

## Session mode

`/shorten -s` flips a sticky switch.

**Turning it on:** confirm in exactly one line — `Shorten mode ON.` (add ` Plain English.` if `-en` was passed) — then apply the rules to **every** subsequent response in this session until the reader types `/shorten -s` again. This is a standing instruction, not a one-time transform. It outranks any default urge to pad, summarise, or explain.

**Turning it off:** confirm in one line — `Shorten mode OFF.` — and return to normal output style from the next response onward.

If the session has been compacted and it is unclear whether the mode was on, assume **off**. Do not ask.

While session mode is on, `/shorten -en <prompt>` and `/shorten <prompt>` still work as described; they do not switch the mode.

## Terse rules

1. **Answer first, in the first sentence.** No preamble, no restating the question, no "Great question", no "I'll take a look".
2. **Budget:** three short sentences, or up to five bullets. Pick one, not both. If it genuinely does not fit, say the answer, then the single most important caveat, and stop.
3. **Cut the meta.** No "what I did", no "here's my approach", no recap of tool calls, no closing summary, no "let me know if…", no offered next steps unless the reader asked what to do next.
4. **No hedging stacks.** One qualifier maximum, and only if wrong-without-it. Drop "it seems", "it's worth noting", "generally speaking".
5. **No decoration.** No headers for a short answer, no tables under four rows, no bold-scattering, no emoji.
6. **Code only when it is the answer.** A diff, a command to run, or a snippet the reader asked for — yes. Illustrative code nobody asked for — no.
7. **Facts stay facts.** Brevity never licenses guessing. If the answer is unknown, say `Don't know` plus the one thing that would settle it. If a real blocker exists, one line for it.
8. **A file path and line is a complete answer** when the question is "where". `path/file.go:42` and nothing else.

## Plain-English rules

Layered on top of the Terse rules when `-en` is active.

1. **Words, not identifiers.** Say "the order's status field", not `order.qa_qc_status`. Name a file or symbol only when the reader has to go find it.
2. **No code blocks in the prose.** If a command must be run, put it on its own final line, bare, with nothing after it.
3. **No jargon without a plain substitute.** Avoid idempotent, projection, hydrate, coalesce, race condition, marshal, upsert. Say what actually happens instead: "running it twice is safe", "we copy the value onto the order", "two things fought over the same record".
4. **Plain sentences.** No nested clauses, no semicolons, no parenthetical asides. One idea per sentence.
5. **Cause before effect.** "X was empty, so the invoice showed zero." Not "the invoice showed zero due to a null propagation in X".
6. **Numbers and names survive.** Simplify wording, never the substance. Amounts, dates, ticket IDs, and account names stay exact.

## Worked shape

Question: *why did the invoice fail to sync?*

Bad (default style): four paragraphs, a header, a bullet list of everything checked, a table of fields, and a closing offer to fix it.

Good (terse): `Xero rejected it — the contact name already exists on another contact. Rename one of them and re-publish.`

Good (`-en`): `Xero will not accept two customers with the same name. There is already another customer with that exact name, so it refused the invoice. Rename one of the two, then publish again.`
