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
const smoke = process.argv.includes('--smoke');
const runOrder = smoke ? [order[0]] : order;
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

verifyBundleManifest();
const servers = [];
for (let index = 0; index < cells.length; index++) {
  const cell = cells[index];
  const indexFile = join(cell.root, 'index.html');
  statSync(indexFile);
  verifyCompleteSource(cell.id, indexFile);
  cell.port = 9380 + index;
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
  for (let run = 0; run < runOrder.length; run++) {
    for (const id of runOrder[run]) {
      const cell = cells.find(candidate => candidate.id === id);
      const measurement = await measure(browser, cell);
      results[id].push(measurement);
      process.stdout.write(`run ${run + 1}/${runOrder.length} ${id}: ${JSON.stringify(measurement)}\n`);
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
  runsPerCell: runOrder.length,
  viewport: '390x844 @2x',
  network: '1.6 Mbit/s down, 750 Kbit/s up, 150 ms RTT',
  cpu: '4x slowdown',
};
const markdown = report(metadata, summary, checks);
process.stdout.write(`\n${markdown}`);
if (!smoke && process.argv.includes('--write')) {
  writeFileSync(join(here, 'SHIPPED_RESULTS.md'), markdown);
}
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
    latencies.push(await interactFlutter(page, 'tab-second'));
    var firstInteractionMs = await page.evaluate(() => performance.now());
    latencies.push(await interactFlutter(page, 'carousel-next'));
    latencies.push(await interactFlutter(page, 'carousel-end'));
    latencies.push(await interactFlutter(page, 'step-next'));
    latencies.push(await interactFlutter(page, 'tab-first'));
  } else {
    await page.waitForFunction(() => ['benchmark-tabs', 'benchmark-carousel', 'benchmark-stepper']
      .every(id => document.getElementById(id)?.dataset.esenEnhanced === 'true'),
    null, { timeout: 30000 });
    latencies.push(await interactDom(page, 'tab-second'));
    var firstInteractionMs = await page.evaluate(() => performance.now());
    latencies.push(await interactDom(page, 'carousel-next'));
    latencies.push(await interactDom(page, 'carousel-end'));
    latencies.push(await interactDom(page, 'step-next'));
    latencies.push(await interactDom(page, 'tab-first'));
  }
  if (cell.id === 'esen') {
    if (requested.some(url => /flutter_bootstrap\.js|main\.dart\.js|canvaskit|skwasm/i.test(url))) {
      throw new Error('DOM-first requested a Flutter artifact');
    }
    if (requested.filter(url => /runtime/i.test(new URL(url).pathname)).length !== 0) {
      throw new Error('DOM-first requested a second runtime artifact');
    }
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

async function interactDom(page, action) {
  return page.evaluate(async actionName => {
    const tabs = [...document.querySelectorAll('#benchmark-tabs [role="tab"]')];
    const slides = [...document.querySelectorAll('#benchmark-carousel [data-esen-carousel-slide]')];
    const stepButtons = [...document.querySelectorAll('#benchmark-stepper [data-esen-step-button], #benchmark-stepper .esen-seo-step-button')];
    const stepPanels = [...document.querySelectorAll('#benchmark-stepper [data-esen-step-panel]')];
    const selectedTab = () => tabs.findIndex(tab => tab.getAttribute('aria-selected') === 'true');
    const selectedSlide = () => slides.findIndex(slide => !slide.hidden);
    const selectedStep = () => stepButtons.findIndex(button => button.getAttribute('aria-current') === 'step');
    const accepted = () => {
      const expectedTab = actionName === 'tab-first' ? 0 : 1;
      const expectedSlide = ['carousel-end', 'step-next', 'tab-first'].includes(actionName)
        ? 2
        : actionName === 'carousel-next' ? 1 : 0;
      const expectedStep = ['step-next', 'tab-first'].includes(actionName) ? 1 : 0;
      const focusOk = actionName !== 'step-next' || document.activeElement === stepPanels[1];
      return selectedTab() === expectedTab && selectedSlide() === expectedSlide &&
        selectedStep() === expectedStep && focusOk;
    };

    const start = performance.now();
    if (actionName === 'tab-second') {
      tabs[1].click();
    } else if (actionName === 'carousel-next') {
      document.querySelector('#benchmark-carousel [aria-label="Next slide"]').click();
    } else if (actionName === 'carousel-end') {
      document.querySelector('#benchmark-carousel [aria-label="Next slide"]')
        .dispatchEvent(new KeyboardEvent('keydown', { key: 'End', bubbles: true }));
    } else if (actionName === 'step-next') {
      const next = document.getElementById('benchmark-stepper-next') ||
        [...document.querySelectorAll('#benchmark-stepper button')]
          .find(button => button.textContent === 'Next');
      next.click();
    } else {
      tabs[0].click();
    }
    for (let frame = 0; !accepted() && frame < 120; frame++) {
      await new Promise(requestAnimationFrame);
    }
    if (!accepted()) throw new Error(`bundle interaction failed: ${actionName}`);
    await new Promise(requestAnimationFrame);
    await new Promise(requestAnimationFrame);
    return performance.now() - start;
  }, action);
}

async function interactFlutter(page, action) {
  const start = await page.evaluate(() => performance.now());
  if (action === 'tab-second') {
    await page.getByRole('button', { name: 'Architecture', exact: true })
      .last().click({ timeout: 30000 });
    await waitForFlutterText(page, 'Pure Dart owns every state transition.');
  } else if (action === 'carousel-next' || action === 'carousel-end') {
    await page.getByRole('button', { name: 'Next slide', exact: true })
      .last().click({ timeout: 30000 });
    const expected = action === 'carousel-next' ? 'Verified runtime' : 'Native parity';
    await waitForFlutterText(page, expected);
  } else if (action === 'step-next') {
    await page.getByRole('button', { name: 'Next', exact: true })
      .last().click({ timeout: 30000 });
    await page.waitForFunction(() =>
      document.activeElement?.textContent?.trim().startsWith('Review'),
    null, { timeout: 30000 });
  } else {
    await page.getByRole('button', { name: 'Overview', exact: true })
      .last().click({ timeout: 30000 });
    await waitForFlutterText(page, 'The page starts as complete HTML.');
    await waitForFlutterText(page, 'Native parity');
    await waitForFlutterText(page, 'Review');
  }
  await page.evaluate(() => new Promise(resolve =>
    requestAnimationFrame(() => requestAnimationFrame(resolve))));
  return await page.evaluate(started => performance.now() - started, start);
}

async function waitForFlutterText(page, expected) {
  await page.waitForFunction(text =>
    [...document.querySelectorAll('flt-semantics')].some(element => {
      const bounds = element.getBoundingClientRect();
      return element.textContent?.includes(text) && bounds.width > 0 && bounds.height > 0;
    }), expected, { timeout: 30000 });
}

function verifyBundleManifest() {
  const file = join(
    here,
    'fixtures/application/build/esen_seo/runtimes/',
    'bundle+tabs+carousel+stepper-effects+benchmark-page.json',
  );
  const manifest = JSON.parse(readFileSync(file, 'utf8'));
  if (manifest.kind !== 'bundle' || manifest.id !== 'benchmark-page' ||
      JSON.stringify(manifest.members) !== JSON.stringify(['tabs', 'carousel', 'stepper-effects'])) {
    throw new Error('runtime bundle manifest has unexpected identity or members');
  }
}

function verifyCompleteSource(id, file) {
  const html = readFileSync(file, 'utf8');
  const required = [
    'The page starts as complete HTML.',
    'Pure Dart owns every state transition.',
    'One verified artifact enhances the route.',
    'Every slide exists before JavaScript.',
    'The manifest binds code and member kinds.',
    'Flutter calls the same Carousel transition.',
    'Write the complete article before review.',
    'Check facts, links and semantic structure.',
    'Release the approved document to readers.',
  ];
  for (const text of required) {
    if (!html.includes(text)) throw new Error(`${id} source omits ${text}`);
  }
  if (id === 'esen') {
    if (/flutter_bootstrap\.js|main\.dart\.js|canvaskit|skwasm/i.test(html)) {
      throw new Error('DOM-first source references a Flutter artifact');
    }
    const runtimes = [...html.matchAll(/<script[^>]*data-esen-seo-dom-first-application-runtime=/gi)];
    if (runtimes.length !== 1) {
      throw new Error(`DOM-first source has ${runtimes.length} application runtimes`);
    }
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
    '# Shipped Runtime Bundle Benchmark Results',
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
  for (const check of checks) {
    lines.push(`- ${check.pass ? 'PASS' : 'FAIL'}: ${check.name} (${check.detail})`);
  }
  lines.push('', checks.every(check => check.pass)
    ? '**Decision: keep the supported bundle candidate. Every applicable gate passed.**'
    : '**Decision: replace or reduce the supported bundle candidate before release.**', '');
  lines.push(
    'The transfer figures are gzip-compressed response bodies; critical JavaScript',
    'adds gzip-compressed inline scripts to external script responses. The fixed',
    'sequence exercises all three independent state slices, Carousel keyboard',
    'wiring and the Stepper focus effect. The scripted proxy is a lab gate, not',
    'field INP; the separate field target remains 200 ms at p75 after release.',
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
