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
    await page.goto(path('/login'));
    const csrfResponse = await csrfWait;
    expect(csrfResponse.status()).toBe(200);
    expect((await csrfResponse.json()).token).toBeTruthy();
    const loginWait = page.waitForResponse((response) => new URL(response.url()).pathname === '/api/login');
    await page.getByLabel('账号').fill(username);
    await page.getByLabel('密码').fill(password);
    await page.getByRole('button', {name: '登录'}).click();
    const loginResponse = await loginWait;
    expect(loginResponse.status()).toBe(200);
    expect((await loginResponse.json()).authenticated).toBe(true);

    const csrfResult = await page.request.get(path('/api/csrf'));
    expect(csrfResult.status()).toBe(200);
    const csrfToken = (await csrfResult.json()).token;
    const callbackUri = new URL('/__hearth_e2e/callback', base).toString();
    const logoutUri = new URL('/__hearth_e2e/logout', base).toString();
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

    const {verifier, challenge} = pkcePair();
    const state = randomSuffix();
    let callbackUrl;
    await page.route('**/__hearth_e2e/callback**', async (route) => {
      callbackUrl = route.request().url();
      await route.fulfill({status: 200, contentType: 'text/plain', body: 'callback captured'});
    });
    await page.goto(authorizationUrl({
      clientId: client.clientId,
      redirectUri: callbackUri,
      scope: 'openid profile email',
      state,
      challenge,
    }));
    await approveIfShown(page);
    await expect.poll(() => callbackUrl).toBeTruthy();
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

    const clientsResponse = await page.request.get(path('/api/admin/oauth-clients'));
    expect(clientsResponse.status()).toBe(200);
    const career = (await clientsResponse.json()).find((registered) => registered.clientId === 'career-staging');
    expect(career).toBeTruthy();
    const careerCallback = career.redirectUris.find((uri) => uri.startsWith('https://staging-career.bytedepth.cn/'));
    expect(careerCallback).toBeTruthy();
    const careerPkce = pkcePair();
    const careerState = randomSuffix();
    let careerCallbackUrl;
    await page.route('https://staging-career.bytedepth.cn/**', async (route) => {
      careerCallbackUrl = route.request().url();
      await route.fulfill({status: 200, contentType: 'text/plain', body: 'Career callback captured'});
    });
    await page.goto(authorizationUrl({
      clientId: career.clientId,
      redirectUri: careerCallback,
      scope: career.scopes.filter((scope) => ['openid', 'profile', 'email'].includes(scope)).join(' '),
      state: careerState,
      challenge: careerPkce.challenge,
    }));
    await approveIfShown(page);
    await expect.poll(() => careerCallbackUrl).toBeTruthy();
    const careerResult = new URL(careerCallbackUrl);
    expect(careerResult.toString().startsWith(careerCallback)).toBe(true);
    expect(careerResult.searchParams.get('state')).toBe(careerState);
    expect(careerResult.searchParams.get('code')).toBeTruthy();

    let logoutCallbackUrl;
    await page.route('**/__hearth_e2e/logout**', async (route) => {
      logoutCallbackUrl = route.request().url();
      await route.fulfill({status: 200, contentType: 'text/plain', body: 'logout callback captured'});
    });
    const logoutState = randomSuffix();
    const logoutUrl = new URL('/connect/logout', base);
    logoutUrl.searchParams.set('id_token_hint', token.id_token);
    logoutUrl.searchParams.set('post_logout_redirect_uri', logoutUri);
    logoutUrl.searchParams.set('state', logoutState);
    await page.goto(logoutUrl.toString());
    await expect.poll(() => logoutCallbackUrl).toBeTruthy();
    expect(new URL(logoutCallbackUrl).searchParams.get('state')).toBe(logoutState);
});
