// Interactive prototype shell — wires the NobleLedger iOS kit together.
// Default nav = direction 1d (2-tab companion app around Capture).
// Login = direction 1e (branded emerald/slate, remembered workspace, Face ID).
// Depends on globals from ios-frame.jsx + noble-ios-app.jsx.

const { IOSDevice, DashboardA, ActivityScreen, MoreScreen, PayablesScreen, ReceivablesScreen, BankingScreen, AccountsScreen, SettingsScreen, JournalBookingScreen, JournalDetail, BillDetail, InvoiceDetail, TxnDetail, CaptureCamera, CaptureReview } = window;
const SF = '-apple-system, "SF Pro Text", system-ui, sans-serif';
const EMERALD = '#047857';

/* ---------- Login — direction 1e ---------- */
function Login1e({ onLogin }) {
  const field = (label) => (
    <div style={{ background: 'rgba(255,255,255,0.07)', border: '1px solid rgba(255,255,255,0.13)', borderRadius: 12, padding: '13px 14px', fontSize: 15, color: '#94a3b8' }}>{label}</div>
  );
  return (
    <div style={{ height: '100%', background: 'linear-gradient(165deg,#0f172a 0%,#123f33 55%,#065f46 130%)', position: 'relative', fontFamily: SF, display: 'flex', flexDirection: 'column', padding: '0 24px', boxSizing: 'border-box' }}>
      <div style={{ flex: 1.1 }} />
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 14 }}>
        <div style={{ width: 64, height: 64, border: '2px solid #475569', borderRadius: 14, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'rgba(15,23,42,0.5)' }}>
          <img src="assets/logo.svg" alt="Noble Ledger" style={{ width: 40, height: 40 }} />
        </div>
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: 30, fontWeight: 700, color: '#fff', letterSpacing: 0.2 }}>Noble Ledger</div>
          <div style={{ fontSize: 14, color: '#94a3b8', marginTop: 3 }}>Accounting for condominium corporations</div>
        </div>
      </div>
      <div style={{ height: 28 }} />
      <div style={{ display: 'flex', alignItems: 'center', gap: 10, background: 'rgba(255,255,255,0.07)', border: '1px solid rgba(255,255,255,0.13)', borderRadius: 12, padding: '11px 14px' }}>
        <svg width="17" height="17" viewBox="0 0 17 17" fill="none"><path d="M2.5 14.5v-11a1 1 0 011-1h6a1 1 0 011 1v11M4.8 5.3h1.5M4.8 8h1.5M4.8 10.7h1.5M10.5 8h3a1 1 0 011 1v5.5M2 14.5h13.5" stroke="#6ee7b7" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round"/></svg>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 11, color: '#94a3b8' }}>Workspace</div>
          <div style={{ fontSize: 15, fontWeight: 600, color: '#fff' }}>Brookline Grove Condo Corp</div>
        </div>
        <span style={{ fontSize: 13, fontWeight: 600, color: '#6ee7b7' }}>Change</span>
      </div>
      <div style={{ height: 12 }} />
      <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
        {field('Email address')}
        <div style={{ display: 'flex', alignItems: 'center', background: 'rgba(255,255,255,0.07)', border: '1px solid rgba(255,255,255,0.13)', borderRadius: 12, padding: '13px 14px' }}>
          <span style={{ flex: 1, fontSize: 15, color: '#94a3b8' }}>Password</span>
          <svg width="18" height="13" viewBox="0 0 18 13" fill="none"><path d="M1 6.5S4 1.5 9 1.5 17 6.5 17 6.5 14 11.5 9 11.5 1 6.5 1 6.5z" stroke="#64748b" strokeWidth="1.4"/><circle cx="9" cy="6.5" r="2.2" stroke="#64748b" strokeWidth="1.4"/></svg>
        </div>
      </div>
      <div style={{ height: 16 }} />
      <div onClick={onLogin} style={{ textAlign: 'center', padding: '14px 0', borderRadius: 12, background: '#059669', color: '#fff', fontSize: 16, fontWeight: 600, cursor: 'pointer' }}>Log In</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 0' }}>
        <div style={{ flex: 1, height: 1, background: 'rgba(255,255,255,0.18)' }} />
        <span style={{ fontSize: 12, color: 'rgba(255,255,255,0.55)' }}>or</span>
        <div style={{ flex: 1, height: 1, background: 'rgba(255,255,255,0.18)' }} />
      </div>
      <div onClick={onLogin} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, padding: '13px 0', borderRadius: 12, background: '#fff', cursor: 'pointer' }}>
        <svg width="14" height="17" viewBox="0 0 14 17" fill="#000"><path d="M11.6 9c0-2 1.7-3 1.8-3.1-1-1.4-2.5-1.6-3-1.6-1.3-.1-2.5.7-3.1.7-.6 0-1.6-.7-2.7-.7C3.2 4.3 1.9 5.1 1.2 6.4c-1.4 2.4-.4 6 1 8 .7 1 1.5 2 2.5 2 1 0 1.4-.6 2.6-.6s1.6.6 2.7.6 1.8-1 2.5-2c.8-1.1 1.1-2.2 1.1-2.3 0 0-2-.8-2-3.1zM9.6 2.9c.5-.7.9-1.6.8-2.5-.8 0-1.7.5-2.3 1.2-.5.6-1 1.5-.8 2.4.9.1 1.8-.4 2.3-1.1z"/></svg>
        <span style={{ fontSize: 15, fontWeight: 600, color: '#000' }}>Sign in with Apple</span>
      </div>
      <div style={{ height: 18 }} />
      <div onClick={onLogin} style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, cursor: 'pointer' }}>
        <svg width="22" height="22" viewBox="0 0 22 22" fill="none"><path d="M2.5 6.5v-2a2 2 0 012-2h2M15.5 2.5h2a2 2 0 012 2v2M19.5 15.5v2a2 2 0 01-2 2h-2M6.5 19.5h-2a2 2 0 01-2-2v-2M7.5 8v1.5M14.5 8v1.5M8 14s1.2 1.2 3 1.2 3-1.2 3-1.2M11 8.5v3.5h-1" stroke="#6ee7b7" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"/></svg>
        <span style={{ fontSize: 14, fontWeight: 600, color: '#6ee7b7' }}>Unlock with Face ID</span>
      </div>
      <div style={{ flex: 1 }} />
      <div style={{ textAlign: 'center', fontSize: 11, color: '#64748b', paddingBottom: 12 }}>v0.0.4.66</div>
    </div>
  );
}

