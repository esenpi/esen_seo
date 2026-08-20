import { createServer } from 'node:http';
import { readFileSync, statSync, writeFileSync } from 'node:fs';
import { extname, join, normalize, resolve } from 'node:path';
import { gzipSync } from 'node:zlib';
import { chromium } from 'playwright';

const here = new URL('.', import.meta.url).pathname;
const cells = [
  { id: 'plain', label: 'Hand-written DOM', root: join(here, 'fixtures/plain') },
  { id: 'next', label: 'Next.js 16.2.11', root: join(here, 'fixtures/next/out') },
  { id: 'esen', label: 'esen_seo DOM-first', root: join(here, 'build/esen') },
  { id: 'flutter', label: 'visibleShell + Flutter', root: join(here, 'fixtures/flutter/build/web') },
];
const order = [
  ['plain', 'next', 'esen', 'flutter'],
  ['next', 'esen', 'flutter', 'plain'],
  ['esen', 'flutter', 'plain', 'next'],
  ['flutter', 'plain', 'next', 'esen'],
  ['plain', 'next', 'esen', 'flutter'],
  ['next', 'esen', 'flutter', 'plain'],
  ['esen', 'flutter', 'plain', 'next'],
];
const ceilings = {
  criticalJsGzipKiB: [25, 25],
  totalTransferKiB: [100, 100],
  lcpMs: [2000, 2500],
  tbtMs: [150, 200],
  firstInteractionMs: [2200, 2700],
  scriptedInpMs: [200, 200],
  cls: [0.05, 0.05],
};
const metricLabels = {
  criticalJsGzipKiB: 'Critical JS gzip (KiB)',
  totalTransferKiB: 'Total transfer (KiB)',
  lcpMs: 'LCP (ms)',
  tbtMs: 'TBT (ms)',
  firstInteractionMs: 'First interaction (ms)',
  scriptedInpMs: 'Scripted INP proxy (ms)',
  cls: 'CLS',
};

const servers = [];
for (let index = 0; index < cells.length; index++) {
  const cell = cells[index];
  const indexFile = join(cell.root, 'index.html');
  statSync(indexFile);
  verifyCompleteSource(cell.id, indexFile);
  cell.port = 9360 + index;
  cell.inlineJsGzip = inlineJavaScriptGzip(indexFile);
  const server = staticServer(cell.root, cell.id === 'plain');
  await new Promise(resolveReady => server.listen(cell.port, '127.0.0.1', resolveReady));
  servers.push(server);
}

const executablePath = process.env.CHROME_PATH ||
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const browser = await chromium.launch({ headless: true, executablePath });
const browserVersion = browser.version();
const results = Object.fromEntries(cells.map(cell => [cell.id, []]));
try {
  for (let run = 0; run < order.length; run++) {
    for (const id of order[run]) {
      const cell = cells.find(candidate => candidate.id === id);
      const measurement = await measure(browser, cell);
      results[id].push(measurement);
      process.stdout.write(`run ${run + 1}/7 ${id}: ${JSON.stringify(measurement)}\n`);
    }
  }
} finally {
  await browser.close();
  await Promise.all(servers.map(server => new Promise(done => server.close(done))));
}

const summary = Object.fromEntries(cells.map(cell => [cell.id, aggregate(results[cell.id])]));
const checks = acceptance(summary);
const metadata = {
  measuredAt: new Date().toISOString(),
  browser: browserVersion,
  node: process.version,
  runsPerCell: 7,
  viewport: '390x844 @2x',
  network: '1.6 Mbit/s down, 750 Kbit/s up, 150 ms RTT',
  cpu: '4x slowdown',
};
const markdown = report(metadata, summary, checks);
process.stdout.write(`\n${markdown}`);
if (process.argv.includes('--write')) writeFileSync(join(here, 'RESULTS.md'), markdown);
if (checks.some(check => !check.pass)) process.exitCode = 1;

