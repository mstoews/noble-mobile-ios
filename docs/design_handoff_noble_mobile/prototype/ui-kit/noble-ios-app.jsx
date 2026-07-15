// NobleLedger iOS — supplemental companion app.
// Native-iOS feel (SF Pro, grouped lists, liquid-glass tab bar) with NobleLedger
// emerald branding. Pulls device chrome from ios-frame.jsx (window globals).

const { IOSDevice, IOSGlassPill } = window;

/* ---------- design tokens (iOS-flavoured + NobleLedger brand) ---------- */
const SF = '-apple-system, "SF Pro Text", system-ui, sans-serif';
const EMERALD = '#047857';      // --nbl-emerald-700
const EMERALD_SOFT = '#ecfdf5';
const INK = '#1c1c1e';
const SEC = 'rgba(60,60,67,0.6)';
const TER = 'rgba(60,60,67,0.3)';
const SEP = 'rgba(60,60,67,0.12)';
const IOSBG = '#F2F2F7';
const RED = '#e0383b';
const BLUE = '#2563eb';

// dark
const D_BG = '#000';
const D_CARD = '#1C1C1E';
const D_INK = '#fff';
const D_SEC = 'rgba(235,235,245,0.6)';
const D_SEP = 'rgba(84,84,88,0.55)';

const FUND_COLORS = { Operating: EMERALD, Reserve: BLUE, 'Special Assessment': '#9333ea' };

const fmt = (n, dec = 2) => n.toLocaleString('en-US', { minimumFractionDigits: dec, maximumFractionDigits: dec });
const money = (n) => `$${fmt(Math.abs(n))}`;
const moneyK = (n) => n >= 1000 ? `$${(n/1000).toFixed(n >= 100000 ? 0 : 1)}K` : `$${fmt(n,0)}`;

/* ---------- shared data (Brookline Grove Condominium Corp.) ---------- */
const FUNDS = [
  { name: 'Operating',          balance: 184920.00, note: 'RBC Operating · chequing' },
  { name: 'Reserve',            balance: 281440.00, note: 'TD Reserve · GIC ladder' },
  { name: 'Special Assessment', balance: 15950.00,  note: 'BMO · elevator project' },
];
const TOTAL_CASH = FUNDS.reduce((a, f) => a + f.balance, 0); // 482,310
const OPEN_PAYMENTS = 28420.00;
const OPEN_RECEIPTS = 14200.00;

const TXNS = [
  { id: 't1', payee: 'Brookline Prop Mgmt',  memo: 'March retainer',        amount: -6400.00,  kind: 'Payment', fund: 'Operating', acct: '5210', ref: 'AP-1918', when: 'Today · 2:14 PM',  by: 'jmalik', signoff: true },
  { id: 't2', payee: 'Hydro One',            memo: 'Common area · Feb',     amount: -4105.22,  kind: 'Payment', fund: 'Operating', acct: '5310', ref: 'AP-1914', when: 'Today · 11:03 AM', by: 'jmalik', signoff: true },
  { id: 't3', payee: 'Unit 1204 — Williams', memo: 'Condo fee · March',     amount:  685.00,   kind: 'Receipt', fund: 'Operating', acct: '4110', ref: 'AR-2842', when: 'Today · 9:48 AM',  by: 'kpatel', signoff: false },
  { id: 't4', payee: 'Toronto Water',        memo: 'Q1 reconciliation',     amount: -9361.10,  kind: 'Payment', fund: 'Operating', acct: '5110', ref: 'AP-1925', when: 'Yesterday',        by: 'jmalik', signoff: false },
  { id: 't5', payee: 'GroveCare Landscaping',memo: 'March contract',        amount: -5578.33,  kind: 'Payment', fund: 'Operating', acct: '5420', ref: 'AP-1922', when: 'Yesterday',        by: 'jmalik', signoff: false },
  { id: 't6', payee: 'Reserve transfer',     memo: 'Monthly contribution',  amount:  12500.00, kind: 'Transfer',fund: 'Reserve',   acct: '1020', ref: 'TR-0312', when: 'Yesterday',        by: 'treasurer', signoff: false },
];
const SIGNOFF_COUNT = TXNS.filter(t => t.signoff).length;

/* ============================================================
   Screen scaffold: padded content + liquid-glass tab bar w/ FAB
   ============================================================ */
function Screen({ children, tab = 'dashboard', dark = false, onCapture, onNav, noChrome = false, scrollPad = 110 }) {
  return (
    <div style={{ height: '100%', display: 'flex', flexDirection: 'column', background: dark ? D_BG : IOSBG, position: 'relative' }}>
      <div style={{ flex: 1, overflow: 'auto', paddingBottom: scrollPad }}>{children}</div>
      {!noChrome && <TabBar active={tab} dark={dark} onCapture={onCapture} onNav={onNav} />}
    </div>
  );
}

function TabIcon({ name, active, dark }) {
  const on = active ? EMERALD : (dark ? 'rgba(235,235,245,0.5)' : 'rgba(60,60,67,0.5)');
  if (name === 'dashboard') return (
    <svg width="26" height="26" viewBox="0 0 26 26" fill="none"><rect x="3" y="3" width="8.5" height="8.5" rx="2.4" fill={on}/><rect x="14.5" y="3" width="8.5" height="8.5" rx="2.4" fill={on} opacity="0.55"/><rect x="3" y="14.5" width="8.5" height="8.5" rx="2.4" fill={on} opacity="0.55"/><rect x="14.5" y="14.5" width="8.5" height="8.5" rx="2.4" fill={on}/></svg>
  );
  if (name === 'more') return (
    <svg width="26" height="26" viewBox="0 0 26 26" fill="none"><circle cx="6" cy="13" r="1.9" fill={on}/><circle cx="13" cy="13" r="1.9" fill={on}/><circle cx="20" cy="13" r="1.9" fill={on}/></svg>
  );
  return ( // activity
    <svg width="26" height="26" viewBox="0 0 26 26" fill="none"><path d="M3 16l4.5-5 3.5 3.2L17 7l3 3.4" stroke={on} strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"/><path d="M3 21h20" stroke={on} strokeWidth="2.4" strokeLinecap="round" opacity="0.4"/></svg>
  );
}

function TabBar({ active, dark, onCapture, onNav }) {
  const label = (t, name) => (
    <div onClick={() => onNav && onNav(name)} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3, cursor: 'pointer' }}>
      <TabIcon name={name} active={active === name} dark={dark} />
      <span style={{ fontFamily: SF, fontSize: 10.5, fontWeight: active === name ? 600 : 500, color: active === name ? EMERALD : (dark ? 'rgba(235,235,245,0.5)' : 'rgba(60,60,67,0.5)') }}>{t}</span>
    </div>
  );
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, zIndex: 40, paddingBottom: 22 }}>
      {/* glass bar */}
      <div style={{ position: 'relative', height: 64, margin: '0 0', display: 'flex', alignItems: 'center', padding: '0 18px' }}>
        <div style={{ position: 'absolute', inset: 0,
          backdropFilter: 'blur(20px) saturate(180%)', WebkitBackdropFilter: 'blur(20px) saturate(180%)',
          background: dark ? 'rgba(20,20,22,0.72)' : 'rgba(255,255,255,0.72)',
          borderTop: `0.5px solid ${dark ? 'rgba(255,255,255,0.12)' : 'rgba(0,0,0,0.07)'}` }} />
        <div style={{ position: 'relative', display: 'flex', width: '100%', alignItems: 'center' }}>
          <div style={{ flex: 1, display: 'flex' }}>
            {label('Home', 'dashboard')}
            {label('Activity', 'activity')}
          </div>
          <div style={{ width: 76 }} />
          <div style={{ flex: 1, display: 'flex' }}>
            {label('More', 'more')}
          </div>
        </div>
      </div>
      {/* center FAB — Capture (the hero) */}
      <div onClick={onCapture} style={{ position: 'absolute', left: '50%', top: -8, transform: 'translateX(-50%)', zIndex: 2 }}>
        <div style={{ width: 64, height: 64, borderRadius: 22, background: `linear-gradient(160deg, #06a06a, ${EMERALD})`,
          boxShadow: `0 8px 20px rgba(4,120,87,0.4), 0 2px 4px rgba(0,0,0,0.2)`,
          display: 'flex', alignItems: 'center', justifyContent: 'center', border: `3px solid ${dark ? D_BG : IOSBG}` }}>
          <svg width="30" height="30" viewBox="0 0 30 30" fill="none">
            <path d="M9 8.5l1.6-2.4a1.5 1.5 0 011.25-.66h4.3a1.5 1.5 0 011.25.66L19 8.5h3.2a2.3 2.3 0 012.3 2.3v9.6a2.3 2.3 0 01-2.3 2.3H7.8a2.3 2.3 0 01-2.3-2.3v-9.6a2.3 2.3 0 012.3-2.3H9z" stroke="#fff" strokeWidth="2" strokeLinejoin="round"/>
            <circle cx="15" cy="15.2" r="3.7" stroke="#fff" strokeWidth="2"/>
          </svg>
        </div>
        <div style={{ textAlign: 'center', marginTop: 2, fontFamily: SF, fontSize: 10.5, fontWeight: 600, color: EMERALD }}>Capture</div>
      </div>
    </div>
  );
}

/* ---------- small shared bits ---------- */
function StatusChip({ children, color, bg }) {
  return <span style={{ fontFamily: SF, fontSize: 11, fontWeight: 600, color, background: bg, padding: '2px 8px', borderRadius: 999, letterSpacing: 0.2 }}>{children}</span>;
}

