# ADR-001: Layering Rules

Date: 2026-05-13
Status: Accepted

## Context
The project originally enforced only two import rules (`ui-cannot-import-platform`, `app-cannot-import-ui`). This allowed UI files to accumulate direct imports of `app/mesh/`, `app/proto/`, and `app/db/`, creating tight coupling that would make v0.3 protocol changes entangled with UI churn.

## Decision
Enforce six import rules:
1. ui-cannot-import-platform
2. app-cannot-import-ui
3. ui-cannot-import-mesh
4. ui-cannot-import-proto
5. ui-cannot-import-db
6. platform-cannot-import-app

All enforced by `tool/check_layers.dart --strict`. Zero baseline after v0.2.5.

## Consequences
- All cross-layer access from UI goes through facades in `app/controllers/` and `app/services/`.
- `platform/` is strictly pure native adapter (no business logic).
- Protocol changes in v0.3 can proceed inside `app/mesh/` with no UI file changes.
- PR review checklist updated to include layer rule verification.

## Status
Accepted on 2026-05-13.