async function measure(browserInstance, cell) {
  const context = await browserInstance.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2,
  });
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  await cdp.send('Network.enable');
  await cdp.send('Network.setCacheDisabled', { cacheDisabled: true });
  await cdp.send('Network.emulateNetworkConditions', {
    offline: false,
    latency: 150,
    downloadThroughput: 200000,
    uploadThroughput: 93750,
    connectionType: 'cellular4g',
  });
  await cdp.send('Emulation.setCPUThrottlingRate', { rate: 4 });

  let totalTransfer = 0;
  let externalScriptTransfer = 0;
  const requested = [];
  page.on('response', async response => {
    if (!response.url().startsWith(`http://127.0.0.1:${cell.port}/`)) return;
    requested.push(response.url());
    const length = Number((await response.allHeaders())['content-length'] || 0);
    totalTransfer += length;
    if (response.request().resourceType() === 'script') externalScriptTransfer += length;
  });
  await page.addInitScript(() => {
    window.__esenBench = { cls: 0, lcp: 0, longTasks: [] };
    new PerformanceObserver(list => {
      for (const entry of list.getEntries()) window.__esenBench.lcp = entry.startTime;
    }).observe({ type: 'largest-contentful-paint', buffered: true });
    new PerformanceObserver(list => {
      for (const entry of list.getEntries()) {
        if (!entry.hadRecentInput) window.__esenBench.cls += entry.value;
      }
    }).observe({ type: 'layout-shift', buffered: true });
    new PerformanceObserver(list => {
      for (const entry of list.getEntries()) window.__esenBench.longTasks.push(entry.duration);
    }).observe({ type: 'longtask', buffered: true });
  });

  await page.goto(`http://127.0.0.1:${cell.port}/`, {
    waitUntil: 'domcontentloaded',
    timeout: 90000,
  });
  const latencies = [];
  if (cell.id === 'flutter') {
    await page.waitForSelector('flutter-view', { timeout: 90000 });
    await page.getByRole('button', { name: 'Enable accessibility' })
      .press('Enter', { timeout: 30000 });
    await page.waitForTimeout(100);
    latencies.push(await interactFlutter(page, 'Next', 'Review'));
    var firstInteractionMs = await page.evaluate(() => performance.now());
    latencies.push(await interactFlutter(page, 'Next', 'Publish'));
    latencies.push(await interactFlutter(page, 'Next', 'Draft'));
    latencies.push(await interactFlutter(page, 'Back', 'Publish'));
    latencies.push(await interactFlutter(page, 'Review', 'Review'));
  } else {
    await page.waitForSelector('#benchmark-stepper[data-esen-enhanced="true"]', {
      timeout: 30000,
    });
    latencies.push(await interactDom(page, 'Next', 1));
    var firstInteractionMs = await page.evaluate(() => performance.now());
    latencies.push(await interactDom(page, 'Next', 2));
    latencies.push(await interactDom(page, 'Next', 0));
    latencies.push(await interactDom(page, 'Back', 2));
    latencies.push(await interactDom(page, 'Review', 1));
  }
  if (cell.id === 'esen' && requested.some(url => /flutter_bootstrap\.js|main\.dart\.js|canvaskit/i.test(url))) {
    throw new Error('DOM-first requested a Flutter artifact');
  }

  await page.waitForLoadState('load', { timeout: 90000 }).catch(() => {});
  await page.waitForTimeout(1000);
  const performance = await page.evaluate(() => ({
    ...window.__esenBench,
    navigation: performance.getEntriesByType('navigation')[0]?.duration || 0,
  }));
  await context.close();

  return {
    criticalJsGzipKiB: round((cell.inlineJsGzip + externalScriptTransfer) / 1024),
    totalTransferKiB: round(totalTransfer / 1024),
    lcpMs: round(performance.lcp),
    tbtMs: round(performance.longTasks.reduce((sum, duration) => sum + Math.max(0, duration - 50), 0)),
    firstInteractionMs: round(firstInteractionMs),
    scriptedInpMs: round(Math.max(...latencies)),
    cls: round(performance.cls, 4),
  };
}

async function interactDom(page, label, expected) {
  return page.evaluate(async ({ label, expected }) => {
    const root = document.getElementById('benchmark-stepper');
    const button = [...root.querySelectorAll('button')]
      .find(candidate => candidate.textContent === label);
    const panels = [...root.querySelectorAll('[data-esen-step-panel]')];
    const start = performance.now();
    button.click();
    for (let frame = 0; frame < 120; frame++) {
      if (!panels[expected].hidden && document.activeElement === panels[expected]) break;
      await new Promise(requestAnimationFrame);
    }
    if (panels[expected].hidden || document.activeElement !== panels[expected]) {
      throw new Error(`interaction did not select and focus panel ${expected}`);
    }
    await new Promise(requestAnimationFrame);
    await new Promise(requestAnimationFrame);
    return performance.now() - start;
  }, { label, expected });
}

async function interactFlutter(page, controlLabel, expectedPanelLabel) {
  const start = await page.evaluate(() => performance.now());
  const control = page.getByRole('button', {
    name: controlLabel,
    exact: true,
  }).last();
  await control.click({ timeout: 30000 });
  await page.waitForFunction(label =>
    document.activeElement?.textContent?.trim().startsWith(label),
  expectedPanelLabel, { timeout: 30000 });
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  return await page.evaluate(started => performance.now() - started, start);
}

function verifyCompleteSource(id, file) {
  const html = readFileSync(file, 'utf8');
  for (const text of ['Draft', 'Review', 'Publish', 'Write the complete article', 'Check facts', 'Release the approved document']) {
    if (!html.includes(text)) throw new Error(`${id} source omits ${text}`);
  }
  if (id === 'esen' && /flutter_bootstrap\.js|main\.dart\.js|canvaskit/i.test(html)) {
    throw new Error('DOM-first source references a Flutter artifact');
  }
}

