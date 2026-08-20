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
  cell.port = 9340 + index;
  cell.inlineJsGzip = inlineJavaScriptGzip(indexFile);
  const server = staticServer(cell.root);
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
  page.on('response', async response => {
    if (!response.url().startsWith(`http://127.0.0.1:${cell.port}/`)) return;
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

  await page.goto(`http://127.0.0.1:${cell.port}/?campaign=bench#catalog`, {
    waitUntil: 'domcontentloaded',
    timeout: 90000,
  });
  let firstInteractionMs = null;
  const latencies = [];
  if (cell.id === 'flutter') {
    await page.waitForSelector('flutter-view', { timeout: 90000 });
    await page.waitForFunction(
      () => document.querySelector('#esen-seo-content')?.hasAttribute('inert'),
      null,
      { timeout: 90000 },
    );
  } else {
    await page.waitForSelector('#benchmark-collection[data-esen-enhanced="true"]', {
      timeout: 30000,
    });
    latencies.push(await interact(page, 'search'));
    firstInteractionMs = await page.evaluate(() => performance.now());
    latencies.push(await interact(page, 'clear'));
    latencies.push(await interact(page, 'category'));
    latencies.push(await interact(page, 'sort'));
    latencies.push(await interact(page, 'next'));
    latencies.push(await interact(page, 'back'));
    latencies.push(await interact(page, 'forward'));
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
    scriptedInpMs: latencies.length ? round(Math.max(...latencies)) : null,
    cls: round(performance.cls, 4),
  };
}

async function interact(page, action) {
  return page.evaluate(async actionName => {
    const root = document.getElementById('benchmark-collection');
    const prefix = 'esen.benchmark-collection.';
    const input = root.querySelector('input[type="search"]');
    const button = label => [...root.querySelectorAll('button')]
      .find(candidate => candidate.getAttribute('aria-label') === label);
    const visibleTitles = () => [...root.querySelectorAll('.esen-seo-collection-item')]
      .filter(item => !item.hidden)
      .map(item => item.querySelector('h2')?.textContent);
    const resultCount = () => Number.parseInt(
      root.querySelector('.esen-seo-collection-results')?.textContent || '',
      10,
    );
    const currentUrl = () => new URL(location.href);
    const commonUrlIsIntact = () => {
      const url = currentUrl();
      return url.searchParams.get('campaign') === 'bench' && url.hash === '#catalog';
    };
    const selected = label => button(label)?.getAttribute('aria-pressed') === 'true';
    const pageIs = number => root.querySelector('.esen-seo-collection-page')?.textContent
      .startsWith(`Page ${number} /`);
    const accepted = () => {
      const url = currentUrl();
      if (!commonUrlIsIntact()) return false;
      if (actionName === 'search') {
        return input.value === 'dart' && resultCount() === 1 &&
          visibleTitles()[0] === 'Dart Rendering Guide' &&
          url.searchParams.get(prefix + 'q') === 'dart';
      }
      if (actionName === 'clear') {
        return input.value === '' && resultCount() === 12 &&
          url.searchParams.get(prefix + 'q') === null;
      }
      if (actionName === 'category') {
        return selected('Guides') && resultCount() === 8 && pageIs(1) &&
          url.searchParams.get(prefix + 'category') === 'guides';
      }
      if (actionName === 'sort' || actionName === 'back') {
        return selected('Guides') && selected('Title') && pageIs(1) &&
          visibleTitles()[0] === 'Accessible Tabs Guide' &&
          url.searchParams.get(prefix + 'category') === 'guides' &&
          url.searchParams.get(prefix + 'sort') === 'title' &&
          url.searchParams.get(prefix + 'page') === null;
      }
      return selected('Guides') && selected('Title') && pageIs(2) &&
        visibleTitles()[0] === 'Dart Rendering Guide' &&
        url.searchParams.get(prefix + 'category') === 'guides' &&
        url.searchParams.get(prefix + 'sort') === 'title' &&
        url.searchParams.get(prefix + 'page') === '2';
    };

    const start = performance.now();
    if (actionName === 'search' || actionName === 'clear') {
      const value = actionName === 'search' ? 'dart' : '';
      const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
      setter.call(input, value);
      input.dispatchEvent(new Event('input', { bubbles: true }));
    } else if (actionName === 'category') {
      button('Guides').click();
    } else if (actionName === 'sort') {
      button('Title').click();
    } else if (actionName === 'next') {
      button('Next').click();
    } else if (actionName === 'back') {
      history.back();
    } else {
      history.forward();
    }
    for (let frame = 0; !accepted() && frame < 120; frame++) {
      await new Promise(requestAnimationFrame);
    }
    if (!accepted()) throw new Error(`collection interaction failed: ${actionName}`);
    await new Promise(requestAnimationFrame);
    await new Promise(requestAnimationFrame);
    return performance.now() - start;
  }, action);
}

function staticServer(root) {
  return createServer((request, response) => {
    let pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    if (pathname.endsWith('/')) pathname += 'index.html';
    const candidate = resolve(root, `.${normalize(pathname)}`);
    const rootPath = resolve(root);
    if (candidate !== rootPath && !candidate.startsWith(`${rootPath}/`)) {
      response.writeHead(403).end();
      return;
    }
    try {
      const body = readFileSync(candidate);
      const compressed = gzipSync(body, { level: 9 });
      response.writeHead(200, {
        'content-type': mime(extname(candidate)),
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

function verifyCompleteSource(id, file) {
  const html = readFileSync(file, 'utf8');
  const itemCount = (html.match(/class="esen-seo-collection-item"/g) || []).length;
  if (itemCount !== 12) throw new Error(`${id} source contains ${itemCount} collection items`);
  for (const title of ['Dart Rendering Guide', 'Roadmap']) {
    if (!html.includes(title)) throw new Error(`${id} source is missing ${title}`);
  }
  if (id === 'esen' && /flutter_bootstrap\.js|main\.dart\.js|canvaskit/i.test(html)) {
    throw new Error('DOM-first source contains a Flutter artifact');
  }
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
    const values = rows
      .map(row => row[metric])
      .filter(Number.isFinite)
      .sort((a, b) => a - b);
    result[metric] = {
      median: values.length ? values[Math.floor(values.length / 2)] : null,
      p75: values.length ? values[Math.ceil(values.length * 0.75) - 1] : null,
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
    if (Number.isFinite(next) && Number.isFinite(flutter) && next < flutter) {
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
    '# DOM-first Collection History Benchmark Results',
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
    'adds gzip-compressed inline scripts to external script responses. The scripted',
    'INP proxy measures dispatch through the resulting paint over search, category,',
    'sort, page, Back and Forward operations. Every operation also asserts canonical',
    'namespaced URL state and preservation of unrelated URL data. It is a reproducible',
    'lab gate, not field INP; the separate field target remains 200 ms at p75 after',
    'release.',
    '',
  );
  return lines.join('\n');
}

function format(value) {
  return Number.isFinite(value.median) ? `${value.median} / ${value.p75}` : 'n/a';
}
function round(value, digits = 1) {
  return Number.isFinite(value) ? Number(value.toFixed(digits)) : null;
}
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