function TxnAvatar({ t, dark }) {
  const isIn = t.amount > 0;
  const c = t.kind === 'Transfer' ? '#9333ea' : (isIn ? EMERALD : RED);
  const glyph = t.kind === 'Transfer'
    ? <path d="M7 9h9l-2.5-2.5M16 14H7l2.5 2.5" stroke="#fff" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
    : isIn
      ? <path d="M11.5 6v11M7 12.5l4.5 4.5 4.5-4.5" stroke="#fff" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      : <path d="M11.5 17V6M7 10.5l4.5-4.5 4.5 4.5" stroke="#fff" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/>;
  return (
    <div style={{ width: 38, height: 38, borderRadius: 11, background: c, flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <svg width="23" height="23" viewBox="0 0 23 23">{glyph}</svg>
    </div>
  );
}

function TxnRow({ t, dark, onTap, last }) {
  return (
    <div onClick={onTap} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 16px', position: 'relative', cursor: 'pointer' }}>
      <TxnAvatar t={t} dark={dark} />
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ fontFamily: SF, fontSize: 16, fontWeight: 600, color: dark ? D_INK : INK, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{t.payee}</span>
          {t.signoff && <span style={{ width: 7, height: 7, borderRadius: 99, background: '#f59e0b', flexShrink: 0 }} />}
        </div>
        <div style={{ fontFamily: SF, fontSize: 13, color: dark ? D_SEC : SEC, marginTop: 1, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{t.memo} · {t.when}</div>
      </div>
      <div style={{ fontFamily: SF, fontSize: 16, fontWeight: 600, color: t.amount > 0 ? EMERALD : (dark ? D_INK : INK), fontVariantNumeric: 'tabular-nums', flexShrink: 0 }}>
        {t.amount > 0 ? '+' : '–'}{money(t.amount)}
      </div>
      {!last && <div style={{ position: 'absolute', bottom: 0, left: 66, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
    </div>
  );
}

function DashHeader({ dark, title = 'Dashboard' }) {
  return (
    <div style={{ padding: '58px 20px 6px', display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
      <div>
        <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: EMERALD, letterSpacing: 0.3 }}>BROOKLINE GROVE</div>
        <div style={{ fontFamily: SF, fontSize: 30, fontWeight: 700, color: dark ? D_INK : INK, letterSpacing: 0.3, marginTop: 1 }}>{title}</div>
      </div>
      <div style={{ width: 36, height: 36, borderRadius: 99, background: EMERALD, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: SF, fontSize: 14, fontWeight: 700 }}>MT</div>
    </div>
  );
}

/* ============================================================
   DASHBOARD — Variant A · Stacked cards
   ============================================================ */
function DashboardA({ dark, onCapture, onTxn, onNav }) {
  const card = { background: dark ? D_CARD : '#fff', borderRadius: 18, boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' };
  return (
    <Screen tab="dashboard" dark={dark} onCapture={onCapture} onNav={onNav}>
      <DashHeader dark={dark} />
      <div style={{ padding: '10px 16px 0', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {/* Cash hero */}
        <div style={{ ...card, padding: 20, background: dark ? D_CARD : `linear-gradient(155deg, #064e3b, ${EMERALD})`, boxShadow: '0 8px 22px rgba(4,120,87,0.28)' }}>
          <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: 'rgba(255,255,255,0.8)', letterSpacing: 0.3 }}>TOTAL CASH ON HAND</div>
          <div style={{ fontFamily: SF, fontSize: 40, fontWeight: 700, color: '#fff', fontVariantNumeric: 'tabular-nums', marginTop: 4, letterSpacing: 0.5 }}>{money(TOTAL_CASH)}</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6 }}>
            <span style={{ fontFamily: SF, fontSize: 13, color: 'rgba(255,255,255,0.85)' }}>Across {FUNDS.length} fund accounts</span>
            <span style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: '#6ee7b7' }}>▲ 2.1%</span>
          </div>
        </div>
        {/* Open items */}
        <div style={{ display: 'flex', gap: 12 }}>
          <OpenTile dark={dark} label="Open Payments" value={OPEN_PAYMENTS} sub="9 bills" tone={RED} />
          <OpenTile dark={dark} label="Open Receipts" value={OPEN_RECEIPTS} sub="6 invoices" tone={BLUE} />
        </div>
        {/* Funds */}
        <div>
          <SectionLabel dark={dark}>FUND BALANCES</SectionLabel>
          <div style={{ ...card, overflow: 'hidden' }}>
            {FUNDS.map((f, i) => (
              <div key={f.name} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 16px', position: 'relative' }}>
                <div style={{ width: 10, height: 10, borderRadius: 3, background: FUND_COLORS[f.name], flexShrink: 0 }} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontFamily: SF, fontSize: 16, fontWeight: 600, color: dark ? D_INK : INK }}>{f.name}</div>
                  <div style={{ fontFamily: SF, fontSize: 12.5, color: dark ? D_SEC : SEC }}>{f.note}</div>
                </div>
                <div style={{ fontFamily: SF, fontSize: 16, fontWeight: 600, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums' }}>{money(f.balance)}</div>
                {i < FUNDS.length - 1 && <div style={{ position: 'absolute', bottom: 0, left: 38, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
              </div>
            ))}
          </div>
        </div>
        {/* Recent + sign-off */}
        <div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <SectionLabel dark={dark}>NEEDS SIGN-OFF</SectionLabel>
            <span style={{ fontFamily: SF, fontSize: 13, color: EMERALD, fontWeight: 600, paddingRight: 4 }}>{SIGNOFF_COUNT} pending</span>
          </div>
          <div style={{ ...card, overflow: 'hidden' }}>
            {TXNS.filter(t => t.signoff).map((t, i, arr) => (
              <TxnRow key={t.id} t={t} dark={dark} onTap={() => onTxn(t)} last={i === arr.length - 1} />
            ))}
          </div>
        </div>
      </div>
    </Screen>
  );
}

function OpenTile({ dark, label, value, sub, tone }) {
  return (
    <div style={{ flex: 1, background: dark ? D_CARD : '#fff', borderRadius: 18, padding: 15, boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ width: 8, height: 8, borderRadius: 99, background: tone }} />
        <span style={{ fontFamily: SF, fontSize: 12.5, fontWeight: 600, color: dark ? D_SEC : SEC }}>{label}</span>
      </div>
      <div style={{ fontFamily: SF, fontSize: 24, fontWeight: 700, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums', marginTop: 8 }}>{money(value)}</div>
      <div style={{ fontFamily: SF, fontSize: 12, color: dark ? D_SEC : SEC, marginTop: 2 }}>{sub}</div>
    </div>
  );
}

function SectionLabel({ children, dark }) {
  return <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: dark ? D_SEC : SEC, letterSpacing: 0.3, padding: '0 4px 7px' }}>{children}</div>;
}

/* ============================================================
   DASHBOARD — Variant B · Native grouped list
   ============================================================ */
function DashboardB({ dark, onCapture, onTxn }) {
  const group = { background: dark ? D_CARD : '#fff', borderRadius: 16, margin: '0 16px', overflow: 'hidden' };
  const groupLabel = (t) => <div style={{ fontFamily: SF, fontSize: 13, color: dark ? D_SEC : SEC, padding: '18px 20px 7px', letterSpacing: 0.2 }}>{t}</div>;
  const row = (left, right, sub, i, n, accent) => (
    <div style={{ display: 'flex', alignItems: 'center', minHeight: 50, padding: '0 16px', position: 'relative' }}>
      {accent && <div style={{ width: 9, height: 9, borderRadius: 3, background: accent, marginRight: 11 }} />}
      <div style={{ flex: 1 }}>
        <div style={{ fontFamily: SF, fontSize: 16, color: dark ? D_INK : INK }}>{left}</div>
        {sub && <div style={{ fontFamily: SF, fontSize: 12.5, color: dark ? D_SEC : SEC }}>{sub}</div>}
      </div>
      <div style={{ fontFamily: SF, fontSize: 16, fontWeight: 600, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums', marginRight: 6 }}>{right}</div>
      <svg width="8" height="13" viewBox="0 0 8 13"><path d="M1 1l6 6-6 6" stroke={TER} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
      {i < n - 1 && <div style={{ position: 'absolute', bottom: 0, left: accent ? 36 : 16, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
    </div>
  );
  return (
    <Screen tab="dashboard" dark={dark} onCapture={onCapture}>
      <DashHeader dark={dark} />
      {/* cash hero — minimal */}
      <div style={{ textAlign: 'center', padding: '14px 20px 6px' }}>
        <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: dark ? D_SEC : SEC, letterSpacing: 0.3 }}>TOTAL CASH ON HAND</div>
        <div style={{ fontFamily: SF, fontSize: 44, fontWeight: 700, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums', letterSpacing: 0.5, marginTop: 2 }}>{money(TOTAL_CASH)}</div>
        <div style={{ fontFamily: SF, fontSize: 13, color: EMERALD, fontWeight: 600 }}>▲ 2.1% this month</div>
      </div>
      {groupLabel('FUND BALANCES')}
      <div style={group}>
        {FUNDS.map((f, i) => <React.Fragment key={f.name}>{row(f.name, money(f.balance), f.note, i, FUNDS.length, FUND_COLORS[f.name])}</React.Fragment>)}
      </div>
      {groupLabel('OPEN ITEMS')}
      <div style={group}>
        {row('Open Payments', money(OPEN_PAYMENTS), '9 bills awaiting payment', 0, 2)}
        {row('Open Receipts', money(OPEN_RECEIPTS), '6 invoices outstanding', 1, 2)}
      </div>
      {groupLabel(`NEEDS SIGN-OFF · ${SIGNOFF_COUNT}`)}
      <div style={group}>
        {TXNS.filter(t => t.signoff).map((t, i, arr) => (
          <div key={t.id} onClick={() => onTxn(t)}><TxnRow t={t} dark={dark} last={i === arr.length - 1} /></div>
        ))}
      </div>
    </Screen>
  );
}

/* ============================================================
   DASHBOARD — Variant C · Visual / allocation
   ============================================================ */
function Donut({ data, size = 150, dark }) {
  const total = data.reduce((a, d) => a + d.v, 0);
  let acc = 0;
  const r = size / 2, cx = r, cy = r, ir = r * 0.64;
  return (
    <svg width={size} height={size} viewBox={`0 0 ${size} ${size}`}>
      {data.map((d, i) => {
        const a0 = (acc / total) * Math.PI * 2 - Math.PI / 2; acc += d.v;
        const a1 = (acc / total) * Math.PI * 2 - Math.PI / 2;
        const large = (a1 - a0) > Math.PI ? 1 : 0;
        const x0 = cx + r * Math.cos(a0), y0 = cy + r * Math.sin(a0);
        const x1 = cx + r * Math.cos(a1), y1 = cy + r * Math.sin(a1);
        const xi0 = cx + ir * Math.cos(a1), yi0 = cy + ir * Math.sin(a1);
        const xi1 = cx + ir * Math.cos(a0), yi1 = cy + ir * Math.sin(a0);
        return <path key={i} d={`M ${x0} ${y0} A ${r} ${r} 0 ${large} 1 ${x1} ${y1} L ${xi0} ${yi0} A ${ir} ${ir} 0 ${large} 0 ${xi1} ${yi1} Z`} fill={d.c} stroke={dark ? D_CARD : '#fff'} strokeWidth="2.5" />;
      })}
    </svg>
  );
}

function DashboardC({ dark, onCapture, onTxn }) {
  const card = { background: dark ? D_CARD : '#fff', borderRadius: 18, boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' };
  const donutData = FUNDS.map(f => ({ v: f.balance, c: FUND_COLORS[f.name], name: f.name }));
  return (
    <Screen tab="dashboard" dark={dark} onCapture={onCapture}>
      <DashHeader dark={dark} />
      <div style={{ padding: '10px 16px 0', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {/* Allocation card */}
        <div style={{ ...card, padding: 18 }}>
          <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: dark ? D_SEC : SEC, letterSpacing: 0.3 }}>FUND ALLOCATION</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginTop: 10 }}>
            <div style={{ position: 'relative', width: 150, height: 150, flexShrink: 0 }}>
              <Donut data={donutData} dark={dark} />
              <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
                <span style={{ fontFamily: SF, fontSize: 11, color: dark ? D_SEC : SEC }}>Total</span>
                <span style={{ fontFamily: SF, fontSize: 19, fontWeight: 700, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums' }}>{moneyK(TOTAL_CASH)}</span>
              </div>
            </div>
            <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 11 }}>
              {donutData.map(d => (
                <div key={d.name} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span style={{ width: 9, height: 9, borderRadius: 3, background: d.c }} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <div style={{ fontFamily: SF, fontSize: 13.5, fontWeight: 600, color: dark ? D_INK : INK }}>{d.name}</div>
                    <div style={{ fontFamily: SF, fontSize: 11.5, color: dark ? D_SEC : SEC }}>{Math.round(d.v / TOTAL_CASH * 100)}% · {moneyK(d.v)}</div>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
        {/* KPI row */}
        <div style={{ display: 'flex', gap: 10 }}>
          <KpiMini dark={dark} label="Cash" value={moneyK(TOTAL_CASH)} tone={EMERALD} />
          <KpiMini dark={dark} label="Open Pay" value={moneyK(OPEN_PAYMENTS)} tone={RED} />
          <KpiMini dark={dark} label="Open Rec" value={moneyK(OPEN_RECEIPTS)} tone={BLUE} />
        </div>
        {/* Recent activity */}
        <div>
          <SectionLabel dark={dark}>LATEST TRANSACTIONS</SectionLabel>
          <div style={{ ...card, overflow: 'hidden' }}>
            {TXNS.slice(0, 4).map((t, i, arr) => (
              <TxnRow key={t.id} t={t} dark={dark} onTap={() => onTxn(t)} last={i === arr.length - 1} />
            ))}
          </div>
        </div>
      </div>
    </Screen>
  );
}

function KpiMini({ dark, label, value, tone }) {
  return (
    <div style={{ flex: 1, background: dark ? D_CARD : '#fff', borderRadius: 16, padding: '13px 12px', boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' }}>
      <div style={{ width: 22, height: 3, borderRadius: 9, background: tone, marginBottom: 9 }} />
      <div style={{ fontFamily: SF, fontSize: 19, fontWeight: 700, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums' }}>{value}</div>
      <div style={{ fontFamily: SF, fontSize: 12, color: dark ? D_SEC : SEC, marginTop: 1 }}>{label}</div>
    </div>
  );
}

/* ============================================================
   ACTIVITY — transactions list + segmented filter
   ============================================================ */
function ActivityScreen({ dark, onCapture, onTxn, onNav }) {
  const [seg, setSeg] = React.useState('all');
  const list = seg === 'signoff' ? TXNS.filter(t => t.signoff) : TXNS;
  const card = { background: dark ? D_CARD : '#fff', borderRadius: 18, margin: '0 16px', overflow: 'hidden', boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' };
  return (
    <Screen tab="activity" dark={dark} onCapture={onCapture} onNav={onNav}>
      <div style={{ padding: '58px 20px 4px' }}>
        <div style={{ fontFamily: SF, fontSize: 30, fontWeight: 700, color: dark ? D_INK : INK, letterSpacing: 0.3 }}>Activity</div>
      </div>
      {/* segmented control */}
      <div style={{ margin: '8px 16px 14px', background: dark ? 'rgba(118,118,128,0.24)' : 'rgba(118,118,128,0.12)', borderRadius: 9, padding: 2, display: 'flex' }}>
        {[['all', 'All'], ['signoff', `Needs sign-off · ${SIGNOFF_COUNT}`]].map(([id, lbl]) => (
          <div key={id} onClick={() => setSeg(id)} style={{ flex: 1, textAlign: 'center', padding: '7px 0', borderRadius: 7,
            fontFamily: SF, fontSize: 13.5, fontWeight: 600,
            background: seg === id ? (dark ? '#636366' : '#fff') : 'transparent',
            color: seg === id ? (dark ? '#fff' : INK) : (dark ? D_SEC : SEC),
            boxShadow: seg === id ? '0 1px 3px rgba(0,0,0,0.12)' : 'none' }}>{lbl}</div>
        ))}
      </div>
      <div style={card}>
        {list.map((t, i) => <TxnRow key={t.id} t={t} dark={dark} onTap={() => onTxn(t)} last={i === list.length - 1} />)}
      </div>
      <div style={{ fontFamily: SF, fontSize: 12.5, color: dark ? D_SEC : SEC, textAlign: 'center', padding: 16 }}>
        Showing {list.length} of {TXNS.length} · synced 2 min ago
      </div>
    </Screen>
  );
}

/* ============================================================
   TRANSACTION DETAIL — single approve (sign off & book)
   ============================================================ */
function TxnDetail({ t, dark, onBack }) {
  const impacts = t.amount < 0
    ? [{ a: `${t.acct}-001`, n: acctName(t.acct), d: Math.abs(t.amount) }, { a: '2010-001', n: 'Accounts Payable', d: -Math.abs(t.amount) }]
    : [{ a: '1010-001', n: 'RBC Operating', d: Math.abs(t.amount) }, { a: `${t.acct}-001`, n: acctName(t.acct), d: -Math.abs(t.amount) }];
  const card = { background: dark ? D_CARD : '#fff', borderRadius: 18, margin: '0 16px', overflow: 'hidden', boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' };
  return (
    <Screen dark={dark} noChrome scrollPad={120}>
      {/* nav */}
      <div style={{ padding: '54px 16px 6px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div onClick={onBack} style={{ display: 'flex', alignItems: 'center', gap: 3, cursor: 'pointer' }}>
          <svg width="11" height="18" viewBox="0 0 11 18"><path d="M9 1L2 9l7 8" stroke={EMERALD} strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ fontFamily: SF, fontSize: 17, color: EMERALD }}>Activity</span>
        </div>
        {t.signoff && <StatusChip color="#92400e" bg="#fef3c7">Awaiting sign-off</StatusChip>}
      </div>
      {/* amount hero */}
      <div style={{ textAlign: 'center', padding: '12px 20px 18px' }}>
        <TxnAvatar t={t} dark={dark} />
        <div style={{ fontFamily: SF, fontSize: 44, fontWeight: 700, color: t.amount > 0 ? EMERALD : (dark ? D_INK : INK), fontVariantNumeric: 'tabular-nums', marginTop: 10, letterSpacing: 0.5 }}>
          {t.amount > 0 ? '+' : '–'}{money(t.amount)}
        </div>
        <div style={{ fontFamily: SF, fontSize: 17, fontWeight: 600, color: dark ? D_INK : INK, marginTop: 2 }}>{t.payee}</div>
        <div style={{ fontFamily: SF, fontSize: 14, color: dark ? D_SEC : SEC }}>{t.memo}</div>
      </div>
      {/* meta */}
      <div style={{ ...card, marginBottom: 14 }}>
        {detailRow('Type', t.kind, dark)}
        {detailRow('Fund', t.fund, dark)}
        {detailRow('Account', `${t.acct} · ${acctName(t.acct)}`, dark)}
        {detailRow('Reference', t.ref, dark)}
        {detailRow('Date', t.when, dark)}
        {detailRow('Submitted by', `${t.by} · ACCT`, dark, true)}
      </div>
      {/* ledger impact */}
      <div style={{ fontFamily: SF, fontSize: 13, color: dark ? D_SEC : SEC, padding: '0 20px 7px', letterSpacing: 0.2 }}>LEDGER IMPACT</div>
      <div style={{ ...card }}>
        {impacts.map((imp, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', padding: '12px 16px', position: 'relative' }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: SF, fontSize: 15, color: dark ? D_INK : INK }}>{imp.n}</div>
              <div style={{ fontFamily: SF, fontSize: 12.5, color: dark ? D_SEC : SEC }}>{imp.a}</div>
            </div>
            <div style={{ fontFamily: SF, fontSize: 15, fontWeight: 600, color: imp.d < 0 ? RED : EMERALD, fontVariantNumeric: 'tabular-nums' }}>
              {imp.d < 0 ? 'Cr ' : 'Dr '}{money(imp.d)}
            </div>
            {i < impacts.length - 1 && <div style={{ position: 'absolute', bottom: 0, left: 16, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
          </div>
        ))}
      </div>
      {/* sticky action */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: '12px 16px 30px',
        backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
        background: dark ? 'rgba(20,20,22,0.8)' : 'rgba(242,242,247,0.8)', borderTop: `0.5px solid ${dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.06)'}` }}>
        {t.signoff ? (
          <>
            <button style={primaryBtn}>Sign off &amp; book</button>
            <div style={{ fontFamily: SF, fontSize: 12, color: dark ? D_SEC : SEC, textAlign: 'center', marginTop: 8 }}>You're acting as MT · Manager</div>
          </>
        ) : (
          <div style={{ textAlign: 'center', fontFamily: SF, fontSize: 14, color: dark ? D_SEC : SEC, padding: '8px 0' }}>
            ✓ Booked · no action required
          </div>
        )}
      </div>
    </Screen>
  );
}

function detailRow(k, v, dark, last) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', minHeight: 46, padding: '0 16px', position: 'relative' }}>
      <div style={{ flex: 1, fontFamily: SF, fontSize: 15, color: dark ? D_SEC : SEC }}>{k}</div>
      <div style={{ fontFamily: SF, fontSize: 15, fontWeight: 500, color: dark ? D_INK : INK }}>{v}</div>
      {!last && <div style={{ position: 'absolute', bottom: 0, left: 16, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
    </div>
  );
}

function acctName(code) {
  return ({ '5210': 'Professional Management', '5310': 'Utilities — Power', '5110': 'Utilities — Water', '5420': 'Landscaping & grounds', '4110': 'Condo Fees — Residential', '1020': 'TD Reserve — GIC' })[code] || 'Account';
}

const primaryBtn = { width: '100%', padding: '15px', background: EMERALD, color: '#fff', border: 'none', borderRadius: 14, fontFamily: SF, fontSize: 17, fontWeight: 600, cursor: 'pointer' };

/* ============================================================
   CAPTURE — camera viewfinder (the FAB hero)
   ============================================================ */
function CaptureCamera({ onCapture, onClose }) {
  return (
    <Screen dark noChrome scrollPad={0}>
      <div style={{ position: 'absolute', inset: 0, background: '#0a0a0a' }}>
        {/* faux viewfinder backdrop */}
        <div style={{ position: 'absolute', inset: 0, background: 'radial-gradient(120% 80% at 50% 35%, #2a2a2e 0%, #111 60%, #000 100%)' }} />
        {/* close */}
        <div onClick={onClose} style={{ position: 'absolute', top: 60, left: 20, width: 38, height: 38, borderRadius: 99, background: 'rgba(255,255,255,0.16)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 5 }}>
          <svg width="16" height="16" viewBox="0 0 16 16"><path d="M2 2l12 12M14 2L2 14" stroke="#fff" strokeWidth="2" strokeLinecap="round"/></svg>
        </div>
        <div style={{ position: 'absolute', top: 64, left: 0, right: 0, textAlign: 'center', fontFamily: SF, fontSize: 16, fontWeight: 600, color: '#fff', zIndex: 5 }}>Capture Invoice</div>
        {/* document guide frame */}
        <div style={{ position: 'absolute', top: 150, left: 36, right: 36, bottom: 230, borderRadius: 14 }}>
          {/* faux invoice doc */}
          <div style={{ position: 'absolute', inset: 0, background: '#fbfbf9', borderRadius: 8, transform: 'rotate(-1.4deg)', boxShadow: '0 20px 50px rgba(0,0,0,0.5)', padding: 22, overflow: 'hidden' }}>
            <div style={{ fontFamily: SF, fontSize: 15, fontWeight: 800, color: '#222' }}>HYDRO ONE</div>
            <div style={{ fontFamily: SF, fontSize: 9, color: '#888', marginTop: 2 }}>Invoice #88213 · Feb 28, 2026</div>
            <div style={{ height: 1, background: '#eee', margin: '12px 0' }} />
            {['Common area lighting', 'Demand charge', 'Delivery', 'Regulatory'].map((l, i) => (
              <div key={i} style={{ display: 'flex', justifyContent: 'space-between', margin: '7px 0' }}>
                <span style={{ fontFamily: SF, fontSize: 9.5, color: '#555' }}>{l}</span>
                <span style={{ fontFamily: SF, fontSize: 9.5, color: '#555' }}>$ —</span>
              </div>
            ))}
            <div style={{ height: 1, background: '#eee', margin: '12px 0' }} />
            <div style={{ display: 'flex', justifyContent: 'space-between' }}>
              <span style={{ fontFamily: SF, fontSize: 12, fontWeight: 700, color: '#222' }}>Total due</span>
              <span style={{ fontFamily: SF, fontSize: 12, fontWeight: 700, color: '#222' }}>$4,105.22</span>
            </div>
          </div>
          {/* corner guides */}
          {[[0,0,'tl'],[1,0,'tr'],[0,1,'bl'],[1,1,'br']].map(([x,y,k]) => (
            <div key={k} style={{ position: 'absolute', [y?'bottom':'top']: -3, [x?'right':'left']: -3, width: 30, height: 30,
              borderTop: y?0:`3px solid ${EMERALD}`, borderBottom: y?`3px solid ${EMERALD}`:0,
              borderLeft: x?0:`3px solid ${EMERALD}`, borderRight: x?`3px solid ${EMERALD}`:0,
              borderTopLeftRadius: (!x&&!y)?8:0, borderTopRightRadius:(x&&!y)?8:0, borderBottomLeftRadius:(!x&&y)?8:0, borderBottomRightRadius:(x&&y)?8:0 }} />
          ))}
        </div>
        {/* hint */}
        <div style={{ position: 'absolute', bottom: 170, left: 0, right: 0, textAlign: 'center', fontFamily: SF, fontSize: 14, color: 'rgba(255,255,255,0.8)' }}>
          Align the invoice within the frame
        </div>
        {/* shutter */}
        <div style={{ position: 'absolute', bottom: 54, left: 0, right: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 50 }}>
          <div style={{ width: 46, height: 46, borderRadius: 10, background: 'rgba(255,255,255,0.14)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg width="22" height="22" viewBox="0 0 22 22"><rect x="2" y="4" width="18" height="14" rx="2.5" stroke="#fff" strokeWidth="1.7" fill="none"/><circle cx="11" cy="11" r="3.6" stroke="#fff" strokeWidth="1.7" fill="none"/></svg>
          </div>
          <div onClick={onCapture} style={{ width: 76, height: 76, borderRadius: 99, border: '4px solid #fff', display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer' }}>
            <div style={{ width: 60, height: 60, borderRadius: 99, background: '#fff' }} />
          </div>
          <div style={{ width: 46, height: 46, borderRadius: 10, background: 'rgba(255,255,255,0.14)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg width="22" height="22" viewBox="0 0 22 22"><path d="M11 3v11M6 9l5 5 5-5M3 19h16" stroke="#fff" strokeWidth="1.7" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          </div>
        </div>
      </div>
    </Screen>
  );
}

/* ============================================================
   CAPTURE REVIEW — AI extraction → draft payable
   ============================================================ */
function CaptureReview({ dark, onBack, onDone }) {
  const card = { background: dark ? D_CARD : '#fff', borderRadius: 18, margin: '0 16px', overflow: 'hidden', boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' };
  const field = (label, value, conf, last) => (
    <div style={{ display: 'flex', alignItems: 'center', minHeight: 54, padding: '0 16px', position: 'relative' }}>
      <div style={{ flex: 1 }}>
        <div style={{ fontFamily: SF, fontSize: 12.5, color: dark ? D_SEC : SEC }}>{label}</div>
        <div style={{ fontFamily: SF, fontSize: 16, fontWeight: 600, color: dark ? D_INK : INK, marginTop: 1 }}>{value}</div>
      </div>
      {conf && <StatusChip color={EMERALD} bg={dark ? 'rgba(4,120,87,0.18)' : EMERALD_SOFT}>{conf}</StatusChip>}
      <svg width="8" height="13" viewBox="0 0 8 13" style={{ marginLeft: 10 }}><path d="M1 1l6 6-6 6" stroke={TER} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
      {!last && <div style={{ position: 'absolute', bottom: 0, left: 16, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
    </div>
  );
  return (
    <Screen dark={dark} noChrome scrollPad={130}>
      <div style={{ padding: '54px 16px 6px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div onClick={onBack} style={{ display: 'flex', alignItems: 'center', gap: 3, cursor: 'pointer' }}>
          <svg width="11" height="18" viewBox="0 0 11 18"><path d="M9 1L2 9l7 8" stroke={EMERALD} strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ fontFamily: SF, fontSize: 17, color: EMERALD }}>Retake</span>
        </div>
        <span style={{ fontFamily: SF, fontSize: 17, fontWeight: 600, color: dark ? D_INK : INK }}>Review</span>
        <span style={{ width: 60 }} />
      </div>
      {/* captured thumb + AI banner */}
      <div style={{ display: 'flex', gap: 14, alignItems: 'center', padding: '10px 20px 16px' }}>
        <div style={{ width: 72, height: 92, borderRadius: 10, background: '#fbfbf9', boxShadow: '0 4px 14px rgba(0,0,0,0.18)', padding: 9, flexShrink: 0, overflow: 'hidden' }}>
          <div style={{ fontFamily: SF, fontSize: 8, fontWeight: 800, color: '#222' }}>HYDRO ONE</div>
          <div style={{ fontFamily: SF, fontSize: 5.5, color: '#999', marginTop: 1 }}>#88213</div>
          {[1,2,3,4].map(i => <div key={i} style={{ height: 3, background: '#eee', borderRadius: 2, margin: '5px 0' }} />)}
          <div style={{ height: 5, background: '#ddd', borderRadius: 2, marginTop: 8, width: '60%' }} />
        </div>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={{ fontSize: 16 }}>✨</span>
            <span style={{ fontFamily: SF, fontSize: 16, fontWeight: 700, color: dark ? D_INK : INK }}>Extracted by AI</span>
          </div>
          <div style={{ fontFamily: SF, fontSize: 13, color: dark ? D_SEC : SEC, marginTop: 3, lineHeight: 1.4 }}>Review the fields below, then create a draft payable. Tap any field to edit.</div>
        </div>
      </div>
      <div style={card}>
        {field('Vendor', 'Hydro One', 'High')}
        {field('Amount', money(4105.22), 'High')}
        {field('Invoice date', 'Feb 28, 2026', 'High')}
        {field('HST (13%)', money(471.79), 'Med')}
        {field('Invoice #', '88213', 'High')}
        {field('Suggested account', '5310 · Utilities — Power', 'Med')}
        {field('Fund', 'Operating', null, true)}
      </div>
      {/* duplicate check */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 9, margin: '14px 20px 0' }}>
        <span style={{ color: EMERALD, fontSize: 15 }}>✓</span>
        <span style={{ fontFamily: SF, fontSize: 13, color: dark ? D_SEC : SEC }}>No duplicate invoice found for this vendor.</span>
      </div>
      {/* sticky actions */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: '12px 16px 30px',
        backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
        background: dark ? 'rgba(20,20,22,0.8)' : 'rgba(242,242,247,0.8)', borderTop: `0.5px solid ${dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.06)'}` }}>
        <button onClick={onDone} style={primaryBtn}>Create draft payable</button>
        <button onClick={onDone} style={{ width: '100%', padding: '13px', marginTop: 8, background: 'transparent', color: EMERALD, border: 'none', fontFamily: SF, fontSize: 16, fontWeight: 600, cursor: 'pointer' }}>Save to document inbox</button>
      </div>
    </Screen>
  );
}

/* ============================================================
   MORE — hub for everything outside the 2 primary tabs
   ============================================================ */
function MoreRow({ dark, icon, iconBg, title, sub, badge, badgeBg, last, onTap }) {
  return (
    <div onClick={onTap} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', position: 'relative', cursor: 'pointer' }}>
      <div style={{ width: 30, height: 30, borderRadius: 8, background: iconBg, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>{icon}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: SF, fontSize: 16, color: dark ? D_INK : INK }}>{title}</div>
        {sub && <div style={{ fontFamily: SF, fontSize: 12.5, color: dark ? D_SEC : SEC }}>{sub}</div>}
      </div>
      {badge != null && <span style={{ minWidth: 20, textAlign: 'center', fontFamily: SF, fontSize: 12, fontWeight: 700, color: '#fff', background: badgeBg, borderRadius: 999, padding: '2px 6px' }}>{badge}</span>}
      <svg width="8" height="13" viewBox="0 0 8 13"><path d="M1 1l6 6-6 6" stroke={dark ? D_SEP : 'rgba(60,60,67,0.3)'} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
      {!last && <div style={{ position: 'absolute', bottom: 0, left: 56, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
    </div>
  );
}

function MoreScreen({ dark, onCapture, onNav, onTxn, onPayables, onReceivables, onBanking, onAccounts, onSettings, onJournals }) {
  const card = { background: dark ? D_CARD : '#fff', borderRadius: 14, margin: '0 16px 18px', overflow: 'hidden', boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' };
  const em = <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 13V3M4 6.5L8 2.5l4 4" stroke="#047857" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/></svg>;
  const emDown = <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 3v10M4 9.5l4 4 4-4" stroke="#047857" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/></svg>;
  return (
    <Screen tab="more" dark={dark} onCapture={onCapture} onNav={onNav}>
      <div style={{ padding: '58px 20px 10px', fontFamily: SF, fontSize: 34, fontWeight: 700, color: dark ? D_INK : INK, letterSpacing: 0.3 }}>More</div>

      {/* profile */}
      <div style={{ margin: '0 16px 18px', background: '#0f172a', borderRadius: 18, padding: 16, display: 'flex', alignItems: 'center', gap: 13, boxShadow: dark ? 'none' : '0 6px 18px rgba(15,23,42,0.25)' }}>
        <div style={{ width: 44, height: 44, border: '1.5px solid #475569', borderRadius: 11, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <img src="assets/logo.svg" alt="" style={{ width: 27, height: 27 }} />
        </div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontFamily: SF, fontSize: 16, fontWeight: 700, color: '#fff' }}>Brookline Grove Condo Corp</div>
          <div style={{ fontFamily: SF, fontSize: 12.5, color: '#94a3b8', marginTop: 1 }}>Murray Toews · Manager</div>
        </div>
        <span style={{ fontFamily: SF, fontSize: 10.5, fontWeight: 700, letterSpacing: 0.4, color: '#6ee7b7', background: 'rgba(4,120,87,0.35)', padding: '3px 8px', borderRadius: 999 }}>ADMIN</span>
      </div>

      <SectionLabel dark={dark}>NEEDS YOUR ACTION</SectionLabel>
      <div style={card}>
        <MoreRow dark={dark} onTap={() => onNav('activity')} title="Payment Sign-Off" sub="$10,505.22 awaiting approval" badge="4" badgeBg="#dc2626"
          iconBg="#047857" icon={<svg width="17" height="17" viewBox="0 0 17 17" fill="none"><path d="M3 9l3.5 3.5L14 4.5" stroke="#fff" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>} />
        <MoreRow dark={dark} last onTap={onJournals} title="Journal Booking" sub="7 open entries · $18,304.10" badge="7" badgeBg="#d97706"
          iconBg="#047857" icon={<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M3 2.5h10v11H3z M5.5 5.5h5 M5.5 8h5 M5.5 10.5h3" stroke="#fff" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/></svg>} />
      </div>

      <SectionLabel dark={dark}>MONEY</SectionLabel>
      <div style={card}>
        <MoreRow dark={dark} title="Payables" onTap={onPayables} iconBg={dark ? 'rgba(4,120,87,0.18)' : EMERALD_SOFT} icon={em} />
        <MoreRow dark={dark} title="Receivables" onTap={onReceivables} iconBg={dark ? 'rgba(4,120,87,0.18)' : EMERALD_SOFT} icon={emDown} />
        <MoreRow dark={dark} last title="Banking" sub="2 accounts connected via Plaid" onTap={onBanking} iconBg={dark ? 'rgba(4,120,87,0.18)' : EMERALD_SOFT}
          icon={<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M2.5 6.5h11M2.5 6.5L8 2.5l5.5 4M4 6.5v6M8 6.5v6M12 6.5v6M2.5 12.5h11" stroke="#047857" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>} />
      </div>

      <SectionLabel dark={dark}>ACCOUNT</SectionLabel>
      <div style={card}>
        <MoreRow dark={dark} title="Chart of Accounts" onTap={onAccounts} iconBg={dark ? 'rgba(148,163,184,0.18)' : '#f1f5f9'}
          icon={<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M3 3h10v10H3z M6 6h4M6 8.5h4M6 11h2.5" stroke="#475569" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round"/></svg>} />
        <MoreRow dark={dark} last title="Settings" sub="Security, Face ID, log out" onTap={onSettings} iconBg={dark ? 'rgba(148,163,184,0.18)' : '#f1f5f9'}
          icon={<svg width="16" height="16" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="2.3" stroke="#475569" strokeWidth="1.6"/><path d="M8 1.8v2M8 12.2v2M1.8 8h2M12.2 8h2M3.6 3.6l1.4 1.4M11 11l1.4 1.4M12.4 3.6L11 5M5 11l-1.4 1.4" stroke="#475569" strokeWidth="1.6" strokeLinecap="round"/></svg>} />
      </div>

      <div style={{ fontFamily: SF, fontSize: 12, color: dark ? D_SEC : SEC, textAlign: 'center', padding: '2px 16px 8px' }}>Noble Ledger · v0.0.4.66</div>
    </Screen>
  );
}

/* ============================================================
   PAYABLES — AP bill list (pushed from More)
   ============================================================ */
const BILLS = [
  { id: 'b1', vendor: 'Toronto Water',         inv: 'AP-1925', due: 'Due in 3 days',  amount: 9361.10, status: 'open' },
  { id: 'b2', vendor: 'Brookline Prop Mgmt',   inv: 'AP-1918', due: 'Due in 6 days',  amount: 6400.00, status: 'open' },
  { id: 'b3', vendor: 'GroveCare Landscaping', inv: 'AP-1922', due: 'Overdue 2 days',  amount: 5578.33, status: 'overdue' },
  { id: 'b4', vendor: 'Hydro One',             inv: 'AP-1914', due: 'Due in 11 days', amount: 4105.22, status: 'open' },
  { id: 'b5', vendor: 'Elevator Serv. Co.',    inv: 'AP-1902', due: 'Paid Mar 4',     amount: 2980.00, status: 'paid' },
  { id: 'b6', vendor: 'BluePoint Insurance',   inv: 'AP-1899', due: 'Paid Mar 1',     amount: 7420.00, status: 'paid' },
];

function PayablesScreen({ dark, onBack, onOpen, extra = [], banner }) {
  const [seg, setSeg] = React.useState('open');
  const all = [...extra, ...BILLS];
  const list = seg === 'all' ? all : all.filter(b => seg === 'open' ? (b.status === 'open' || b.status === 'overdue' || b.status === 'draft') : b.status === seg);
  const openTotal = all.filter(b => b.status === 'open' || b.status === 'overdue' || b.status === 'draft').reduce((a, b) => a + b.amount, 0);
  const card = { background: dark ? D_CARD : '#fff', borderRadius: 16, margin: '0 16px', overflow: 'hidden', boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' };
  const segTab = (id, lbl) => (
    <div key={id} onClick={() => setSeg(id)} style={{ flex: 1, textAlign: 'center', padding: '7px 0', borderRadius: 7,
      fontFamily: SF, fontSize: 13.5, fontWeight: 600,
      background: seg === id ? (dark ? '#636366' : '#fff') : 'transparent',
      color: seg === id ? (dark ? '#fff' : INK) : (dark ? D_SEC : SEC),
      boxShadow: seg === id ? '0 1px 3px rgba(0,0,0,0.12)' : 'none', cursor: 'pointer' }}>{lbl}</div>
  );
  return (
    <Screen dark={dark} noChrome scrollPad={30}>
      {/* nav */}
      <div style={{ padding: '54px 16px 4px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div onClick={onBack} style={{ display: 'flex', alignItems: 'center', gap: 3, cursor: 'pointer' }}>
          <svg width="11" height="18" viewBox="0 0 11 18"><path d="M9 1L2 9l7 8" stroke={EMERALD} strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ fontFamily: SF, fontSize: 17, color: EMERALD }}>More</span>
        </div>
        <div style={{ width: 30, height: 30, borderRadius: 8, background: dark ? D_CARD : '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: dark ? 'none' : '0 1px 2px rgba(0,0,0,0.08)' }}>
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 3.5v9M3.5 8h9" stroke={EMERALD} strokeWidth="2" strokeLinecap="round"/></svg>
        </div>
      </div>
      <div style={{ padding: '2px 20px 2px', fontFamily: SF, fontSize: 32, fontWeight: 700, color: dark ? D_INK : INK, letterSpacing: 0.3 }}>Payables</div>

      {banner && (
        <div style={{ margin: '8px 16px 4px', display: 'flex', alignItems: 'center', gap: 9, background: dark ? 'rgba(4,120,87,0.18)' : EMERALD_SOFT, borderRadius: 12, padding: '11px 14px' }}>
          <svg width="18" height="18" viewBox="0 0 18 18" fill="none"><circle cx="9" cy="9" r="8" fill={EMERALD}/><path d="M5.5 9.2l2.3 2.3 4.5-4.7" stroke="#fff" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ flex: 1, fontFamily: SF, fontSize: 13.5, fontWeight: 500, color: dark ? D_INK : '#065f46' }}>{banner}</span>
        </div>
      )}

      {/* open total */}
      <div style={{ ...card, marginBottom: 14, padding: 16, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontFamily: SF, fontSize: 12.5, fontWeight: 600, color: dark ? D_SEC : SEC }}>Open payables</div>
          <div style={{ fontFamily: SF, fontSize: 28, fontWeight: 700, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums', marginTop: 2 }}>{money(openTotal)}</div>
        </div>
        <StatusChip color="#92400e" bg="#fef3c7">1 overdue</StatusChip>
      </div>

      {/* segmented control */}
      <div style={{ margin: '0 16px 14px', background: dark ? 'rgba(118,118,128,0.24)' : 'rgba(118,118,128,0.12)', borderRadius: 9, padding: 2, display: 'flex' }}>
        {segTab('open', 'Open')}{segTab('paid', 'Paid')}{segTab('all', 'All')}
      </div>

      <div style={card}>
        {list.map((b, i) => {
          const tone = b.status === 'overdue' ? RED : b.status === 'draft' ? EMERALD : b.status === 'paid' ? EMERALD : (dark ? D_SEC : SEC);
          return (
            <div key={b.id} onClick={() => onOpen && onOpen(b)} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 16px', position: 'relative', cursor: 'pointer' }}>
              <div style={{ width: 38, height: 38, borderRadius: 11, background: b.status === 'paid' || b.status === 'draft' ? (dark ? 'rgba(4,120,87,0.18)' : EMERALD_SOFT) : (dark ? 'rgba(148,163,184,0.16)' : '#f1f5f9'), flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: SF, fontSize: 14, fontWeight: 700, color: b.status === 'paid' || b.status === 'draft' ? EMERALD : '#475569' }}>{b.vendor[0]}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
                  <span style={{ fontFamily: SF, fontSize: 16, fontWeight: 600, color: dark ? D_INK : INK, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{b.vendor}</span>
                  {b.status === 'draft' && <span style={{ fontFamily: SF, fontSize: 10, fontWeight: 700, letterSpacing: 0.4, color: EMERALD, background: dark ? 'rgba(4,120,87,0.2)' : EMERALD_SOFT, padding: '1px 6px', borderRadius: 999, flexShrink: 0 }}>DRAFT</span>}
                </div>
                <div style={{ fontFamily: SF, fontSize: 12.5, color: tone, fontWeight: b.status === 'overdue' ? 600 : 400 }}>{b.inv} · {b.due}</div>
              </div>
              <div style={{ fontFamily: SF, fontSize: 16, fontWeight: 600, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums', flexShrink: 0 }}>{money(b.amount)}</div>
              {i < list.length - 1 && <div style={{ position: 'absolute', bottom: 0, left: 66, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
            </div>
          );
        })}
      </div>
      <div style={{ fontFamily: SF, fontSize: 12.5, color: dark ? D_SEC : SEC, textAlign: 'center', padding: 16 }}>Showing {list.length} of {all.length} bills</div>
    </Screen>
  );
}

/* ============================================================
   RECEIVABLES — AR invoice list (pushed from More)
   ============================================================ */
const INVOICES = [
  { id: 'r1', cust: 'Unit 1204 — Williams', inv: 'AR-2831', due: 'Overdue 42 days', amount: 1370.00, status: 'overdue' },
  { id: 'r2', cust: 'Unit 0807 — Nguyen',   inv: 'AR-2836', due: 'Overdue 18 days', amount: 685.00,  status: 'overdue' },
  { id: 'r3', cust: 'Unit 1502 — Okafor',   inv: 'AR-2840', due: 'Overdue 4 days',  amount: 2835.00, status: 'overdue' },
  { id: 'r4', cust: 'Unit 0311 — Rossi',    inv: 'AR-2842', due: 'Due in 5 days',   amount: 685.00,  status: 'open' },
  { id: 'r5', cust: 'Unit 0906 — Chen',     inv: 'AR-2844', due: 'Due in 12 days',  amount: 8625.00, status: 'open' },
  { id: 'r6', cust: 'Unit 0102 — Dubois',   inv: 'AR-2820', due: 'Paid Mar 2',      amount: 685.00,  status: 'paid' },
];

function ReceivablesScreen({ dark, onBack, onOpen }) {
  const [seg, setSeg] = React.useState('open');
  const list = seg === 'all' ? INVOICES : INVOICES.filter(r => seg === 'open' ? (r.status === 'open' || r.status === 'overdue') : r.status === seg);
  const openTotal = INVOICES.filter(r => r.status === 'open' || r.status === 'overdue').reduce((a, r) => a + r.amount, 0);
  const overdueCount = INVOICES.filter(r => r.status === 'overdue').length;
  const card = { background: dark ? D_CARD : '#fff', borderRadius: 16, margin: '0 16px', overflow: 'hidden', boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' };
  const segTab = (id, lbl) => (
    <div key={id} onClick={() => setSeg(id)} style={{ flex: 1, textAlign: 'center', padding: '7px 0', borderRadius: 7,
      fontFamily: SF, fontSize: 13.5, fontWeight: 600,
      background: seg === id ? (dark ? '#636366' : '#fff') : 'transparent',
      color: seg === id ? (dark ? '#fff' : INK) : (dark ? D_SEC : SEC),
      boxShadow: seg === id ? '0 1px 3px rgba(0,0,0,0.12)' : 'none', cursor: 'pointer' }}>{lbl}</div>
  );
  return (
    <Screen dark={dark} noChrome scrollPad={30}>
      <div style={{ padding: '54px 16px 4px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div onClick={onBack} style={{ display: 'flex', alignItems: 'center', gap: 3, cursor: 'pointer' }}>
          <svg width="11" height="18" viewBox="0 0 11 18"><path d="M9 1L2 9l7 8" stroke={EMERALD} strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ fontFamily: SF, fontSize: 17, color: EMERALD }}>More</span>
        </div>
        <div style={{ width: 30, height: 30, borderRadius: 8, background: dark ? D_CARD : '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', boxShadow: dark ? 'none' : '0 1px 2px rgba(0,0,0,0.08)' }}>
          <svg width="16" height="16" viewBox="0 0 16 16" fill="none"><path d="M8 3.5v9M3.5 8h9" stroke={EMERALD} strokeWidth="2" strokeLinecap="round"/></svg>
        </div>
      </div>
      <div style={{ padding: '2px 20px 2px', fontFamily: SF, fontSize: 32, fontWeight: 700, color: dark ? D_INK : INK, letterSpacing: 0.3 }}>Receivables</div>

      <div style={{ ...card, marginBottom: 14, padding: 16, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontFamily: SF, fontSize: 12.5, fontWeight: 600, color: dark ? D_SEC : SEC }}>Outstanding</div>
          <div style={{ fontFamily: SF, fontSize: 28, fontWeight: 700, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums', marginTop: 2 }}>{money(openTotal)}</div>
        </div>
        <StatusChip color="#92400e" bg="#fef3c7">{overdueCount} overdue</StatusChip>
      </div>

      <div style={{ margin: '0 16px 14px', background: dark ? 'rgba(118,118,128,0.24)' : 'rgba(118,118,128,0.12)', borderRadius: 9, padding: 2, display: 'flex' }}>
        {segTab('open', 'Open')}{segTab('overdue', 'Overdue')}{segTab('paid', 'Paid')}
      </div>

      <div style={card}>
        {list.map((r, i) => {
          const tone = r.status === 'overdue' ? RED : r.status === 'paid' ? EMERALD : (dark ? D_SEC : SEC);
          return (
            <div key={r.id} onClick={() => onOpen && onOpen(r)} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 16px', position: 'relative', cursor: 'pointer' }}>
              <div style={{ width: 38, height: 38, borderRadius: 11, background: dark ? 'rgba(37,99,235,0.16)' : '#eff6ff', flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: SF, fontSize: 13, fontWeight: 700, color: BLUE }}>{r.cust.replace('Unit ', '').slice(0, 2)}</div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontFamily: SF, fontSize: 16, fontWeight: 600, color: dark ? D_INK : INK, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{r.cust}</div>
                <div style={{ fontFamily: SF, fontSize: 12.5, color: tone, fontWeight: r.status === 'overdue' ? 600 : 400 }}>{r.inv} · {r.due}</div>
              </div>
              <div style={{ fontFamily: SF, fontSize: 16, fontWeight: 600, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums', flexShrink: 0 }}>{money(r.amount)}</div>
              {i < list.length - 1 && <div style={{ position: 'absolute', bottom: 0, left: 66, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
            </div>
          );
        })}
      </div>
      <div style={{ fontFamily: SF, fontSize: 12.5, color: dark ? D_SEC : SEC, textAlign: 'center', padding: 16 }}>Showing {list.length} of {INVOICES.length} invoices</div>
    </Screen>
  );
}

/* ============================================================
   BANKING — connected accounts + transactions (pushed from More)
   ============================================================ */
const BANK_ACCTS = [
  { id: 'a1', name: 'RBC Operating', mask: '···· 4821', current: 184920.00, available: 179140.00, fund: 'Operating' },
  { id: 'a2', name: 'TD Reserve GIC', mask: '···· 0512', current: 281440.00, available: 281440.00, fund: 'Reserve' },
  { id: 'a3', name: 'BMO Special Assmt', mask: '···· 7734', current: 15950.00, available: 15950.00, fund: 'Special Assessment' },
];
const BANK_TXNS = {
  a1: [
    { id: 'x1', name: 'Hydro One', when: 'Today', amount: -4105.22 },
    { id: 'x2', name: 'Condo fee — Unit 0311', when: 'Yesterday', amount: 685.00 },
    { id: 'x3', name: 'GroveCare Landscaping', when: 'Mar 11', amount: -5578.33 },
    { id: 'x4', name: 'Reserve transfer out', when: 'Mar 10', amount: -12500.00 },
  ],
  a2: [
    { id: 'x5', name: 'Reserve contribution', when: 'Mar 10', amount: 12500.00 },
    { id: 'x6', name: 'GIC interest', when: 'Mar 1', amount: 934.10 },
  ],
  a3: [
    { id: 'x7', name: 'Elevator project draw', when: 'Mar 6', amount: -2980.00 },
  ],
};

function BankingScreen({ dark, onBack }) {
  const [acct, setAcct] = React.useState('a1');
  const card = { background: dark ? D_CARD : '#fff', borderRadius: 16, margin: '0 16px', overflow: 'hidden', boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' };
  const txns = BANK_TXNS[acct] || [];
  return (
    <Screen dark={dark} noChrome scrollPad={30}>
      <div style={{ padding: '54px 16px 4px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div onClick={onBack} style={{ display: 'flex', alignItems: 'center', gap: 3, cursor: 'pointer' }}>
          <svg width="11" height="18" viewBox="0 0 11 18"><path d="M9 1L2 9l7 8" stroke={EMERALD} strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ fontFamily: SF, fontSize: 17, color: EMERALD }}>More</span>
        </div>
        <span style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: EMERALD }}>Connect</span>
      </div>
      <div style={{ padding: '2px 20px 12px', fontFamily: SF, fontSize: 32, fontWeight: 700, color: dark ? D_INK : INK, letterSpacing: 0.3 }}>Banking</div>

      {/* account cards */}
      <div style={{ display: 'flex', gap: 12, overflowX: 'auto', padding: '0 16px 4px' }}>
        {BANK_ACCTS.map(a => {
          const on = acct === a.id;
          return (
            <div key={a.id} onClick={() => setAcct(a.id)} style={{ flexShrink: 0, width: 210, borderRadius: 16, padding: 16, cursor: 'pointer',
              background: on ? 'linear-gradient(155deg,#064e3b,#047857)' : (dark ? D_CARD : '#fff'),
              boxShadow: on ? '0 8px 20px rgba(4,120,87,0.28)' : (dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)'),
              border: on ? 'none' : `1px solid ${dark ? D_SEP : SEP}` }}>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                <span style={{ fontFamily: SF, fontSize: 13.5, fontWeight: 600, color: on ? '#fff' : (dark ? D_INK : INK) }}>{a.name}</span>
                <span style={{ width: 8, height: 8, borderRadius: 3, background: FUND_COLORS[a.fund] || EMERALD }} />
              </div>
              <div style={{ fontFamily: SF, fontSize: 12, color: on ? 'rgba(255,255,255,0.75)' : (dark ? D_SEC : SEC), marginTop: 2 }}>{a.mask}</div>
              <div style={{ fontFamily: SF, fontSize: 24, fontWeight: 700, color: on ? '#fff' : (dark ? D_INK : INK), fontVariantNumeric: 'tabular-nums', marginTop: 10 }}>{money(a.current)}</div>
              <div style={{ fontFamily: SF, fontSize: 12, color: on ? 'rgba(255,255,255,0.8)' : (dark ? D_SEC : SEC), marginTop: 1 }}>{money(a.available)} available</div>
            </div>
          );
        })}
      </div>

      <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: dark ? D_SEC : SEC, letterSpacing: 0.3, padding: '18px 20px 7px' }}>RECENT TRANSACTIONS</div>
      <div style={card}>
        {txns.map((x, i) => (
          <div key={x.id} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 16px', position: 'relative' }}>
            <div style={{ width: 34, height: 34, borderRadius: 10, background: x.amount > 0 ? (dark ? 'rgba(4,120,87,0.18)' : EMERALD_SOFT) : (dark ? 'rgba(148,163,184,0.16)' : '#f1f5f9'), flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="18" height="18" viewBox="0 0 18 18" fill="none">{x.amount > 0
                ? <path d="M9 4.5v9M5 8l4 4 4-4" stroke={EMERALD} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
                : <path d="M9 13.5v-9M5 10l4-4 4 4" stroke="#475569" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>}</svg>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: SF, fontSize: 15.5, fontWeight: 600, color: dark ? D_INK : INK, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{x.name}</div>
              <div style={{ fontFamily: SF, fontSize: 12.5, color: dark ? D_SEC : SEC }}>{x.when}</div>
            </div>
            <div style={{ fontFamily: SF, fontSize: 15.5, fontWeight: 600, color: x.amount > 0 ? EMERALD : (dark ? D_INK : INK), fontVariantNumeric: 'tabular-nums', flexShrink: 0 }}>{x.amount > 0 ? '+' : '–'}{money(x.amount)}</div>
            {i < txns.length - 1 && <div style={{ position: 'absolute', bottom: 0, left: 62, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
          </div>
        ))}
      </div>
      <div style={{ fontFamily: SF, fontSize: 12.5, color: dark ? D_SEC : SEC, textAlign: 'center', padding: 16 }}>Synced via Plaid · 2 min ago</div>
    </Screen>
  );
}

/* ============================================================
   BILL DETAIL (payable) / INVOICE DETAIL (receivable)
   ============================================================ */
function DocDetail({ dark, onBack, backLabel, kind, party, partyLabel, refText, hero, statusChip, meta, lines, breakdown, remaining, actionLabel }) {
  const card = { background: dark ? D_CARD : '#fff', borderRadius: 16, margin: '0 16px', overflow: 'hidden', boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' };
  return (
    <Screen dark={dark} noChrome scrollPad={120}>
      <div style={{ padding: '54px 16px 6px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div onClick={onBack} style={{ display: 'flex', alignItems: 'center', gap: 3, cursor: 'pointer' }}>
          <svg width="11" height="18" viewBox="0 0 11 18"><path d="M9 1L2 9l7 8" stroke={EMERALD} strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ fontFamily: SF, fontSize: 17, color: EMERALD }}>{backLabel}</span>
        </div>
        {statusChip}
      </div>
      {/* amount hero */}
      <div style={{ textAlign: 'center', padding: '12px 20px 18px' }}>
        <div style={{ fontFamily: SF, fontSize: 12.5, fontWeight: 600, color: dark ? D_SEC : SEC, letterSpacing: 0.3 }}>{partyLabel}</div>
        <div style={{ fontFamily: SF, fontSize: 44, fontWeight: 700, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums', marginTop: 6, letterSpacing: 0.5 }}>{money(hero)}</div>
        <div style={{ fontFamily: SF, fontSize: 17, fontWeight: 600, color: dark ? D_INK : INK, marginTop: 2 }}>{party}</div>
        <div style={{ fontFamily: SF, fontSize: 14, color: dark ? D_SEC : SEC }}>{refText}</div>
      </div>
      {/* meta */}
      <div style={{ ...card, marginBottom: 14 }}>
        {meta.map((m, i) => detailRow(m[0], m[1], dark, i === meta.length - 1))}
      </div>
      {/* line items */}
      <div style={{ fontFamily: SF, fontSize: 13, color: dark ? D_SEC : SEC, padding: '0 20px 7px', letterSpacing: 0.2 }}>LINE ITEMS</div>
      <div style={{ ...card, marginBottom: 14 }}>
        {lines.map((l, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', padding: '12px 16px', position: 'relative' }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: SF, fontSize: 15, color: dark ? D_INK : INK }}>{l[0]}</div>
              <div style={{ fontFamily: SF, fontSize: 12.5, color: dark ? D_SEC : SEC }}>{l[1]}</div>
            </div>
            <div style={{ fontFamily: SF, fontSize: 15, fontWeight: 600, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums' }}>{money(l[2])}</div>
            {i < lines.length - 1 && <div style={{ position: 'absolute', bottom: 0, left: 16, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
          </div>
        ))}
        {breakdown.map((b, i) => (
          <div key={'b' + i} style={{ display: 'flex', alignItems: 'center', padding: '10px 16px', position: 'relative', background: dark ? 'rgba(255,255,255,0.02)' : '#fafafa' }}>
            <div style={{ flex: 1, fontFamily: SF, fontSize: 14, fontWeight: b[2] ? 700 : 400, color: b[2] ? (dark ? D_INK : INK) : (dark ? D_SEC : SEC) }}>{b[0]}</div>
            <div style={{ fontFamily: SF, fontSize: 14, fontWeight: b[2] ? 700 : 500, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums' }}>{money(b[1])}</div>
            <div style={{ position: 'absolute', top: 0, left: 16, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />
          </div>
        ))}
      </div>
      {remaining != null && (
        <div style={{ ...card, marginBottom: 14, padding: '13px 16px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <span style={{ fontFamily: SF, fontSize: 15, fontWeight: 600, color: dark ? D_INK : INK }}>Remaining balance</span>
          <span style={{ fontFamily: SF, fontSize: 17, fontWeight: 700, color: remaining > 0 ? RED : EMERALD, fontVariantNumeric: 'tabular-nums' }}>{money(remaining)}</span>
        </div>
      )}
      {/* sticky action */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: '12px 16px 30px',
        backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
        background: dark ? 'rgba(20,20,22,0.8)' : 'rgba(242,242,247,0.8)', borderTop: `0.5px solid ${dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.06)'}` }}>
        <button style={primaryBtn}>{actionLabel}</button>
      </div>
    </Screen>
  );
}

function BillDetail({ dark, onBack, bill }) {
  const b = bill;
  const overdue = b.status === 'overdue';
  const subtotal = +(b.amount / 1.13).toFixed(2);
  const hst = +(b.amount - subtotal).toFixed(2);
  return (
    <DocDetail dark={dark} onBack={onBack} backLabel="Payables" party={b.vendor} partyLabel="AMOUNT DUE" refText={b.inv} hero={b.amount}
      statusChip={b.status === 'paid'
        ? <StatusChip color={EMERALD} bg={dark ? 'rgba(4,120,87,0.18)' : EMERALD_SOFT}>Paid</StatusChip>
        : overdue ? <StatusChip color="#991b1b" bg="#fee2e2">Overdue</StatusChip>
        : <StatusChip color="#92400e" bg="#fef3c7">Open</StatusChip>}
      meta={[['Invoice #', b.inv.replace('AP-', '')], ['Vendor', b.vendor], ['Invoice date', 'Feb 28, 2026'], ['Due', b.due], ['Fund', 'Operating'], ['Account', '5310 · Utilities'], ['Submitted by', 'kpatel · ACCT']]}
      lines={[['Service charges', 'Feb billing period', subtotal - 320], ['Delivery & regulatory', 'Fixed', 320]]}
      breakdown={[['Subtotal', subtotal, false], ['HST (13%)', hst, false], ['Total', b.amount, true]]}
      actionLabel={b.status === 'paid' ? 'View payment' : 'Record payment'} />
  );
}

function InvoiceDetail({ dark, onBack, invoice }) {
  const r = invoice;
  const overdue = r.status === 'overdue';
  const paid = r.status === 'paid';
  return (
    <DocDetail dark={dark} onBack={onBack} backLabel="Receivables" party={r.cust} partyLabel="AMOUNT DUE" refText={r.inv} hero={r.amount}
      statusChip={paid
        ? <StatusChip color={EMERALD} bg={dark ? 'rgba(4,120,87,0.18)' : EMERALD_SOFT}>Paid</StatusChip>
        : overdue ? <StatusChip color="#991b1b" bg="#fee2e2">Overdue</StatusChip>
        : <StatusChip color="#92400e" bg="#fef3c7">Open</StatusChip>}
      meta={[['Invoice #', r.inv.replace('AR-', '')], ['Customer', r.cust], ['Issued', 'Mar 1, 2026'], ['Due', r.due], ['Fund', 'Operating'], ['Account', '4110 · Condo Fees']]}
      lines={[['Monthly condo fee', 'March 2026', r.amount > 1000 ? r.amount - 685 : r.amount], ...(r.amount > 1000 ? [['Special assessment', 'Elevator project', 685]] : [])]}
      breakdown={[['Total billed', r.amount, true]]}
      remaining={paid ? 0 : r.amount}
      actionLabel={paid ? 'View receipt' : 'Record payment received'} />
  );
}

/* ============================================================
   CHART OF ACCOUNTS — hierarchical GL (pushed from More)
   ============================================================ */
const COA = [
  { type: 'Assets', total: 812400, accts: [
    { no: '1010', name: 'RBC Operating', bal: 184920 },
    { no: '1020', name: 'TD Reserve — GIC', bal: 281440 },
    { no: '1030', name: 'BMO Special Assessment', bal: 15950 },
    { no: '1200', name: 'Accounts Receivable', bal: 14200 },
    { no: '1500', name: 'Capital Assets', bal: 315890 },
  ] },
  { type: 'Liabilities', total: 96200, accts: [
    { no: '2010', name: 'Accounts Payable', bal: 28420 },
    { no: '2100', name: 'Prepaid Condo Fees', bal: 12780 },
    { no: '2400', name: 'Elevator Loan', bal: 55000 },
  ] },
  { type: 'Equity', total: 716200, accts: [
    { no: '3010', name: 'Operating Surplus', bal: 148760 },
    { no: '3020', name: 'Reserve Fund Balance', bal: 567440 },
  ] },
  { type: 'Revenue', total: 412600, accts: [
    { no: '4110', name: 'Condo Fees — Residential', bal: 396000 },
    { no: '4300', name: 'Interest & Other Income', bal: 16600 },
  ] },
  { type: 'Expenses', total: 389100, accts: [
    { no: '5110', name: 'Utilities — Water', bal: 41200 },
    { no: '5310', name: 'Utilities — Power', bal: 31240 },
    { no: '5210', name: 'Professional Management', bal: 76800 },
    { no: '5420', name: 'Landscaping & Grounds', bal: 28900 },
  ] },
];

function AccountsScreen({ dark, onBack }) {
  const [open, setOpen] = React.useState('Assets');
  const card = { background: dark ? D_CARD : '#fff', borderRadius: 16, margin: '0 16px 12px', overflow: 'hidden', boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' };
  return (
    <Screen dark={dark} noChrome scrollPad={30}>
      <div style={{ padding: '54px 16px 4px', display: 'flex', alignItems: 'center' }}>
        <div onClick={onBack} style={{ display: 'flex', alignItems: 'center', gap: 3, cursor: 'pointer' }}>
          <svg width="11" height="18" viewBox="0 0 11 18"><path d="M9 1L2 9l7 8" stroke={EMERALD} strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ fontFamily: SF, fontSize: 17, color: EMERALD }}>More</span>
        </div>
      </div>
      <div style={{ padding: '2px 20px 12px', fontFamily: SF, fontSize: 32, fontWeight: 700, color: dark ? D_INK : INK, letterSpacing: 0.3 }}>Accounts</div>
      {COA.map(group => {
        const isOpen = open === group.type;
        return (
          <div key={group.type} style={card}>
            <div onClick={() => setOpen(isOpen ? null : group.type)} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '13px 16px', cursor: 'pointer', position: 'relative' }}>
              <svg width="11" height="11" viewBox="0 0 11 11" style={{ transform: isOpen ? 'rotate(90deg)' : 'none', transition: 'transform .15s' }}><path d="M3 1l5 4.5L3 10" stroke={dark ? D_SEC : SEC} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
              <span style={{ flex: 1, fontFamily: SF, fontSize: 16, fontWeight: 700, color: dark ? D_INK : INK }}>{group.type}</span>
              <span style={{ fontFamily: SF, fontSize: 15, fontWeight: 600, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums' }}>{money(group.total)}</span>
              {isOpen && <div style={{ position: 'absolute', bottom: 0, left: 16, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
            </div>
            {isOpen && group.accts.map((a, i) => (
              <div key={a.no} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 16px 11px 37px', position: 'relative' }}>
                <span style={{ fontFamily: SF, fontSize: 12.5, fontWeight: 600, color: EMERALD, width: 42, flexShrink: 0, fontVariantNumeric: 'tabular-nums' }}>{a.no}</span>
                <span style={{ flex: 1, fontFamily: SF, fontSize: 14.5, color: dark ? D_INK : INK, minWidth: 0, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{a.name}</span>
                <span style={{ fontFamily: SF, fontSize: 14.5, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums' }}>{money(a.bal)}</span>
                {i < group.accts.length - 1 && <div style={{ position: 'absolute', bottom: 0, left: 37, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
              </div>
            ))}
          </div>
        );
      })}
    </Screen>
  );
}

/* ============================================================
   SETTINGS — account, security, session (pushed from More)
   ============================================================ */
function SettingsScreen({ dark, onBack, onLogout }) {
  const [faceId, setFaceId] = React.useState(true);
  const [darkPref, setDarkPref] = React.useState(false);
  const card = { background: dark ? D_CARD : '#fff', borderRadius: 16, margin: '0 16px 12px', overflow: 'hidden', boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' };
  const groupLabel = (t) => <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: dark ? D_SEC : SEC, letterSpacing: 0.3, padding: '6px 20px 7px' }}>{t}</div>;
  const infoRow = (k, v, last) => (
    <div style={{ display: 'flex', alignItems: 'center', minHeight: 46, padding: '0 16px', position: 'relative' }}>
      <span style={{ flex: 1, fontFamily: SF, fontSize: 15, color: dark ? D_SEC : SEC }}>{k}</span>
      <span style={{ fontFamily: SF, fontSize: 15, fontWeight: 500, color: dark ? D_INK : INK }}>{v}</span>
      {!last && <div style={{ position: 'absolute', bottom: 0, left: 16, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
    </div>
  );
  const toggleRow = (label, on, set, last) => (
    <div style={{ display: 'flex', alignItems: 'center', minHeight: 48, padding: '0 16px', position: 'relative' }}>
      <span style={{ flex: 1, fontFamily: SF, fontSize: 16, color: dark ? D_INK : INK }}>{label}</span>
      <div onClick={() => set(!on)} style={{ width: 51, height: 31, borderRadius: 999, background: on ? EMERALD : (dark ? '#39393d' : '#e5e5ea'), position: 'relative', cursor: 'pointer', transition: 'background .15s' }}>
        <div style={{ position: 'absolute', top: 2, left: on ? 22 : 2, width: 27, height: 27, borderRadius: 999, background: '#fff', boxShadow: '0 1px 3px rgba(0,0,0,0.2)', transition: 'left .15s' }} />
      </div>
      {!last && <div style={{ position: 'absolute', bottom: 0, left: 16, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
    </div>
  );
  return (
    <Screen dark={dark} noChrome scrollPad={30}>
      <div style={{ padding: '54px 16px 4px', display: 'flex', alignItems: 'center' }}>
        <div onClick={onBack} style={{ display: 'flex', alignItems: 'center', gap: 3, cursor: 'pointer' }}>
          <svg width="11" height="18" viewBox="0 0 11 18"><path d="M9 1L2 9l7 8" stroke={EMERALD} strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ fontFamily: SF, fontSize: 17, color: EMERALD }}>More</span>
        </div>
      </div>
      <div style={{ padding: '2px 20px 12px', fontFamily: SF, fontSize: 32, fontWeight: 700, color: dark ? D_INK : INK, letterSpacing: 0.3 }}>Settings</div>

      {groupLabel('ACCOUNT')}
      <div style={card}>
        {infoRow('Name', 'Murray Toews')}
        {infoRow('Email', 'murray@toews.dev')}
        {infoRow('Company', 'Brookline Grove Condo Corp')}
        {infoRow('Role', 'Manager · ADMIN', true)}
      </div>

      {groupLabel('SECURITY')}
      <div style={card}>
        {toggleRow('Face ID / Touch ID', faceId, setFaceId)}
        {toggleRow('Dark appearance', darkPref, setDarkPref, true)}
      </div>

      {groupLabel('BANKING')}
      <div style={card}>
        <div style={{ display: 'flex', alignItems: 'center', minHeight: 48, padding: '0 16px', cursor: 'pointer' }}>
          <span style={{ flex: 1, fontFamily: SF, fontSize: 16, color: EMERALD }}>Connect a bank account</span>
          <svg width="8" height="13" viewBox="0 0 8 13"><path d="M1 1l6 6-6 6" stroke={dark ? D_SEP : 'rgba(60,60,67,0.3)'} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
        </div>
      </div>

      <div style={{ ...card, marginTop: 4 }}>
        <div onClick={onLogout} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: 50, cursor: 'pointer' }}>
          <span style={{ fontFamily: SF, fontSize: 16, fontWeight: 600, color: RED }}>Log Out</span>
        </div>
      </div>
      <div style={{ fontFamily: SF, fontSize: 12, color: dark ? D_SEC : SEC, textAlign: 'center', padding: '6px 16px 8px' }}>Noble Ledger · v0.0.4.66</div>
    </Screen>
  );
}

/* ============================================================
   JOURNAL BOOKING — review & book open entries (pushed from More)
   ============================================================ */
const JOURNALS = [
  { id: 3312, desc: 'March utilities accrual', date: 'Mar 12, 2026', type: 'Accrual', amount: 13466.32, balanced: true, lines: [
    { acct: '5310', name: 'Utilities — Power', dr: 4105.22, cr: 0 },
    { acct: '5110', name: 'Utilities — Water', dr: 9361.10, cr: 0 },
    { acct: '2010', name: 'Accounts Payable', dr: 0, cr: 13466.32 },
  ] },
  { id: 3311, desc: 'Condo fees — March billing', date: 'Mar 1, 2026', type: 'Standard', amount: 33000.00, balanced: true, lines: [
    { acct: '1200', name: 'Accounts Receivable', dr: 33000.00, cr: 0 },
    { acct: '4110', name: 'Condo Fees — Residential', dr: 0, cr: 33000.00 },
  ] },
  { id: 3310, desc: 'Reserve fund contribution', date: 'Mar 10, 2026', type: 'Transfer', amount: 12500.00, balanced: true, lines: [
    { acct: '3020', name: 'Reserve Fund Balance', dr: 0, cr: 12500.00 },
    { acct: '1020', name: 'TD Reserve — GIC', dr: 12500.00, cr: 0 },
  ] },
  { id: 3309, desc: 'Landscaping contract', date: 'Mar 11, 2026', type: 'Standard', amount: 5578.33, balanced: true, lines: [
    { acct: '5420', name: 'Landscaping & Grounds', dr: 5578.33, cr: 0 },
    { acct: '2010', name: 'Accounts Payable', dr: 0, cr: 5578.33 },
  ] },
  { id: 3308, desc: 'Elevator project draw', date: 'Mar 6, 2026', type: 'Standard', amount: 2980.00, balanced: false, lines: [
    { acct: '1500', name: 'Capital Assets', dr: 2980.00, cr: 0 },
    { acct: '1030', name: 'BMO Special Assessment', dr: 0, cr: 2680.00 },
  ] },
];
const JRN_TOTAL = JOURNALS.reduce((a, j) => a + j.amount, 0);

function JournalBookingScreen({ dark, onBack, onOpen }) {
  const card = { background: dark ? D_CARD : '#fff', borderRadius: 16, margin: '0 16px', overflow: 'hidden', boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' };
  const unbalanced = JOURNALS.filter(j => !j.balanced).length;
  return (
    <Screen dark={dark} noChrome scrollPad={116}>
      <div style={{ padding: '54px 16px 4px', display: 'flex', alignItems: 'center' }}>
        <div onClick={onBack} style={{ display: 'flex', alignItems: 'center', gap: 3, cursor: 'pointer' }}>
          <svg width="11" height="18" viewBox="0 0 11 18"><path d="M9 1L2 9l7 8" stroke={EMERALD} strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ fontFamily: SF, fontSize: 17, color: EMERALD }}>More</span>
        </div>
      </div>
      <div style={{ padding: '2px 20px 2px', fontFamily: SF, fontSize: 32, fontWeight: 700, color: dark ? D_INK : INK, letterSpacing: 0.3 }}>Journal Booking</div>

      <div style={{ ...card, marginBottom: 14, padding: 16, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontFamily: SF, fontSize: 12.5, fontWeight: 600, color: dark ? D_SEC : SEC }}>Open entries</div>
          <div style={{ fontFamily: SF, fontSize: 28, fontWeight: 700, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums', marginTop: 2 }}>{money(JRN_TOTAL)}</div>
        </div>
        {unbalanced > 0
          ? <StatusChip color="#991b1b" bg="#fee2e2">{unbalanced} unbalanced</StatusChip>
          : <StatusChip color={EMERALD} bg={dark ? 'rgba(4,120,87,0.18)' : EMERALD_SOFT}>All balanced</StatusChip>}
      </div>

      <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: dark ? D_SEC : SEC, letterSpacing: 0.3, padding: '0 20px 7px' }}>{JOURNALS.length} ENTRIES TO REVIEW</div>
      <div style={card}>
        {JOURNALS.map((j, i) => (
          <div key={j.id} onClick={() => onOpen && onOpen(j)} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 16px', position: 'relative', cursor: 'pointer' }}>
            <div style={{ width: 34, height: 34, borderRadius: 10, background: j.balanced ? (dark ? 'rgba(4,120,87,0.18)' : EMERALD_SOFT) : '#fee2e2', flexShrink: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="17" height="17" viewBox="0 0 17 17" fill="none">{j.balanced
                ? <path d="M3 9l3.5 3.5L14 4.5" stroke={EMERALD} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
                : <path d="M8.5 4v5.5M8.5 12v.5" stroke="#dc2626" strokeWidth="2" strokeLinecap="round"/>}</svg>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: SF, fontSize: 15.5, fontWeight: 600, color: dark ? D_INK : INK, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{j.desc}</div>
              <div style={{ fontFamily: SF, fontSize: 12.5, color: j.balanced ? (dark ? D_SEC : SEC) : RED, fontWeight: j.balanced ? 400 : 600 }}>J-{j.id} · {j.type} · {j.balanced ? j.date : 'Debits ≠ credits'}</div>
            </div>
            <div style={{ fontFamily: SF, fontSize: 15.5, fontWeight: 600, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums', flexShrink: 0 }}>{money(j.amount)}</div>
            <svg width="8" height="13" viewBox="0 0 8 13" style={{ marginLeft: 4 }}><path d="M1 1l6 6-6 6" stroke={dark ? D_SEP : 'rgba(60,60,67,0.3)'} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
            {i < JOURNALS.length - 1 && <div style={{ position: 'absolute', bottom: 0, left: 62, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />}
          </div>
        ))}
      </div>

      {/* sticky book-all */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: '12px 16px 30px',
        backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
        background: dark ? 'rgba(20,20,22,0.8)' : 'rgba(242,242,247,0.8)', borderTop: `0.5px solid ${dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.06)'}` }}>
        <button style={primaryBtn}>Book {JOURNALS.length - unbalanced} balanced entries</button>
        <div style={{ fontFamily: SF, fontSize: 12, color: dark ? D_SEC : SEC, textAlign: 'center', marginTop: 8 }}>{unbalanced} unbalanced entry skipped · requires Face ID</div>
      </div>
    </Screen>
  );
}

function JournalDetail({ dark, onBack, journal }) {
  const j = journal;
  const totalDr = j.lines.reduce((a, l) => a + l.dr, 0);
  const totalCr = j.lines.reduce((a, l) => a + l.cr, 0);
  const balanced = Math.abs(totalDr - totalCr) < 0.005;
  const card = { background: dark ? D_CARD : '#fff', borderRadius: 16, margin: '0 16px', overflow: 'hidden', boxShadow: dark ? 'none' : '0 1px 3px rgba(0,0,0,0.06)' };
  return (
    <Screen dark={dark} noChrome scrollPad={130}>
      <div style={{ padding: '54px 16px 6px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div onClick={onBack} style={{ display: 'flex', alignItems: 'center', gap: 3, cursor: 'pointer' }}>
          <svg width="11" height="18" viewBox="0 0 11 18"><path d="M9 1L2 9l7 8" stroke={EMERALD} strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
          <span style={{ fontFamily: SF, fontSize: 17, color: EMERALD }}>Booking</span>
        </div>
        <StatusChip color="#92400e" bg="#fef3c7">Open</StatusChip>
      </div>
      <div style={{ textAlign: 'center', padding: '10px 20px 16px' }}>
        <div style={{ fontFamily: SF, fontSize: 12.5, fontWeight: 600, color: dark ? D_SEC : SEC, letterSpacing: 0.3 }}>J-{j.id} · {j.type.toUpperCase()}</div>
        <div style={{ fontFamily: SF, fontSize: 22, fontWeight: 700, color: dark ? D_INK : INK, marginTop: 4 }}>{j.desc}</div>
        <div style={{ fontFamily: SF, fontSize: 14, color: dark ? D_SEC : SEC }}>{j.date}</div>
      </div>

      <div style={{ fontFamily: SF, fontSize: 13, color: dark ? D_SEC : SEC, padding: '0 20px 7px', letterSpacing: 0.2 }}>JOURNAL LINES</div>
      <div style={{ ...card, marginBottom: 14 }}>
        <div style={{ display: 'flex', padding: '8px 16px', background: dark ? 'rgba(255,255,255,0.03)' : '#fafafa' }}>
          <span style={{ flex: 1, fontFamily: SF, fontSize: 11.5, fontWeight: 600, color: dark ? D_SEC : SEC, letterSpacing: 0.4 }}>ACCOUNT</span>
          <span style={{ width: 78, textAlign: 'right', fontFamily: SF, fontSize: 11.5, fontWeight: 600, color: dark ? D_SEC : SEC, letterSpacing: 0.4 }}>DEBIT</span>
          <span style={{ width: 78, textAlign: 'right', fontFamily: SF, fontSize: 11.5, fontWeight: 600, color: dark ? D_SEC : SEC, letterSpacing: 0.4 }}>CREDIT</span>
        </div>
        {j.lines.map((l, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', padding: '11px 16px', position: 'relative' }}>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: SF, fontSize: 14.5, color: dark ? D_INK : INK, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{l.name}</div>
              <div style={{ fontFamily: SF, fontSize: 12, color: EMERALD, fontVariantNumeric: 'tabular-nums' }}>{l.acct}</div>
            </div>
            <span style={{ width: 78, textAlign: 'right', fontFamily: SF, fontSize: 14, color: l.dr ? (dark ? D_INK : INK) : (dark ? D_SEP : '#cbd5e1'), fontVariantNumeric: 'tabular-nums' }}>{l.dr ? money(l.dr) : '—'}</span>
            <span style={{ width: 78, textAlign: 'right', fontFamily: SF, fontSize: 14, color: l.cr ? (dark ? D_INK : INK) : (dark ? D_SEP : '#cbd5e1'), fontVariantNumeric: 'tabular-nums' }}>{l.cr ? money(l.cr) : '—'}</span>
            <div style={{ position: 'absolute', bottom: 0, left: 16, right: 0, height: 0.5, background: dark ? D_SEP : SEP }} />
          </div>
        ))}
        <div style={{ display: 'flex', alignItems: 'center', padding: '11px 16px', background: dark ? 'rgba(255,255,255,0.03)' : '#fafafa' }}>
          <span style={{ flex: 1, fontFamily: SF, fontSize: 14, fontWeight: 700, color: dark ? D_INK : INK }}>Totals</span>
          <span style={{ width: 78, textAlign: 'right', fontFamily: SF, fontSize: 14, fontWeight: 700, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums' }}>{money(totalDr)}</span>
          <span style={{ width: 78, textAlign: 'right', fontFamily: SF, fontSize: 14, fontWeight: 700, color: dark ? D_INK : INK, fontVariantNumeric: 'tabular-nums' }}>{money(totalCr)}</span>
        </div>
      </div>

      <div style={{ display: 'flex', alignItems: 'center', gap: 9, margin: '0 20px' }}>
        <svg width="16" height="16" viewBox="0 0 16 16" fill="none">{balanced
          ? <path d="M3 8l3 3 7-7" stroke={EMERALD} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
          : <path d="M8 3v6M8 12v.5" stroke="#dc2626" strokeWidth="2" strokeLinecap="round"/>}</svg>
        <span style={{ fontFamily: SF, fontSize: 13, color: balanced ? EMERALD : RED, fontWeight: 600 }}>{balanced ? 'Debits and credits balance' : `Out of balance by ${money(Math.abs(totalDr - totalCr))}`}</span>
      </div>

      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, padding: '12px 16px 30px',
        backdropFilter: 'blur(20px)', WebkitBackdropFilter: 'blur(20px)',
        background: dark ? 'rgba(20,20,22,0.8)' : 'rgba(242,242,247,0.8)', borderTop: `0.5px solid ${dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.06)'}` }}>
        {balanced ? (
          <>
            <button style={primaryBtn}>Book journal</button>
            <button style={{ width: '100%', padding: '13px', marginTop: 8, background: 'transparent', color: EMERALD, border: 'none', fontFamily: SF, fontSize: 16, fontWeight: 600, cursor: 'pointer' }}>Edit lines</button>
          </>
        ) : (
          <button style={{ ...primaryBtn, background: '#94a3b8' }}>Fix balance to book</button>
        )}
      </div>
    </Screen>
  );
}

/* ---------- demo-bound wrappers for the static canvas ---------- */
function TxnDetailDemo({ dark }) { return <TxnDetail t={TXNS[0]} dark={dark} onBack={() => {}} />; }

Object.assign(window, {
  DashboardA, DashboardB, DashboardC, ActivityScreen, MoreScreen, PayablesScreen, ReceivablesScreen, BankingScreen, AccountsScreen, SettingsScreen, JournalBookingScreen, JournalDetail, BillDetail, InvoiceDetail, TxnDetail, TxnDetailDemo, CaptureCamera, CaptureReview,
});
