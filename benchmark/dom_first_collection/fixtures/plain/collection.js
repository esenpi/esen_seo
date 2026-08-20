(() => {
  const root = document.getElementById('benchmark-collection');
  const itemRoot = root.querySelector('[data-esen-collection-items]');
  const items = [...itemRoot.children].map((element, index) => ({
    element,
    index,
    title: element.dataset.title.toLowerCase(),
    search: `${element.dataset.title} ${element.dataset.search}`.toLowerCase(),
    category: element.dataset.category,
    key: Number(element.dataset.key),
  }));
  const input = root.querySelector('input[type="search"]');
  const categories = [...root.querySelectorAll('[data-category]')];
  const sorts = [...root.querySelectorAll('[data-sort]')];
  const result = root.querySelector('.esen-seo-collection-results');
  const empty = root.querySelector('.esen-seo-collection-empty');
  const pagination = root.querySelector('.esen-seo-collection-pagination');
  const pageStatus = root.querySelector('.esen-seo-collection-page');
  const previous = root.querySelector('[data-previous]');
  const next = root.querySelector('[data-next]');
  const prefix = 'esen.benchmark-collection.';
  const validCategories = new Set(['guides', 'releases', 'notes']);
  const validSorts = new Set(['newest', 'oldest', 'title']);
  let state = { query: '', category: '', sort: 'newest', page: 0 };

  const snapshot = candidate => {
    const query = String(candidate.query || '').slice(0, 4096);
    const terms = query.toLowerCase().trim().split(/\s+/).filter(Boolean);
    const category = validCategories.has(candidate.category) ? candidate.category : '';
    const sort = validSorts.has(candidate.sort) ? candidate.sort : 'newest';
    const ordered = items.filter(item =>
      (!category || item.category === category) &&
      terms.every(term => item.search.includes(term))
    ).sort((left, right) => {
      const compared = sort === 'title'
        ? left.title.localeCompare(right.title)
        : sort === 'oldest' ? left.key - right.key : right.key - left.key;
      return compared || left.index - right.index;
    });
    const pages = Math.ceil(ordered.length / 4);
    const page = pages ? Math.max(0, Math.min(Number(candidate.page) || 0, pages - 1)) : 0;
    return { state: { query, category, sort, page }, ordered, pages };
  };

  const fromUrl = () => {
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
  };

  const syncUrl = push => {
    const url = new URL(location.href);
    for (const name of ['q', 'category', 'sort', 'page']) url.searchParams.delete(prefix + name);
    if (state.query.trim()) url.searchParams.set(prefix + 'q', state.query);
    if (state.category) url.searchParams.set(prefix + 'category', state.category);
    if (state.sort !== 'newest') url.searchParams.set(prefix + 'sort', state.sort);
    if (state.page > 0) url.searchParams.set(prefix + 'page', String(state.page + 1));
    if (url.href === location.href) return;
    history[push ? 'pushState' : 'replaceState'](null, '', url.href);
  };

  const render = candidate => {
    const selected = snapshot(candidate);
    state = selected.state;
    input.value = state.query;
    for (const item of selected.ordered) itemRoot.appendChild(item.element);
    const visible = new Set(selected.ordered.slice(state.page * 4, state.page * 4 + 4));
    for (const item of items) item.element.hidden = !visible.has(item);
    for (const button of categories) button.setAttribute('aria-pressed', String(button.dataset.category === state.category));
    for (const button of sorts) button.setAttribute('aria-pressed', String(button.dataset.sort === state.sort));
    result.textContent = `${selected.ordered.length} results`;
    empty.hidden = selected.ordered.length !== 0;
    pagination.hidden = selected.pages <= 1;
    previous.disabled = state.page === 0;
    next.disabled = state.page + 1 >= selected.pages;
    pageStatus.textContent = selected.pages ? `Page ${state.page + 1} / ${selected.pages}` : 'Page 0 / 0';
  };

  const change = (candidate, push) => {
    render(candidate);
    syncUrl(push);
  };
  input.addEventListener('input', () => change({ ...state, query: input.value, page: 0 }, false));
  for (const button of categories) button.addEventListener('click', () => change({ ...state, category: button.dataset.category, page: 0 }, true));
  for (const button of sorts) button.addEventListener('click', () => change({ ...state, sort: button.dataset.sort, page: 0 }, true));
  previous.addEventListener('click', () => change({ ...state, page: state.page - 1 }, true));
  next.addEventListener('click', () => change({ ...state, page: state.page + 1 }, true));
  addEventListener('popstate', () => {
    render(fromUrl());
    syncUrl(false);
  });
  render(fromUrl());
  syncUrl(false);
  root.dataset.esenEnhanced = 'true';
})();
