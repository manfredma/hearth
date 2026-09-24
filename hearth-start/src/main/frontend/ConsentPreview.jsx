import React, { useState } from 'react';
import { Check, ChevronRight, Globe2, Mail, ShieldCheck, UserRound } from 'lucide-react';

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
        <header className="consent-brand-row">
          <div className="consent-brand">
            <img className="brand-mark" src="/favicon.svg" alt="Hearth 标志" />
            <div><strong>hearth</strong><small>统一身份中心</small></div>
          </div>
          <span className="consent-label"><ShieldCheck size={14} />授权确认</span>
        </header>

        <section className="consent-app" aria-label="来源应用">
          <div className="consent-app-icon sage">c</div>
          <div className="consent-app-copy">
            <strong>Career</strong>
            <span>职业成长与工作台</span>
            <small><Globe2 size={13} /> staging-career.bytedepth.cn</small>
          </div>
          <ChevronRight className="consent-app-arrow" size={20} />
        </section>

        <div className="consent-heading">
          <span className="eyebrow"><span className="eyebrow-dot" />安全授权</span>
          <h1 id="consent-title">Career 想连接你的 Hearth 账号</h1>
          <p>你可以选择允许 Career 访问哪些信息。Hearth 不会分享你的密码。</p>
        </div>

        <section className="consent-account" aria-label="当前账号">
          <div className="avatar">冯</div>
          <div><span>当前账号</span><strong>冯华杰 <small>admin</small></strong></div>
          <Check size={18} />
        </section>

        <section className="consent-permissions" aria-labelledby="permissions-title">
          <div className="consent-section-heading">
            <div><span className="section-kicker">REQUESTED ACCESS</span><h2 id="permissions-title">Career 将获得</h2></div>
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

        <div className="consent-actions">
          <button className="consent-cancel" type="button">暂不授权</button>
          <button className="consent-submit" type="button" disabled={selectedCount === 0}>同意并继续 <ChevronRight size={17} /></button>
        </div>

        <p className="consent-footnote">授权后，你可以随时在 Hearth 的应用接入设置中撤销访问。</p>
      </section>
    </main>
  );
}
