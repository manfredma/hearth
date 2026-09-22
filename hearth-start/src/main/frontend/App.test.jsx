import React from 'react';
import { fireEvent, render, screen } from '@testing-library/react';
import { vi } from 'vitest';
import App from './App.jsx';

describe('Hearth application shell', () => {
  beforeEach(() => {
    globalThis.fetch = vi.fn().mockResolvedValue({ ok: false });
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
    expect(screen.getByRole('link', { name: '登录' }).getAttribute('href')).toBe('/oauth2/authorization/hearth');
  });
});