function staticServer(root, serveShared) {
  return createServer((request, response) => {
    let pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    let file;
    if (serveShared && pathname === '/shared.css') {
      file = join(here, 'fixtures/shared.css');
    } else {
      if (pathname.endsWith('/')) pathname += 'index.html';
      const candidate = resolve(root, `.${normalize(pathname)}`);
      const rootPath = resolve(root);
      if (candidate !== rootPath && !candidate.startsWith(`${rootPath}/`)) {
        response.writeHead(403).end();
        return;
      }
      file = candidate;
    }
    try {
      const body = readFileSync(file);
      const compressed = gzipSync(body, { level: 9 });
      response.writeHead(200, {
        'content-type': mime(extname(file)),
        'content-encoding': 'gzip',
        'content-length': compressed.length,
        'cache-control': 'no-store',
      });
      response.end(compressed);
    } catch (_) {
      response.writeHead(404).end('not found');
    }
  });
}

function inlineJavaScriptGzip(file) {
  const html = readFileSync(file, 'utf8');
  let total = 0;
  for (const match of html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)) {
    if (match[1].trim()) total += gzipSync(match[1], { level: 9 }).length;
  }
  return total;
}

function aggregate(rows) {
  const result = {};
  for (const metric of Object.keys(metricLabels)) {
    const values = rows.map(row => row[metric]).sort((a, b) => a - b);
    result[metric] = {
      median: values[Math.floor(values.length / 2)],
      p75: values[Math.ceil(values.length * 0.75) - 1],
      values,
    };
  }
  return result;
}

function acceptance(summary) {
  const checks = [];
  for (const [metric, [medianLimit, p75Limit]] of Object.entries(ceilings)) {
    const value = summary.esen[metric];
    checks.push({
      name: `${metric} absolute ceiling`,
      pass: value.median <= medianLimit && value.p75 <= p75Limit,
      detail: `${value.median}/${value.p75} <= ${medianLimit}/${p75Limit}`,
    });
    if (metric === 'cls') continue;
    const next = summary.next[metric].median;
    const flutter = summary.flutter[metric].median;
    if (next < flutter) {
      const dom = value.median;
      checks.push({
        name: `${metric} relative bound`,
        pass: Math.abs(dom - next) < Math.abs(dom - flutter),
        detail: `DOM ${dom}, Next ${next}, Flutter ${flutter}`,
      });
    }
  }
  return checks;
}

function report(metadata, summary, checks) {
  const lines = [
    '# DOM-first Stepper Effects Benchmark Results',
    '',
    `Measured: ${metadata.measuredAt}`,
    '',
    `Dart 3.6.2; Flutter 3.27.4; Browser: ${metadata.browser}; Node: ${metadata.node}; Next.js 16.2.11; React 19.2.0.`,
    `${metadata.runsPerCell} cold runs per cell; ${metadata.viewport}; ${metadata.network}; ${metadata.cpu}.`,
    '',
    '| Metric (median / p75) | Hand DOM | Next.js | DOM-first | Flutter |',
    '| --- | ---: | ---: | ---: | ---: |',
  ];
  for (const [metric, label] of Object.entries(metricLabels)) {
    lines.push(`| ${label} | ${format(summary.plain[metric])} | ${format(summary.next[metric])} | ${format(summary.esen[metric])} | ${format(summary.flutter[metric])} |`);
  }
  lines.push('', '## Acceptance', '');
  for (const check of checks) lines.push(`- ${check.pass ? 'PASS' : 'FAIL'}: ${check.name} (${check.detail})`);
  lines.push('', checks.every(check => check.pass)
    ? '**Decision: keep the compiled candidate. Every applicable gate passed.**'
    : '**Decision: replace or reduce the candidate before release.**', '');
  lines.push(
    'The transfer figures are gzip-compressed response bodies; critical JavaScript',
    'adds gzip-compressed inline scripts to external script responses. Every DOM',
    'interaction requires both the selected panel and its focus effect before two',
    'animation frames complete. The scripted proxy is a lab gate, not field INP;',
    'the separate field target remains 200 ms at p75 after release.',
    '',
  );
  return lines.join('\n');
}

function format(value) { return `${value.median} / ${value.p75}`; }
function round(value, digits = 1) { return Number(value.toFixed(digits)); }
function mime(extension) {
  return ({
    '.css': 'text/css; charset=utf-8',
    '.html': 'text/html; charset=utf-8',
    '.js': 'text/javascript; charset=utf-8',
    '.json': 'application/json',
    '.wasm': 'application/wasm',
    '.png': 'image/png',
  })[extension] || 'application/octet-stream';
}
