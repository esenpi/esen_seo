'use client';

import { useEffect, useMemo, useState } from 'react';

const items = [
  ['Dart Rendering Guide', 'dart flutter rendering semantic', 'guides', 120, 'Render one Dart model into native widgets and semantic HTML.'],
  ['CSS Token Guide', 'css design tokens styling', 'guides', 110, 'Keep visual tokens aligned across permanent web documents.'],
  ['JavaScript State Guide', 'javascript state transition progressive', 'guides', 100, 'Compile bounded transitions for progressive interaction.'],
  ['Browser History Guide', 'browser history url back forward', 'guides', 90, 'Restore canonical collection state from browser History.'],
  ['Accessible Tabs Guide', 'accessible keyboard aria tabs', 'guides', 80, 'Preserve semantic controls and predictable keyboard input.'],
  ['Collection Search Guide', 'collection search filter pagination', 'guides', 70, 'Search complete static content without hiding it from bots.'],
  ['Static HTML Guide', 'static html prerender seo', 'guides', 60, 'Deliver readable content before any script executes.'],
  ['Deployment Guide', 'deployment server static hosting', 'guides', 50, 'Choose static output or a pure server delivery path.'],
  ['Release 0.11', 'release application runtime carousel stepper', 'releases', 40, 'Application-owned transitions reach more components.'],
  ['Runtime Notes', 'runtime size csp hash validation', 'notes', 30, 'Runtime manifests bind identity, bytes and policy.'],
  ['Security Policy', 'security policy validation allow list', 'notes', 20, 'All mutations pass the package-owned apply boundary.'],
  ['Roadmap', 'roadmap effects routing forms', 'notes', 10, 'Future slices remain behind explicit admission gates.'],
];
const categories = [['', 'All'], ['guides', 'Guides'], ['releases', 'Releases'], ['notes', 'Notes']];
const sorts = [['newest', 'Newest'], ['oldest', 'Oldest'], ['title', 'Title']];
const prefix = 'esen.benchmark-collection.';

function select(candidate) {
  const query = String(candidate.query || '').slice(0, 4096);
  const terms = query.toLowerCase().trim().split(/\s+/).filter(Boolean);
  const category = categories.some(([value]) => value === candidate.category) ? candidate.category : '';
  const sort = sorts.some(([value]) => value === candidate.sort) ? candidate.sort : 'newest';
  const ordered = items.map((item, index) => ({ item, index })).filter(({ item }) =>
    (!category || item[2] === category) &&
    terms.every(term => `${item[0]} ${item[1]}`.toLowerCase().includes(term))
  ).sort((left, right) => {
    const compared = sort === 'title'
      ? left.item[0].toLowerCase().localeCompare(right.item[0].toLowerCase())
      : sort === 'oldest' ? left.item[3] - right.item[3] : right.item[3] - left.item[3];
    return compared || left.index - right.index;
  });
  const pages = Math.ceil(ordered.length / 4);
  const page = pages ? Math.max(0, Math.min(Number(candidate.page) || 0, pages - 1)) : 0;
  return { state: { query, category, sort, page }, ordered, pages };
}

function fromUrl() {
  const url = new URL(location.href);
  const one = name => {
    const values = url.searchParams.getAll(prefix + name);
    return values.length === 1 ? values[0] : null;
  };
  const rawPage = one('page');
  return {
    query: one('q') || '',
    category: one('category') || '',
    sort: one('sort') || 'newest',
    page: rawPage && /^[1-9][0-9]{0,8}$/.test(rawPage) ? Number(rawPage) - 1 : 0,
  };
}

function syncUrl(state, push) {
  const url = new URL(location.href);
  for (const name of ['q', 'category', 'sort', 'page']) url.searchParams.delete(prefix + name);
  if (state.query.trim()) url.searchParams.set(prefix + 'q', state.query);
  if (state.category) url.searchParams.set(prefix + 'category', state.category);
  if (state.sort !== 'newest') url.searchParams.set(prefix + 'sort', state.sort);
  if (state.page > 0) url.searchParams.set(prefix + 'page', String(state.page + 1));
  if (url.href !== location.href) history[push ? 'pushState' : 'replaceState'](null, '', url.href);
}

