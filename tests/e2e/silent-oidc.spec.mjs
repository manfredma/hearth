import {createHash, randomBytes} from 'node:crypto';
import {expect, test} from '@playwright/test';

const base = process.env.E2E_BASE_URL;
const business = 'https://staging-bytedepth.bytedepth.cn';
test.use({trace: 'off', screenshot: 'off', video: 'off'});

// Keep OAuth artifacts in memory and out of assertion/network diagnostics.
async function get(context, url, options = {}) {
  try { return await context.request.get(url, {maxRedirects: 0, ...options}); }
  catch { throw new Error('Private OIDC request failed'); }
}
async function post(context, url, options) {
  try { return await context.request.post(url, {maxRedirects: 0, ...options}); }
  catch { throw new Error('Private OIDC submission failed'); }
}
async function generatedRequest(context) {
  const response = await get(context, business + '/oauth2/authorization/hearth');
  expect(response.status()).toBe(302);
  const url = new URL(response.headers().location);
  expect(url.origin === new URL(base).origin && url.pathname === '/oauth2/authorize').toBe(true);
  expect(url.searchParams.get('client_id') === 'bytedepth-staging').toBe(true);
  expect(url.searchParams.get('code_challenge_method') === 'S256').toBe(true);
  expect(Boolean(url.searchParams.get('state') && url.searchParams.get('nonce'))).toBe(true);
  url.searchParams.set('prompt', 'none');
  return url;
}
async function silent(context, mutate = () => {}) {
  const request = await generatedRequest(context);
  mutate(request);
  const response = await get(context, request.toString());
  return {request, response};
}
function protocol(result, expectedError) {
  const {request, response} = result;
  expect(response.status()).toBe(302);
  const callback = new URL(response.headers().location, base);
  expect(callback.origin + callback.pathname === request.searchParams.get('redirect_uri')).toBe(true);
  expect(callback.searchParams.get('state') === request.searchParams.get('state')).toBe(true);
  expect(callback.searchParams.get('error') === expectedError).toBe(true);
  expect(callback.searchParams.has('code')).toBe(expectedError === null);
  return callback;
}
async function successfulBusinessCallback(context) {
  const callback = protocol(await silent(context), null);
  const response = await get(context, callback.toString());
  expect(response.status()).toBe(302);
  const destination = new URL(response.headers().location, business);
  expect(destination.searchParams.has('error')).toBe(false);
  expect((await get(context, business + '/admin/analytics')).status()).toBe(200);
}
async function login(page) {
  const username = process.env.HEARTH_E2E_ADMIN_USERNAME;
  const password = process.env.HEARTH_E2E_ADMIN_PASSWORD;
  expect(Boolean(username && password)).toBe(true);
  await page.goto(new URL('/login', base).toString());
  await page.getByLabel('账号').fill(username);
  await page.getByLabel('密码').fill(password);
  await page.getByRole('checkbox', {name: '保持登录 30 天'}).check();
  const result = page.waitForResponse(r => new URL(r.url()).pathname === '/api/login');
  await page.getByRole('button', {name: '登录'}).click();
  expect((await result).status()).toBe(200);
  await expect.poll(() => new URL(page.url()).pathname !== '/login').toBe(true);
}

