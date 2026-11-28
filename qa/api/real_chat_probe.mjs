#!/usr/bin/env node
// Narrow real-account chat probe. Credentials are read from stdin; never log them.
import { randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';

const TIMEOUT_MS = 15_000;
const MARKER = `QA-CHAT-${randomUUID()}`;
const argv = process.argv.slice(2);
const outputArg = argv.indexOf('--output');
const outputPath = outputArg >= 0 ? argv[outputArg + 1] : undefined;
const selfCheck = argv.includes('--self-check');
let sha;
try { sha = execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(); }
catch { sha = /^[0-9a-f]{40}$/i.test(process.env.SOURCE_SHA ?? '') ? process.env.SOURCE_SHA : 'UNAVAILABLE'; }
const results = [];
const now = () => new Date().toISOString();
const record = (caseId, status, fields = {}) => results.push({ case_id: caseId, status, ...fields });

function assert(condition, message) { if (!condition) throw new Error(message); }
function stompFrame(command, headers = {}, body = '') {
  const h = Object.entries(headers).map(([k, v]) => `${k}:${v}`).join('\n');
  return `${command}\n${h}${h ? '\n' : ''}\n${body}\0`;
}
function parseFrame(raw) {
  if (raw === '\n' || raw === '\r\n') return { command: 'HEARTBEAT', headers: {}, body: '' };
  raw = raw.replace(/\r\n/g, '\n');
  const end = raw.indexOf('\n\n');
  if (end < 0) throw new Error('malformed STOMP frame');
  const [command, ...headerLines] = raw.slice(0, end).split('\n');
  const headers = Object.fromEntries(headerLines.map(line => {
    const i = line.indexOf(':'); return [line.slice(0, i), line.slice(i + 1)];
  }));
  return { command, headers, body: raw.slice(end + 2).replace(/\0$/, '') };
}
async function fetchJson(url, options = {}) {
  const response = await fetch(url, {
    ...options, redirect: 'error', signal: AbortSignal.timeout(TIMEOUT_MS),
    headers: { ...(options.headers ?? {}), Accept: 'application/json' },
  });
  let payload = null;
  try { payload = await response.json(); } catch { /* status still recorded */ }
  return { status: response.status, payload, code: payload?.code == null ? undefined : String(payload.code) };
}
function apiUrl(base, path) { return `${base.replace(/\/$/, '')}${path}`; }
function dataOf(payload) { return payload?.data ?? payload; }
function messageRows(payload) {
  const data = dataOf(payload);
  if (Array.isArray(data?.messages)) return data.messages;
  return [];
}
const successful = r => r.status >= 200 && r.status < 300 && ['0000', '1000'].includes(r.code);

class StompSocket {
  constructor(url, token) {
    this.ws = new WebSocket(url);
    this.frames = [];
    this.waiters = [];
    this.pending = '';
    this.ready = new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('stomp connect timeout')), TIMEOUT_MS);
      this.ws.addEventListener('open', () => this.ws.send(stompFrame('CONNECT', {
        'accept-version': '1.2', 'heart-beat': '0,0', host: new URL(url).host,
        Authorization: `Bearer ${token}`,
      })));
      this.ws.addEventListener('message', event => {
        this.pending += String(event.data);
        let at;
          while ((at = this.pending.indexOf('\0')) >= 0) {
          const raw = this.pending.slice(0, at).replace(/^[\r\n]+/, ''); this.pending = this.pending.slice(at + 1);
          if (!raw) continue;
          try {
            const frame = parseFrame(raw);
            if (frame.command === 'HEARTBEAT') continue;
            if (frame.command === 'CONNECTED') { clearTimeout(timer); resolve(); }
            if (frame.command === 'ERROR') { clearTimeout(timer); reject(new Error('stomp error frame')); }
            this.frames.push(frame);
            for (const wake of this.waiters.splice(0)) wake();
          } catch { /* discard malformed frame without exposing body */ }
        }
      });
      this.ws.addEventListener('error', () => { clearTimeout(timer); reject(new Error('websocket error')); });
      this.ws.addEventListener('close', () => { for (const wake of this.waiters.splice(0)) wake(); });
    });
  }
  send(command, headers, body = '') { this.ws.send(stompFrame(command, headers, body)); }
  subscribe(destination, id) { this.send('SUBSCRIBE', { id, destination, ack: 'auto' }); }
  async waitFor(predicate, timeout = 12_000) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
      const i = this.frames.findIndex(predicate);
      if (i >= 0) return this.frames.splice(i, 1)[0];
      await new Promise(resolve => {
        const remaining = Math.max(0, deadline - Date.now());
        const timer = setTimeout(resolve, remaining);
        this.waiters.push(() => { clearTimeout(timer); resolve(); });
      });
    }
    return undefined;
  }
  close() {
    try { if (this.ws.readyState === WebSocket.OPEN) this.send('DISCONNECT', { receipt: randomUUID() }); } catch {}
    try { this.ws.close(); } catch {}
  }
}

