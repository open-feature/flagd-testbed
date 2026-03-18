# Agent Guidance for `flagd-testbed`

This file provides guidance for AI agents (such as GitHub Copilot) working in this repository.

---

## Repository Purpose

`flagd-testbed` is a **shared test harness** used by OpenFeature provider SDK teams across many languages to validate their flagd provider implementations. It is **not** a library or application — it is the **test artefact itself**.

It ships:
- A Docker image (`flagd-testbed`) bundling [flagd](https://flagd.dev/) and a control server called **Launchpad**.
- [Gherkin](https://cucumber.io/docs/gherkin/) feature files (in `gherkin/`) that define the expected behaviour of flagd providers.
- Flag definition JSON files (in `flags/`) that back the test scenarios.

SDK teams include this repo as a **git submodule**, spin up the Docker image via [Testcontainers](https://testcontainers.com/) or Docker Compose, then run the Gherkin scenarios against their provider implementation.

> **There are no local test runners in this repository.** `npm run gherkin-lint` only lints the Gherkin file syntax. The actual tests are executed by each provider SDK repo using their own test framework.

---

## Key Directories

| Path | Description |
|------|-------------|
| `gherkin/` | Cucumber/Gherkin `.feature` files — the primary test contracts |
| `flags/` | flagd flag definition JSON files backing the scenarios |
| `flagd/` | Dockerfile and build assets for the `flagd-testbed` Docker image |
| `launchpad/` | Go HTTP server that controls flagd lifecycle during tests (start/stop/restart/change) |
| `ssl/` | TLS certificate assets for SSL/TLS test scenarios |

---

## Semantic Commit & PR Title Conventions

This repo uses [Conventional Commits](https://www.conventionalcommits.org/) enforced by `lint-pr.yml` via `action-semantic-pull-request`. Releases are automated by `release-please`.

### ⚠️ Important: Gherkin and Flag Changes Are `feat:`

Changes to `gherkin/` feature files and `flags/` JSON files **must** use the `feat:` prefix (not `test:` or `chore:`).

**Why:** The Gherkin scenarios and flag definitions are **the product** of this repository. They define the test contract behaviour that every provider SDK must implement. Adding or changing a scenario or flag definition is adding or changing a feature of the contract — it has downstream impact on SDK teams and triggers a version bump.

```
# Correct
feat(targeting): add semver range operator scenario
feat(evaluation): add object flag zero-value scenario

# Incorrect — these under-represent the impact
test(targeting): add semver range scenario
chore: update flags for fractional test
```

Use `fix:` for corrections to existing scenarios (wrong expected value, typo in step). Use `docs:` only for documentation files like `README.md` or `agents.md`.

---

## Gherkin Tagging Conventions

Tags appear at the `Feature` level and/or individual `Scenario`/`Examples` level. Provider SDKs filter which tests to run using tag expressions (e.g., `-t 'not @rpc'`).

### Provider Mode Tags

These tags declare which flagd provider mode a scenario applies to:

| Tag | Meaning |
|-----|---------|
| `@rpc` | Scenario applies to RPC (gRPC) mode providers |
| `@in-process` | Scenario applies to in-process evaluation providers |
| `@file` | Scenario applies to file-based (local) providers |

Most feature files open with `@rpc @in-process @file` to indicate universal applicability.

### Feature / Capability Tags

| Tag | Meaning |
|-----|---------|
| `@targeting` | Scenario requires JSON-logic targeting rule evaluation |
| `@fractional` | Scenario tests the `fractional` custom operator (bucketing) |
| `@fractional-v1` | Examples using the legacy float-based bucketing algorithm (`abs(hash) / i32::MAX * 100`) |
| `@fractional-v2` | Examples using the high-precision integer bucketing algorithm (`(hash * totalWeight) >> 32`) |
| `@fractional-nested` | Scenarios testing nested fractional expressions |
| `@string` | Scenarios testing the `string` custom operator |
| `@semver` | Scenarios testing the `sem_ver` (semantic versioning) custom operator |
| `@caching` | Scenarios testing RPC response caching behaviour |
| `@events` | Scenarios testing provider state-change event emission |
| `@metadata` | Scenarios testing flag/flag-set metadata |
| `@contextEnrichment` | Scenarios testing server-side context enrichment |

### Opt-out Pattern

SDKs that do not support a feature can exclude its scenarios:

```
# Skip RPC-only tests
-t 'not @rpc'

# Skip fractional tests entirely
-t 'not @fractional'

# Use only v2 fractional bucketing
-t 'not @fractional-v1'
```

### Deprecated Tags

| Tag | Notes |
|-----|-------|
| `@no-default` | Deprecated; use `@no-default-variant` instead |
| `@deprecated` | Marks scenarios scheduled for removal |

### Adding New Tags

When introducing a new opt-in or transition tag (e.g., for a new operator or a breaking behaviour change):
1. Document the tag in this file under the appropriate table.
2. Announce it in the PR description so SDK maintainers can plan adoption.
3. Consider whether existing scenarios need updating or whether the new tag is additive-only.

---

## Flag File Conventions

Flag definitions live in `flags/*.json`. Each file corresponds to a category of test scenarios.

| File | Purpose |
|------|---------|
| `testing-flags.json` | Core flag types: boolean, string, integer, float, object, context-aware, error cases |
| `zero-flags.json` | Falsy/zero-value variants for all types |
| `custom-ops.json` | Custom operators: `fractional`, `sem_ver`, `string` |
| `evaluator-refs.json` | Shared evaluator definitions via `$ref` |
| `changing-flag.json` | A single flag whose variant toggles (used to test real-time changes via Launchpad) |
| `metadata-flags.json` | Flag and flag-set metadata fields |
| `edge-case-flags.json` | Null defaults, missing variants, error conditions |
| `selector-flags.json` | Selector mode (in-process) flag definitions |
| `selector-flag-combined-metadata.json` | Combined metadata for selector scenarios |

### Flag JSON Structure

```jsonc
{
  "flags": {
    "<flag-key>": {
      "state": "ENABLED",           // or "DISABLED"
      "variants": {
        "<variant-name>": <value>   // value type matches flag type
      },
      "defaultVariant": "<variant-name>",
      "targeting": { ... }          // optional JSON Logic expression
    }
  },
  "$evaluators": { ... }            // optional shared evaluator definitions
}
```

Special variables available in targeting expressions:
- `$flagd.flagKey` — the key of the flag being evaluated
- `$flagd.timestamp` — current Unix timestamp

### Flag Key Contract

**Flag keys used in Gherkin `Given` steps must exactly match keys in the JSON files.** There is no runtime discovery — a mismatch causes a test failure in every SDK that runs the suite. When renaming a flag key, update both the `.feature` file and the `.json` file in the same commit.

---

## DCO — Developer Certificate of Origin

All commits in this repository **must be signed off** to satisfy the [DCO](https://developercertificate.org/) check enforced on every PR.

Add a sign-off line to every commit by passing `-s` / `--signoff` to `git commit`:

```bash
git commit -s -m "feat(targeting): add semver range scenario"
```

This appends `Signed-off-by: Your Name <your@email.com>` to the commit message body. The DCO bot verifies that this line is present and that the email matches a GitHub-verified address on your account.

### Amending existing commits

If a commit is missing the sign-off, amend it before pushing:

```bash
# Most recent commit only
git commit --amend --signoff --no-edit

# Multiple commits (interactive rebase)
git rebase --signoff HEAD~<n>
```

For force-pushing a PR branch after amendment:

```bash
git push --force-with-lease origin <branch>
```

### Checklist reminder

Every commit on every PR branch must contain:

```
Signed-off-by: Your Name <your@email.com>
```

This applies to fixup commits, merge-conflict resolutions, and co-authored commits alike.

---

## Contribution: Adding New Scenarios

When adding a new test scenario, **always provide both artefacts together**:

1. **Flag definition** — add the flag key and its variants/targeting to the appropriate `flags/*.json` file (or create a new one if it belongs to a new category).
2. **Gherkin scenario** — add the scenario to the appropriate `gherkin/*.feature` file (or create a new one).

A PR that adds only one of the two will be incomplete — the scenario will fail in all SDK test suites because either the flag or the step is missing.

### Checklist for New Scenarios

- [ ] Flag key in JSON matches exactly the key referenced in the Gherkin step.
- [ ] Scenario is tagged with the correct provider mode tags (`@rpc`, `@in-process`, `@file`).
- [ ] Any new capability tag is documented in `README.md`.
- [ ] `npm run gherkin-lint` passes locally.
- [ ] PR title uses `feat:` (new scenario) or `fix:` (correction).

---

## Versioning

- **Scheme:** Semantic Versioning, managed by [release-please](https://github.com/googleapis/release-please).
- **Current version:** stored in `version.txt` (currently `3.0.1`).
- **Trigger:** `feat:` commits bump the minor version; `fix:` bumps the patch; breaking changes (`!` or `BREAKING CHANGE`) bump the major.
- **Consumer guidance:** SDK submodule references should pin to a version tag (not a branch). Renovate is the recommended tool for automated submodule updates.

---

## Docker Image

The testbed image is built from `flagd/Dockerfile` (multi-stage: flagd base → busybox final).

```bash
# Default build
docker build -f flagd/Dockerfile -t flagd-testbed:latest --target testbed .

# Custom flagd version
docker build -f flagd/Dockerfile \
  --build-arg FLAGD_BASE_IMAGE=ghcr.io/open-feature/flagd:v0.14.1 \
  -t flagd-testbed:custom --target testbed .
```

Exposed ports:
| Port | Protocol | Service |
|------|----------|---------|
| 8013 | gRPC | flagd evaluation (RPC) |
| 8014 | gRPC | flagd sync stream |
| 8015 | gRPC | flagd sync (in-process) |
| 8080 | HTTP | Launchpad control API |

---

## Launchpad API

Launchpad (`launchpad/`) is a Go HTTP server that controls flagd during test runs.

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/start?config=<name>` | POST | Start flagd with a named config |
| `/stop` | POST | Stop flagd |
| `/change` | POST | Toggle `changing-flag` between variants |
| `/restart?seconds=<n>` | POST | Restart flagd after `n` seconds |

Named configs live in `launchpad/configs/`. Each config specifies which flag files to load and how to start flagd. On start, Launchpad generates `/flags/allFlags.json` (aggregates all non-`selector` flag files) for use in full-suite runs.

---

## Linting

```bash
npm install
npm run gherkin-lint   # validates .feature file structure and style
```

Linting rules are defined in `.gherkin-lintrc`. Notable rules:
- No unnamed features or scenarios.
- No duplicate scenario names within a feature.
- Strict indentation (Feature: 0, Scenario: 2, Step: 4).
- No `@watch` or `@wip` tags allowed.
- Maximum 16 steps per scenario.
