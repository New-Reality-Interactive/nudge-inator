## Agent skills

### Issue tracker

Issues and specs are local markdown files under `.scratch/`. See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Apple platform questions

For any iOS design, implementation or testing question, or any Xcode question, look it up with the `apple-rag-mcp` tools before answering or deciding: `search` first, then `fetch` for a full page. Don't answer from memory.

- Say what the docs confirm and what they don't. If they're silent, mark it as a device check instead of guessing.
- If `apple-rag-mcp` has nothing on a page (for example a support.apple.com guide), say so before falling back to another source.