export default function Page() {
  const [state, setState] = useState({ query: '', category: '', sort: 'newest', page: 0 });
  const [enhanced, setEnhanced] = useState(false);
  const snapshot = useMemo(() => select(state), [state]);

  useEffect(() => {
    const restore = () => {
      const accepted = select(fromUrl()).state;
      setState(accepted);
      syncUrl(accepted, false);
    };
    restore();
    setEnhanced(true);
    addEventListener('popstate', restore);
    return () => removeEventListener('popstate', restore);
  }, []);

  const change = (candidate, push) => {
    const accepted = select(candidate).state;
    setState(accepted);
    syncUrl(accepted, push);
  };
  const visible = new Set(snapshot.ordered.slice(snapshot.state.page * 4, snapshot.state.page * 4 + 4).map(({ index }) => index));
  const matching = new Set(snapshot.ordered.map(({ index }) => index));
  const rendered = enhanced
    ? [
        ...snapshot.ordered,
        ...items.map((item, index) => ({ item, index })).filter(({ index }) => !matching.has(index)),
      ]
    : items.map((item, index) => ({ item, index }));

  return (
    <main id="catalog">
      <h1>Publishing library</h1>
      <p>Twelve complete resources with searchable, shareable state.</p>
      <section className="esen-seo-collection" id="benchmark-collection" aria-label="Publishing library" data-esen-enhanced={enhanced ? 'true' : 'false'}>
        <div className="esen-seo-collection-toolbar">
          <label className="esen-seo-collection-search" htmlFor="benchmark-collection-search"><span>Search</span><input id="benchmark-collection-search" type="search" maxLength={4096} value={state.query} onChange={event => change({ ...state, query: event.target.value, page: 0 }, false)} /></label>
          <div className="esen-seo-collection-categories" role="group" aria-label="Categories"><span className="esen-seo-collection-control-label">Categories</span><div className="esen-seo-collection-category-options">{categories.map(([value, label]) => <button key={label} type="button" aria-label={label} aria-pressed={snapshot.state.category === value} onClick={() => change({ ...state, category: value, page: 0 }, true)}>{label}</button>)}</div></div>
          <div className="esen-seo-collection-sort" role="group" aria-label="Sort"><span className="esen-seo-collection-control-label">Sort</span><div className="esen-seo-collection-sort-options">{sorts.map(([value, label]) => <button key={label} type="button" aria-label={label} aria-pressed={snapshot.state.sort === value} onClick={() => change({ ...state, sort: value, page: 0 }, true)}>{label}</button>)}</div></div>
        </div>
        <p className="esen-seo-collection-results" aria-live="polite" aria-atomic="true">{snapshot.ordered.length} results</p>
        <p className="esen-seo-collection-empty" hidden={snapshot.ordered.length !== 0}>No results</p>
        <div data-esen-collection-items>{rendered.map(({ item, index }) => <article className="esen-seo-collection-item" key={item[0]} hidden={enhanced && !visible.has(index)}><h2>{item[0]}</h2><p>{item[4]}</p></article>)}</div>
        <div className="esen-seo-collection-pagination" role="navigation" aria-label="Page" hidden={snapshot.pages <= 1}><button type="button" aria-label="Previous" disabled={snapshot.state.page === 0} onClick={() => change({ ...state, page: state.page - 1 }, true)}>‹</button><span className="esen-seo-collection-page">{snapshot.pages ? `Page ${snapshot.state.page + 1} / ${snapshot.pages}` : 'Page 0 / 0'}</span><button type="button" aria-label="Next" disabled={snapshot.state.page + 1 >= snapshot.pages} onClick={() => change({ ...state, page: state.page + 1 }, true)}>›</button></div>
      </section>
    </main>
  );
}
