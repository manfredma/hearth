import React, { useState } from 'react';
import { Check, ChevronRight, Globe2, LockKeyhole, Mail, ShieldCheck, UserRound } from 'lucide-react';

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
    <main className="consent-shell">
      <section className="consent-card" aria-labelledby="consent-title">
        <header className="consent-header">
          <div className="consent-brand">
            <img className="brand-mark" src="/favicon.svg" alt="Hearth 标志" />
            <div><strong>hearth</strong><small>统一身份中心</small></div>
          </div>
          <span className="consent-label"><ShieldCheck size={14} />Hearth 安全授权</span>
        </header>

        <section className="consent-connection" aria-label="授权来源">
          <div className="consent-connection-top">
            <span>来自 Career</span>
            <span className="consent-verified"><Check size={13} />已验证来源</span>
          </div>
          <div className="consent-connection-main">
            <div className="consent-source">
              <div className="consent-app-icon sage">c</div>
              <div className="consent-app-copy">
                <strong>Career</strong>
                <span>职业成长与工作台</span>
              </div>
            </div>
            <div className="consent-connection-arrow" aria-hidden="true">
              <span>连接到</span>
              <ChevronRight size={18} />
            </div>
            <div className="consent-destination">
              <img className="consent-mini-mark" src="/favicon.svg" alt="" />
              <div><strong>Hearth</strong><span>你的身份中心</span></div>
            </div>
          </div>
          <div className="consent-domain"><Globe2 size={13} />staging-career.bytedepth.cn</div>
        </section>

        <div className="consent-heading">
          <span className="eyebrow"><span className="eyebrow-dot" />确认授权</span>
          <h1 id="consent-title">允许 Career 使用你的 Hearth 账号？</h1>
          <p>Career 只能访问你在下面选择的信息，密码和 Hearth 登录凭据不会共享。</p>
        </div>

        <section className="consent-account" aria-label="当前账号">
          <div className="avatar">冯</div>
          <div><span>使用账号</span><strong>冯华杰 <small>admin</small></strong></div>
          <Check size={18} />
        </section>

        <section className="consent-permissions" aria-labelledby="permissions-title">
          <div className="consent-section-heading">
            <div><span className="section-kicker">PERMISSIONS</span><h2 id="permissions-title">权限范围</h2></div>
            <span className="permission-count">{selectedCount}/2 项</span>
          </div>
          <div className="permission-list">
            {permissions.map(({ key, icon: Icon, title, description }) => (
              <label className={`permission-row${selected[key] ? ' is-selected' : ''}`} key={key} htmlFor={`permission-${key}`}>
                <span className="permission-icon"><Icon size={18} /></span>
                <span className="permission-copy"><strong>{title}</strong><small>{description}</small></span>
                <input id={`permission-${key}`} type="checkbox" checked={selected[key]} onChange={() => togglePermission(key)} />
              </label>
            ))}
          </div>
        </section>

        <div className="consent-action-note"><LockKeyhole size={14} /><span>你可以随时在 Hearth 中撤销授权。</span></div>
        <div className="consent-actions">
          <button className="consent-cancel" type="button">取消</button>
          <button className="consent-submit" type="button" disabled={selectedCount === 0}>同意并继续 <ChevronRight size={17} /></button>
        </div>

        <p className="consent-footnote">只会分享你勾选的信息</p>
      </section>
    </main>
  );
}
