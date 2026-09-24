import React, { useEffect, useRef, useState } from 'react';
import { Check, ChevronRight, LockKeyhole, Mail, ShieldCheck, UserRound } from 'lucide-react';

const scopeDefinitions = [
  { key: 'profile', icon: UserRound, title: '基本资料', description: '查看你的显示名称和头像' },
  { key: 'email', icon: Mail, title: '邮箱地址', description: '查看与你的 Hearth 账号关联的邮箱' },
];

const applications = {
  'career-staging': { name: 'Career', description: '职业成长与工作台', domain: 'staging-career.bytedepth.cn', tone: 'sage' },
};

const previewApplication = { name: 'Career', description: '职业成长与工作台', domain: 'staging-career.bytedepth.cn', tone: 'sage' };
const previewIdentity = { username: 'admin', displayName: '冯华杰' };

export default function ConsentPreview({ preview = true, search = '' }) {
  const query = new URLSearchParams(preview ? '' : search || window.location.search);
  const clientId = query.get('client_id') || 'career-staging';
  const application = preview ? previewApplication : applications[clientId] || {
    name: clientId,
    description: '已接入 Hearth 的应用',
    domain: '已验证来源',
    tone: 'sage',
  };
  const requestedScopes = preview
    ? scopeDefinitions.map(({ key }) => key)
    : (query.get('scope') || '').split(/\s+/).filter((scope) => scopeDefinitions.some((item) => item.key === scope));
  const visiblePermissions = scopeDefinitions.filter(({ key }) => requestedScopes.includes(key));
  const displayedPermissions = visiblePermissions.length > 0 ? visiblePermissions : scopeDefinitions;
  const [selected, setSelected] = useState(() => Object.fromEntries(displayedPermissions.map(({ key }) => [key, true])));
  const [identity, setIdentity] = useState(preview ? previewIdentity : null);
  const [csrfToken, setCsrfToken] = useState(preview ? null : '');
  const formRef = useRef(null);

  useEffect(() => {
    if (preview) {
      return undefined;
    }
    fetch('/api/session', { headers: { Accept: 'application/json' } })
      .then((response) => response.ok ? response.json() : Promise.reject(new Error('session unavailable')))
      .then((session) => setIdentity({ username: session.username || '当前账号', displayName: session.displayName || '当前账号' }))
      .catch(() => setIdentity({ username: '当前账号', displayName: '当前账号' }));
    return undefined;
  }, [preview]);

  useEffect(() => {
    if (preview) {
      return undefined;
    }
    // The OAuth authorization endpoint is a state-changing POST. The form is
    // rendered by React rather than Thymeleaf, so it must explicitly load the
    // server-issued token and submit it as the standard `_csrf` parameter.
    fetch('/api/csrf', { headers: { Accept: 'application/json' } })
      .then((response) => response.ok ? response.json() : Promise.reject(new Error('csrf unavailable')))
      .then((payload) => setCsrfToken(payload.token || ''))
      .catch(() => setCsrfToken(''));
    return undefined;
  }, [preview]);

  useEffect(() => {
    if (preview || !formRef.current) {
      return undefined;
    }
    const form = formRef.current;
    form.elements.namedItem('client_id').value = clientId;
    form.elements.namedItem('state').value = query.get('state') || '';
    const userCodeField = form.elements.namedItem('user_code');
    if (userCodeField) {
      userCodeField.value = query.get('user_code');
    }
    form.querySelectorAll('input[data-scope]').forEach((input) => {
      input.value = input.dataset.scope;
    });
    return undefined;
  });

  function togglePermission(key) {
    setSelected((current) => ({ ...current, [key]: !current[key] }));
  }

  function submitOAuthForm(form) {
    const clientField = form.elements.namedItem('client_id');
    const stateField = form.elements.namedItem('state');
    const userCodeField = form.elements.namedItem('user_code');
    clientField.value = clientId;
    stateField.value = query.get('state') || '';
    if (userCodeField) {
      userCodeField.value = query.get('user_code');
    }
    form.querySelectorAll('input[data-scope]').forEach((input) => {
      input.value = input.dataset.scope;
    });
    HTMLFormElement.prototype.submit.call(form);
  }

  function cancelConsent(event) {
    if (preview) {
      return;
    }
    event.preventDefault();
    formRef.current?.querySelectorAll('input[name="scope"]').forEach((input) => {
      input.checked = false;
    });
    if (formRef.current) {
      submitOAuthForm(formRef.current);
    }
  }

  function handleSubmit(event) {
    event.preventDefault();
    submitOAuthForm(event.currentTarget);
  }

  const selectedCount = Object.values(selected).filter(Boolean).length;
  const account = identity || { username: '正在读取…', displayName: '正在读取…' };

  return (
    <main className="consent-shell consent-shell--quiet">
      <section className="consent-card" aria-labelledby="consent-title">
        <header className="consent-header">
          <div className="consent-brand">
            <img className="brand-mark" src="/favicon.svg" alt="Hearth 标志" />
            <div><strong>hearth</strong><small>统一身份中心</small></div>
          </div>
          <span className="consent-label"><ShieldCheck size={13} />Hearth 安全授权</span>
        </header>

        <div className="consent-heading">
          <span className="eyebrow"><span className="eyebrow-dot" />确认授权</span>
          <h1 className="consent-title-type" id="consent-title">允许 {application.name} 使用你的 Hearth 账号？</h1>
        </div>

        <section className="consent-connection consent-flat-surface" aria-label="授权来源">
          <div className="consent-connection-top">
            <span>来自 {application.name}</span>
            <span className="consent-verified"><Check size={13} />已验证来源</span>
          </div>
          <div className="consent-context-body">
            <div className="consent-connection-main">
              <div className={`consent-source consent-app-${application.tone}`}>
                <div className="consent-app-icon sage">c</div>
                <div className="consent-app-copy">
                  <strong>{application.name}</strong>
                  <span>{application.description}</span>
                  <small className="consent-domain">{application.domain}</small>
                </div>
              </div>
              <div className="consent-connection-arrow" aria-hidden="true">
                <span>连接到</span>
                <ChevronRight size={17} />
              </div>
            </div>
            <section className="consent-account-inline" aria-label="当前账号">
              <img className="consent-account-mark" src="/favicon.svg" alt="Hearth 账号标志" />
              <div className="consent-account-copy">
                <span>账号：{account.username}</span>
                <span>名称：{account.displayName}</span>
              </div>
            </section>
          </div>
        </section>

        <form ref={formRef} className="consent-form" method="post" action="/oauth2/authorize" onSubmit={preview ? undefined : handleSubmit}>
          {!preview && <>
            <input type="hidden" name="client_id" value={clientId} readOnly />
            <input type="hidden" name="state" value={query.get('state') || ''} readOnly />
            <input type="hidden" name="_csrf" value={csrfToken} readOnly />
            {query.get('user_code') && <input type="hidden" name="user_code" value={query.get('user_code')} readOnly />}
          </>}
          <section className="consent-permissions" aria-labelledby="permissions-title">
            <div className="consent-section-heading">
              <div><span className="section-kicker">权限范围</span><h2 className="consent-title-type" id="permissions-title">{application.name} 可访问</h2></div>
            </div>
            <div className="consent-permission-helper"><LockKeyhole size={13} /><span>{application.name} 只能访问你选择的信息，登录凭据不会共享；授权后可随时在 Hearth 中撤销。</span></div>
            <div className="permission-list">
              {displayedPermissions.map(({ key, icon: Icon, title, description }) => (
                <label className={`permission-row${selected[key] ? ' is-selected' : ''}`} key={key} htmlFor={`permission-${key}`}>
                  <input id={`permission-${key}`} name={preview ? undefined : 'scope'} data-scope={key} value={key} type="checkbox" checked={selected[key]} onChange={() => togglePermission(key)} />
                  <span className="permission-icon"><Icon size={18} /></span>
                  <span className="permission-copy"><strong>{title}</strong><small>{description}</small></span>
                </label>
              ))}
            </div>
          </section>

          <div className="consent-actions">
            <button className="consent-cancel" type={preview ? 'button' : 'submit'} disabled={!preview && !csrfToken} onClick={cancelConsent}>取消</button>
            <button className="consent-submit" type={preview ? 'button' : 'submit'} disabled={selectedCount === 0 || (!preview && !csrfToken)}>同意并继续 <ChevronRight size={17} /></button>
          </div>
        </form>

        <p className="consent-footnote">只会分享你勾选的信息</p>
      </section>
    </main>
  );
}
