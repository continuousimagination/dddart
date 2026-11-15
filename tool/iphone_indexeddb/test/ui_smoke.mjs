// Optional compiled-UI smoke check. Node >=22, Chrome, and serve.py required.
// Desktop evidence only: this does not establish physical-iPhone behavior.
import {spawn} from 'node:child_process';
import {mkdtemp, readFile, writeFile, rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';

const origin = process.env.PROBE_URL || 'http://127.0.0.1:8787/';
const chrome = process.env.CHROME_EXECUTABLE || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const output = process.env.PROBE_OUTPUT || path.join(tmpdir(), 'dddart-77-desktop-smoke.json');
const profile = await mkdtemp(path.join(tmpdir(), 'dddart-77-chrome-'));
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
let child, browser, page;
class CDP {
  constructor(ws) {
    this.ws = ws; this.next = 0; this.pending = new Map();
    ws.onmessage = event => {
      const data = JSON.parse(event.data), pending = this.pending.get(data.id);
      if (pending) {
        this.pending.delete(data.id);
        data.error ? pending.reject(new Error(JSON.stringify(data.error))) : pending.resolve(data.result);
      }
    };
    ws.onclose = () => {
      for (const pending of this.pending.values()) pending.reject(new Error('CDP connection closed'));
      this.pending.clear();
    };
  }
  static async connect(url) {
    const ws = new WebSocket(url);
    await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
    return new CDP(ws);
  }
  send(method, params = {}) {
    const id = ++this.next;
    return new Promise((resolve, reject) => {
      this.pending.set(id, {resolve, reject});
      this.ws.send(JSON.stringify({id, method, params}));
    });
  }
  async evaluate(expression) {
    const result = await this.send('Runtime.evaluate', {expression, returnByValue: true, awaitPromise: true});
    if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
    return result.result.value;
  }
}
async function launch() {
  await rm(path.join(profile, 'DevToolsActivePort'), {force: true});
  child = spawn(chrome, ['--headless=new', '--no-first-run', '--no-default-browser-check',
    '--remote-debugging-port=0', `--user-data-dir=${profile}`, 'about:blank'], {stdio: 'ignore'});
  for (let i = 0; i < 100; i++) {
    try {
      const [port, endpoint] = (await readFile(path.join(profile, 'DevToolsActivePort'), 'utf8')).trim().split('\n');
      browser = await CDP.connect(`ws://127.0.0.1:${port}${endpoint}`);
      return port;
    } catch { await sleep(100); }
  }
  throw new Error('Chrome debugging endpoint did not start');
}
async function open(port, url) {
  const {targetId} = await browser.send('Target.createTarget', {url});
  const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  page = await CDP.connect(targets.find(t => t.id === targetId).webSocketDebuggerUrl);
  await page.send('Page.enable');
  return targetId;
}
async function until(expression, label) {
  for (let i = 0; i < 150; i++) {
    try { if (await page.evaluate(expression)) return; } catch {}
    await sleep(100);
  }
  throw new Error(`${label}: ${await page.evaluate("document.body.innerText + '\\nLOG\\n' + document.getElementById('log')?.textContent")}`);
}
const ready = id => until(`document.getElementById(${JSON.stringify(id)})?.disabled === false`, `Button ${id}`);
const click = async id => {
  await ready(id);
  await page.evaluate(`document.getElementById(${JSON.stringify(id)}).click()`);
};
const verify = async () => {
  await ready('verify');
  await page.evaluate("document.getElementById('confirm').checked=true");
  await click('verify');
  await ready('reload');
};
async function stopBrowser() {
  const exited = new Promise(resolve => child.once('exit', resolve));
  await browser.send('Browser.close').catch(() => {});
  await exited;
}
try {
  let port = await launch();
  let targetId = await open(port, origin);
  await ready('baseline');
  await page.send('Emulation.setDeviceMetricsOverride', {width: 390, height: 844, deviceScaleFactor: 1, mobile: true});
  await page.evaluate("document.getElementById('model').value='Desktop Chrome smoke test';document.getElementById('ios').value='macOS, not iOS'");
  await click('baseline'); await ready('unknown');
  const runUrl = await page.evaluate('location.href');
  const firstDocument = await page.evaluate('performance.timeOrigin');
  await click('unknown');
  await until(`performance.timeOrigin !== ${firstDocument}`, 'Lost-result reload');
  await ready('reconcile');
  await click('reconcile'); await ready('failures');
  await click('failures'); await ready('reload');
  const secondDocument = await page.evaluate('performance.timeOrigin');
  await click('reload');
  await until(`performance.timeOrigin !== ${secondDocument}`, 'Lifecycle reload');
  await verify();
  await click('background');
  const other = await browser.send('Target.createTarget', {url:'about:blank'});
  await browser.send('Target.activateTarget', {targetId:other.targetId});
  await sleep(300);
  await browser.send('Target.activateTarget', {targetId});
  await verify();
  await click('reopen');
  await stopBrowser();
  port = await launch();
  targetId = await open(port, runUrl);
  await verify();
  await until("document.getElementById('status').innerText.startsWith('Checklist complete')", 'Checklist completion');
  await click('report');
  const report = JSON.parse(await page.evaluate("document.getElementById('report-text').value"));
  assert.equal(report.summary.hasFailures, false);
  assert.deepEqual(report.summary.lifecyclePassed, ['reload','background','reopen']);
  assert.equal(report.testedSha, '62af23ffa369c2d2cba13c93e39eee4c90c2325d');
  assert.ok(report.events.filter(e => e.status === 'pass').length > 100);
  await writeFile(output, JSON.stringify(report, null, 2));
  await page.send('Emulation.setDeviceMetricsOverride', {width:390,height:844,deviceScaleFactor:1,mobile:true});
  const screenshot = await page.send('Page.captureScreenshot', {captureBeyondViewport:true});
  await writeFile(output.replace(/\.json$/, '.png'), Buffer.from(screenshot.data, 'base64'));
  // Losing the independent manifest must be visible, never start a new baseline.
  await browser.send('Target.closeTarget', {targetId});
  await open(port, 'about:blank');
  await page.send('Storage.clearDataForOrigin', {origin:new URL(origin).origin, storageTypes:'local_storage'});
  await page.send('Page.navigate', {url:runUrl});
  await until("document.getElementById('run').innerText.includes('Run manifest missing')", 'Manifest-loss detection');
  assert.equal(await page.evaluate("document.getElementById('baseline').disabled"), true);
  console.log(`PASS: compiled UI, reload, background, full Chrome restart, report export, missing-manifest detection. ${output}`);
} finally {
  if (child && child.exitCode === null) await stopBrowser().catch(() => child.kill());
  await rm(profile, {recursive:true,force:true});
}
