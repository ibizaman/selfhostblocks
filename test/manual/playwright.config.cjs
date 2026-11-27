const { defineConfig } = require('@playwright/test');

const port = 4173;
const baseURL = `http://127.0.0.1:${port}`;
const manualDirectory = process.env.SHB_MANUAL_HTML;
if (!manualDirectory) {
  throw new Error('Run from the repository root with nix run .#manual-visual-tests -- test');
}

module.exports = defineConfig({
  testDir: '.',
  snapshotPathTemplate: '{testDir}/goldens/{projectName}/{arg}{ext}',
  updateSnapshots: 'none',
  workers: 1,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    baseURL,
    browserName: 'chromium',
    channel: 'chromium',
    colorScheme: 'light',
    locale: 'en-US',
    deviceScaleFactor: 1,
    trace: 'retain-on-failure',
  },
  projects: [
    { name: 'desktop', use: { viewport: { width: 960, height: 900 } } },
    { name: 'narrow', use: { viewport: { width: 390, height: 900 } } },
  ],
  webServer: {
    command: `python3 -m http.server ${port} --bind 127.0.0.1`,
    cwd: manualDirectory,
    url: `${baseURL}/index.html`,
    reuseExistingServer: false,
  },
});