async function run() {
  if (selfCheck) {
    const f = parseFrame(stompFrame('MESSAGE', { destination: '/user/queue/messages' }, '{"content":"TOKEN_SECRET"}'));
    assert(f.command === 'MESSAGE' && f.headers.destination === '/user/queue/messages', 'frame parse failed');
    assert(apiUrl('https://example.invalid/api/v1', '/auth/login') === 'https://example.invalid/api/v1/auth/login', 'base URL duplicated');
    assert(!successful({ status: 200, code: '9000' }) && successful({ status: 200, code: '0000' }), 'envelope success check failed');
    const serialized = JSON.stringify({ command: f.command, headers: Object.keys(f.headers), bodyKeys: Object.keys(JSON.parse(f.body)) });
    assert(!serialized.includes('TOKEN_SECRET') && !serialized.includes('Bearer'), 'sanitization self-check failed');
    record('SELF-01', 'PASS', { parser: true, secret_leak: false, network: false });
    return;
  }
  let input;
  try { input = JSON.parse(await new Promise(resolve => { let s = ''; process.stdin.setEncoding('utf8'); process.stdin.on('data', c => s += c); process.stdin.on('end', () => resolve(s)); })); }
  catch { record('SETUP', 'BLOCKED', { reason: 'invalid_stdin_json' }); return; }
  const accounts = input?.accounts;
  const chosen = Array.isArray(accounts) ? (accounts.filter(a => ['son', 'nam'].includes(String(a.alias).toLowerCase())).slice(0, 2).length === 2 ? accounts.filter(a => ['son', 'nam'].includes(String(a.alias).toLowerCase())).slice(0, 2) : accounts.slice(0, 2)) : [];
  const base = String(input?.base_url ?? '').replace(/\/$/, '');
  let parsedBase;
  try { parsedBase = new URL(base); } catch {}
  if (!parsedBase || parsedBase.protocol !== 'https:' || parsedBase.username || parsedBase.password || parsedBase.search || parsedBase.hash || parsedBase.pathname.replace(/\/$/, '') !== '/api/v1' || chosen.length < 2 || chosen.some(a => !a.email || !a.password)) {
    record('SETUP', 'BLOCKED', { reason: 'need_base_url_and_two_accounts' }); return;
  }
  const sessions = [];
  let socketA, socketB, conversationId, messageId, sendStarted = false, recallComplete = false;
  const aliases = chosen.map((a, i) => ['son', 'nam'].includes(String(a.alias).toLowerCase()) ? String(a.alias).toLowerCase() : `account${i + 1}`);
  try {
    for (let i = 0; i < 2; i++) {
      const r = await fetchJson(apiUrl(base, '/auth/login'), { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email: chosen[i].email, password: chosen[i].password, device_id: randomUUID(), platform: 'ANDROID', device_name: 'QA chat probe', app_version: '1.0.0' }) });
      const d = dataOf(r.payload); const token = d?.access_token;
      if (r.status !== 200 || !successful(r) || !token || !d?.user_id) { record(`LOGIN-${i + 1}`, 'BLOCKED', { http_status: r.status, ...(r.code ? { code: r.code } : {}) }); return; }
      sessions.push({ token, userId: d.user_id });
      record(`LOGIN-${i + 1}`, 'PASS', { alias: aliases[i], http_status: r.status });
    }
    const conv = await fetchJson(apiUrl(base, '/conversations/direct'), { method: 'POST', headers: { Authorization: `Bearer ${sessions[0].token}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ target_user_id: sessions[1].userId }) });
    if (!successful(conv)) { record('DIRECT', 'BLOCKED', { http_status: conv.status, ...(conv.code ? { code: conv.code } : {}) }); return; }
    conversationId = dataOf(conv.payload)?.conversation_id;
    if (conversationId == null) { record('DIRECT', 'BLOCKED', { http_status: conv.status, reason: 'conversation_id_missing' }); return; }
    record('DIRECT', 'PASS', { http_status: conv.status, reused_or_created: true });

    const wsUrl = `${parsedBase.origin}${parsedBase.pathname.replace(/\/$/, '')}/ws/websocket`;
    socketA = new StompSocket(wsUrl, sessions[0].token); socketB = new StompSocket(wsUrl, sessions[1].token);
    await Promise.all([socketA.ready, socketB.ready]);
    socketA.subscribe('/user/queue/messages', 'qa-a'); socketB.subscribe('/user/queue/messages', 'qa-b');
    await new Promise(resolve => setTimeout(resolve, 250));
    record('WS-CONNECT', 'PASS', { sockets: 2, endpoint: '/api/v1/ws/websocket' });

    const body = JSON.stringify({ conversation_id: conversationId, content: MARKER, message_type: 'TEXT', media_urls: [], reply_to_message_id: null });
    sendStarted = true;
    socketA.send('SEND', { destination: '/app/chat.send', 'content-type': 'application/json' }, body);
    const delivery = await socketB.waitFor(frame => frame.command === 'MESSAGE' && frame.headers.destination === '/user/queue/messages' && frame.body.includes(MARKER));
    if (delivery) {
      try { messageId = dataOf(JSON.parse(delivery.body))?.message_id ?? JSON.parse(delivery.body)?.message_id; } catch {}
      record('DELIVERY', 'PASS', { marker_received: true, payload_keys: (() => { try { return Object.keys(JSON.parse(delivery.body)).slice(0, 20); } catch { return []; } })() });
    } else record('DELIVERY', 'FAIL', { marker_received: false, timeout_seconds: 12 });

    const hist = await fetchJson(apiUrl(base, `/conversations/${encodeURIComponent(conversationId)}/messages?limit=20`), { headers: { Authorization: `Bearer ${sessions[1].token}` } });
    const row = hist.status >= 200 && hist.status < 300 ? messageRows(hist.payload).find(m => m?.content === MARKER) : undefined;
    messageId ??= row?.message_id;
    record('REST-HISTORY', successful(hist) && row ? 'PASS' : 'BLOCKED', { http_status: hist.status, ...(hist.code ? { code: hist.code } : {}), marker_found: Boolean(row), marks_read: true });
    if (messageId == null) return;

    const del = await fetchJson(apiUrl(base, `/messages/${encodeURIComponent(messageId)}`), { method: 'DELETE', headers: { Authorization: `Bearer ${sessions[0].token}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ scope: 'EVERYONE' }) });
    recallComplete = successful(del);
    const after = await fetchJson(apiUrl(base, `/conversations/${encodeURIComponent(conversationId)}/messages?limit=20`), { headers: { Authorization: `Bearer ${sessions[1].token}` } });
    const deletedRow = messageRows(after.payload).find(m => String(m?.message_id ?? m?.id) === String(messageId));
    const revoked = deletedRow?.revoked;
    record('RECALL', !successful(del) ? 'FAIL' : !successful(after) ? 'BLOCKED' : revoked === true || !deletedRow ? 'PASS' : revoked === false ? 'FAIL' : 'WAITING', { delete_http_status: del.status, ...(del.code ? { delete_code: del.code } : {}), verify_http_status: after.status, ...(after.code ? { verify_code: after.code } : {}), revoked_flag: typeof revoked === 'boolean' ? revoked : 'field_missing', marker_content_logged: false });
  } catch (error) {
    record('FLOW', 'BLOCKED', { reason: error?.message === 'stomp connect timeout' ? 'ws_connect_timeout' : error?.message === 'websocket error' ? 'ws_error' : 'request_or_protocol_error' });
  } finally {
    if (sendStarted && messageId == null && conversationId != null && sessions.length > 0) {
      try {
        const recover = await fetchJson(apiUrl(base, `/conversations/${encodeURIComponent(conversationId)}/messages?limit=20`), { headers: { Authorization: `Bearer ${sessions[0].token}` } });
        const markerRow = successful(recover) ? messageRows(recover.payload).find(m => m?.content === MARKER) : undefined;
        messageId = markerRow?.message_id;
      } catch {}
    }
    if (sendStarted && !recallComplete && messageId != null && conversationId != null && sessions.length > 0) {
      try {
        const cleanup = await fetchJson(apiUrl(base, `/messages/${encodeURIComponent(messageId)}`), { method: 'DELETE', headers: { Authorization: `Bearer ${sessions[0].token}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ scope: 'EVERYONE' }) });
        recallComplete = successful(cleanup);
        if (recallComplete) {
          const verify = await fetchJson(apiUrl(base, `/conversations/${encodeURIComponent(conversationId)}/messages?limit=20`), { headers: { Authorization: `Bearer ${sessions[1]?.token ?? sessions[0].token}` } });
          const recoveredRow = messageRows(verify.payload).find(m => m?.content === MARKER || String(m?.message_id) === String(messageId));
          const removed = successful(verify) && (!recoveredRow || recoveredRow.revoked === true);
          record('CLEANUP', removed ? 'PASS' : successful(verify) && recoveredRow?.revoked === false ? 'FAIL' : 'WAITING', { delete_http_status: cleanup.status, verify_http_status: verify.status, marker_only: true, removed_or_revoked: removed });
        } else record('CLEANUP', 'BLOCKED', { http_status: cleanup.status, ...(cleanup.code ? { code: cleanup.code } : {}), marker_only: true });
      } catch { record('CLEANUP', 'BLOCKED', { marker_only: true }); }
    } else if (sendStarted && !recallComplete) record('CLEANUP', 'BLOCKED', { marker_left_unconfirmed: true });
    socketA?.close(); socketB?.close();
    for (let i = 0; i < sessions.length; i++) {
      try {
        const r = await fetchJson(apiUrl(base, '/auth/logout'), { method: 'POST', headers: { Authorization: `Bearer ${sessions[i].token}` } });
        record(`LOGOUT-${i + 1}`, successful(r) ? 'PASS' : 'BLOCKED', { alias: aliases[i], http_status: r.status, ...(r.code ? { code: r.code } : {}) });
      } catch { record(`LOGOUT-${i + 1}`, 'BLOCKED', { alias: aliases[i], reason: 'request_error' }); }
    }
  }
}

await run();
const output = { source_sha: sha, timestamp_utc: now(), mode: selfCheck ? 'offline_self_check' : 'real_api_probe', results };
const json = JSON.stringify(output, null, 2);
if (outputPath) {
  const { mkdir, writeFile } = await import('node:fs/promises');
  const { dirname } = await import('node:path');
  await mkdir(dirname(outputPath), { recursive: true });
  await writeFile(outputPath, `${json}\n`, { mode: 0o600 });
} else process.stdout.write(`${json}\n`);
if (!selfCheck && results.some(r => r.status === 'FAIL')) process.exitCode = 1;
else if (!selfCheck && results.some(r => r.status === 'BLOCKED')) process.exitCode = 2;
