import {defineConfig, devices} from '@playwright/test';

const chromiumExecutablePath = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE;
const hostResolverRules = process.env.HEARTH_E2E_HOST_RESOLVER_RULES;
const chromiumArgs = hostResolverRules ? ['--host-resolver-rules=' + hostResolverRules] : [];
const chromiumLaunchOptions = chromiumExecutablePath || chromiumArgs.length
    ? {launchOptions: {...(chromiumExecutablePath ? {executablePath: chromiumExecutablePath} : {}), args: chromiumArgs}}
    : {};

export default defineConfig({
    testDir: './tests/e2e',
    workers: 1,
    timeout: 30_000,
    forbidOnly: Boolean(process.env.CI),
    retries: process.env.CI ? 2 : 0,
    reporter: process.env.CI ? [['html', {open: 'never'}], ['list']] : 'list',
    use: {
        baseURL: process.env.E2E_BASE_URL ?? 'http://127.0.0.1:8080',
        trace: 'retain-on-failure',
        screenshot: 'only-on-failure',
        video: 'retain-on-failure'
    },
    projects: [
        {name: 'chromium', use: {...devices['Desktop Chrome'], ...chromiumLaunchOptions}},
        {name: 'mobile-chromium', use: {...devices['Pixel 5'], ...chromiumLaunchOptions}}
    ]
});
