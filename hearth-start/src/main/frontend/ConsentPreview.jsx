import React, { useState } from 'react';
import { Check, ChevronRight, LockKeyhole, Mail, ShieldCheck, UserRound } from 'lucide-react';

const permissions = [
  { key: 'profile', icon: UserRound, title: '基本资料', description: '查看你的显示名称和头像' },
  { key: 'email', icon: Mail, title: '邮箱地址', description: '查看与你的 Hearth 账号关联的邮箱' },
];

export default function ConsentPreview() {
  const [selected, setSelected] = useState({ profile: true, email: true });

  function togglePermission(key) {
    setSelected((current) => ({ ...current, [key]: !current[key] }));
  }

  const selectedCount = Object.values(selected).filter(Boolean).length;

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
          <h1 className="consent-title-type" id="consent-title">允许 Career 使用你的 Hearth 账号？</h1>
        </div>

        <section className="consent-connection consent-flat-surface" aria-label="授权来源">
          <div className="consent-connection-top">
            <span>来自 Career</span>
            <span className="consent-verified"><Check size={13} />已验证来源</span>
          </div>
          <div className="consent-context-body">
            <div className="consent-connection-main">
              <div className="consent-source">
                <div className="consent-app-icon sage">c</div>
                <div className="consent-app-copy">
                  <strong>Career</strong>
                  <span>职业成长与工作台</span>
                  <small className="consent-domain">staging-career.bytedepth.cn</small>
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
                <span>账号：admin</span>
                <span>名称：冯华杰</span>
              </div>
            </section>
          </div>
        </section>

        <section className="consent-permissions" aria-labelledby="permissions-title">
          <div className="consent-section-heading">
            <div><span className="section-kicker">权限范围</span><h2 className="consent-title-type" id="permissions-title">Career 可访问</h2></div>
          </div>
          <div className="consent-permission-helper"><LockKeyhole size={13} /><span>Career 只能访问你选择的信息，登录凭据不会共享；授权后可随时在 Hearth 中撤销。</span></div>
          <div className="permission-list">
            {permissions.map(({ key, icon: Icon, title, description }) => (
              <label className={`permission-row${selected[key] ? ' is-selected' : ''}`} key={key} htmlFor={`permission-${key}`}>
                <input id={`permission-${key}`} type="checkbox" checked={selected[key]} onChange={() => togglePermission(key)} />
                <span className="permission-icon"><Icon size={18} /></span>
                <span className="permission-copy"><strong>{title}</strong><small>{description}</small></span>
              </label>
            ))}
          </div>
        </section>

        <div className="consent-actions">
          <button className="consent-cancel" type="button">取消</button>
          <button className="consent-submit" type="button" disabled={selectedCount === 0}>同意并继续 <ChevronRight size={17} /></button>
        </div>

        <p className="consent-footnote">只会分享你勾选的信息</p>
      </section>
    </main>
  );
}
