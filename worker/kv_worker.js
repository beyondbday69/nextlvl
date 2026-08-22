const ADMIN_HTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
<title>Lulilolo · Admin</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&family=JetBrains+Mono:wght@400;500;600;700&display=swap" rel="stylesheet">
<style>
*{margin:0;padding:0;box-sizing:border-box;-webkit-tap-highlight-color:transparent}
:root{
  --bg-0:#040406;
  --glass:rgba(255,255,255,.05);
  --glass-hi:rgba(255,255,255,.09);
  --glass-border:rgba(255,255,255,.12);
  --glass-border-hi:rgba(255,255,255,.24);
  --blue:#0a84ff;
  --blue-2:#64d2ff;
  --violet:#7c5cff;
  --mint:#30d5c8;
  --pink:#ff6482;
  --green:#32d74b;
  --red:#ff375f;
  --orange:#ff9f0a;
  --text:#f5f5f7;
  --text-dim:#9a9aa2;
  --text-faint:#5b5b62;
  --r-lg:24px;
  --r-md:16px;
  --r-sm:11px;
  --spring:cubic-bezier(.34,1.56,.64,1);
  --ease:cubic-bezier(.16,1,.3,1);
}
html,body{height:100%}
body{
  font-family:'Inter',-apple-system,BlinkMacSystemFont,'SF Pro Display',sans-serif;
  background:var(--bg-0);
  color:var(--text);
  min-height:100vh;
  -webkit-font-smoothing:antialiased;
  overflow-x:hidden;
  position:relative;
}

