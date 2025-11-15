# Repository Guidelines

AFFiNE is a TypeScript + Rust monorepo. This guide summarizes how to work productively and consistently across packages.

## Project Structure & Module Organization

- Root config (`package.json`, `Cargo.toml`, `tsconfig*.json`) and shared docs live at the repository root.
- Editor and core libraries are under `blocksuite/`.
- Frontend apps and UI live in `packages/frontend/*` (web, desktop, mobile, shared components).
- Backend services and native bindings live in `packages/backend/*`.
- Shared utilities live in `packages/common/*`.
- End-to-end suites live under `tests/*`; internal helpers and fixtures are colocated in those folders.
- Deployment and maintenance scripts live in `scripts/` and `tools/`.

## Build, Test, and Development Commands

Common root commands:

```bash
yarn install           # install workspace dependencies
yarn dev               # run main AFFiNE dev experience
yarn build             # build the full monorepo
yarn lint              # run ESLint + Prettier checks
yarn test              # run Vitest test suite
yarn test:coverage     # run tests with coverage
```

Example e2e run: `cd tests/affine-local && yarn e2e`.

## Coding Style & Naming Conventions

- JavaScript/TypeScript formatting is enforced by Prettier and ESLint; do not hand-tune formatting—run `yarn lint:fix` instead.
- Prefer `PascalCase` for React components, `camelCase` for variables/functions, and kebab-case for directories and non-component files.
- Rust code is formatted with `cargo fmt` (see `rustfmt.toml`); keep modules small and cohesive.

## Testing Guidelines

- Unit and integration tests use Vitest; place specs adjacent to code in `__tests__` using `.spec.ts`/`.test.ts`.
- E2E tests use Playwright under `tests/*/e2e`; keep scenarios small and focused.
- Rust crates use `cargo test` in their respective package directories.
- For changes with behavior impact, add or update tests and ensure `yarn test` (and relevant e2e suites) pass before opening a PR.

## Commit & Pull Request Guidelines

- Follow Conventional Commits: e.g., `feat: add offline sync queue`, `fix: handle empty workspace name`, `chore: update dependencies`.
- One logical change per commit; keep diffs narrowly scoped to the feature or bug.
- PRs should describe motivation, approach, and risk, and include a short “Test plan” (commands run) plus links to related issues (`Fixes #123`).
- Add screenshots or screen recordings for UI-facing changes when practical.

## Security & Configuration

- Do not commit secrets or real environment configs; use patterns like `config.example.json` and local `.env.*` files instead.
- Review `SECURITY.md` and use `scripts/switch-env.sh` for environment switching rather than editing production configs by hand.

## Agent-Specific Instructions

- Prefer focused edits in the smallest relevant package; avoid cross-cutting refactors unless explicitly requested.
- Use existing scripts and root `yarn` commands where possible, and avoid adding new dependencies or tools without clear justification.
