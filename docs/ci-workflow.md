# CI/CD Workflow Overview

This document explains the CI/CD configuration located in `.github/workflows/` and the branching strategy it supports. Use it as a reference when contributing code or updating automation.

## Branching Strategy

- **Long-lived branches:**
  - `master` represents production-ready code. Only fast-forward or well-reviewed merges are expected here.
  - `develop` is the integration branch. Feature work merges here before graduating to `master`.
- **Short-lived branches:**
  - Feature branches follow the `feature/<name>` pattern. They branch from `develop` and merge back through pull requests.
- **Release tags:**
  - Versioned releases are created by pushing annotated tags that start with `v` (examples: `v1.0.0`, `v1.1.0-rc1`).

This layout mirrors a light GitFlow model—feature work feeds into `develop`, then stabilised changes are promoted to `master`, and tagged builds trigger release automation.

## CI Workflow (`ci.yml`)

### Triggers

- **Push events** on `master`, `develop`, and any `feature/**` branch.
- **Pull request events** targeting `master` or `develop` for open, reopen, sync, and ready-for-review actions.

Push and pull request runs are separate. A feature branch push runs the full pipeline, including image publication, while the matching pull request run validates the merge without pushing images.

### Job Graph

1. **`build`** (always runs):
   - Checks out code and sets up Temurin JDK 25 with Maven cache.
   - Runs `mvn clean install -DskipTests` followed by `mvn -B -ntp -DskipTests package` to produce distributable artifacts.
   - Uploads `target/*.jar` as the `jars` artifact.

2. **`unit-tests`** (needs `build`):
   - Repeats checkout and Java setup to ensure a clean workspace.
   - Executes `mvn -B -ntp -DskipITs=true test`, limiting execution to Surefire unit tests.
   - Publishes Surefire XML reports for later inspection.

3. **`integration-tests`** (needs `unit-tests`):
   - Similar setup steps.
   - Runs `mvn -B -ntp -DskipTests=true verify`, enabling failsafe-based integration tests (including Testcontainers).
   - Uploads Failsafe reports.

4. **`docker-build`** (needs `integration-tests`, only on push events):
   - Guarded by `if: github.event_name == 'push'` plus branch filter.
   - Downloads the previously built `jars` artifact to reuse the compiled output.
   - Logs into GHCR using the workflow token.
   - Builds the Docker image and pushes multiple tags:
     - Always tags with the short commit SHA (`ghcr.io/<repo>:<sha>`).
     - Adds branch tags:
       - `latest` and `master` when pushing `master`.
       - `develop` when pushing `develop`.
       - For feature branches, sanitises the branch name (lowercase, alphanumeric, hyphen) or falls back to `branch`.

### Key Points & Practices

- Duplicate Maven builds in the first job guarantee both a clean installation and a packaged artifact for later jobs.
- Separate push and PR runs are intentional: push runs publish container images needed for branch testing, while PR runs ensure merge safety without publishing.
- Artifacts uploaded in earlier jobs are reused downstream, keeping the pipeline consistent across environments.

## Release Workflow (`release.yml`)

### Trigger

- Fires on pushes of tags that start with `v`. No branch filtering—any tagged commit will run the release.

### Steps

1. Checkout with full history (`fetch-depth: 0`) to ensure tag and version metadata are available.
2. Set up Temurin JDK 25 and run a full `mvn -B -ntp clean verify` build to re-validate the code.
3. Upload release JARs (fails the job if none are produced).
4. Derive release metadata (tag and semantic version stripped of the `v` prefix) for reuse in later steps.
5. Authenticate to GHCR and build/push Docker images tagged with the release tag, the commit SHA, and the plain version (when the tag includes a leading `v`).
6. Publish a GitHub Release that attaches the built JARs.

## Operational Tips

- When working on new features, branch from `develop`, push as `feature/<slug>`, and open a PR back to `develop`.
- Use PR runs to validate changes before merging; they mirror push runs minus the Docker publication.
- Promote changes from `develop` to `master` via PRs once they are production-ready. The push to `master` will publish an image tagged `latest`.
- Tag a commit with `vX.Y.Z` (and push the tag) once you are ready to cut a release. The release workflow will publish both artifacts and container images and create the GitHub Release entry.
- If you need to avoid duplicate builds across workflows, consider adjusting triggers or adding conditional logic, but the current design optimises for safety and predictability.

