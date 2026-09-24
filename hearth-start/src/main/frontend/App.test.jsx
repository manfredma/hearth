import React from 'react';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, vi } from 'vitest';
import App from './App.jsx';
import ConsentPreview from './ConsentPreview.jsx';
import { LoginPage, redirectTo } from './main.jsx';

describe('Hearth application shell', () => {
  beforeEach(() => {
    globalThis.fetch = vi.fn().mockResolvedValue({ ok: false });
  });

  afterEach(() => {
    window.history.replaceState({}, '', '/');
  });

  it('shows the identity overview and connected applications', async () => {
    render(<App />);

    expect(await screen.findByText(/欢迎回到 hearth/)).toBeTruthy();
    expect(screen.getByText(/Byte.*Depth/)).toBeTruthy();
    expect(screen.getByText('Daylilt')).toBeTruthy();
  });

  it('opens the mobile navigation', async () => {
    render(<App />);
    await screen.findByText(/欢迎回到 hearth/);
    fireEvent.click(screen.getByRole('button', { name: '打开菜单' }));
    expect(screen.getAllByRole('button', { name: '关闭菜单' })).toHaveLength(2);
    fireEvent.click(screen.getAllByRole('button', { name: '关闭菜单' })[0]);
    expect(screen.queryByRole('button', { name: '打开菜单' })).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: '打开菜单' }));
    fireEvent.click(screen.getAllByRole('button', { name: '关闭菜单' })[1]);
  });

  it('renders the signed-in identity returned by the server', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: () => Promise.resolve({ displayName: '冯华杰' }),
    });
    render(<App />);

    expect(await screen.findByText(/你好，冯华杰/)).toBeTruthy();
    expect(screen.getByText('已登录')).toBeTruthy();
  });

  it('falls back to the guest state when the session request fails', async () => {
    globalThis.fetch = vi.fn().mockRejectedValue(new Error('offline'));
    render(<App />);

    expect(await screen.findByText(/欢迎回到 hearth/)).toBeTruthy();
    expect(screen.getByRole('link', { name: '登录' }).getAttribute('href')).toBe('/login');
  });

  it('renders a server-session login form without browser storage', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({ ok: true, json: () => Promise.resolve({ token: 'csrf-token' }) });
    const localStorageSetItem = vi.spyOn(Storage.prototype, 'setItem');
    const sessionStorageSetItem = vi.spyOn(window.sessionStorage, 'setItem');
    render(<LoginPage />);

    expect(screen.getByRole('heading', { name: '回到 hearth' })).toBeTruthy();
    expect(screen.getByLabelText('账号')).toBeTruthy();
    expect(screen.getByLabelText('密码')).toBeTruthy();
    expect(screen.getByRole('checkbox', { name: '保持登录 30 天' }).checked).toBe(false);
    await waitFor(() => expect(globalThis.fetch).toHaveBeenCalledWith('/api/csrf', { headers: { Accept: 'application/json' } }));
    expect(localStorageSetItem).not.toHaveBeenCalled();
    expect(sessionStorageSetItem).not.toHaveBeenCalled();
  });

  it('sends the selected 30-day login preference with credentials', async () => {
    const navigate = vi.fn();
    globalThis.fetch = vi.fn()
      .mockResolvedValueOnce({ ok: true, json: () => Promise.resolve({ token: 'csrf-token' }) })
      .mockResolvedValueOnce({ ok: true, json: () => Promise.resolve({ authenticated: true }) });
    render(<LoginPage navigate={navigate} />);

    await waitFor(() => expect(screen.getByRole('button', { name: '登录' }).disabled).toBe(false));
    fireEvent.change(screen.getByLabelText('账号'), { target: { value: 'admin' } });
    fireEvent.change(screen.getByLabelText('密码'), { target: { value: 'secret' } });
    fireEvent.click(screen.getByRole('checkbox', { name: '保持登录 30 天' }));
    fireEvent.click(screen.getByRole('button', { name: '登录' }));

    await waitFor(() => expect(globalThis.fetch).toHaveBeenCalledTimes(2));
    expect(JSON.parse(globalThis.fetch.mock.calls[1][1].body)).toEqual({ login: 'admin', password: 'secret', rememberMe: true });
    expect(navigate).toHaveBeenCalledWith('/');
  });

  it('uses the same brand mark on the login page and sidebar', async () => {
    render(<App />);
    expect(await screen.findByText(/欢迎回到 hearth/)).toBeTruthy();
    const sidebarMark = screen.getByAltText('Hearth 标志');
    expect(sidebarMark.getAttribute('src')).toBe('/favicon.svg');

    render(<LoginPage />);
    const marks = screen.getAllByAltText('Hearth 标志');
    expect(marks).toHaveLength(2);
    expect(marks[1].getAttribute('src')).toBe(sidebarMark.getAttribute('src'));
  });

  it('does not allow login submission before the CSRF token is ready', async () => {
    let resolveCsrf;
    globalThis.fetch = vi.fn().mockReturnValue(new Promise((resolve) => {
      resolveCsrf = resolve;
    }));
    render(<LoginPage />);

    const submit = screen.getByRole('button', { name: '登录' });
    expect(submit.disabled).toBe(true);
    resolveCsrf({ ok: true, json: () => Promise.resolve({ token: 'csrf-token' }) });
    await waitFor(() => expect(submit.disabled).toBe(false));
  });

  it('shows an unavailable state when the csrf token cannot be loaded', async () => {
    globalThis.fetch = vi.fn().mockResolvedValue({ ok: false });
    render(<LoginPage />);

    expect((await screen.findByRole('alert')).textContent).toContain('当前登录服务暂不可用');
  });

  it('submits credentials and navigates only after a successful server response', async () => {
    const navigate = vi.fn();
    globalThis.fetch = vi.fn()
      .mockResolvedValueOnce({ ok: true, json: () => Promise.resolve({ token: 'csrf-token' }) })
      .mockResolvedValueOnce({ ok: true, json: () => Promise.resolve({ redirectTo: '/oauth2/authorize?client_id=daylilt' }) });
    window.history.replaceState({}, '', '/login?continue=/applications');
    render(<LoginPage navigate={navigate} />);
    await waitFor(() => expect(globalThis.fetch).toHaveBeenCalledTimes(1));
    fireEvent.change(screen.getByLabelText('账号'), { target: { value: 'admin' } });
    fireEvent.change(screen.getByLabelText('密码'), { target: { value: 'secret' } });
    fireEvent.submit(screen.getByLabelText('账号').closest('form'));

    await waitFor(() => expect(navigate).toHaveBeenCalledWith('/oauth2/authorize?client_id=daylilt'));
    expect(globalThis.fetch).toHaveBeenLastCalledWith('/api/login', expect.objectContaining({
      method: 'POST',
      headers: expect.objectContaining({ 'X-CSRF-TOKEN': 'csrf-token' }),
    }));
    expect(JSON.parse(globalThis.fetch.mock.lastCall[1].body).rememberMe).toBe(false);
  });

  it('uses the requested return target when no saved authorization request exists', async () => {
    const navigate = vi.fn();
    globalThis.fetch = vi.fn()
      .mockResolvedValueOnce({ ok: true, json: () => Promise.resolve({ token: 'csrf-token' }) })
      .mockResolvedValueOnce({ ok: true, json: () => Promise.resolve({ authenticated: true }) });
    window.history.replaceState({}, '', '/login?continue=/applications');
    render(<LoginPage navigate={navigate} />);
    fireEvent.change(screen.getByLabelText('账号'), { target: { value: 'admin' } });
    fireEvent.change(screen.getByLabelText('密码'), { target: { value: 'secret' } });
    fireEvent.submit(screen.getByLabelText('账号').closest('form'));

    await waitFor(() => expect(navigate).toHaveBeenCalledWith('/applications'));
  });

  it('keeps the user on the page and shows a generic error for failed login', async () => {
    globalThis.fetch = vi.fn()
      .mockResolvedValueOnce({ ok: true, json: () => Promise.resolve({ token: 'csrf-token' }) })
      .mockResolvedValueOnce({ ok: false });
    render(<LoginPage />);
    fireEvent.change(screen.getByLabelText('账号'), { target: { value: 'admin' } });
    fireEvent.change(screen.getByLabelText('密码'), { target: { value: 'wrong' } });
    fireEvent.submit(screen.getByLabelText('账号').closest('form'));

    expect((await screen.findByRole('alert')).textContent).toContain('登录失败，请检查账号或密码');
  });

  it('falls back to the home page for an unsafe return target and handles network errors', async () => {
    const navigate = vi.fn();
    globalThis.fetch = vi.fn()
      .mockResolvedValueOnce({ ok: true, json: () => Promise.resolve({ token: 'csrf-token' }) })
      .mockRejectedValueOnce(new Error('offline'));
    window.history.replaceState({}, '', '/login?continue=//evil.example');
    render(<LoginPage navigate={navigate} />);
    fireEvent.change(screen.getByLabelText('账号'), { target: { value: 'admin' } });
    fireEvent.change(screen.getByLabelText('密码'), { target: { value: 'secret' } });
    fireEvent.submit(screen.getByLabelText('账号').closest('form'));

    expect((await screen.findByRole('alert')).textContent).toContain('当前登录服务暂不可用');
    expect(navigate).not.toHaveBeenCalled();
  });

  it('keeps browser navigation in one testable helper', () => {
    const assign = vi.fn();
    redirectTo('/target', { assign });
    expect(assign).toHaveBeenCalledWith('/target');
  });

  it('renders the branded consent preview with source application and permissions', () => {
    render(<ConsentPreview />);

    expect(document.querySelector('.consent-shell')?.classList.contains('consent-shell--quiet')).toBe(true);
    expect(screen.getByRole('heading', { name: '允许 Career 使用你的 Hearth 账号？' })).toBeTruthy();
    expect(screen.getByText('来自 Career')).toBeTruthy();
    expect(screen.getByText('已验证来源')).toBeTruthy();
    expect(screen.getByText('连接到')).toBeTruthy();
    expect(screen.getByText('Career 可访问')).toBeTruthy();
    expect(screen.getByText('staging-career.bytedepth.cn')).toBeTruthy();
    expect(screen.getByText('名称：冯华杰')).toBeTruthy();
    expect(screen.getByText('基本资料')).toBeTruthy();
    expect(screen.getByText('邮箱地址')).toBeTruthy();
    expect(screen.getByRole('button', { name: /同意并继续/ }).disabled).toBe(false);
    expect(screen.queryByText('使用账号')).toBeNull();
    expect(screen.getByText('staging-career.bytedepth.cn').parentElement?.classList.contains('consent-app-copy')).toBe(true);
    expect(screen.getByRole('region', { name: '授权来源' }).classList.contains('consent-flat-surface')).toBe(true);
    const source = screen.getByRole('region', { name: '授权来源' });
    const account = screen.getByRole('region', { name: '当前账号' });
    expect(account.classList.contains('consent-account-inline')).toBe(true);
    expect(source.contains(account)).toBe(true);
    expect(screen.getByAltText('Hearth 账号标志').getAttribute('src')).toBe('/favicon.svg');
    expect(screen.getByText('账号：admin')).toBeTruthy();
    expect(screen.getByText('名称：冯华杰')).toBeTruthy();
    expect(screen.queryByText('你的身份中心')).toBeNull();
    expect(account.querySelector('svg')).toBeNull();
    expect(screen.getByRole('heading', { name: '允许 Career 使用你的 Hearth 账号？' }).classList.contains('consent-title-type')).toBe(true);
    expect(screen.getByRole('heading', { name: 'Career 可访问' }).classList.contains('consent-title-type')).toBe(true);
    const permissions = screen.getByRole('region', { name: 'Career 可访问' });
    expect(permissions.textContent).toContain('Career 只能访问你选择的信息，登录凭据不会共享；授权后可随时在 Hearth 中撤销。');
    const title = screen.getByRole('heading', { name: '允许 Career 使用你的 Hearth 账号？' });
    expect(title.compareDocumentPosition(source) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  });

  it('lets the user review permissions before continuing', () => {
    render(<ConsentPreview />);

    const profile = screen.getByRole('checkbox', { name: /基本资料/ });
    const email = screen.getByRole('checkbox', { name: /邮箱地址/ });
    expect(profile.closest('label')?.firstElementChild).toBe(profile);
    fireEvent.click(profile);
    expect(profile.checked).toBe(false);
    fireEvent.click(email);
    expect(screen.getByRole('button', { name: /同意并继续/ }).disabled).toBe(true);
  });
});
