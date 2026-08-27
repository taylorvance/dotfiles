## Commit Message Format

Commits should include a one-line summary of the change, optionally followed by a blank line and
brief bullet points.

## Local Dev Servers

Use Devhost before starting or checking any long-running local web servers.

When asked things like "is the server running?", "what URL should I open?", "open/test the app",
or when a task requires a browser/dev server:

- First use Devhost MCP if available.
- Call `devhost_find_project_for_path` with the current repo path.
- If matched, use `devhost_get_project` or `devhost_get_project_urls` to check status and URL.
- Do not start a separate dev server with `npm run dev`, Vite, Python http.server, etc. unless the
  project is not registered in Devhost or Devhost is unavailable.
- Only call Devhost start/stop/restart tools with permission.

## declog

Use `.declog.md` as the repository's decision log.

- If it exists, read it before significant architectural decisions and update it when the
  rationale would help a future maintainer.
- If it does not exist, create it with the first qualifying decision when the repository is
  clearly personal. In shared, organizational, or work repositories, ask before introducing it;
  if ownership is unclear, ask.
- Do not log routine implementation choices, easily reversible decisions, or facts already
  obvious from the code.
- Keep entries newest-first: insert new entries immediately below the introductory text; never
  append them to the end.
- Legacy entries do not need every current field. Normalize structure when convenient, but never
  invent historical rationale or consequences. Update an old entry when it is relied upon,
  clarified, or superseded.
- When replacing a decision, add the replacement at the top, change the old status to
  `superseded`, and identify the replacement under `Refs`.

Use this template, omitting fields that genuinely do not apply:

```markdown
## YYYY-MM-DD Title

- Status: proposed | accepted | superseded
- Topics:
- Refs:
- Decision:
- Rationale:
- Consequences:
- Alternatives:
```
