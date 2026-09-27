import {createHash, randomBytes} from 'node:crypto';
import {expect, test} from '@playwright/test';

const base = process.env.E2E_BASE_URL;
const expectedIssuer = process.env.HEARTH_E2E_EXPECTED_ISSUER;
const path = (value) => new URL(value, base).toString();
const randomSuffix = () => randomBytes(8).toString('hex');
// Browser diagnostics can contain real administrator credentials and OAuth artifacts.
test.use({trace: 'off', screenshot: 'off', video: 'off'});

function pkcePair() {
  const verifier = randomBytes(32).toString('base64url');
  const challenge = createHash('sha256').update(verifier).digest('base64url');
  return {verifier, challenge};
}

function authorizationUrl({clientId, redirectUri, scope, state, challenge}) {
  const url = new URL('/oauth2/authorize', base);
  url.searchParams.set('response_type', 'code');
  url.searchParams.set('client_id', clientId);
  url.searchParams.set('redirect_uri', redirectUri);
  url.searchParams.set('scope', scope);
  url.searchParams.set('state', state);
  url.searchParams.set('code_challenge', challenge);
  url.searchParams.set('code_challenge_method', 'S256');
  return url.toString();
}

async function approveIfShown(page) {
  if (new URL(page.url()).pathname === '/oauth2/consent') {
    await page.getByRole('button', {name: /同意并继续/}).click();
  }
}

function captureRequestUrl(page, matches) {
  return new Promise((resolve) => {
    const onRequest = (request) => {
      const url = new URL(request.url());
      if (matches(url)) {
        page.off('request', onRequest);
        resolve(request.url());
      }
    };
    page.on('request', onRequest);
  });
}

test('native candidate exposes matching version and OIDC discovery', async ({request}) => {
  const expectedCommit = process.env.HEARTH_EXPECTED_COMMIT;
  expect(expectedCommit).toMatch(/^[0-9a-f]{40}$/);
  const versionResponse = await request.get('/version');
  expect(versionResponse.status()).toBe(200);
  const version = await versionResponse.json();
  expect(version.commitId).toBe(expectedCommit);
  expect(version.version).not.toBe('unknown');

  const discoveryResponse = await request.get('/.well-known/openid-configuration');
  expect(discoveryResponse.status()).toBe(200);
  const discovery = await discoveryResponse.json();
  expect(discovery.issuer).toBe(expectedIssuer);
  expect(discovery.authorization_endpoint).toContain('/oauth2/authorize');
  expect(discovery.token_endpoint).toContain('/oauth2/token');
  const jwksResponse = await request.get(discovery.jwks_uri);
  expect(jwksResponse.status()).toBe(200);
  expect((await jwksResponse.json()).keys.length).toBeGreaterThan(0);
});

test('login form obtains CSRF and rejects invalid credentials', async ({page}) => {
  const csrfPromise = page.waitForResponse((response) => new URL(response.url()).pathname === '/api/csrf');
  await page.goto(path('/login'));
  const csrfResponse = await csrfPromise;
  expect(csrfResponse.status()).toBe(200);
  expect((await csrfResponse.json()).token).toBeTruthy();

  const loginPromise = page.waitForResponse((response) => new URL(response.url()).pathname === '/api/login');
  await page.getByLabel('账号').fill('missing-e2e-' + randomSuffix());
  await page.getByLabel('密码').fill('invalid-e2e-password');
  await page.getByRole('button', {name: '登录'}).click();
  const response = await loginPromise;
  expect(response.status()).toBe(401);
  await expect(page.getByRole('alert')).toHaveText('登录失败，请检查账号或密码');
});

