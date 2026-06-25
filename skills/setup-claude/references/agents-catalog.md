# Agents Catalog

Eight review agents, copied from `${CLAUDE_PLUGIN_ROOT}/agents/` (slash command) or
`$SCRIPT_DIR/agents/` (install.sh) into the target project's `.claude/agents/`.

Pre-mark an agent as recommended when its **Recommend when** condition is met by the project scan.

| # | Agent | File | Purpose | Recommend when |
|---|-------|------|---------|----------------|
| 1 | `code-reviewer` | `code-reviewer.md` | TypeScript / Next.js / Hono correctness, type safety, pattern adherence | Always (any TS/JS project) |
| 2 | `security-reviewer` | `security-reviewer.md` | Auth flows, API route authorization, env handling, Drizzle injection risk | BetterAuth or any auth detected, OR API routes / Hono present. Default: recommend |
| 3 | `performance-reviewer` | `performance-reviewer.md` | Re-renders, N+1 queries, bundle size in Next.js + Drizzle | `next.config.*` OR `drizzle.config.*` detected |
| 4 | `sanity-reviewer` | `sanity-reviewer.md` | Sanity schema changes, GROQ queries, content modeling | `sanity.config.*` detected |
| 5 | `doc-reviewer` | `doc-reviewer.md` | Inline docs, README quality, CLAUDE.md completeness | Always |
| 6 | `frontend-designer` | `frontend-designer.md` | Tokens-first UI design, avoids generic AI aesthetics, accessibility | Frontend files present (`.tsx`/`.jsx`/`.vue`/`.svelte`) |
| 7 | `pr-test-analyzer` | `pr-test-analyzer.md` | Judges whether tests actually verify behavior — catches assertion-free tests, mock theater | A test suite/runner detected |
| 8 | `silent-failure-hunter` | `silent-failure-hunter.md` | Finds swallowed errors, failures masked as success, error-hiding fallbacks | Always (any codebase with error handling) |

Notes:

- All eight are safe to install regardless of stack; the conditions above only control which are **pre-checked** by default. The user may add or remove any.
- Agents are invoked on demand inside a session (e.g. "use the security-reviewer agent"). They do not run automatically.
