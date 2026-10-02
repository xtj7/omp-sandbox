# AGENTS.md

Guidance for AI coding agents (and humans) working in this repository.

## Communication

- The owner's working language is **English**. All conversation, reports, and questions go to the owner in English.

## Project

Add details of your project here.

## Stack (locked — do not substitute without owner approval)

| Layer                 | Tech                                                                                                                       |
|-----------------------|----------------------------------------------------------------------------------------------------------------------------|
| Backend               | Go + **Echo** + **sqlx** + **PostgreSQL 16 + PostGIS**; OpenAPI 3 spec generated from Go types (contract for all clients)  |
| Public web            | **Next.js** (TypeScript), SSR for SEO, EN/BM i18n, GA4                                                                     |
| Admin/organizer panel | **React + Vite** (TypeScript), separate app/build/deploy, role-based UI for admin **and** organizer (exactly two web apps) |
| Mobile (Phase 2)      | **Flutter** (single codebase, iOS + Android), Firebase Analytics                                                           |
| Object storage        | S3-compatible: **Garage** (dev/test), R2 expected (prod); presigned uploads                                                |
| Geocoding             | **Self-hosted OSM Nominatim, Malaysia extract only** (O9 locked)                                                           |
| Map tiles             | Self-hosted OSM tile server; provider behind a config-level interface (swappable)                                          |
| Translation           | **Self-hosted OpenAI-compatible LLM endpoint**; model + prompt in config                                                   |
| Email                 | **SMTP**; Mailpit in dev/test                                                                                              |
| CI                    | GitHub Actions on github.com/...                                                                                           |
| Local dev             | docker compose: postgres+PostGIS, garage, mailpit, nominatim, api, web, admin                                              |

## Repo layout

```
backend/            # Go API: cmd/server, internal/{handlers,service,repo,models,middleware}, migrations/ (goose), openapi/
web/                # Next.js public site
admin/              # React (Vite) admin + organizer panel
mobile/             # Flutter (added in S10)
docker/             # Dockerfiles, docker-compose.yml, seed data, OSM extract import
.github/workflows/  # CI
docs/               # ADRs, runbooks
```

## Commands

- `docker compose up` — full local stack (postgres+PostGIS, garage, mailpit, nominatim, api, web, admin)
- `make seed` — load sample MY data
- Backend: `go test ./...` (unit + integration via testcontainers), `go run ./cmd/server`
- API types: `make api-clients` — regenerate TypeScript types for **both** web + admin from the OpenAPI spec (run after any API change; commit both generated `schema.d.ts` files together)
- Web/admin: `npm run dev`, `npm test` (Playwright), `npm run build`
- CI runs lint + test + build for every app on every PR; it must be green.

## Language servers (LSP)

