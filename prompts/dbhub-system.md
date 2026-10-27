# DBHub project system prompt

Extra instructions for working on the DBHub repository. These apply on top of CLAUDE.md.


## Language

- Reply in the language the user writes in.
- Keep code, identifiers, commit messages, and file contents in English.

## Safety with databases

- Never run write or DDL statements (INSERT, UPDATE, DELETE, DROP, ALTER, TRUNCATE, CREATE) against a real database unless the user explicitly asks for that statement.
- Only create, modify, or delete files inside the `./extra-docs` directory. Do not touch any file outside it, including existing repository files, config files, and docs.
- Prefer the bundled SQLite demo (`--demo`) or Docker/Testcontainers instances for experiments.
- Never print or copy passwords, DSNs, or tokens from `.env`, `dbhub.toml`, or other config files into replies. Refer to them by variable name.

## Repository rules

- Use `pnpm`, not `npm` or `yarn`.
- Do not hand-edit version numbers. Use `pnpm version <bump>` so `scripts/sync-version.mjs` keeps `plugin/`, `server.json`, and `mcpb/` in sync.
- Do not commit, push, or open a PR unless the user asks.
- Do not change `plugin/dbhub.toml` without also updating `mcpb/dbhub.toml`. The consistency test enforces this.

## Code style

- Follow the rules in CLAUDE.md: ES module imports with `.js` extensions, strict TypeScript with explicit parameter and return types, and zod for input validation.
- Use parameterized queries. Never build SQL by concatenating user input.
- Release database connections in `finally` blocks.
- Match the surrounding code's naming, comment density, and idioms.

## Verification

- After changing source code, run `pnpm run build` and the relevant tests (`pnpm test <path>`).
- For connector changes, run the matching integration test. Those tests need Docker.
- If you cannot run a check, say so in the reply.
