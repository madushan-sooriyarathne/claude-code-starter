# Rules Catalog

Rules files, copied from `${CLAUDE_PLUGIN_ROOT}/rules/` (slash command) or
`$SCRIPT_DIR/rules/` (install.sh) into the target project's `.claude/rules/`.

Most rules carry `paths:` frontmatter, so once installed they only load when
Claude touches matching files — safe to install several even if only one
stack is active. Pre-mark based on scan signals.

| # | Rule | File | Covers | Recommend when |
|---|------|------|--------|----------------|
| 1 | `typescript` | `typescript.md` | No `any`, infer types from Drizzle schema, Zod at external boundaries, strict tsconfig flags | `tsconfig.json` or `.ts`/`.tsx` files. Default: recommend |
| 2 | `git-workflow` | `git-workflow.md` | Conventional commits, branch naming, no direct push to main, no `--no-verify`, no destructive force-push | Always (Git repo). Default: recommend |
| 3 | `nextjs` | `nextjs.md` | App Router conventions, server vs client components, DAL pattern, caching/revalidation | `next.config.*` detected |
| 4 | `monorepo` | `monorepo.md` | Turborepo package boundaries, pnpm workspaces, no cross-package `../` imports, no barrel files | `turbo.json` OR `pnpm-workspace.yaml` detected |
| 5 | `react` | `react.md` | Composition over boolean props, stable keys, effects as last resort, React 19 async primitives | `react` dep detected |
| 6 | `hono` | `hono.md` | Route structure, zod-validator at the boundary, centralized `onError`, shared RPC client type | `hono` dep detected |
| 7 | `bun` | `bun.md` | Native APIs over Node polyfills, `bun:test`, no `dotenv`, graceful shutdown | `bunfig.toml`, `bun.lockb`, or `packageManager: bun@*` detected |
| 8 | `golang` | `golang.md` | Standard layout, error wrapping, goroutine lifecycle, context propagation, table-driven tests | `go.mod` detected |
| 9 | `rust` | `rust.md` | `unsafe` discipline, error types, ownership/borrowing, clippy-clean idioms | `Cargo.toml` detected |
| 10 | `tailwind` | `tailwind.md` | v4 CSS-first `@theme`, `cn()` merging, container queries, class ordering | `tailwindcss` dep (v4) or `@theme` block in CSS detected |
| 11 | `code-quality` | `code-quality.md` | Anti-defaults (no premature abstraction, no scope creep), naming conventions, code markers, file organization | Always. No `paths:` frontmatter — always-loaded. Default: recommend |
| 12 | `database` | `database.md` | Migration discipline: never edit an existing migration, reversibility, no raw SQL over ORM methods, indexes in their own migration | Migrations or ORM dir found (`**/migrations/**`, `prisma/`, `drizzle/`, `alembic/`, etc.) |
| 13 | `error-handling` | `error-handling.md` | Typed errors, no swallowed errors, consistent HTTP error shape, retry policy for transient errors | Backend/API surface found (`src/api/`, `src/services/`, `**/controllers/**`, `**/routes/**`, `**/handlers/**`) |
| 14 | `frontend` | `frontend.md` | Design tokens, accessibility (non-negotiable), layout, performance budget | Frontend files found (`.tsx`/`.jsx`/`.vue`/`.svelte`, `**/components/**`, `**/pages/**`) |
| 15 | `security` | `security.md` | Input validation at boundary, parameterized queries, output sanitization, short-lived tokens, rate-limited auth endpoints | Backend/API/auth surface found (`src/api/`, `src/auth/`, `src/middleware/**`, `**/routes/**`) |
| 16 | `testing` | `testing.md` | Behavior over implementation, one assertion per test, real implementations over mocks except at boundaries | A test suite/runner actually exists. No `paths:` frontmatter — always-loaded once installed |

Notes:

- `typescript`, `git-workflow`, and `code-quality` apply to essentially every project; pre-check them by default.
- All other rules are stack- or surface-specific; only pre-check when their signal is present, but still list them so the user can opt in.
- `bun`/`hono`/`react` share broad `paths:` globs with `typescript` (can't reliably distinguish runtime/framework by filename alone) — that's fine, the install-time signal above is what keeps irrelevant rules out of a project in the first place.
- `code-quality` and `testing` carry no `paths:` frontmatter, so they count toward the always-loaded token budget (see Step 6 verification) — weigh that before recommending both by default on a token-sensitive setup.
