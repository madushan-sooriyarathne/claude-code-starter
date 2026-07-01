# Rules

Rules are modular instruction files that Claude Code loads automatically from `.claude/rules/`. They extend `CLAUDE.md` without bloating it.

- **No `paths:` frontmatter**. Loaded every session, like `CLAUDE.md`. Costs tokens every turn, so keep it tight.
- **`paths: [...]` frontmatter**. Loaded only when working with files matching the glob patterns. Free until you're near matched files.

Budget convention for always-loaded rules: under 30 lines each. Push everything that doesn't actively change Claude's behavior into a path-scoped rule, into an agent, or out entirely.

## Available rules

### Always-loaded

#### code-quality.md
~28 lines.

Anti-defaults that counter common Claude tendencies (no premature abstraction, no scope expansion, no surrounding refactors, WHY-not-WHAT comments). Plus naming conventions, code markers (TODO, FIXME, HACK, NOTE), and file organization.

#### testing.md
~7 lines.

Six terse principles: verify behavior, run the specific test file, fix or delete flaky tests, prefer real implementations, one assertion per test, no empty assertions. Comprehensive test writing is handled by the `test-writer` skill.

#### git-workflow.md
Conventional commits, branch naming, no direct push to main, no `--no-verify`, no destructive force-push, deliberate staging.

### Path-scoped

#### typescript.md
**Scope**: `**/*.ts`, `**/*.tsx`

No `any`, infer types from the source of truth (Drizzle schema, Zod, `as const`), validate external boundaries with Zod, strict tsconfig flags, `satisfies` over `as`, branded IDs, `import type`.

#### react.md
**Scope**: `**/*.tsx`, `**/*.jsx`

Composition over boolean props, stable list keys, effects as a last resort with mandatory cleanup, derive-don't-duplicate state, React 19 async primitives, error boundaries, role-based testing.

#### nextjs.md
**Scope**: `**/app/**`, `**/pages/**`, `next.config.*`

App Router conventions, server vs client components, data access layer with `server-only`, fetch memoization, tag-based revalidation, server action validation, image/font optimization.

#### hono.md
**Scope**: `**/*.ts`

Route structure, `@hono/zod-validator` at the boundary, centralized `onError`, shared RPC client type instead of hand-typed `fetch`.

#### bun.md
**Scope**: `**/*.ts`, `bunfig.toml`, `**/*.test.ts`

Bun CLI only, native APIs over Node polyfills (`Bun.serve`, `Bun.file`, `bun:sqlite`), no `dotenv`, `bun:test`, graceful shutdown.

#### golang.md
**Scope**: `**/*.go`

Standard project layout (`cmd`/`internal`/`pkg`), naming and receiver conventions, error wrapping with `%w`, small interfaces, pointer/value receiver rules, goroutine lifecycle, context propagation, table-driven tests.

#### rust.md
**Scope**: `**/*.rs`, `Cargo.toml`

`unsafe` discipline with `// SAFETY:` comments, no `unwrap`/`expect`/panic outside tests, typed errors (`thiserror`/`anyhow`), ownership/borrowing, clippy-clean idioms, builder pattern.

#### tailwind.md
**Scope**: `**/*.tsx`, `**/*.jsx`, `**/*.css`, `tailwind.config.*`

v4 CSS-first `@theme` (no JS config), `cn()` class merging, `tailwind-variants` for component variants, container queries, class ordering, no `@apply` sprawl.

#### monorepo.md
**Scope**: `apps/**`, `packages/**`, `turbo.json`, `pnpm-workspace.yaml`

Turborepo package boundaries, pnpm workspaces, no cross-package `../` imports, no barrel files.

#### security.md
**Scope**: `src/api/**`, `src/auth/**`, `src/middleware/**`, `**/routes/**`, `**/controllers/**`

Loads when touching API or auth code. Input validation, parameterized queries, XSS prevention, token handling, secret logging, constant-time comparison, security headers, rate limiting.

#### error-handling.md
**Scope**: `src/api/**`, `src/services/**`, `**/controllers/**`, `**/routes/**`, `**/handlers/**`

Loads near backend code. Typed error classes, no swallowing, no floating promises, consistent HTTP error shapes, no stack-trace leaks, retry policy.

#### database.md
**Scope**: migration directories across Prisma, Drizzle, Knex, Sequelize, TypeORM, Alembic, Flyway, Liquibase

Loads near migrations. Never modify existing migrations, reversibility, test both directions, no raw SQL when an ORM method exists, never seed production data in migrations.

#### frontend.md
**Scope**: `**/*.tsx`, `**/*.jsx`, `**/*.vue`, `**/*.svelte`, `**/*.css`, `**/*.scss`, `**/*.html`, `**/components/**`, `**/pages/**`, etc.

Loads when touching frontend files. Design token requirements, design principle pick-list, component framework options, layout rules, accessibility (WCAG 2.1 AA), performance.

## Adding your own

Create a new `.md` file in this directory. With no frontmatter it loads every session:

```markdown
# Your Rule Name

- Your instructions here
```

Or path-scoped, so it only loads when Claude touches matching files:

```yaml
---
paths:
  - "src/your-area/**"
---

# Your Rule Name

- Instructions that only apply when touching these files
```

If a language/framework can't be reliably distinguished from its file extension alone (e.g. Bun vs Node both use `.ts`), scope broadly and rely on `setup-agents`'s dependency/config-file detection to keep the rule out of projects that don't use that stack in the first place — see `skills/setup-agents/references/rules-catalog.md`.

See [Claude Code docs](https://code.claude.com/docs/en/memory#path-specific-rules) for glob pattern syntax.