/* ---------- Ambient aurora background ---------- */
.aurora{position:fixed;inset:-10%;z-index:0;pointer-events:none;filter:blur(100px) saturate(160%);opacity:.6}
.aurora span{position:absolute;border-radius:50%;mix-blend-mode:screen}
.aurora span:nth-child(1){width:48vw;height:48vw;top:-14%;left:-10%;background:radial-gradient(circle,var(--blue) 0%,transparent 70%);animation:drift1 24s ease-in-out infinite}
.aurora span:nth-child(2){width:40vw;height:40vw;bottom:-16%;right:-8%;background:radial-gradient(circle,var(--mint) 0%,transparent 70%);animation:drift2 30s ease-in-out infinite}
.aurora span:nth-child(3){width:32vw;height:32vw;top:35%;left:52%;background:radial-gradient(circle,var(--violet) 0%,transparent 70%);animation:drift3 20s ease-in-out infinite}
.aurora span:nth-child(4){width:26vw;height:26vw;top:65%;left:10%;background:radial-gradient(circle,var(--pink) 0%,transparent 70%);animation:drift2 28s ease-in-out infinite reverse;opacity:.5}
@keyframes drift1{0%,100%{transform:translate(0,0) scale(1)}50%{transform:translate(7vw,9vh) scale(1.18)}}
@keyframes drift2{0%,100%{transform:translate(0,0) scale(1)}50%{transform:translate(-8vw,-6vh) scale(1.12)}}
@keyframes drift3{0%,100%{transform:translate(0,0) scale(1)}50%{transform:translate(-6vw,7vh) scale(.88)}}
.grain{position:fixed;inset:0;z-index:1;pointer-events:none;opacity:.03;background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='120' height='120'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E")}
.vignette{position:fixed;inset:0;z-index:1;pointer-events:none;background:radial-gradient(120% 100% at 50% 0%,transparent 40%,rgba(0,0,0,.35) 100%)}

/* ---------- Progress bar (top) ---------- */
.topload{position:fixed;top:0;left:0;height:2.5px;width:0;z-index:400;background:linear-gradient(90deg,var(--blue),var(--mint));box-shadow:0 0 12px var(--blue-2);transition:width .3s var(--ease),opacity .3s var(--ease)}
.topload.active{width:70%}
.topload.done{width:100%;opacity:0}

/* ---------- Glass primitives ---------- */
.glass{
  --mx:50%; --my:50%;
  background:var(--glass);
  border:1px solid var(--glass-border);
  backdrop-filter:blur(30px) saturate(190%);
  -webkit-backdrop-filter:blur(30px) saturate(190%);
  border-radius:var(--r-lg);
  box-shadow:0 24px 70px rgba(0,0,0,.55), inset 0 1px 0 rgba(255,255,255,.09);
  position:relative;
  transition:transform .35s var(--ease), box-shadow .35s var(--ease), border-color .35s var(--ease);
}
.glass::before{
  content:'';position:absolute;inset:0;border-radius:inherit;padding:1px;
  background:linear-gradient(160deg,rgba(255,255,255,.2),rgba(255,255,255,0) 45%);
  -webkit-mask:linear-gradient(#000 0 0) content-box,linear-gradient(#000 0 0);
  -webkit-mask-composite:xor;mask-composite:exclude;pointer-events:none;
}
.glass::after{
  content:'';position:absolute;inset:0;border-radius:inherit;opacity:0;pointer-events:none;
  background:radial-gradient(380px circle at var(--mx) var(--my),rgba(255,255,255,.14),transparent 68%);
  transition:opacity .4s var(--ease);
}
.glass:hover::after{opacity:1}
.glass.lift:hover{transform:translateY(-3px);box-shadow:0 30px 80px rgba(0,0,0,.6), inset 0 1px 0 rgba(255,255,255,.1)}

/* ---------- Login ---------- */
.login-wrap{position:relative;z-index:2;display:flex;align-items:center;justify-content:center;min-height:100vh;padding:24px}
.login-card{width:100%;max-width:390px;padding:40px 34px 32px;text-align:center;animation:riseIn .7s var(--ease) both}
@keyframes riseIn{from{opacity:0;transform:translateY(24px) scale(.96)}to{opacity:1;transform:translateY(0) scale(1)}}
.login-icon{width:60px;height:60px;margin:0 auto 20px;border-radius:18px;display:flex;align-items:center;justify-content:center;position:relative;
  background:linear-gradient(145deg,var(--blue),var(--violet));box-shadow:0 10px 28px rgba(10,132,255,.5), inset 0 1px 0 rgba(255,255,255,.35);
  animation:iconFloat 4.5s ease-in-out infinite}
.login-icon::after{content:'';position:absolute;inset:-8px;border-radius:24px;border:1px solid rgba(10,132,255,.35);animation:pulseRing 2.6s ease-out infinite}
@keyframes pulseRing{0%{transform:scale(.85);opacity:.9}100%{transform:scale(1.35);opacity:0}}
@keyframes iconFloat{0%,100%{transform:translateY(0) rotate(0)}50%{transform:translateY(-6px) rotate(-4deg)}}
.login-icon svg{width:28px;height:28px;position:relative;z-index:1}
.login-card h1{font-size:1.6rem;font-weight:800;letter-spacing:-.02em;margin-bottom:4px;
  background:linear-gradient(135deg,#fff,#b8c6ff);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.login-card p{color:var(--text-dim);font-size:.85rem;margin-bottom:26px;font-weight:500}
.field{position:relative;margin-bottom:14px;text-align:left}
input[type=password],input[type=text],input[type=number]{
  width:100%;padding:14px 16px;background:rgba(255,255,255,.05);border:1px solid var(--glass-border);
  border-radius:var(--r-md);color:var(--text);font-size:.92rem;outline:none;font-family:inherit;
  transition:border-color .2s var(--ease), background .2s var(--ease), box-shadow .2s var(--ease);
}
input::placeholder{color:var(--text-faint)}
input:focus{border-color:var(--blue);background:rgba(10,132,255,.08);box-shadow:0 0 0 4px rgba(10,132,255,.16)}
input[readonly]{cursor:default}
.field.has-eye input{padding-right:44px}
.eye-btn{position:absolute;right:6px;top:50%;transform:translateY(-50%);width:32px;height:32px;border:none;background:transparent;color:var(--text-faint);cursor:pointer;display:flex;align-items:center;justify-content:center;border-radius:8px;transition:.15s}
.eye-btn:hover{color:var(--text);background:rgba(255,255,255,.07)}
.eye-btn svg{width:16px;height:16px}
.shake{animation:shake .4s}
@keyframes shake{20%,60%{transform:translateX(-8px)}40%,80%{transform:translateX(8px)}100%{transform:translateX(0)}}

.remember-row{display:flex;align-items:center;justify-content:space-between;margin-bottom:6px;padding:2px 2px}
.remember-row span{font-size:.83rem;color:var(--text-dim);font-weight:500}

/* ---------- iOS toggle switch ---------- */
.toggle{position:relative;display:inline-flex;align-items:center;cursor:pointer;user-select:none}
.toggle input{position:absolute;opacity:0;width:0;height:0}
.toggle .track{width:42px;height:25px;border-radius:999px;background:rgba(255,255,255,.14);border:1px solid var(--glass-border);position:relative;transition:background .25s var(--ease),border-color .25s}
.toggle .thumb{position:absolute;top:2px;left:2px;width:19px;height:19px;background:#fff;border-radius:50%;box-shadow:0 2px 6px rgba(0,0,0,.35);transition:transform .3s var(--spring)}
.toggle input:checked + .track{background:linear-gradient(135deg,var(--blue),var(--violet));border-color:transparent}
.toggle input:checked + .track .thumb{transform:translateX(17px)}

/* ---------- Stepper widget ---------- */
.stepper{display:flex;align-items:center;gap:0;background:rgba(255,255,255,.05);border:1px solid var(--glass-border);border-radius:var(--r-md);overflow:hidden}
.stepper input{border:none!important;background:transparent!important;text-align:center;box-shadow:none!important;border-radius:0!important;flex:1;font-weight:700;font-variant-numeric:tabular-nums}
.step-btn{width:44px;height:46px;flex-shrink:0;border:none;background:transparent;color:var(--text-dim);font-size:1.2rem;font-weight:600;cursor:pointer;transition:background .15s,color .15s;display:flex;align-items:center;justify-content:center}
.step-btn:hover{background:rgba(255,255,255,.08);color:var(--text)}
.step-btn:active{background:rgba(10,132,255,.18);color:var(--blue-2)}

/* ---------- Buttons ---------- */
.btn{
  appearance:none;border:none;cursor:pointer;font-family:inherit;font-weight:600;font-size:.86rem;
  padding:11px 20px;border-radius:999px;color:var(--text);position:relative;overflow:hidden;
  transition:transform .16s var(--spring), box-shadow .25s var(--ease), background .25s var(--ease), opacity .2s, color .2s;
  display:inline-flex;align-items:center;justify-content:center;gap:6px;white-space:nowrap;
}
.btn:active{transform:scale(.94)}
.btn:disabled{opacity:.5;pointer-events:none}
.btn-primary{width:100%;margin-top:6px;padding:15px;background:linear-gradient(135deg,var(--blue),var(--violet));box-shadow:0 12px 32px rgba(10,132,255,.4)}
.btn-primary:hover{box-shadow:0 14px 38px rgba(10,132,255,.55);transform:translateY(-1px)}
.btn.loading{color:transparent;pointer-events:none}
.btn.loading::after{content:'';position:absolute;width:17px;height:17px;border:2.5px solid rgba(255,255,255,.35);border-top-color:#fff;border-radius:50%;animation:spin .7s linear infinite}
@keyframes spin{to{transform:rotate(360deg)}}
.btn-success{background:rgba(50,215,75,.14);color:var(--green);border:1px solid rgba(50,215,75,.26)}
.btn-success:hover{background:rgba(50,215,75,.24)}
.btn-danger{background:rgba(255,55,95,.13);color:var(--red);border:1px solid rgba(255,55,95,.24)}
.btn-danger:hover{background:rgba(255,55,95,.24)}
.btn-warning{background:rgba(255,159,10,.14);color:var(--orange);border:1px solid rgba(255,159,10,.26)}
.btn-warning:hover{background:rgba(255,159,10,.24)}
.btn-flat{background:rgba(10,132,255,.13);color:var(--blue-2);border:1px solid rgba(10,132,255,.22)}
.btn-flat:hover{background:rgba(10,132,255,.24)}
.btn-mint{background:rgba(48,213,200,.14);color:var(--mint);border:1px solid rgba(48,213,200,.26)}
.btn-mint:hover{background:rgba(48,213,200,.24)}
.btn-ghost{background:rgba(255,255,255,.05);color:var(--text-dim);padding:11px 18px;border:1px solid var(--glass-border)}
.btn-ghost:hover{color:var(--text);background:rgba(255,255,255,.09)}
.btn-tg{background:linear-gradient(135deg,#2aabee,#229ed9);color:#fff;box-shadow:0 8px 24px rgba(34,158,217,.45)}
.btn-tg:hover{box-shadow:0 12px 30px rgba(34,158,217,.6);transform:translateY(-1px)}
.btn-sm{padding:7px 14px;font-size:.78rem}
.btn-icon{width:36px;height:36px;padding:0;border-radius:11px;background:rgba(255,255,255,.06);border:1px solid var(--glass-border);color:var(--text-dim)}
.btn-icon:hover{color:#fff;background:rgba(10,132,255,.18);border-color:rgba(10,132,255,.3)}
.btn svg{width:14px;height:14px;flex-shrink:0}
.ripple{position:absolute;border-radius:50%;background:rgba(255,255,255,.5);transform:scale(0);animation:rippleAnim .6s var(--ease) forwards;pointer-events:none}
@keyframes rippleAnim{to{transform:scale(2.8);opacity:0}}

.error{color:var(--red);font-size:.82rem;margin-top:4px;margin-bottom:10px;font-weight:500;text-align:left}
.hidden{display:none!important}

/* ---------- Dashboard shell ---------- */
.dash{position:relative;z-index:2;max-width:1120px;margin:0 auto;padding:32px 18px 60px;animation:riseIn .55s var(--ease) both}
.dash-header{display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:26px;gap:12px;flex-wrap:wrap}
.dash-title{display:flex;align-items:center;gap:14px}
.dash-badge{width:48px;height:48px;border-radius:15px;background:linear-gradient(145deg,var(--blue),var(--violet));display:flex;align-items:center;justify-content:center;box-shadow:0 8px 22px rgba(10,132,255,.45);position:relative}
.dash-badge::after{content:'';position:absolute;inset:-6px;border-radius:19px;border:1px solid rgba(10,132,255,.3);animation:pulseRing 3s ease-out infinite}
.dash-badge svg{width:22px;height:22px;position:relative;z-index:1}
.dash-header h1{font-size:1.7rem;font-weight:800;letter-spacing:-.03em;line-height:1.1;
  background:linear-gradient(135deg,#fff,#c2cfff);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.dash-header .eyebrow{display:flex;align-items:center;gap:6px;color:var(--text-dim);font-size:.74rem;font-weight:600;text-transform:uppercase;letter-spacing:.09em;margin-top:2px}
.live-dot{width:6px;height:6px;border-radius:50%;background:var(--green);box-shadow:0 0 8px var(--green);animation:livePulse 2s ease-in-out infinite}
@keyframes livePulse{0%,100%{opacity:1}50%{opacity:.35}}

/* ---------- Stats / iOS Widgets ---------- */
.stats{display:grid;grid-template-columns:repeat(6,1fr);gap:12px;margin-bottom:22px}
.stat{padding:16px 16px 15px;display:flex;flex-direction:column;gap:10px;min-height:98px;justify-content:space-between}
.stat .wtop{display:flex;align-items:center;justify-content:space-between}
.stat .wico{width:26px;height:26px;border-radius:8px;display:flex;align-items:center;justify-content:center;flex-shrink:0}
.stat .wico svg{width:13px;height:13px}
.stat .n{font-size:1.55rem;font-weight:800;letter-spacing:-.02em;font-variant-numeric:tabular-nums;line-height:1}
.stat .l{font-size:.68rem;color:var(--text-dim);font-weight:600;text-transform:uppercase;letter-spacing:.06em;margin-top:3px}
.stat.dot-blue .n{color:var(--blue-2);text-shadow:0 0 18px rgba(100,210,255,.5)}
.stat.dot-blue .wico{background:rgba(100,210,255,.14);color:var(--blue-2)}
.stat.dot-green .n{color:var(--green);text-shadow:0 0 18px rgba(50,215,75,.5)}
.stat.dot-green .wico{background:rgba(50,215,75,.14);color:var(--green)}
.stat.dot-red .n{color:var(--red);text-shadow:0 0 18px rgba(255,55,95,.5)}
.stat.dot-red .wico{background:rgba(255,55,95,.14);color:var(--red)}
.stat.dot-mint .n{color:var(--mint);text-shadow:0 0 18px rgba(48,213,200,.5)}
.stat.dot-mint .wico{background:rgba(48,213,200,.14);color:var(--mint)}
.stat.dot-violet .n{color:var(--violet);text-shadow:0 0 18px rgba(124,92,255,.5)}
.stat.dot-violet .wico{background:rgba(124,92,255,.14);color:var(--violet)}
.ring-stat{display:flex;flex-direction:row;align-items:center;gap:12px;justify-content:flex-start}
.ring-wrap{position:relative;width:44px;height:44px;flex-shrink:0}
.ring-svg{transform:rotate(-90deg);width:44px;height:44px}
.ring-bg{fill:none;stroke:rgba(255,255,255,.1);stroke-width:5}
.ring-fg{fill:none;stroke:url(#ringGrad);stroke-width:5;stroke-linecap:round;stroke-dasharray:113.1;stroke-dashoffset:113.1;transition:stroke-dashoffset 1s var(--ease)}
.ring-pct{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-size:.6rem;font-weight:800}
.ring-stat .l{margin-top:0}

/* ---------- Filter chips ---------- */
.chip-row{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:14px}
.chip-btn{padding:7px 14px;border-radius:999px;font-size:.76rem;font-weight:600;background:rgba(255,255,255,.05);
  border:1px solid var(--glass-border);color:var(--text-dim);cursor:pointer;transition:.2s var(--ease);font-family:inherit}
.chip-btn:hover{color:var(--text);background:rgba(255,255,255,.09)}
.chip-btn.active{background:linear-gradient(135deg,var(--blue),var(--violet));border-color:transparent;color:#fff;box-shadow:0 6px 16px rgba(10,132,255,.4)}

/* ---------- Bulk action bar ---------- */
.bulk-bar{display:none;align-items:center;gap:10px;justify-content:space-between;background:rgba(10,132,255,.1);
  border:1px solid rgba(10,132,255,.28);border-radius:14px;padding:11px 16px;margin-bottom:14px;flex-wrap:wrap;animation:fadeUp .3s var(--ease) both}
.bulk-bar.show{display:flex}
.bulk-bar .bulk-count{font-size:.83rem;font-weight:600;color:var(--text)}
.bulk-bar .bulk-actions{display:flex;gap:8px;flex-wrap:wrap}
.rowchk{width:17px;height:17px;accent-color:var(--blue);cursor:pointer}
.refresh-btn svg{transition:transform .5s var(--ease)}
.refresh-btn.spin svg{transform:rotate(360deg)}

/* ---------- Segmented Tabs ---------- */
.tabs{position:relative;display:flex;padding:5px;border-radius:17px;margin-bottom:22px;gap:2px}
.tab-thumb{position:absolute;top:5px;bottom:5px;left:5px;width:calc(50% - 5px);border-radius:12px;
  background:linear-gradient(135deg,var(--blue),var(--violet));box-shadow:0 6px 20px rgba(10,132,255,.45);
  transition:transform .4s var(--spring)}
.tab{flex:1;position:relative;z-index:1;padding:12px;text-align:center;border-radius:12px;cursor:pointer;
  color:var(--text-dim);font-weight:600;font-size:.88rem;transition:color .25s;border:none;background:none;font-family:inherit;
  display:flex;align-items:center;justify-content:center;gap:7px}
.tab.active{color:#fff}
.tab svg{width:16px;height:16px}
.tab-panel{display:none;animation:fadeUp .4s var(--ease) both}
.tab-panel.active{display:block}
@keyframes fadeUp{from{opacity:0;transform:translateY(10px)}to{opacity:1;transform:translateY(0)}}

/* ---------- Card ---------- */
.card{overflow:hidden}
.card-header{display:flex;justify-content:space-between;align-items:center;padding:22px 24px;border-bottom:1px solid rgba(255,255,255,.08);flex-wrap:wrap;gap:12px}
.card-header h2{font-size:1.05rem;font-weight:700;letter-spacing:-.01em;display:flex;align-items:center;gap:9px}
.card-header .chip{font-size:.68rem;font-weight:700;color:var(--text-dim);background:rgba(255,255,255,.06);border:1px solid var(--glass-border);padding:3px 9px;border-radius:20px}
.card-header .hdr-actions{display:flex;gap:8px;flex-wrap:wrap}
.card-body{padding:16px 24px 22px}

/* ---------- Search bar ---------- */
.search-bar{display:flex;align-items:center;gap:10px;background:rgba(255,255,255,.045);border:1px solid var(--glass-border);
  border-radius:var(--r-md);padding:11px 14px;margin-bottom:16px;transition:border-color .2s,background .2s}
.search-bar:focus-within{border-color:var(--blue);background:rgba(10,132,255,.06)}
.search-bar svg{width:16px;height:16px;color:var(--text-faint);flex-shrink:0}
.search-bar input{border:none;background:transparent;padding:0;font-size:.87rem}
.search-bar input:focus{box-shadow:none}

/* ---------- Table ---------- */
table{width:100%;border-collapse:collapse}
th{text-align:left;padding:12px 10px;color:var(--text-faint);font-size:.7rem;font-weight:700;text-transform:uppercase;letter-spacing:.07em;border-bottom:1px solid rgba(255,255,255,.08)}
td{padding:15px 10px;border-bottom:1px solid rgba(255,255,255,.05);vertical-align:middle;font-size:.87rem}
tr{transition:background .15s}
tbody tr{animation:rowIn .45s var(--ease) both}
@keyframes rowIn{from{opacity:0;transform:translateY(6px)}to{opacity:1;transform:translateY(0)}}
tr:hover td{background:rgba(255,255,255,.03)}
.keycell{display:flex;align-items:center;gap:8px;font-family:'JetBrains Mono',monospace;font-weight:700;color:var(--text)}
.copy-mini{width:24px;height:24px;border-radius:7px;border:none;background:rgba(255,255,255,.06);color:var(--text-faint);cursor:pointer;flex-shrink:0;display:inline-flex;align-items:center;justify-content:center;transition:.15s}
.copy-mini:hover{background:rgba(10,132,255,.18);color:var(--blue-2)}
.copy-mini svg{width:12px;height:12px}
.badge{padding:4px 11px;border-radius:20px;font-size:.72rem;font-weight:700;display:inline-flex;align-items:center;gap:5px}
.badge::before{content:'';width:6px;height:6px;border-radius:50%;background:currentColor;box-shadow:0 0 8px currentColor}
.badge-active{background:rgba(50,215,75,.13);color:var(--green)}
.badge-banned{background:rgba(255,55,95,.13);color:var(--red)}
.actions{display:flex;gap:6px;flex-wrap:wrap}
.scripts-col{max-width:150px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;color:var(--text-dim);font-size:.8rem}
.file-cell{display:flex;align-items:center;gap:9px}
.file-ico{width:30px;height:30px;flex-shrink:0;border-radius:9px;background:rgba(100,210,255,.12);color:var(--blue-2);display:flex;align-items:center;justify-content:center}
.file-ico svg{width:15px;height:15px}
.file-name{color:var(--text);font-weight:600;font-family:'JetBrains Mono',monospace;font-size:.85rem}
.file-cell{display:flex;align-items:center;gap:9px;flex-wrap:wrap}
.file-label{color:var(--blue-2);font-size:.72rem;font-weight:600;background:rgba(100,210,255,.12);padding:2px 8px;border-radius:99px;letter-spacing:.02em}
.file-size{color:var(--text-dim);font-size:.82rem;font-variant-numeric:tabular-nums}
.dcount{font-variant-numeric:tabular-nums;color:var(--text-dim)}
.dcount b{color:var(--text)}
.exp-wrap{display:flex;flex-direction:column;gap:3px}
.exp-tag{font-size:.68rem;font-weight:700;text-transform:uppercase;letter-spacing:.04em;width:fit-content;padding:1px 7px;border-radius:8px}
.exp-green{color:var(--green);background:rgba(50,215,75,.12)}
.exp-orange{color:var(--orange);background:rgba(255,159,10,.12)}
.exp-red{color:var(--red);background:rgba(255,55,95,.12)}

/* ---------- Skeleton loading ---------- */
.skel-row td{padding:15px 10px}
.skel{height:14px;border-radius:7px;background:linear-gradient(90deg,rgba(255,255,255,.06) 25%,rgba(255,255,255,.14) 37%,rgba(255,255,255,.06) 63%);background-size:400% 100%;animation:shimmer 1.4s ease infinite}
@keyframes shimmer{0%{background-position:100% 0}100%{background-position:-100% 0}}

/* ---------- Modal ---------- */
.modal-overlay{position:fixed;inset:0;background:rgba(0,0,0,.6);backdrop-filter:blur(8px);z-index:100;display:flex;align-items:center;justify-content:center;padding:20px;animation:fadeBg .25s var(--ease)}
@keyframes fadeBg{from{opacity:0}to{opacity:1}}
.modal{background:rgba(18,18,22,.92);border:1px solid var(--glass-border-hi);backdrop-filter:blur(34px) saturate(190%);
  border-radius:26px;width:100%;max-width:460px;max-height:88vh;overflow-y:auto;box-shadow:0 34px 90px rgba(0,0,0,.65);
  animation:modalIn .4s var(--spring)}
@keyframes modalIn{from{opacity:0;transform:translateY(34px) scale(.93)}to{opacity:1;transform:translateY(0) scale(1)}}
.modal.wide{max-width:780px}
.modal.narrow{max-width:380px;text-align:center}
.modal-header{padding:24px 26px 16px;font-size:1.12rem;font-weight:700;border-bottom:1px solid rgba(255,255,255,.08);letter-spacing:-.01em;display:flex;align-items:center;justify-content:space-between;gap:10px}
.modal-close{width:30px;height:30px;border-radius:10px;border:none;background:rgba(255,255,255,.06);color:var(--text-dim);cursor:pointer;display:flex;align-items:center;justify-content:center;flex-shrink:0;transition:.15s}
.modal-close:hover{background:rgba(255,55,95,.15);color:var(--red)}
.modal-close svg{width:14px;height:14px}
.modal-body{padding:22px 26px;display:flex;flex-direction:column;gap:17px}
.modal-footer{padding:17px 26px;display:flex;justify-content:flex-end;gap:10px;border-top:1px solid rgba(255,255,255,.08)}
label{font-size:.8rem;font-weight:600;color:var(--text-dim);margin-bottom:6px;display:block}
.form-group{display:flex;flex-direction:column;gap:4px}
.field-hint{font-size:.72rem;color:var(--text-faint);margin-top:2px}
textarea{width:100%;height:360px;padding:16px;background:rgba(255,255,255,.04);border:1px solid var(--glass-border);
  border-radius:var(--r-md);color:#e4e4e7;font-family:'JetBrains Mono',monospace;font-size:.84rem;resize:vertical;outline:none;line-height:1.6}
textarea:focus{border-color:var(--blue)}
.textarea-bar{display:flex;justify-content:space-between;align-items:center;margin-top:6px}
.textarea-bar .count{font-size:.72rem;color:var(--text-faint);font-variant-numeric:tabular-nums}

.checkbox-group{display:flex;flex-direction:column;gap:2px}
.checkbox-group label.main-label{font-weight:600;margin-bottom:8px;color:var(--text)}
.checkbox-item{display:flex;align-items:center;justify-content:space-between;gap:10px;cursor:pointer;padding:10px 6px;border-radius:10px;transition:background .15s}
.checkbox-item:hover{background:rgba(255,255,255,.05)}
.checkbox-item span{font-size:.87rem;font-family:'JetBrains Mono',monospace}
.empty{text-align:center;color:var(--text-faint);padding:48px 20px;font-size:.88rem}
.empty svg{width:36px;height:36px;margin:0 auto 12px;opacity:.5;display:block}

.device-row{display:flex;align-items:center;justify-content:space-between;gap:10px;background:rgba(255,255,255,.05);border:1px solid var(--glass-border);border-radius:12px;padding:11px 13px}
.device-row .did{font-family:'JetBrains Mono',monospace;font-size:.78rem;color:var(--text);word-break:break-all;flex:1}
/* Share modal specifics */
.share-key-display{display:flex;align-items:center;gap:8px;background:rgba(255,255,255,.05);border:1px solid var(--glass-border);
  border-radius:16px;padding:16px 18px}
.share-key-display span{flex:1;font-family:'JetBrains Mono',monospace;font-weight:700;font-size:1.05rem;letter-spacing:.02em;word-break:break-all}
.share-meta{display:flex;gap:20px;flex-wrap:wrap;font-size:.8rem;color:var(--text-dim);justify-content:center}
.share-meta b{color:var(--text);font-weight:600}
.share-actions{display:grid;grid-template-columns:1fr 1fr;gap:10px}
.share-actions .btn{padding:14px}
.confirm-icon{width:54px;height:54px;border-radius:16px;margin:0 auto;display:flex;align-items:center;justify-content:center}
.confirm-icon.danger{background:rgba(255,55,95,.14);color:var(--red)}
.confirm-icon svg{width:25px;height:25px}
.confirm-text{color:var(--text-dim);font-size:.88rem;line-height:1.5}
.confirm-footer{display:flex;gap:10px;justify-content:center;padding:6px 26px 26px}
.confirm-footer .btn{flex:1}

/* ---------- Toasts ---------- */
.toast-stack{position:fixed;bottom:22px;left:50%;transform:translateX(-50%);z-index:200;display:flex;flex-direction:column-reverse;gap:10px;width:min(92vw,380px);align-items:center}
.toast{width:100%;background:rgba(20,20,24,.94);border:1px solid var(--glass-border-hi);backdrop-filter:blur(26px);
  border-radius:16px;padding:13px 14px 13px 16px;display:flex;align-items:center;gap:11px;box-shadow:0 16px 44px rgba(0,0,0,.55);
  animation:toastIn .45s var(--spring);font-size:.85rem;font-weight:500;position:relative;overflow:hidden}
.toast.out{animation:toastOut .3s var(--ease) forwards}
@keyframes toastIn{from{opacity:0;transform:translateY(18px) scale(.9)}to{opacity:1;transform:translateY(0) scale(1)}}
@keyframes toastOut{to{opacity:0;transform:translateY(10px) scale(.92)}}
.toast .ico{width:22px;height:22px;border-radius:50%;flex-shrink:0;display:flex;align-items:center;justify-content:center}
.toast .ico svg{width:13px;height:13px}
.toast.success .ico{background:rgba(50,215,75,.18);color:var(--green)}
.toast.error .ico{background:rgba(255,55,95,.18);color:var(--red)}
.toast.info .ico{background:rgba(100,210,255,.18);color:var(--blue-2)}
.toast .msg{flex:1;line-height:1.35}
.toast .tclose{width:20px;height:20px;border:none;background:transparent;color:var(--text-faint);cursor:pointer;flex-shrink:0;display:flex;align-items:center;justify-content:center;border-radius:6px;transition:.15s}
.toast .tclose:hover{color:var(--text);background:rgba(255,255,255,.08)}
.toast .tclose svg{width:11px;height:11px}
.toast .tbar{position:absolute;left:0;bottom:0;height:2px;background:currentColor;opacity:.55;animation:tbarShrink 3.6s linear forwards}
.toast.success .tbar{color:var(--green)}
.toast.error .tbar{color:var(--red)}
.toast.info .tbar{color:var(--blue-2)}
@keyframes tbarShrink{from{width:100%}to{width:0%}}

/* ---------- Scrollbar ---------- */
::-webkit-scrollbar{width:7px;height:7px}
::-webkit-scrollbar-track{background:transparent}
::-webkit-scrollbar-thumb{background:rgba(255,255,255,.15);border-radius:4px}
::-webkit-scrollbar-thumb:hover{background:rgba(255,255,255,.26)}

/* ---------- Responsive: table -> cards ---------- */
@media (max-width:980px){ .stats{grid-template-columns:repeat(3,1fr)} }
@media (max-width:720px){
  .dash{padding:22px 12px 50px}
  .card-body{padding:14px 14px 18px}
  table thead{display:none}
  table, tbody, tr, td{display:block;width:100%}
  tr{background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.07);border-radius:16px;padding:14px 16px;margin-bottom:11px}
  td{border:none;padding:7px 0;display:flex;justify-content:space-between;align-items:center;gap:10px}
  td::before{content:attr(data-label);color:var(--text-faint);font-size:.7rem;font-weight:700;text-transform:uppercase;letter-spacing:.06em;flex-shrink:0}
  td.actions-row{justify-content:flex-start}
  td.actions-row::before{display:none}
  .actions{width:100%}
  .scripts-col{max-width:60%;text-align:right}
  .stats{grid-template-columns:repeat(2,1fr)}
  /* iOS-style bottom sheet modals on mobile */
  .modal-overlay{align-items:flex-end;padding:0}
  .modal{max-width:100%!important;width:100%;max-height:92vh;border-radius:26px 26px 0 0;animation:sheetUp .38s var(--spring);
    border-left:none;border-right:none;border-bottom:none;padding-top:6px}
  .modal::before{content:'';display:block;width:36px;height:4px;border-radius:3px;background:rgba(255,255,255,.22);margin:6px auto 2px}
}
@keyframes sheetUp{from{opacity:0;transform:translateY(60px)}to{opacity:1;transform:translateY(0)}}
@media (max-width:480px){
  .share-actions{grid-template-columns:1fr}
  .login-card{padding:32px 22px 26px}
  .dash-header h1{font-size:1.4rem}
  .stats{grid-template-columns:repeat(2,1fr)}
}
@media (prefers-reduced-motion:reduce){
  *{animation-duration:.01ms!important;animation-iteration-count:1!important;transition-duration:.01ms!important}
}
</style>
</head>
<body>

<div class="topload" id="topload"></div>
<div class="aurora"><span></span><span></span><span></span><span></span></div>
<div class="grain"></div>
<div class="vignette"></div>

<!-- Login -->
<div id="loginView" class="login-wrap">
  <div class="login-card glass">
    <div class="login-icon">
      <svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
    </div>
    <h1>Admin Portal</h1>
    <p>Sign in to manage keys &amp; scripts</p>
    <div class="field has-eye">
      <input type="password" id="pwdInput" placeholder="Password" autocomplete="current-password" onkeydown="if(event.key==='Enter')login()">
      <button type="button" class="eye-btn" id="eyeBtn" onclick="togglePwdVisibility()" tabindex="-1">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8Z"/><circle cx="12" cy="12" r="3"/></svg>
      </button>
    </div>
    <div class="remember-row">
      <span>Keep me signed in</span>
      <label class="toggle"><input type="checkbox" id="rememberInput"><span class="track"><span class="thumb"></span></span></label>
    </div>
    <div id="loginError" class="error hidden"></div>
    <button class="btn btn-primary" id="loginBtn" onclick="login()">Log In</button>
  </div>
</div>

<!-- Dashboard -->
<div id="dashView" class="dash hidden">
  <div class="dash-header">
    <div class="dash-title">
      <div class="dash-badge">
        <svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
      </div>
      <div>
        <h1>Lulilolo</h1>
        <div class="eyebrow"><span class="live-dot"></span>Admin Dashboard</div>
      </div>
    </div>
    <div style="display:flex;gap:8px">
      <button class="btn btn-icon refresh-btn" id="refreshBtn" onclick="refreshAll()" title="Refresh">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M23 4v6h-6M1 20v-6h6"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>
      </button>
      <button class="btn btn-ghost" onclick="logout()">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/></svg>
        Log Out
      </button>
    </div>
  </div>

  <div class="stats">
    <div class="stat glass lift dot-blue">
      <div class="wtop"><span class="wico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg></span></div>
      <div><div class="n" id="statTotal">0</div><div class="l">Total Keys</div></div>
    </div>
    <div class="stat glass lift dot-green">
      <div class="wtop"><span class="wico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg></span></div>
      <div><div class="n" id="statActive">0</div><div class="l">Active</div></div>
    </div>
    <div class="stat glass lift dot-red">
      <div class="wtop"><span class="wico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg></span></div>
      <div><div class="n" id="statBanned">0</div><div class="l">Banned</div></div>
    </div>
    <div class="stat glass lift dot-mint">
      <div class="wtop"><span class="wico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="6" width="20" height="12" rx="2"/><path d="M6 12h.01M10 12h4"/></svg></span></div>
      <div><div class="n" id="statDevices">0</div><div class="l">Devices Bound</div></div>
    </div>
    <div class="stat glass lift dot-violet">
      <div class="wtop"><span class="wico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/></svg></span></div>
      <div><div class="n" id="statScripts">0</div><div class="l">Scripts</div></div>
    </div>
    <div class="stat glass lift ring-stat">
      <div class="ring-wrap">
        <svg class="ring-svg" viewBox="0 0 44 44">
          <defs><linearGradient id="ringGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="#0a84ff"/><stop offset="100%" stop-color="#30d5c8"/>
          </linearGradient></defs>
          <circle class="ring-bg" cx="22" cy="22" r="18"></circle>
          <circle class="ring-fg" id="healthRing" cx="22" cy="22" r="18"></circle>
        </svg>
        <div class="ring-pct" id="statHealthPct">0%</div>
      </div>
      <div class="l">Health</div>
    </div>
  </div>

  <div class="tabs glass">
    <div class="tab-thumb" id="tabThumb"></div>
    <button class="tab active" onclick="switchTab('keys',this)" data-i="0">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
      User Keys
    </button>
    <button class="tab" onclick="switchTab('scripts',this)" data-i="1">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M16 13H8M16 17H8M10 9H8"/></svg>
      Lua Scripts
    </button>
  </div>

  <!-- Keys Panel -->
  <div id="panel-keys" class="tab-panel active">
    <div class="card glass">
      <div class="card-header">
        <h2>Key Management <span class="chip" id="keysCountChip">0</span></h2>
        <div class="hdr-actions">
          <button class="btn btn-success btn-sm" onclick="openKeyModal(false)">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>
            New Key
          </button>
        </div>
      </div>
      <div class="card-body">
        <div class="search-bar">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.3-4.3"/></svg>
          <input type="text" id="keySearch" placeholder="Search keys..." oninput="filterKeys()">
        </div>
        <div class="chip-row" id="keyFilterChips">
          <button class="chip-btn active" data-f="all" onclick="setKeyFilter('all',this)">All</button>
          <button class="chip-btn" data-f="active" onclick="setKeyFilter('active',this)">Active</button>
          <button class="chip-btn" data-f="banned" onclick="setKeyFilter('banned',this)">Banned</button>
          <button class="chip-btn" data-f="expiring" onclick="setKeyFilter('expiring',this)">Expiring Soon</button>
          <button class="chip-btn" data-f="lifetime" onclick="setKeyFilter('lifetime',this)">Lifetime</button>
        </div>
        <div class="bulk-bar" id="bulkBar">
          <span class="bulk-count" id="bulkCount">0 selected</span>
          <div class="bulk-actions">
            <button class="btn btn-success btn-sm" onclick="bulkAction('unban')">Unban</button>
            <button class="btn btn-warning btn-sm" onclick="bulkAction('ban')">Ban</button>
            <button class="btn btn-danger btn-sm" onclick="bulkAction('delete')">Delete</button>
            <button class="btn btn-ghost btn-sm" onclick="clearSelection()">Clear</button>
          </div>
        </div>
        <table><thead><tr>
          <th style="width:30px"><input type="checkbox" class="rowchk" id="selectAllChk" onchange="toggleSelectAll(this)"></th>
          <th>Key</th><th>Status</th><th>Devices</th><th>Expiry</th><th>Scripts</th><th>Actions</th>
        </tr></thead><tbody id="keysTable"></tbody></table>
        <div id="keysEmpty" class="empty hidden">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M21 2l-2 2m-7.61 7.61a5.5 5.5 0 1 1-7.778 7.778 5.5 5.5 0 0 1 7.777-7.777zm0 0L15.5 7.5m0 0l3 3L22 7l-3-3m-3.5 3.5L19 4"/></svg>
          No keys yet — create one to get started.
        </div>
      </div>
    </div>
  </div>

  <!-- Scripts Panel -->
  <div id="panel-scripts" class="tab-panel">
    <div class="card glass">
      <div class="card-header">
        <h2>Script Management <span class="chip" id="scriptsCountChip">0</span></h2>
        <div class="hdr-actions">
          <button class="btn btn-mint btn-sm" id="downloadAllBtn" onclick="downloadAllScripts()">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/></svg>
            Download All
          </button>
          <button class="btn btn-success btn-sm" onclick="openScriptModal()">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg>
            New Script
          </button>
        </div>
      </div>
      <div class="card-body">
        <div class="search-bar">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.3-4.3"/></svg>
          <input type="text" id="scriptSearch" placeholder="Search scripts..." oninput="filterScripts()">
        </div>
        <table><thead><tr>
          <th>Filename</th><th>Size</th><th>Actions</th>
        </tr></thead><tbody id="scriptsTable"></tbody></table>
        <div id="scriptsEmpty" class="empty hidden">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/></svg>
          No scripts yet — upload one to get started.
        </div>
      </div>
    </div>
  </div>
</div>

<!-- Key Modal -->
<div id="keyModal" class="modal-overlay hidden" onclick="if(event.target===this)closeModal('keyModal')">
  <div class="modal">
    <div class="modal-header"><span id="keyModalTitle">Create Key</span>
      <button class="modal-close" onclick="closeModal('keyModal')"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M18 6 6 18M6 6l12 12"/></svg></button>
    </div>
    <div class="modal-body">
      <div class="form-group">
        <label>Key Name</label>
        <div style="display:flex;gap:8px">
          <input type="text" id="keyNameInput" placeholder="e.g. user123" style="flex:1">
          <button type="button" class="btn-icon" id="randKeyBtn" title="Generate random name" onclick="randomizeKeyName()">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 2 2 21M2 2l19 19"/></svg>
          </button>
        </div>
      </div>
      <div class="form-group"><label>Device Limit</label>
        <div class="stepper" data-target="deviceLimitInput">
          <button type="button" class="step-btn" data-dir="-1">−</button>
          <input type="number" id="deviceLimitInput" value="1" min="1" readonly>
          <button type="button" class="step-btn" data-dir="1">+</button>
        </div>
      </div>
      <div class="form-group" id="expiryGroup">
        <label>Validity</label>
        <div class="chip-row" id="expiryPresets" style="margin-bottom:8px">
          <button type="button" class="chip-btn" data-days="1" onclick="setExpiryPreset(1,this)">1 Day</button>
          <button type="button" class="chip-btn" data-days="7" onclick="setExpiryPreset(7,this)">7 Days</button>
          <button type="button" class="chip-btn active" data-days="30" onclick="setExpiryPreset(30,this)">30 Days</button>
          <button type="button" class="chip-btn" data-days="90" onclick="setExpiryPreset(90,this)">90 Days</button>
          <button type="button" class="chip-btn" data-days="365" onclick="setExpiryPreset(365,this)">1 Year</button>
          <button type="button" class="chip-btn" data-days="lifetime" onclick="setExpiryPreset('lifetime',this)">Lifetime</button>
        </div>
        <div class="stepper" id="expiryStepper" data-target="expiryInput">
          <button type="button" class="step-btn" data-dir="-1">−</button>
          <input type="number" id="expiryInput" value="30" min="1" readonly>
          <button type="button" class="step-btn" data-dir="1">+</button>
        </div>
      </div>
      <div class="checkbox-group"><label class="main-label">Allowed Scripts</label><div id="scriptCheckboxes"></div></div>
    </div>
    <div class="modal-footer">
      <button class="btn btn-ghost" onclick="closeModal('keyModal')">Cancel</button>
      <button class="btn btn-primary" style="width:auto;margin:0" id="saveKeyBtn" onclick="saveKey()">Save Key</button>
    </div>
  </div>
</div>

<!-- Script Modal -->
<div id="scriptModal" class="modal-overlay hidden" onclick="if(event.target===this)closeModal('scriptModal')">
  <div class="modal wide">
    <div class="modal-header"><span id="scriptModalTitle">New Script</span>
      <button class="modal-close" onclick="closeModal('scriptModal')"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M18 6 6 18M6 6l12 12"/></svg></button>
    </div>
    <div class="modal-body">
      <div class="form-group"><label>Filename</label><input type="text" id="scriptNameInput" placeholder="e.g. main.lua"></div>
      <div class="form-group"><label>Label</label><input type="text" id="scriptLabelInput" placeholder="e.g. c03 skin lua"></div>
      <div class="form-group">
        <label>Lua Code</label>
        <textarea id="scriptContentInput" placeholder="print('Hello World')" spellcheck="false" oninput="updateScriptCount()"></textarea>
        <div class="textarea-bar">
          <span class="field-hint">Stored in the SCRIPTS KV. Only served via /g with a valid session. Upload encrypted chunks (.lua names) with the build tool push_chunk API.</span>
          <span class="count" id="scriptCharCount">0 chars</span>
        </div>
      </div>
    </div>
    <div class="modal-footer">
      <button class="btn btn-flat" id="downloadCurrentBtn" onclick="downloadCurrentScript()">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/></svg>
        Download
      </button>
      <button class="btn btn-ghost" onclick="closeModal('scriptModal')">Cancel</button>
      <button class="btn btn-primary" style="width:auto;margin:0" id="saveScriptBtn" onclick="saveScript()">Save Script</button>
    </div>
  </div>
</div>

<!-- Share Modal -->
<div id="shareModal" class="modal-overlay hidden" onclick="if(event.target===this)closeModal('shareModal')">
  <div class="modal narrow">
    <div class="modal-header" style="text-align:left">Share Key
      <button class="modal-close" onclick="closeModal('shareModal')"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M18 6 6 18M6 6l12 12"/></svg></button>
    </div>
    <div class="modal-body">
      <div class="share-key-display">
        <span id="shareKeyText"></span>
        <button class="btn-icon" onclick="copyShareKey()" title="Copy">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
        </button>
      </div>
      <div class="share-meta">
        <div>Expires <b id="shareKeyExpiry">—</b></div>
        <div>Devices <b id="shareKeyDevices">—</b></div>
      </div>
      <div class="share-actions">
        <button class="btn btn-tg" onclick="shareToTelegram()">
          <svg viewBox="0 0 24 24" fill="currentColor"><path d="M21.94 4.05c-.28-.24-.7-.27-1.28-.08-.6.2-16.1 6.2-16.98 6.56-.6.24-1.18.6-1.18 1.12 0 .38.28.72.98.98l4.28 1.42 1.66 5.14c.14.42.44.66.82.66.28 0 .5-.12.72-.34l2.36-2.28 4.34 3.24c.24.18.5.28.76.28.5 0 .92-.34 1.06-.94l3-13.9c.1-.5.02-1.02-.4-1.86Zm-4.5 3.3-6.9 6.3-.34 3.24-1.36-4.32L18.4 6.4c.28-.16.5.06.24.3l-1.2.65Z"/></svg>
          Telegram
        </button>
        <button class="btn btn-flat" id="nativeShareBtn" onclick="shareNative()">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="M8.6 13.5l6.8 3.9M15.4 6.6L8.6 10.5"/></svg>
          Share…
        </button>
      </div>
    </div>
    <div class="modal-footer" style="justify-content:center">
      <button class="btn btn-ghost" onclick="closeModal('shareModal')">Close</button>
    </div>
  </div>
</div>

<!-- Devices Modal -->
<div id="devicesModal" class="modal-overlay hidden" onclick="if(event.target===this)closeModal('devicesModal')">
  <div class="modal narrow">
    <div class="modal-header" style="text-align:left">Bound Devices
      <button class="modal-close" onclick="closeModal('devicesModal')"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M18 6 6 18M6 6l12 12"/></svg></button>
    </div>
    <div class="modal-body">
      <div id="devicesList" style="display:flex;flex-direction:column;gap:8px"></div>
      <div id="devicesEmpty" class="empty hidden" style="padding:20px">No devices bound to this key yet.</div>
    </div>
    <div class="modal-footer" style="justify-content:center">
      <button class="btn btn-ghost" onclick="closeModal('devicesModal')">Close</button>
    </div>
  </div>
</div>

<!-- Confirm Modal -->
<div id="confirmModal" class="modal-overlay hidden">
  <div class="modal narrow">
    <div class="modal-body" style="padding-top:28px">
      <div class="confirm-icon danger" id="confirmIcon">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2m3 0v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6h14ZM10 11v6M14 11v6"/></svg>
      </div>
      <div style="font-weight:700;font-size:1.05rem" id="confirmTitle">Delete item?</div>
      <div class="confirm-text" id="confirmText">This action cannot be undone.</div>
    </div>
    <div class="confirm-footer">
      <button class="btn btn-ghost" onclick="closeModal('confirmModal')">Cancel</button>
      <button class="btn btn-danger" id="confirmActionBtn">Delete</button>
    </div>
  </div>
</div>

<div class="toast-stack" id="toastStack"></div>

<script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
<script>
const API = location.origin + '/admin/api';
const REMEMBER_KEY = 'lulilolo_admin_pwd';
let pwd = '', keys = {}, scripts = [], scriptLabels = {}, editingKey = false, shareCtxKey = '', editingScriptName = null;

/* ---------- top loading bar ---------- */
let loadDepth = 0;
function loadStart(){
  loadDepth++;
  const el = document.getElementById('topload');
  el.classList.remove('done'); el.style.opacity = 1;
  requestAnimationFrame(function(){ el.classList.add('active'); });
}
function loadEnd(){
  loadDepth = Math.max(0, loadDepth - 1);
  if (loadDepth > 0) return;
  const el = document.getElementById('topload');
  el.classList.remove('active'); el.classList.add('done');
  setTimeout(function(){ el.style.width='0'; el.style.opacity=0; el.classList.remove('done'); }, 320);
}

/* ---------- ripple + press feedback on all buttons ---------- */
document.addEventListener('click', function(e){
  const btn = e.target.closest('.btn, .btn-icon');
  if(!btn) return;
  const rect = btn.getBoundingClientRect();
  const rp = document.createElement('span');
  const size = Math.max(rect.width, rect.height) * 1.4;
  rp.className = 'ripple';
  rp.style.width = rp.style.height = size + 'px';
  rp.style.left = (e.clientX - rect.left - size/2) + 'px';
  rp.style.top = (e.clientY - rect.top - size/2) + 'px';
  btn.appendChild(rp);
  setTimeout(function(){ rp.remove(); }, 650);
});

/* ---------- spotlight hover glow on glass surfaces ---------- */
document.addEventListener('mousemove', function(e){
  document.querySelectorAll('.glass').forEach(function(el){
    const r = el.getBoundingClientRect();
    if(e.clientX>=r.left && e.clientX<=r.right && e.clientY>=r.top && e.clientY<=r.bottom){
      el.style.setProperty('--mx', (e.clientX-r.left)+'px');
      el.style.setProperty('--my', (e.clientY-r.top)+'px');
    }
  });
});

/* ---------- stepper widgets ---------- */
document.addEventListener('click', function(e){
  const sb = e.target.closest('.step-btn');
  if(!sb) return;
  const wrap = sb.closest('.stepper');
  const inp = wrap.querySelector('input');
  const dir = parseInt(sb.dataset.dir);
  const min = parseInt(inp.min) || 1;
  let val = (parseInt(inp.value) || 0) + dir;
  if(val < min) val = min;
  inp.value = val;
});

/* ---------- toasts ---------- */
const TOAST_ICONS = {
  success: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>',
  error: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>',
  info: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M12 16v-4M12 8h.01"/><circle cx="12" cy="12" r="9"/></svg>'
};
function toast(msg, type){
  type = type || 'info';
  const stack = document.getElementById('toastStack');
  while (stack.children.length >= 4) stack.removeChild(stack.firstChild);
  const t = document.createElement('div');
  t.className = 'toast ' + type;
  t.innerHTML = '<span class="ico">'+(TOAST_ICONS[type]||TOAST_ICONS.info)+'</span><span class="msg"></span><button class="tclose"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M18 6 6 18M6 6l12 12"/></svg></button><span class="tbar"></span>';
  t.querySelector('.msg').textContent = msg;
  function dismiss(){ if(t.classList.contains('out')) return; t.classList.add('out'); setTimeout(function(){ t.remove(); }, 320); }
  t.querySelector('.tclose').addEventListener('click', dismiss);
  stack.appendChild(t);
  setTimeout(dismiss, 3600);
}

/* ---------- count up numbers ---------- */
function countUp(el, target){
  const dur = 650, t0 = performance.now(), start = parseInt(el.textContent) || 0;
  function step(t){
    const p = Math.min((t - t0) / dur, 1);
    el.textContent = Math.round(start + (target - start) * p);
    if(p < 1) requestAnimationFrame(step);
  }
  requestAnimationFrame(step);
}

/* ---------- confirm dialog ---------- */
function confirmDialog(title, text, onYes){
  document.getElementById('confirmTitle').textContent = title;
  document.getElementById('confirmText').textContent = text;
  const btn = document.getElementById('confirmActionBtn');
  const fresh = btn.cloneNode(true);
  btn.parentNode.replaceChild(fresh, btn);
  fresh.addEventListener('click', function(){ closeModal('confirmModal'); onYes(); });
  document.getElementById('confirmModal').classList.remove('hidden');
}

/* ---------- client-side file download helper ---------- */
function downloadTextFile(filename, content){
  const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url; a.download = filename;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(function(){ URL.revokeObjectURL(url); }, 1000);
}

/* ---------- api ---------- */
async function api(action, extra) {
  extra = extra || {};
  const body = Object.assign({ password: pwd, action: action }, extra);
  loadStart();
  try {
    const r = await fetch(API, { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify(body) });
    if (r.status === 401) { logout(); throw new Error('Unauthorized'); }
    return await r.json();
  } finally {
    loadEnd();
  }
}

function togglePwdVisibility(){
  const inp = document.getElementById('pwdInput');
  const btn = document.getElementById('eyeBtn');
  const isPwd = inp.type === 'password';
  inp.type = isPwd ? 'text' : 'password';
  btn.innerHTML = isPwd
    ? '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.94 10.94 0 0 1 12 20c-7 0-11-8-11-8a21.6 21.6 0 0 1 5.06-6.06M9.9 4.24A10.94 10.94 0 0 1 12 4c7 0 11 8 11 8a21.6 21.6 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24M1 1l22 22"/></svg>'
    : '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8Z"/><circle cx="12" cy="12" r="3"/></svg>';
}

async function refreshAll(){
  const btn = document.getElementById('refreshBtn');
  btn.classList.add('spin');
  try {
    await Promise.all([loadKeys(), loadScripts()]);
    toast('Refreshed', 'success');
  } catch(e) {
    toast('Refresh failed', 'error');
  } finally {
    setTimeout(function(){ btn.classList.remove('spin'); }, 500);
  }
}

async function login() {
  pwd = document.getElementById('pwdInput').value;
  const errEl = document.getElementById('loginError');
  const btn = document.getElementById('loginBtn');
  btn.classList.add('loading');
  try {
    const r = await api('list');
    if (r.error) {
      errEl.textContent = r.error; errEl.classList.remove('hidden');
      document.querySelector('.login-card').classList.add('shake');
      setTimeout(function(){ document.querySelector('.login-card').classList.remove('shake'); }, 400);
      btn.classList.remove('loading');
      return;
    }
    keys = r.keys;
    errEl.classList.add('hidden');
    if (document.getElementById('rememberInput').checked) {
      try { localStorage.setItem(REMEMBER_KEY, pwd); } catch(e) {}
    } else {
      try { localStorage.removeItem(REMEMBER_KEY); } catch(e) {}
    }
    document.getElementById('loginView').classList.add('hidden');
    document.getElementById('dashView').classList.remove('hidden');
    renderKeys();
    loadScripts();
    toast('Welcome back', 'success');
  } catch(e) {
    errEl.textContent = e.message; errEl.classList.remove('hidden');
  }
  btn.classList.remove('loading');
}

function logout() {
  pwd = '';
  try { localStorage.removeItem(REMEMBER_KEY); } catch(e) {}
  document.getElementById('rememberInput').checked = false;
  document.getElementById('dashView').classList.add('hidden');
  document.getElementById('loginView').classList.remove('hidden');
  document.getElementById('pwdInput').value = '';
}

window.addEventListener('DOMContentLoaded', function(){
  let saved = null;
  try { saved = localStorage.getItem(REMEMBER_KEY); } catch(e) {}
  if (saved) {
    document.getElementById('pwdInput').value = saved;
    document.getElementById('rememberInput').checked = true;
    login();
  }
});

function switchTab(name, el) {
  document.querySelectorAll('.tab').forEach(function(t){ t.classList.remove('active'); });
  document.querySelectorAll('.tab-panel').forEach(function(p){ p.classList.remove('active'); });
  el.classList.add('active');
  document.getElementById('panel-' + name).classList.add('active');
  document.getElementById('tabThumb').style.transform = 'translateX(' + (el.dataset.i === '1' ? '100%' : '0') + ')';
}

/* ---------- KEYS ---------- */
async function loadKeys() { const r = await api('list'); keys = r.keys || {}; renderKeys(); }

function updateStats(){
  const entries = Object.values(keys);
  const total = entries.length;
  const active = entries.filter(function(v){ return v.active; }).length;
  const banned = total - active;
  const devicesBound = entries.reduce(function(sum,v){ return sum + ((v.devices||[]).length); }, 0);
  countUp(document.getElementById('statTotal'), total);
  countUp(document.getElementById('statActive'), active);
  countUp(document.getElementById('statBanned'), banned);
  countUp(document.getElementById('statDevices'), devicesBound);
  countUp(document.getElementById('statScripts'), scripts.length);
  document.getElementById('keysCountChip').textContent = total;
  const ratio = total ? active / total : 0;
  const circumference = 113.1;
  document.getElementById('healthRing').style.strokeDashoffset = circumference * (1 - ratio);
  document.getElementById('statHealthPct').textContent = Math.round(ratio * 100) + '%';
}

function expiryTag(expiry){
  const diff = Math.ceil((new Date(expiry) - new Date()) / 86400000);
  if (diff < 0) return { text: 'Expired', cls: 'exp-red' };
  if (diff <= 7) return { text: diff + 'd left', cls: 'exp-orange' };
  return { text: diff + 'd left', cls: 'exp-green' };
}

let selectedKeys = new Set();
let keyFilter = 'all';
const LIFETIME_YEARS = 100;

function isLifetimeKey(v){
  return v && v.expiry && (new Date(v.expiry).getFullYear() - new Date().getFullYear()) >= 50;
}

function renderKeys() {
  const tb = document.getElementById('keysTable');
  const entries = Object.entries(keys);
  document.getElementById('keysEmpty').classList.toggle('hidden', entries.length > 0);
  updateStats();
  tb.innerHTML = '';
  entries.forEach(function(entry, idx){
    const k = entry[0], v = entry[1];
    const devs = (v.devices||[]).length;
    const lim = v.device_limit||1;
    const lifetime = isLifetimeKey(v);
    const exp = lifetime ? 'Never' : new Date(v.expiry).toLocaleDateString();
    const tag = lifetime ? { text: 'Lifetime', cls: 'exp-green' } : expiryTag(v.expiry);
    const files = (v.allowed_files||[]).map(function(f){ return scriptLabels[f] || f; }).join(', ') || '—';
    const tr = document.createElement('tr');
    tr.dataset.key = k;
    tr.dataset.status = v.active ? 'active' : 'banned';
    tr.dataset.lifetime = lifetime ? '1' : '0';
    tr.dataset.expiring = (!lifetime && (Math.ceil((new Date(v.expiry) - new Date())/86400000) <= 7)) ? '1' : '0';
    tr.style.animationDelay = (idx * 35) + 'ms';
    tr.innerHTML = '<td style="width:30px"><input type="checkbox" class="rowchk" data-act="chk"></td>'
      +'<td data-label="Key"><div class="keycell"><span class="keytxt"></span>'
        +'<button class="copy-mini" data-act="copy" title="Copy key"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg></button></div></td>'
      +'<td data-label="Status"><span class="badge '+(v.active?'badge-active':'badge-banned')+'">'+(v.active?'Active':'Banned')+'</span></td>'
      +'<td data-label="Devices" class="dcount"><b>'+devs+'</b> / '+lim+'</td>'
      +'<td data-label="Expiry"><div class="exp-wrap"><span>'+exp+'</span><span class="exp-tag '+tag.cls+'">'+tag.text+'</span></div></td>'
      +'<td data-label="Scripts" class="scripts-col" title=""></td>'
      +'<td class="actions-row actions">'
        +'<button class="btn btn-flat btn-sm" data-act="edit">Edit</button>'
        +'<button class="btn btn-sm '+(v.active?'btn-warning':'btn-success')+'" data-act="ban">'+(v.active?'Ban':'Unban')+'</button>'
        +'<button class="btn btn-icon" data-act="devices" title="Devices"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="6" width="20" height="12" rx="2"/><path d="M6 12h.01M10 12h4"/></svg></button>'
        +'<button class="btn btn-icon" data-act="share" title="Share"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="M8.6 13.5l6.8 3.9M15.4 6.6L8.6 10.5"/></svg></button>'
        +'<button class="btn btn-danger btn-sm" data-act="delete">Delete</button>'
      +'</td>';
    tr.querySelector('.keytxt').textContent = k;
    tr.querySelector('[data-label="Scripts"]').textContent = files;
    tr.querySelector('[data-label="Scripts"]').title = files;
    tr.querySelector('[data-act="chk"]').checked = selectedKeys.has(k);
    tr.querySelector('[data-act="chk"]').addEventListener('change', function(e){ toggleRowSelect(k, e.target.checked); });
    tr.querySelector('[data-act="copy"]').addEventListener('click', function(){
      navigator.clipboard.writeText(k).then(function(){ toast('Key copied to clipboard', 'success'); }).catch(function(){ toast('Copy failed', 'error'); });
    });
    tr.querySelector('[data-act="edit"]').addEventListener('click', function(){ openKeyModal(true,k); });
    tr.querySelector('[data-act="ban"]').addEventListener('click', function(){ toggleBan(k,v.active); });
    tr.querySelector('[data-act="devices"]').addEventListener('click', function(){ openDevicesModal(k); });
    tr.querySelector('[data-act="share"]').addEventListener('click', function(){ openShareModal(k,v); });
    tr.querySelector('[data-act="delete"]').addEventListener('click', function(){ deleteKey(k); });
    tb.appendChild(tr);
  });
  applyKeyFilters();
}

function setKeyFilter(f, el){
  keyFilter = f;
  document.querySelectorAll('#keyFilterChips .chip-btn').forEach(function(c){ c.classList.remove('active'); });
  el.classList.add('active');
  applyKeyFilters();
}

function applyKeyFilters(){
  const q = document.getElementById('keySearch').value.trim().toLowerCase();
  document.querySelectorAll('#keysTable tr').forEach(function(tr){
    const k = (tr.dataset.key||'').toLowerCase();
    let show = k.indexOf(q) !== -1;
    if (show && keyFilter === 'active') show = tr.dataset.status === 'active';
    if (show && keyFilter === 'banned') show = tr.dataset.status === 'banned';
    if (show && keyFilter === 'expiring') show = tr.dataset.expiring === '1';
    if (show && keyFilter === 'lifetime') show = tr.dataset.lifetime === '1';
    tr.style.display = show ? '' : 'none';
  });
}

function filterKeys(){ applyKeyFilters(); }

/* ---------- Bulk selection ---------- */
function toggleRowSelect(k, checked){
  if (checked) selectedKeys.add(k); else selectedKeys.delete(k);
  updateBulkBar();
}
function toggleSelectAll(el){
  document.querySelectorAll('#keysTable tr').forEach(function(tr){
    if (tr.style.display === 'none') return;
    const chk = tr.querySelector('[data-act="chk"]');
    chk.checked = el.checked;
    if (el.checked) selectedKeys.add(tr.dataset.key); else selectedKeys.delete(tr.dataset.key);
  });
  updateBulkBar();
}
function clearSelection(){
  selectedKeys.clear();
  document.getElementById('selectAllChk').checked = false;
  document.querySelectorAll('#keysTable [data-act="chk"]').forEach(function(c){ c.checked = false; });
  updateBulkBar();
}
function updateBulkBar(){
  const bar = document.getElementById('bulkBar');
  bar.classList.toggle('show', selectedKeys.size > 0);
  document.getElementById('bulkCount').textContent = selectedKeys.size + ' selected';
}
async function bulkAction(kind){
  if (selectedKeys.size === 0) return;
  const list = Array.from(selectedKeys);
  const run = async function(){
    for (const k of list) {
      if (kind === 'delete') await api('delete_key', { keyName: k });
      else await api('toggle_ban', { keyName: k, active: kind === 'unban' });
    }
    clearSelection();
    loadKeys();
    toast(kind === 'delete' ? (list.length+' key(s) deleted') : (list.length+' key(s) updated'), 'success');
  };
  if (kind === 'delete') {
    confirmDialog('Delete '+list.length+' key(s)?', 'This will permanently remove the selected keys. This cannot be undone.', run);
  } else {
    run();
  }
}

/* ---------- Devices modal ---------- */
function openDevicesModal(name){
  shareCtxKey = name;
  const v = keys[name] || {};
  const devs = v.devices || [];
  const list = document.getElementById('devicesList');
  list.innerHTML = '';
  document.getElementById('devicesEmpty').classList.toggle('hidden', devs.length > 0);
  devs.forEach(function(d){
    const row = document.createElement('div');
    row.className = 'device-row';
    row.innerHTML = '<span class="did"></span><button class="btn btn-danger btn-sm" data-act="unbind">Unbind</button>';
    row.querySelector('.did').textContent = d;
    row.querySelector('[data-act="unbind"]').addEventListener('click', function(){ unbindDevice(name, d); });
    list.appendChild(row);
  });
  document.getElementById('devicesModal').classList.remove('hidden');
}
async function unbindDevice(name, deviceId){
  const data = Object.assign({}, keys[name]);
  data.devices = (data.devices || []).filter(function(d){ return d !== deviceId; });
  await api('update_key', { keyName: name, data: data });
  await loadKeys();
  openDevicesModal(name);
  toast('Device unbound', 'success');
}

let pendingLifetime = false;

function randomizeKeyName(){
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = 'KEY-';
  for (let i=0;i<10;i++){ out += chars[Math.floor(Math.random()*chars.length)]; if(i===4) out+='-'; }
  document.getElementById('keyNameInput').value = out;
}

function setExpiryPreset(days, el){
  document.querySelectorAll('#expiryPresets .chip-btn').forEach(function(c){ c.classList.remove('active'); });
  el.classList.add('active');
  if (days === 'lifetime') {
    pendingLifetime = true;
    document.getElementById('expiryStepper').classList.add('hidden');
  } else {
    pendingLifetime = false;
    document.getElementById('expiryStepper').classList.remove('hidden');
    document.getElementById('expiryInput').value = days;
  }
}

function openKeyModal(editing, name) {
  editingKey = editing;
  pendingLifetime = false;
  document.getElementById('keyModalTitle').textContent = editing ? 'Edit Key' : 'Create New Key';
  document.getElementById('keyNameInput').value = editing ? name : '';
  document.getElementById('keyNameInput').disabled = editing;
  document.getElementById('randKeyBtn').classList.toggle('hidden', editing);
  document.getElementById('expiryGroup').classList.toggle('hidden', editing);
  document.getElementById('expiryStepper').classList.remove('hidden');
  document.querySelectorAll('#expiryPresets .chip-btn').forEach(function(c){ c.classList.remove('active'); });
  const thirty = document.querySelector('#expiryPresets [data-days="30"]');
  if (thirty) thirty.classList.add('active');
  if (editing && keys[name]) {
    document.getElementById('deviceLimitInput').value = keys[name].device_limit || 1;
  } else {
    document.getElementById('deviceLimitInput').value = 1;
    document.getElementById('expiryInput').value = 30;
  }
  const sel = editing && keys[name] ? (keys[name].allowed_files||[]) : scripts.map(function(s){ return s.name; });
  const box = document.getElementById('scriptCheckboxes');
  box.innerHTML = '';
  scripts.forEach(function(s){
    const lab = document.createElement('label');
    lab.className = 'checkbox-item';
    lab.innerHTML = '<span></span><label class="toggle"><input type="checkbox" value=""><span class="track"><span class="thumb"></span></span></label>';
    lab.querySelector('span').textContent = (scriptLabels[s.name] ? scriptLabels[s.name] + ' (' + s.name + ')' : s.name);
    const inp = lab.querySelector('input');
    inp.value = s.name;
    inp.checked = sel.indexOf(s.name) !== -1;
    box.appendChild(lab);
  });
  document.getElementById('keyModal').classList.remove('hidden');
}

async function saveKey() {
  const name = document.getElementById('keyNameInput').value.trim();
  if (!name) { toast('Enter a key name', 'error'); return; }
  const btn = document.getElementById('saveKeyBtn');
  btn.classList.add('loading');
  let data = editingKey ? Object.assign({}, keys[name]) : { active:true, devices:[], created: new Date().toISOString() };
  data.device_limit = parseInt(document.getElementById('deviceLimitInput').value) || 1;
  if (!editingKey) {
    const exp = new Date();
    if (pendingLifetime) {
      exp.setFullYear(exp.getFullYear() + LIFETIME_YEARS);
    } else {
      const days = parseInt(document.getElementById('expiryInput').value) || 30;
      exp.setDate(exp.getDate() + days);
    }
    data.expiry = exp.toISOString();
  }
  data.allowed_files = Array.prototype.map.call(document.querySelectorAll('#scriptCheckboxes input:checked'), function(c){ return c.value; });
  try {
    await api(editingKey ? 'update_key' : 'create_key', { keyName: name, data: data });
    closeModal('keyModal');
    loadKeys();
    toast(editingKey ? 'Key updated' : 'Key created', 'success');
  } finally {
    btn.classList.remove('loading');
  }
}

async function toggleBan(name, active) {
  await api('toggle_ban', { keyName: name, active: !active });
  loadKeys();
  toast(active ? 'Key banned' : 'Key unbanned', active ? 'error' : 'success');
}

function deleteKey(name) {
  confirmDialog('Delete key?', 'This will permanently remove "' + name + '". This cannot be undone.', async function(){
    await api('delete_key', { keyName: name });
    loadKeys();
    toast('Key deleted', 'success');
  });
}

/* ---------- Share ---------- */
function openShareModal(name, data){
  shareCtxKey = name;
  document.getElementById('shareKeyText').textContent = name;
  document.getElementById('shareKeyExpiry').textContent = data && data.expiry ? new Date(data.expiry).toLocaleDateString() : '—';
  document.getElementById('shareKeyDevices').textContent = data ? ((data.devices||[]).length + ' / ' + (data.device_limit||1)) : '—';
  document.getElementById('nativeShareBtn').classList.toggle('hidden', !navigator.share);
  document.getElementById('shareModal').classList.remove('hidden');
}

function copyShareKey(){
  navigator.clipboard.writeText(shareCtxKey).then(function(){ toast('Key copied to clipboard', 'success'); }).catch(function(){ toast('Copy failed', 'error'); });
}

function shareToTelegram(){
  const text = 'Your access key: ' + shareCtxKey;
  const url = 'https://t.me/share/url?url=' + encodeURIComponent('') + '&text=' + encodeURIComponent(text);
  window.open(url, '_blank', 'noopener');
}

function shareNative(){
  if (navigator.share) {
    navigator.share({ title: 'Access Key', text: 'Your access key: ' + shareCtxKey }).catch(function(){});
  } else {
    copyShareKey();
  }
}

/* ---------- SCRIPTS ---------- */
async function loadScripts() { const r = await api('list_scripts'); scripts = r.scripts || []; scriptLabels = r.labels || {}; renderScripts(); updateStats(); }

function fmtSize(bytes){
  if (bytes < 1024) return bytes + ' B';
  return (bytes/1024).toFixed(bytes < 1024*10 ? 1 : 0) + ' KB';
}

function renderScripts() {
  const tb = document.getElementById('scriptsTable');
  document.getElementById('scriptsEmpty').classList.toggle('hidden', scripts.length > 0);
  document.getElementById('scriptsCountChip').textContent = scripts.length;
  document.getElementById('downloadAllBtn').disabled = scripts.length === 0;
  tb.innerHTML = '';
  scripts.forEach(function(s, idx){
    const tr = document.createElement('tr');
    tr.dataset.name = s.name;
    tr.style.animationDelay = (idx * 35) + 'ms';
    tr.innerHTML = '<td data-label="File"><div class="file-cell"><span class="file-ico"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/></svg></span><span class="file-name"></span><span class="file-label"></span></div></td>'
      +'<td data-label="Size" class="file-size">'+fmtSize(s.size)+'</td>'
      +'<td class="actions-row actions">'
        +'<button class="btn btn-icon" data-act="download" title="Download"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M7 10l5 5 5-5M12 15V3"/></svg></button>'
        +'<button class="btn btn-flat btn-sm" data-act="edit">Edit</button>'
        +'<button class="btn btn-danger btn-sm" data-act="delete">Delete</button>'
      +'</td>';
    tr.querySelector('.file-name').textContent = s.name;
    const lab = scriptLabels[s.name] || '';
    const labEl = tr.querySelector('.file-label');
    if (lab) { labEl.textContent = lab; } else { labEl.style.display = 'none'; }
    tr.querySelector('[data-act="download"]').addEventListener('click', function(){ downloadScript(s.name); });
    tr.querySelector('[data-act="edit"]').addEventListener('click', function(){ editScript(s.name); });
    tr.querySelector('[data-act="delete"]').addEventListener('click', function(){ deleteScript(s.name); });
    tb.appendChild(tr);
  });
}

function filterScripts(){
  const q = document.getElementById('scriptSearch').value.trim().toLowerCase();
  document.querySelectorAll('#scriptsTable tr').forEach(function(tr){
    const n = (tr.dataset.name||'').toLowerCase();
    tr.style.display = n.indexOf(q) !== -1 ? '' : 'none';
  });
}

async function downloadScript(name){
  toast('Preparing download…', 'info');
  const r = await api('get_script', { filename: name });
  downloadTextFile(name, r.content || '');
  toast(name + ' downloaded', 'success');
}

function downloadCurrentScript(){
  const name = document.getElementById('scriptNameInput').value.trim() || 'script.lua';
  const content = document.getElementById('scriptContentInput').value;
  downloadTextFile(name, content);
  toast(name + ' downloaded', 'success');
}

async function downloadAllScripts(){
  if (!scripts.length) { toast('No scripts to download', 'error'); return; }
  const btn = document.getElementById('downloadAllBtn');
  btn.classList.add('loading');
  try {
    if (typeof JSZip === 'undefined') { toast('Zip library unavailable, downloading individually', 'info'); for (const s of scripts) { await downloadScript(s.name); } return; }
    const zip = new JSZip();
    for (const s of scripts) {
      const r = await api('get_script', { filename: s.name });
      zip.file(s.name, r.content || '');
    }
    const blob = await zip.generateAsync({ type: 'blob' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = 'lulilolo-scripts.zip';
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(function(){ URL.revokeObjectURL(url); }, 1000);
    toast('All scripts downloaded as .zip', 'success');
  } catch(e) {
    toast('Download failed: ' + e.message, 'error');
  } finally {
    btn.classList.remove('loading');
  }
}

function updateScriptCount(){
  const len = document.getElementById('scriptContentInput').value.length;
  document.getElementById('scriptCharCount').textContent = len + ' chars';
}

function openScriptModal() {
  editingScriptName = null;
  document.getElementById('scriptModalTitle').textContent = 'New Script';
  document.getElementById('scriptNameInput').value = '';
  document.getElementById('scriptNameInput').disabled = false;
  document.getElementById('scriptLabelInput').value = '';
  document.getElementById('scriptContentInput').value = '';
  updateScriptCount();
  document.getElementById('scriptModal').classList.remove('hidden');
}

async function editScript(name) {
  const r = await api('get_script', { filename: name });
  editingScriptName = name;
  document.getElementById('scriptModalTitle').textContent = 'Edit Script';
  document.getElementById('scriptNameInput').value = name;
  document.getElementById('scriptNameInput').disabled = true;
  document.getElementById('scriptLabelInput').value = (scriptLabels && scriptLabels[name]) || '';
  document.getElementById('scriptContentInput').value = r.content || '';
  updateScriptCount();
  document.getElementById('scriptModal').classList.remove('hidden');
}

async function saveScript() {
  const name = document.getElementById('scriptNameInput').value.trim();
  if (!name.endsWith('.lua')) { toast('Filename must end with .lua', 'error'); return; }
  const content = document.getElementById('scriptContentInput').value;
  const label = document.getElementById('scriptLabelInput').value.trim();
  const btn = document.getElementById('saveScriptBtn');
  btn.classList.add('loading');
  try {
    await api('save_script', { filename: name, content: content, label: label });
    closeModal('scriptModal');
    loadScripts();
    toast('Script saved', 'success');
  } finally {
    btn.classList.remove('loading');
  }
}

function deleteScript(name) {
  confirmDialog('Delete script?', 'This will permanently remove "' + name + '". This cannot be undone.', async function(){
    await api('delete_script', { filename: name });
    loadScripts();
    toast('Script deleted', 'success');
  });
}

function closeModal(id) { document.getElementById(id).classList.add('hidden'); }
document.addEventListener('keydown', function(e){
  if (e.key === 'Escape') {
    ['keyModal','scriptModal','shareModal','confirmModal'].forEach(function(id){
      const el = document.getElementById(id);
      if (el && !el.classList.contains('hidden')) el.classList.add('hidden');
    });
  }
});
</script>
</body>
</html>`;

// ============ v2 helpers ============
const SESSION_TTL_MS = 15 * 60 * 1000;   // session lifetime
const SESSION_QUOTA = 128;               // max chunk fetches per session

async function rateLimit(env, id, windowSec, max) {
  const now = Date.now();
  const k = "rl_" + id;
  const cur = await env.LULILOLO_KV.get(k, "json");
  if (!cur || (now - cur.t) > windowSec * 1000) {
    await env.LULILOLO_KV.put(k, JSON.stringify({ t: now, c: 1 }), { expirationTtl: windowSec + 5 });
    return true;
  }
  if (cur.c >= max) return false;
  await env.LULILOLO_KV.put(k, JSON.stringify({ t: cur.t, c: cur.c + 1 }), { expirationTtl: windowSec + 5 });
  return true;
}

function randHex(n) {
  const b = new Uint8Array(n);
  crypto.getRandomValues(b);
  return Array.from(b, (x) => x.toString(16).padStart(2, "0")).join("");
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const method = request.method;
    const path = url.pathname;

    if (method === "OPTIONS") {
      return new Response(null, { headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Methods": "GET, POST, OPTIONS", "Access-Control-Allow-Headers": "Content-Type" }});
    }

    if (path === "/admin" && method === "GET") {
      return new Response(ADMIN_HTML, { headers: { "Content-Type": "text/html; charset=utf-8" }});
    }

    if (path === "/admin/api" && method === "POST") {
      try {
        const body = await request.json();
        const pwd = env.ADMIN_PASSWORD || "admin";
        if (body.password !== pwd) {
          return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
        }

        if (!env.LULILOLO_KV) return new Response(JSON.stringify({ error: "KV not bound" }));

        // Keys API
        if (body.action === "list") {
          const list = await env.LULILOLO_KV.list({ prefix: "key_" });
          let keysMap = {};
          for (let k of list.keys) {
            const val = await env.LULILOLO_KV.get(k.name, "json");
            keysMap[k.name.replace("key_", "")] = val;
          }
          return new Response(JSON.stringify({ keys: keysMap }));
        }
        if (body.action === "create_key" || body.action === "update_key") {
          await env.LULILOLO_KV.put("key_" + body.keyName, JSON.stringify(body.data));
          return new Response(JSON.stringify({ success: true }));
        }
        if (body.action === "delete_key") {
          await env.LULILOLO_KV.delete("key_" + body.keyName);
          return new Response(JSON.stringify({ success: true }));
        }
        if (body.action === "toggle_ban") {
          const val = await env.LULILOLO_KV.get("key_" + body.keyName, "json");
          if (val) {
            val.active = body.active;
            await env.LULILOLO_KV.put("key_" + body.keyName, JSON.stringify(val));
          }
          return new Response(JSON.stringify({ success: true }));
        }

        // Scripts API
        if (!env.LULILOLO_SCRIPTS) return new Response(JSON.stringify({ error: "SCRIPTS KV not bound" }));

        if (body.action === "list_scripts") {
          const list = await env.LULILOLO_SCRIPTS.list();
          let scripts = [];
          let labels = {};
          const labelsRaw = await env.LULILOLO_KV.get("meta_script_labels", "json");
          if (labelsRaw && typeof labelsRaw === "object") labels = labelsRaw;
          for (let k of list.keys) {
             if (k.name.endsWith('.lua')) {
                 const content = await env.LULILOLO_SCRIPTS.get(k.name, "text");
                 scripts.push({ name: k.name, size: content ? content.length : 0 });
             }
          }
          return new Response(JSON.stringify({ scripts, labels }));
        }
        if (body.action === "get_script") {
          const content = await env.LULILOLO_SCRIPTS.get(body.filename, "text");
          return new Response(JSON.stringify({ content: content || "" }));
        }
        if (body.action === "save_script") {
          await env.LULILOLO_SCRIPTS.put(body.filename, body.content);
          if (body.label !== undefined) {
            let labels = {};
            const labelsRaw = await env.LULILOLO_KV.get("meta_script_labels", "json");
            if (labelsRaw && typeof labelsRaw === "object") labels = labelsRaw;
            if (body.label) labels[body.filename] = String(body.label);
            else delete labels[body.filename];
            await env.LULILOLO_KV.put("meta_script_labels", JSON.stringify(labels));
          }
          return new Response(JSON.stringify({ success: true }));
        }
        if (body.action === "delete_script") {
          await env.LULILOLO_SCRIPTS.delete(body.filename);
          let labels = {};
          const labelsRaw = await env.LULILOLO_KV.get("meta_script_labels", "json");
          if (labelsRaw && typeof labelsRaw === "object") labels = labelsRaw;
          if (labels[body.filename]) {
            delete labels[body.filename];
            await env.LULILOLO_KV.put("meta_script_labels", JSON.stringify(labels));
          }
          return new Response(JSON.stringify({ success: true }));
        }

        // Push encrypted chunk (base64). This is the ONLY supported way to publish scripts now.
        if (body.action === "push_chunk") {
          const fn = String(body.filename || "");
          const b64 = String(body.data_b64 || "");
          if (!/^[a-z0-9]+\.(lua|enc)$/.test(fn)) return new Response(JSON.stringify({ error: "bad filename" }), { status: 400 });
          if (!b64 || b64.length < 16 || b64.length > 20000000) return new Response(JSON.stringify({ error: "bad payload" }), { status: 400 });
          await env.LULILOLO_SCRIPTS.put(fn, b64);
          return new Response(JSON.stringify({ success: true, filename: fn, size: b64.length }));
        }

        // Kill switch
        if (body.action === "kill_set") {
          await env.LULILOLO_KV.put("meta_kill", body.kill ? "1" : "0");
          return new Response(JSON.stringify({ success: true, kill: !!body.kill }));
        }
        if (body.action === "kill_get") {
          const k = await env.LULILOLO_KV.get("meta_kill");
          return new Response(JSON.stringify({ kill: k === "1" }));
        }

      } catch (e) {
        return new Response(JSON.stringify({ error: e.message }), { status: 500 });
      }
    }

    // Public kill switch
    if ((path === "/validate" || path === "/g")) {
      const killed = await env.LULILOLO_KV.get("meta_kill");
      if (killed === "1") {
        return new Response(JSON.stringify({ valid: false, error: "Service unavailable" }), { status: 403, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
      }
    }

    // ============ KEY VALIDATION API ============
    if (path === "/validate" && method === "POST") {
      try {
        const body = await request.json();
        const { key, device_id } = body;

        if (!key || !device_id) return new Response(JSON.stringify({ valid: false, error: "Missing key or device_id" }), { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
        if (!env.LULILOLO_KV) return new Response(JSON.stringify({ valid: false, error: "KV Database not configured" }), { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});

        const ip = request.headers.get("CF-Connecting-IP") || "unknown";
        if (!(await rateLimit(env, "val_ip_" + ip, 60, 20))) return new Response(JSON.stringify({ valid: false, error: "Rate limited" }), { status: 429, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
        if (!(await rateLimit(env, "val_key_" + key, 60, 10))) return new Response(JSON.stringify({ valid: false, error: "Rate limited" }), { status: 429, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});

        const keyData = await env.LULILOLO_KV.get("key_" + key, "json");
        if (!keyData) return new Response(JSON.stringify({ valid: false, error: "Invalid key" }), { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
        if (!keyData.active) return new Response(JSON.stringify({ valid: false, error: "Key banned" }), { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});

        if (new Date() > new Date(keyData.expiry)) {
          return new Response(JSON.stringify({ valid: false, error: "Key expired" }), { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
        }

        const deviceLimit = keyData.device_limit || 1;
        const currentDevices = keyData.devices || [];
        const cleanDeviceId = String(device_id).trim();
        const fakeIds = ["UNKNOWN", "123456789", "000000000000000", "9774d56d682e549c", "unknown", "null", "undefined", ""];

        if (fakeIds.includes(cleanDeviceId) || cleanDeviceId.length < 5) {
          return new Response(JSON.stringify({ valid: false, error: "Invalid device ID" }), { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
        }

        const deviceExists = currentDevices.some(d => d === cleanDeviceId);
        if (!deviceExists && currentDevices.length >= deviceLimit) {
          return new Response(JSON.stringify({ valid: false, error: "Device limit reached", device_limit: deviceLimit, devices: currentDevices, devices_count: currentDevices.length }), { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
        }

        if (!deviceExists) {
          currentDevices.push(cleanDeviceId);
          keyData.devices = currentDevices;
          await env.LULILOLO_KV.put("key_" + key, JSON.stringify(keyData));
        }

        const files = (keyData.allowed_files && keyData.allowed_files.length) ? keyData.allowed_files : ["c01.lua"];
        const token = randHex(32);
        const exp = Date.now() + SESSION_TTL_MS;
        await env.LULILOLO_KV.put("sess_" + token, JSON.stringify({ dev: cleanDeviceId, exp, files, used: 0 }), { expirationTtl: Math.ceil(SESSION_TTL_MS / 1000) + 10 });

        return new Response(JSON.stringify({
          valid: true, expiry: keyData.expiry, device_limit: keyData.device_limit, devices: currentDevices, devices_count: currentDevices.length, is_new_device: !deviceExists, allowed_files: files, session: token, session_exp: exp
        }), { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});

      } catch(e) {
        return new Response(JSON.stringify({ valid: false, error: "Server error: " + e.message }), { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
      }
    }

    // ============ CHUNK FETCH (only way to get script data) ============
    if (path === "/g" && method === "POST") {
      try {
        const body = await request.json();
        const { session, dev, f } = body || {};

        if (!session || !dev || !f) return new Response(JSON.stringify({ ok: false, error: "missing fields" }), { status: 400, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
        if (!/^[a-z0-9]+\.(lua|enc)$/.test(String(f))) return new Response(JSON.stringify({ ok: false, error: "bad file" }), { status: 400, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
        if (!env.LULILOLO_KV || !env.LULILOLO_SCRIPTS) return new Response(JSON.stringify({ ok: false, error: "not configured" }), { status: 500, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});

        const sess = await env.LULILOLO_KV.get("sess_" + session, "json");
        if (!sess) return new Response(JSON.stringify({ ok: false, error: "invalid session" }), { status: 403, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
        if (Date.now() > sess.exp) return new Response(JSON.stringify({ ok: false, error: "session expired" }), { status: 403, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
        if (sess.dev !== String(dev).trim()) return new Response(JSON.stringify({ ok: false, error: "device mismatch" }), { status: 403, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
        if (!sess.files || !sess.files.includes(String(f))) return new Response(JSON.stringify({ ok: false, error: "file not allowed" }), { status: 403, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
        if ((sess.used || 0) >= SESSION_QUOTA) return new Response(JSON.stringify({ ok: false, error: "quota exceeded" }), { status: 403, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});

        const ip = request.headers.get("CF-Connecting-IP") || "unknown";
        if (!(await rateLimit(env, "g_" + session, 60, 60))) return new Response(JSON.stringify({ ok: false, error: "rate limited" }), { status: 429, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});

        const data = await env.LULILOLO_SCRIPTS.get(String(f));
        if (!data) return new Response(JSON.stringify({ ok: false, error: "file not found" }), { status: 404, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});

        sess.used = (sess.used || 0) + 1;
        await env.LULILOLO_KV.put("sess_" + session, JSON.stringify(sess), { expirationTtl: Math.max(10, Math.ceil((sess.exp - Date.now()) / 1000)) });

        return new Response(JSON.stringify({ ok: true, f, data }), { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});

      } catch (e) {
        return new Response(JSON.stringify({ ok: false, error: "server error" }), { status: 500, headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
      }
    }

    // ============ ROOT ============
    if (path === "/") {
      return new Response(JSON.stringify({ ok: true, service: "lulilolo-v2" }), { headers: { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" }});
    }

    return new Response("Not found", { status: 404 });
  }
};