import React, { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { ArrowUpRight, Boxes, ChevronDown, Command, ExternalLink, Fingerprint, Menu, ShieldCheck, Sparkles, X } from 'lucide-react';
import './styles.css';

const applications = [
  { key: 'byte-depth', name: ['Byte', 'Depth'].join(''), description: '技术写作与知识沉淀', tone: 'coral', status: '已连接' },
  { key: 'daylilt', name: 'Daylilt', description: '给日常留一处安静的光', tone: 'lilac', status: '已连接' },
  { key: 'career', name: 'Career', description: '职业成长与工作台', tone: 'sage', status: '已连接' },
  { key: 'toolbox', name: 'Toolbox', description: '常用工具与自动化', tone: 'gold', status: '已连接' },
];

export default function App() {
  const [identity, setIdentity] = useState(null);
  const [loading, setLoading] = useState(true);
  const [mobileOpen, setMobileOpen] = useState(false);

  useEffect(() => {
    fetch('/api/session', { headers: { Accept: 'application/json' } })
      .then((response) => response.ok ? response.json() : null)
      .then(setIdentity)
      .catch(() => setIdentity(null))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="hearth-shell">
      <aside className={`hearth-sidebar ${mobileOpen ? 'is-open' : ''}`}>
        <div className="brand-lockup"><div className="brand-mark"><span>h</span></div><div><strong>hearth</strong><small>identity center</small></div><button className="icon-button sidebar-close" onClick={() => setMobileOpen(false)} aria-label="关闭菜单"><X size={18} /></button></div>
        <nav className="side-nav" aria-label="主导航">
          <a className="nav-item is-active" href="#overview"><Command size={18} /><span>总览</span></a>
          <a className="nav-item" href="#applications"><Boxes size={18} /><span>应用接入</span><span className="nav-count">4</span></a>
          <a className="nav-item" href="#security"><ShieldCheck size={18} /><span>安全设置</span></a>
        </nav>
        <div className="sidebar-footer"><div className="quiet-note"><Sparkles size={16} /><span>一个账号，连接你的工作与生活。</span></div><div className="identity-mini"><div className="avatar">{identity?.displayName?.slice(0, 1) || '·'}</div><div><b>{identity?.displayName || '访客'}</b><small>{identity ? '已登录' : '尚未登录'}</small></div><ChevronDown size={16} /></div></div>
      </aside>
      {mobileOpen && <button className="mobile-scrim" onClick={() => setMobileOpen(false)} aria-label="关闭菜单" />}
      <main className="hearth-main">
        <header className="topbar"><button className="icon-button menu-trigger" onClick={() => setMobileOpen(true)} aria-label="打开菜单"><Menu size={20} /></button><div className="breadcrumb"><span>hearth</span><span className="slash">/</span><b>总览</b></div><div className="topbar-actions"><button className="help-link">帮助文档 <ExternalLink size={14} /></button>{identity ? <button className="profile-chip"><div className="avatar small">{identity.displayName.slice(0, 1)}</div><span>{identity.displayName}</span><ChevronDown size={15} /></button> : <a className="button button-dark" href="/login">{loading ? '检查登录' : '登录'}</a>}</div></header>
        <div className="content-wrap" id="overview">
          <section className="hero-row"><div><div className="eyebrow"><span className="eyebrow-dot" />统一身份中心</div><h1>你好，{loading ? '正在确认你的身份' : identity?.displayName || '欢迎回到 hearth'}</h1><p className="hero-copy">从这里进入你使用的每一个应用。一次登录，保持专注。</p></div><div className="hero-symbol"><Fingerprint size={38} strokeWidth={1.3} /><span>your<br />identity<br />is yours</span></div></section>
          <section className="stats-grid" aria-label="身份概览"><div className="stat-card"><span>已连接应用</span><strong>04</strong><small>均使用 Hearth 统一认证</small></div><div className="stat-card"><span>当前会话</span><strong>{identity ? '安全' : '访客'}</strong><small>{identity ? '服务端会话已建立' : '登录后可访问应用'}</small></div><div className="stat-card accent"><span>身份提供方</span><strong>OIDC</strong><small>Provider-neutral by design</small></div></section>
          <section className="section-block" id="applications"><div className="section-heading"><div><span className="section-kicker">YOUR APPS</span><h2>你的应用</h2></div><button className="text-button">管理接入 <ArrowUpRight size={16} /></button></div><div className="app-grid">{applications.map((app) => <ApplicationCard key={app.key} app={app} />)}</div></section>
          <section className="security-banner" id="security"><div className="security-icon"><ShieldCheck size={24} /></div><div><b>你的身份，由你掌握</b><p>Hearth 只负责确认“你是谁”，应用自己的业务权限仍由应用管理。</p></div><ArrowUpRight size={18} /></section>
          <footer className="page-footer"><span>hearth · a quiet place for identity</span><span>v0.1 · <a href="#security">隐私与安全</a></span></footer>
        </div>
      </main>
    </div>
  );
}

export function LoginPage({ navigate = redirectTo } = {}) {
  const [login, setLogin] = useState('');
  const [password, setPassword] = useState('');
  const [csrfToken, setCsrfToken] = useState(null);
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    fetch('/api/csrf', { headers: { Accept: 'application/json' } })
      .then((response) => response.ok ? response.json() : Promise.reject(new Error('csrf unavailable')))
      .then((payload) => setCsrfToken(payload.token))
      .catch(() => setError('当前登录服务暂不可用，请稍后再试'));
  }, []);

  const returnTo = safeReturnTo(new URLSearchParams(window.location.search).get('continue'));

  async function submit(event) {
    event.preventDefault();
    setSubmitting(true);
    setError('');
    try {
      const response = await fetch('/api/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'X-XSRF-TOKEN': csrfToken || '' },
        body: JSON.stringify({ login, password }),
      });
      if (!response.ok) {
        setError('登录失败，请检查账号或密码');
        return;
      }
      const payload = await response.json();
      navigate(safeReturnTo(payload.redirectTo || returnTo));
    } catch {
      setError('当前登录服务暂不可用，请稍后再试');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="login-shell">
      <section className="login-card" aria-labelledby="login-title">
        <div className="login-brand"><div className="brand-mark"><span>h</span></div><span>hearth</span></div>
        <div className="eyebrow"><span className="eyebrow-dot" />统一身份中心</div>
        <h1 id="login-title">回到 hearth</h1>
        <p className="login-copy">一次登录，连接你的工作与生活。</p>
        <form onSubmit={submit} noValidate>
          <label htmlFor="login-account">账号</label>
          <input id="login-account" value={login} onChange={(event) => setLogin(event.target.value)} autoComplete="username" required />
          <label htmlFor="login-password">密码</label>
          <input id="login-password" type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="current-password" required />
          {error && <p className="login-error" role="alert">{error}</p>}
          <button className="button button-dark login-submit" type="submit" disabled={submitting}>{submitting ? '正在登录…' : '登录'}</button>
        </form>
        <p className="login-footnote">你的密码只提交给 Hearth，登录状态保存在服务端会话中。</p>
      </section>
    </main>
  );
}

function safeReturnTo(value) {
  return value && value.startsWith('/') && !value.startsWith('//') ? value : '/';
}

export function redirectTo(path, locationObject = window.location) {
  locationObject.assign(path);
}

function ApplicationCard({ app }) { return <a className="app-card" href={`#app-${app.key}`}><div className={`app-icon ${app.tone}`}>{app.name.slice(0, 1).toLowerCase()}</div><div className="app-copy"><div className="app-title"><h3>{app.name}</h3><span className="status-dot" /></div><p>{app.description}</p><small>{app.status}</small></div><ArrowUpRight className="card-arrow" size={18} /></a>; }

/* c8 ignore start */
const rootElement = document.getElementById('root');
if (rootElement) {
  createRoot(rootElement).render(window.location.pathname === '/login' ? <LoginPage /> : <App />);
}
/* c8 ignore stop */