/* ---------- App shell ---------- */
function NobleApp() {
  const [view, setView] = React.useState('login');     // login | app
  const [tab, setTab] = React.useState('dashboard');    // dashboard | activity
  const [capture, setCapture] = React.useState(null);   // null | camera | review
  const [txn, setTxn] = React.useState(null);
  const [route, setRoute] = React.useState(null);       // null | payables | receivables | banking | accounts | settings
  const [doc, setDoc] = React.useState(null);           // null | {kind:'bill'|'invoice', item}
  const [drafts, setDrafts] = React.useState([]);       // captured draft payables
  const [justCaptured, setJustCaptured] = React.useState(false);

  const finishCapture = () => {
    const draft = { id: 'd' + Date.now(), vendor: 'Hydro One', inv: 'AP-1926', due: 'Due in 11 days', amount: 4105.22, status: 'draft' };
    setDrafts(d => [draft, ...d]);
    setCapture(null);
    setJustCaptured(true);
    setTab('dashboard');
    setRoute('payables');
  };

  let content, dark = false;

  if (view === 'login') {
    content = <Login1e onLogin={() => setView('app')} />;
    dark = true;
  } else if (capture === 'camera') {
    content = <CaptureCamera onCapture={() => setCapture('review')} onClose={() => setCapture(null)} />;
    dark = true;
  } else if (capture === 'review') {
    content = <CaptureReview onBack={() => setCapture('camera')} onDone={finishCapture} />;
  } else if (doc && doc.kind === 'journal') {
    content = <JournalDetail journal={doc.item} onBack={() => setDoc(null)} />;
  } else if (doc && doc.kind === 'bill') {
    content = <BillDetail bill={doc.item} onBack={() => setDoc(null)} />;
  } else if (doc && doc.kind === 'invoice') {
    content = <InvoiceDetail invoice={doc.item} onBack={() => setDoc(null)} />;
  } else if (route === 'payables') {
    content = <PayablesScreen extra={drafts} banner={justCaptured ? 'Draft payable created from your captured invoice.' : null} onBack={() => { setRoute(null); setJustCaptured(false); }} onOpen={(b) => setDoc({ kind: 'bill', item: b })} />;
  } else if (route === 'receivables') {
    content = <ReceivablesScreen onBack={() => setRoute(null)} onOpen={(r) => setDoc({ kind: 'invoice', item: r })} />;
  } else if (route === 'banking') {
    content = <BankingScreen onBack={() => setRoute(null)} />;
  } else if (route === 'accounts') {
    content = <AccountsScreen onBack={() => setRoute(null)} />;
  } else if (route === 'settings') {
    content = <SettingsScreen onBack={() => setRoute(null)} onLogout={() => { setRoute(null); setTab('dashboard'); setView('login'); }} />;
  } else if (route === 'journals') {
    content = <JournalBookingScreen onBack={() => setRoute(null)} onOpen={(j) => setDoc({ kind: 'journal', item: j })} />;
  } else if (txn) {
    content = <TxnDetail t={txn} onBack={() => setTxn(null)} />;
  } else if (tab === 'activity') {
    content = <ActivityScreen onCapture={() => setCapture('camera')} onTxn={setTxn} onNav={setTab} />;
  } else if (tab === 'more') {
    content = <MoreScreen onCapture={() => setCapture('camera')} onNav={setTab} onTxn={setTxn} onPayables={() => setRoute('payables')} onReceivables={() => setRoute('receivables')} onBanking={() => setRoute('banking')} onAccounts={() => setRoute('accounts')} onSettings={() => setRoute('settings')} onJournals={() => setRoute('journals')} />;
  } else {
    content = <DashboardA onCapture={() => setCapture('camera')} onTxn={setTxn} onNav={setTab} />;
  }

  return <IOSDevice dark={dark}>{content}</IOSDevice>;
}

window.NobleApp = NobleApp;
