#!/usr/bin/env node
// Control Playwright browser window state via CDP + DYLD signals
// Usage: node window-ctl.js show|hide|toggle [cdp-port]
//   show   — make window visible (SIGUSR2 → setAlphaValue:1) and bring on-screen via CDP
//   hide   — make window invisible (SIGUSR1 → setAlphaValue:0), screenshots still work
//   toggle — switch between show/hide

const fs = require('fs');
const path = require('path');
const os = require('os');

const action = process.argv[2] || 'toggle';
const portArg = process.argv[3];

const STATE_FILE = '/tmp/.chrome-alpha-hidden';

function getCdpPort() {
  if (portArg) return parseInt(portArg, 10);
  const ps = require('child_process').execSync(
    'ps aux | grep "Google Chrome" | grep -v Helper | grep -v grep | grep -o "remote-debugging-port=[0-9]*" | head -1 | cut -d= -f2',
    { encoding: 'utf8' }
  ).trim();
  if (ps) return parseInt(ps, 10);
  throw new Error('No Chrome CDP port found');
}

function getChromePid() {
  const ps = require('child_process').execSync(
    'ps aux | grep "Google Chrome" | grep -v Helper | grep -v grep | head -1',
    { encoding: 'utf8' }
  ).trim();
  if (!ps) throw new Error('No Chrome process found');
  return parseInt(ps.split(/\s+/)[1], 10);
}

async function run() {
  const port = getCdpPort();
  const chromePid = getChromePid();
  const resp = await fetch(`http://127.0.0.1:${port}/json/version`);
  const { webSocketDebuggerUrl } = await resp.json();
  const listResp = await fetch(`http://127.0.0.1:${port}/json/list`);
  const targets = await listResp.json();
  const page = targets.find(t => t.type === 'page');
  if (!page) { console.error('No page target'); process.exit(1); }

  const ws = new WebSocket(webSocketDebuggerUrl);
  await new Promise(r => ws.addEventListener('open', r));

  const send = (method, params) => new Promise(resolve => {
    const id = Math.random() * 1e9 | 0;
    ws.addEventListener('message', function handler(e) {
      const d = JSON.parse(e.data);
      if (d.id === id) { ws.removeEventListener('message', handler); resolve(d.result || d.error); }
    });
    ws.send(JSON.stringify({ id, method, params }));
  });

  const win = await send('Browser.getWindowForTarget', { targetId: page.id });
  const isMinimized = win.bounds?.windowState === 'minimized';
  const isAlphaHidden = fs.existsSync(STATE_FILE);
  const isHidden = isAlphaHidden || isMinimized;

  let doShow;
  if (action === 'show' || action === 'restore') doShow = true;
  else if (action === 'hide') doShow = false;
  else doShow = isHidden; // toggle

  if (doShow) {
    // Un-minimize if needed, position on-screen
    await send('Browser.setWindowBounds', { windowId: win.windowId, bounds: { windowState: 'normal' } });
    await send('Browser.setWindowBounds', { windowId: win.windowId, bounds: { left: 100, top: 100, width: 1280, height: 800 } });
    // SIGUSR2 → DYLD hook sets all windows alpha=1
    process.kill(chromePid, 'SIGUSR2');
    try { fs.unlinkSync(STATE_FILE); } catch {}
    console.log('Window shown');
  } else {
    // SIGUSR1 → DYLD hook sets all windows alpha=0
    // Window is still "on screen" in normal state → Chrome renders → screenshots work
    process.kill(chromePid, 'SIGUSR1');
    fs.writeFileSync(STATE_FILE, String(chromePid));
    console.log('Window hidden');
  }

  ws.close();
}

run().catch(e => { console.error(e.message); process.exit(1); });