test('silent relying-party authorization: anonymous, session, Remember-Me, consent, validation and local logout', async ({page, browser}) => {
  test.setTimeout(90_000);
  const context = page.context();
  protocol(await silent(context), 'login_required');
  expect((await context.cookies(base)).some(c => /SESSION/.test(c.name))).toBe(false);
  console.log('SILENT_SCENARIO anonymous: PASS');

  await context.addCookies([{name: 'hearth-remember-me', value: 'invalid-signature', url: base,
    httpOnly: true, secure: true, sameSite: 'Lax'}]);
  protocol(await silent(context), 'login_required');
  expect((await context.cookies(base)).some(c => c.name === 'hearth-remember-me')).toBe(false);
  console.log('SILENT_SCENARIO invalid-signature: PASS');

  for (const kind of ['client', 'redirect', 'missing-pkce', 'plain-pkce', 'prompt']) {
    const result = await silent(context, url => {
      if (kind === 'client') url.searchParams.set('client_id', 'unregistered-silent-client');
      if (kind === 'redirect') url.searchParams.set('redirect_uri', 'https://untrusted.invalid/callback');
      if (kind === 'missing-pkce') url.searchParams.delete('code_challenge');
      if (kind === 'plain-pkce') url.searchParams.set('code_challenge_method', 'plain');
      if (kind === 'prompt') url.searchParams.set('prompt', 'none login');
    });
    if (kind === 'client' || kind === 'redirect') {
      expect(result.response.status()).toBe(400);
      expect(Boolean(result.response.headers().location)).toBe(false);
    } else protocol(result, 'invalid_request');
  }
  console.log('SILENT_SCENARIO invalid-client-redirect-pkce-prompt: PASS');

  await login(page);
  // Establish explicit relying-party consent once through its ordinary flow.
  try { await page.goto(business + '/oauth2/authorization/hearth'); }
  catch { throw new Error('Interactive relying-party navigation failed'); }
  await expect.poll(() => ['/oauth2/consent'].includes(new URL(page.url()).pathname)
    || new URL(page.url()).origin === business).toBe(true);
  if (new URL(page.url()).pathname === '/oauth2/consent') {
    await page.getByRole('button', {name: /同意并继续/}).click();
  }
  await expect.poll(() => new URL(page.url()).origin === business).toBe(true);
  expect((await get(context, business + '/admin/analytics')).status()).toBe(200);
  console.log('SILENT_SCENARIO ordinary-interactive-flow: PASS');

  const hearthCookies = await context.cookies(base);
  const remembered = hearthCookies.filter(c => c.name === 'hearth-remember-me');
  const sessions = hearthCookies.filter(c => c.httpOnly && c.name !== 'hearth-remember-me');
  expect(remembered.length).toBe(1);
  expect(sessions.length > 0).toBe(true);
  const sessionOnly = await browser.newContext();
  const cookieOnly = await browser.newContext();
  try {
    await sessionOnly.addCookies(sessions);
    expect((await sessionOnly.cookies(base)).some(c => c.name === 'hearth-remember-me')).toBe(false);
    await successfulBusinessCallback(sessionOnly);
    console.log('SILENT_SCENARIO session-only-real-callback: PASS');

    await cookieOnly.addCookies(remembered);
    expect((await cookieOnly.cookies(base)).every(c => c.name === 'hearth-remember-me')).toBe(true);
    // The first Hearth request is authorization, with no /api/session prewarm.
    await successfulBusinessCallback(cookieOnly);
    console.log('SILENT_SCENARIO remember-only-real-callback: PASS');

    const csrf = await cookieOnly.request.get(new URL('/api/csrf', base).toString());
    const csrfToken = (await csrf.json()).token;
    const localLogout = await post(cookieOnly, new URL('/api/session/logout', base).toString(), {
      headers: {'X-CSRF-TOKEN': csrfToken},
    });
    expect(localLogout.status()).toBe(204);
    expect((await cookieOnly.cookies(base)).some(c => c.name === 'hearth-remember-me')).toBe(false);
    protocol(await silent(cookieOnly), 'login_required');
    console.log('SILENT_SCENARIO local-logout-no-restore: PASS');
  } finally {
    await sessionOnly.close();
    await cookieOnly.close();
  }

  // A newly registered isolated client has no previous consent to borrow.
  const csrf = await context.request.get(new URL('/api/csrf', base).toString());
  const csrfToken = (await csrf.json()).token;
  const callback = new URL('/consent-preview', base).toString();
  const created = await post(context, new URL('/api/admin/oauth-clients', base).toString(), {
    headers: {'X-CSRF-TOKEN': csrfToken}, data: {
      applicationKey: 'silent-e2e-' + randomBytes(8).toString('hex'), displayName: 'Silent consent fixture',
      redirectUris: [callback], postLogoutRedirectUris: [callback], scopes: ['openid', 'profile'],
    },
  });
  expect(created.status()).toBe(201);
  const client = await created.json();
  const request = new URL('/oauth2/authorize', base);
  const verifier = randomBytes(32).toString('base64url');
  request.search = new URLSearchParams({response_type: 'code', client_id: client.clientId,
    redirect_uri: callback, scope: 'openid profile', state: randomBytes(16).toString('hex'),
    nonce: randomBytes(16).toString('hex'), prompt: 'none',
    code_challenge: createHash('sha256').update(verifier).digest('base64url'), code_challenge_method: 'S256'}).toString();
  protocol({request, response: await get(context, request.toString())}, 'consent_required');
  console.log('SILENT_SCENARIO consent-required: PASS');
});