Symbol-aware work goes through the `lsp` tool, not text search. Config lives in `.omp/lsp.json` (machine-local, gitignored — absolute paths point at this workstation's tooling).

| Server                       | Scope            | Notes                                                                                                                                     |
|------------------------------|------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| `gopls`                      | `backend/`       | Runs from the repo root as a multi-module workspace; resolves `backend/go.mod` per file                                                   |
| `typescript-language-server` | `web/`, `admin/` | Pinned to the project's TypeScript (web's `tsserver.js`, TS 5.9); tsserver picks each app's own `tsconfig.json` + `node_modules` per file |
| `dartls`                     | `mobile/`        | `dart` from PATH (must match the Flutter SDK's Dart); needs `flutter pub get` in `mobile/` first                                          |

- **Rename** — always `lsp` `rename` / `rename_file`; never sed/AST/text rename across files (misses call sites, breaks re-exports).
- **Navigate** — `definition`, `references`, `hover`, `type_definition`, `implementation` for "where is X / who calls X" once files are known; for *discovery* across many files, prefer a scout subagent (see below).
- **Diagnostics** — run `lsp diagnostics` on files after editing; `file: "*"` runs a workspace check (`go build` / `tsc --noEmit`).
- **Code actions** — list `code_actions` before hand-editing imports or applying quick fixes.
- **Server not ready or stale** — `lsp status` to inspect, `lsp reload` (workspace) to re-read config and restart. Missing deps break intelligence silently: `npm ci` in `web/` and `admin/`, `flutter pub get` in `mobile/`.

## Issue/task handling

- TDD + vertical slices: every slice is independently testable and deployable.
- Every new issue belongs to a slice and has clearly defined acceptance criteria. Open owner questions have to be clarified by asking the owner before implementation begins
- Every decision made during the implementation has to be documented in the issue.
- After all the issues in a slice are implemented, E2E tests will be the last issue in each slice to ensure a comprehensive test suite.

## TDD rules (non-negotiable)

1. **Tests first.** For each slice, write the failing acceptance tests (API integration + e2e) before implementation.
2. **Definition of done** (PRD §8): all slice ACs covered by automated tests and green; full regression suite green; OpenAPI updated; migrations included; `.env.example` updated; manual smoke test on the compose stack documented in the PR.
3. Go integration tests use **testcontainers** (real Postgres + Garage S3). Web/admin e2e uses **Playwright**. Flutter (S10+) uses widget tests + `integration_test`.
4. **Mock geocoder in CI** — never download/import OSM data in CI. Real Nominatim is exercised in local dev and manual smoke tests only.
5. **Owner-decision gate:** issue files in `issues/` may contain a `⚠️ Owner decision` section. If present and unanswered, **stop and ask the owner** before implementing — present the options with a recommendation, wait for the answer, record it in the file's decision log. These are owner decisions, same as PRD §12 open items.
6. **e2e assumes a fresh database** (CI parity — CI spins up a new Postgres per run). If you are running the web/admin Playwright suites against a local dev DB that has been in use, reset it first (recreate the postgres volume + `make seed`); row-count and list-based assertions can flake or fail against a dirty DB.

## Todo discipline (non-negotiable)

- Create the todo list when an issue starts: one item per step
  (tests first, implementation, verification, bookkeeping).
- **Mark a task done the moment its work finishes** — in the same
  turn as the work itself (batched with the real call), never
  "I'll update the todos at the end".
- Before reporting completion or committing: `todo view` —
  finished work must be [X], and anything still open must be
  genuinely open. A stale list at the end of a task is a defect.

## Task completion workflow (non-negotiable)

After each task/issue is implemented and all tests pass:

1. **Verify the todo list** — `todo view`; flip anything finished
   to done (see "Todo discipline").
2. **Update the issue file** in `issues/` — mark it as done, add a brief completion note (what was built, key decisions, test coverage).
3. **Update `PLAN.md`** — mark the task as complete, adjust the remaining work list if the scope changed.
4. **Commit** — stage all changes (code + issue file + PLAN.md) and commit with a descriptive message referencing the issue/task.
5. **Stop and wait.** Do NOT automatically start the next task. Report what was done and wait for the user to direct the next step.

## Subagent delegation (non-negotiable)

Exploration and research are done in **subagents**, not the main agent, so the main agent's context window stays small. This covers **both tasks and questions**: any request whose answer requires exploring the repo is an investigation and gets delegated — including status questions like "which issue should come next?", "what's the state of X?", "what depends on Y?", "is Z covered by tests?".

- **Tasks** that need surveying the codebase, reading many files, tracing how something works, or investigating before acting: delegate to a subagent (a read-only scout) and work from its **compressed findings** — the conclusions, the specific files/symbols to touch, and any open questions. Do not let bulk file contents, search output, or trial-and-error reading accumulate in the main context.
- **Questions** that need reading multiple files or cross-referencing state (plan/issue files, git history, configs): delegate one bounded scout and **report only the answer** — the compressed conclusion, not the exploration process. Example: "which issue should come next?" → a scout reads `PLAN.md` + `issues/` + recent git history and returns the open issues, their dependency states, and a recommendation; the main agent presents only that.
- The main agent reads a file itself only when it is about to **edit that exact file**. Everything upstream of the edit — "where is this? how does it work? what else references it?" — belongs in a subagent.
- Give subagents a precise question and a bounded scope, and ask for a tight summary, not a dump of file contents.

## Conventions

- **OpenAPI is the contract.** Any API change: update Go types → `make api-gen` (regenerate the spec) → `make api-clients` (regenerate the TypeScript types for **both** `web/` and `admin/` from the pinned `openapi-typescript`) → all apps must compile in CI. Both generated `schema.d.ts` files come from the same spec + pinned generator and must be committed together — never regenerate or hand-edit one without the other.
- **Migrations:** goose, in `backend/migrations/`. Never edit an applied migration; add a new one.
- **SQL:** sqlx prepared statements only; no string-con interpolated queries.
- **i18n:** every UI string in EN **and** BM; no hardcoded strings in components. Content fields (title/description) are per-locale with auto-translation.
- **Go:** standard project layout under `internal/`; no ORM; structured logging; config via env.
- **Money/age/price:** `is_paid` flag + nullable amount; age ranges nullable = "all ages".
- **Branding:** white + bright orange; logo pending (placeholder until provided).

## Do not

- Do not commit OSM data, `.env` files, or secrets.
- Do not "finish" a slice by skipping or weakening an acceptance criterion.