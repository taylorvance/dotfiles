---
name: devhost
description: Inspect and control local development servers registered with Devhost. Use when Devhost MCP tools are available and asked whether a local app or server is running, what URL to open, to open or test an app, or whenever browser testing requires a local development server.
---

1. Call `devhost_find_project_for_path` with the current repository path.
2. If matched, use `devhost_get_project` or `devhost_get_project_urls` to determine status and
   URLs.
3. Reuse the registered Devhost server; never start a competing Vite, npm, Python, or other server.
4. Ask before starting, stopping, or restarting a Devhost project.
5. If Devhost is unavailable or the repository is unregistered, fall back to the repository's
   documented server workflow.
