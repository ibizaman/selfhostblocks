# Manual screenshot prototype

This test compares the first viewport of the built Nextcloud manual page
against two committed PNGs: desktop (960 x 900) and narrow (390 x 900). Both use
headless Chromium and the light theme. It does not test the open mobile menu or
replace the existing service tests. The `manual` CI job runs it after building the
manual, including on documentation-only changes.

## Run

From the repository root on x86_64 Linux:

```sh
nix run .#manual-visual-tests -- test
```

Nix builds the current manual and supplies Playwright Test, its matching Chromium,
Python's static HTTP server, and a fixed fallback font configuration. No npm
installation or browser download is needed. Roboto is served by the manual itself.
The tests and goldens are read from the working tree, so edits to them take effect
without committing. Newly added Nix files must be staged for flake discovery.

Playwright starts a loopback-only server on port 4173 and stops it when finished.
An occupied port is an error rather than permission to test an unrelated server.
Checking never creates or updates goldens; a missing or different image fails.

## Review and update goldens

1. Run the test normally and inspect any failures:

   ```sh
   nix run .#manual-visual-tests -- show-report
   ```

   Open the printed local URL to inspect expected, actual, and difference images.
   Stop the report server with Ctrl-C before continuing.

2. If the visual change is intentional, regenerate the goldens:

   ```sh
   nix run .#manual-visual-tests -- test --update-snapshots
   ```

   To update only one viewport, add `--project=desktop` or `--project=narrow`.
   This command also creates the initial goldens when they do not exist.

3. Inspect the changed PNGs under `test/manual/goldens/`, then rerun without
   `--update-snapshots`:

   ```sh
   nix run .#manual-visual-tests -- test
   ```

   Commit only reviewed goldens alongside the change that explains them. Passing
   immediately after regeneration is not proof that the new appearance is correct.

Reports and failure artifacts live in the ignored `test/manual/playwright-report/`
and `test/manual/test-results/` directories. They are not baselines.

Use the same x86_64 Linux runner and flake lock for comparison and regeneration.
Browser or font updates can legitimately change pixels; investigate before
accepting changes or increasing tolerances. CI explicitly disables snapshot
updates and rejects focused tests (`test.only`). On failure, download the
`manual-visual-tests` artifact from the workflow run for the report, screenshot
diffs, and traces. A screenshot failure fails the existing `Final Results` check.

The implementation uses Playwright's standard
[visual comparisons](https://playwright.dev/docs/test-snapshots) and
[web server lifecycle](https://playwright.dev/docs/test-webserver), rather than a
custom comparison or server framework. The Nix wrapper exposes the Node test
runner, not SHB's existing Python `.#playwright` trace viewer.
