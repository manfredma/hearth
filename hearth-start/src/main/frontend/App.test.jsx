import React from 'react';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, vi } from 'vitest';
import App from './App.jsx';
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
    render(<LoginPage />);

    expect(screen.getByRole('heading', { name: '回到 hearth' })).toBeTruthy();
    expect(screen.getByLabelText('账号')).toBeTruthy();
    expect(screen.getByLabelText('密码')).toBeTruthy();
    await waitFor(() => expect(globalThis.fetch).toHaveBeenCalledWith('/api/csrf', { headers: { Accept: 'application/json' } }));
    expect(localStorageSetItem).not.toHaveBeenCalled();
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
});