test('admin login, consent, token exchange, RP logout, and Career callback', async ({page}) => {
    const username = process.env.HEARTH_E2E_ADMIN_USERNAME;
    const password = process.env.HEARTH_E2E_ADMIN_PASSWORD;
    expect(username).toBeTruthy();
    expect(password).toBeTruthy();

    const csrfWait = page.waitForResponse((response) => new URL(response.url()).pathname === '/api/csrf');
    // Career owns state, nonce and the PKCE verifier in its server-side session.
    const careerAuthorizationObserved = page.waitForRequest((request) => {
      const url = new URL(request.url());
      return url.origin === new URL(base).origin && url.pathname === '/oauth2/authorize'
        && url.searchParams.get('client_id') === 'career-staging';
    });
    const careerCallbackObserved = page.waitForRequest((request) => {
      const url = new URL(request.url());
      return url.hostname === 'staging-career.bytedepth.cn' && url.pathname === '/login/oauth2/code/hearth';
    });
    await page.goto('https://staging-career.bytedepth.cn/calendar');
    const careerAuthorization = new URL((await careerAuthorizationObserved).url());
    expect(careerAuthorization.searchParams.get('state')).toBeTruthy();
    expect(careerAuthorization.searchParams.get('code_challenge_method')).toBe('S256');
    expect(careerAuthorization.searchParams.get('code_challenge')).toMatch(/^[A-Za-z0-9_-]{43}$/);
    const csrfResponse = await csrfWait;
    expect(csrfResponse.status()).toBe(200);
    expect((await csrfResponse.json()).token).toBeTruthy();
    const loginWait = page.waitForResponse((response) => new URL(response.url()).pathname === '/api/login');
    await page.getByLabel('账号').fill(username);
    await page.getByLabel('密码').fill(password);
    await page.getByRole('button', {name: '登录'}).click();
    const loginResponse = await loginWait;
    expect(loginResponse.status()).toBe(200);
    await expect(page).toHaveURL((url) => url.pathname === '/oauth2/consent'
      || url.hostname === 'staging-career.bytedepth.cn');
    await approveIfShown(page);
    const careerResult = new URL((await careerCallbackObserved).url());
    expect(careerResult.origin + careerResult.pathname).toBe(careerAuthorization.searchParams.get('redirect_uri'));
    expect(careerResult.searchParams.get('state')).toBe(careerAuthorization.searchParams.get('state'));
    expect(careerResult.searchParams.get('code')).toBeTruthy();
    expect(careerResult.searchParams.has('error')).toBe(false);
    await expect(page).toHaveURL((url) => url.hostname === 'staging-career.bytedepth.cn'
      && url.pathname === '/calendar');
    const sessionResponse = await page.request.get(path('/api/session'));
    expect(sessionResponse.status()).toBe(200);
    const hearthSession = await sessionResponse.json();
    expect(hearthSession.authenticated).toBe(true);
    expect(hearthSession.displayName).toBeTruthy();
    await expect(page.locator('.career-header__username')).toHaveText(hearthSession.displayName);

    const csrfResult = await page.request.get(path('/api/csrf'));
    expect(csrfResult.status()).toBe(200);
    const csrfToken = (await csrfResult.json()).token;
    const callbackUri = path('/consent-preview');
    const logoutUri = path('/consent-preview');
    const suffix = randomSuffix();
    const createClient = await page.request.post(path('/api/admin/oauth-clients'), {
      headers: {'X-CSRF-TOKEN': csrfToken},
      data: {
        applicationKey: 'hearth-e2e-' + suffix,
        displayName: 'Hearth E2E',
        redirectUris: [callbackUri],
        postLogoutRedirectUris: [logoutUri],
        scopes: ['openid', 'profile', 'email'],
      },
    });
    expect(createClient.status()).toBe(201);
    const client = await createClient.json();
    expect(client.clientSecret).toBeTruthy();

    const clientsResponse = await page.request.get(path('/api/admin/oauth-clients'));
    expect(clientsResponse.status()).toBe(200);
    const career = (await clientsResponse.json()).find((registered) => registered.clientId === 'career-staging');
    expect(career).toBeTruthy();
    const careerCallback = career.redirectUris.find((uri) => uri.startsWith('https://staging-career.bytedepth.cn/'));
    expect(careerCallback).toBeTruthy();

    const {verifier, challenge} = pkcePair();
    const state = randomSuffix();
    let callbackUrl;
    const callbackObserved = captureRequestUrl(page, (url) =>
      url.origin === new URL(base).origin && url.pathname === '/consent-preview' && url.searchParams.has('code'));
    await page.goto(authorizationUrl({
      clientId: client.clientId,
      redirectUri: callbackUri,
      scope: 'openid profile email',
      state,
      challenge,
    }));
    await expect(page).toHaveURL(/\/oauth2\/consent(?:\?|$)/);
    await expect(page.getByRole('heading', {
      name: '允许 Hearth E2E 使用你的 Hearth 账号？',
    })).toBeVisible();
    await expect(page.getByText('Hearth E2E 可访问')).toBeVisible();
    await expect(page.getByText(`已登记回调来源：${new URL(callbackUri).origin}`)).toBeVisible();
    await expect(page.getByText('基本资料')).toBeVisible();
    await expect(page.getByText('查看你的显示名称和头像')).toBeVisible();
    await expect(page.getByText('邮箱地址')).toBeVisible();
    await expect(page.getByText('查看与你的 Hearth 账号关联的邮箱')).toBeVisible();
    await expect(page.getByRole('button', {name: /同意并继续/})).toBeEnabled();
    await approveIfShown(page);
    callbackUrl = await callbackObserved;
    const callback = new URL(callbackUrl);
    expect(callback.searchParams.get('state')).toBe(state);
    const code = callback.searchParams.get('code');
    expect(code).toBeTruthy();

    const basic = Buffer.from(client.clientId + ':' + client.clientSecret).toString('base64');
    const tokenResponse = await page.request.post(path('/oauth2/token'), {
      headers: {Authorization: 'Basic ' + basic},
      form: {
        grant_type: 'authorization_code',
        code,
        redirect_uri: callbackUri,
        code_verifier: verifier,
      },
    });
    expect(tokenResponse.status()).toBe(200);
    const token = await tokenResponse.json();
    expect(token.access_token).toBeTruthy();
    expect(token.id_token).toBeTruthy();
    const idClaims = JSON.parse(Buffer.from(token.id_token.split('.')[1], 'base64url').toString());
    expect(idClaims.iss).toBe(expectedIssuer);
    expect(idClaims.sub).toBeTruthy();
    const userInfoResponse = await page.request.get(path('/userinfo'), {
      headers: {Authorization: 'Bearer ' + token.access_token},
    });
    expect(userInfoResponse.status()).toBe(200);
    expect((await userInfoResponse.json()).sub).toBe(idClaims.sub);

    expect(careerAuthorization.searchParams.get('redirect_uri')).toBe(careerCallback);
    await page.goto('https://staging-career.bytedepth.cn/calendar');
    await expect(page).toHaveURL((url) => url.hostname === 'staging-career.bytedepth.cn'
      && url.pathname === '/calendar');
    await expect(page.locator('.career-header__username')).toBeVisible();
    await expect(page.locator('.career-header__username')).toHaveText(hearthSession.displayName);
    const logoutButton = page.getByRole('button', {name: '退出登录'});
    const logoutForm = page.locator('form.career-header__logout');

    let logoutCallbackUrl;
    const logoutCallbackObserved = captureRequestUrl(page, (url) =>
      url.origin === new URL(base).origin && url.pathname === '/consent-preview' && url.searchParams.has('state'));
    const logoutState = randomSuffix();
    const logoutUrl = new URL('/connect/logout', base);
    logoutUrl.searchParams.set('id_token_hint', token.id_token);
    logoutUrl.searchParams.set('post_logout_redirect_uri', logoutUri);
    logoutUrl.searchParams.set('state', logoutState);
    await page.goto(logoutUrl.toString());
    logoutCallbackUrl = await logoutCallbackObserved;
    expect(new URL(logoutCallbackUrl).searchParams.get('state')).toBe(logoutState);
    const sessionAfterLogout = await page.request.get(path('/api/session'));
    expect(sessionAfterLogout.status()).toBe(403);
    // Hearth logout alone does not invalidate Career's local session. Exercise
    // Career's real logout button and its RP-initiated logout navigation too.
    await page.goto('https://staging-career.bytedepth.cn/calendar');
    await expect(page.locator('.career-header__username')).toHaveText(hearthSession.displayName);
    const rpLogout = page.waitForRequest((request) => new URL(request.url()).pathname === '/connect/logout');
    if (await logoutButton.isVisible()) {
      await logoutButton.click();
    } else {
      await logoutForm.evaluate((form) => form.requestSubmit());
    }
    expect(new URL((await rpLogout).url()).searchParams.get('id_token_hint')).toBeTruthy();
    await expect(page).toHaveURL((url) => url.origin === new URL(base).origin && url.pathname === '/login');
    const careerAfterLogout = await page.request.get('https://staging-career.bytedepth.cn/calendar', {
      headers: {Accept: 'text/html'}, maxRedirects: 0,
    });
    expect(careerAfterLogout.status()).toBe(302);
    expect((await page.request.get(path('/api/session'))).status()).toBe(403);
});
