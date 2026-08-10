(() => {
  const root = document.getElementById('benchmark-tabs');
  const panels = [...root.children];
  const list = document.createElement('div');
  list.className = 'esen-seo-tab-list';
  list.setAttribute('role', 'tablist');
  list.setAttribute('aria-label', 'Rendering targets');
  let selected = 0;
  const tabs = panels.map((panel, index) => {
    const heading = panel.firstElementChild;
    const tab = document.createElement('button');
    tab.type = 'button';
    tab.id = `benchmark-tabs-tab-${index}`;
    tab.className = 'esen-seo-tab';
    tab.textContent = heading.textContent;
    tab.setAttribute('role', 'tab');
    tab.setAttribute('aria-controls', panel.id);
    panel.setAttribute('role', 'tabpanel');
    panel.setAttribute('aria-labelledby', tab.id);
    heading.hidden = true;
    list.appendChild(tab);
    return tab;
  });
  const apply = (index, focus) => {
    selected = index;
    tabs.forEach((tab, tabIndex) => {
      const active = tabIndex === selected;
      tab.setAttribute('aria-selected', active ? 'true' : 'false');
      tab.tabIndex = active ? 0 : -1;
      panels[tabIndex].hidden = !active;
    });
    if (focus) tabs[selected].focus();
  };
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => apply(index, false));
    tab.addEventListener('keydown', event => {
      const target = event.key === 'ArrowRight' ? (selected + 1) % tabs.length
        : event.key === 'ArrowLeft' ? (selected - 1 + tabs.length) % tabs.length
        : event.key === 'Home' ? 0 : event.key === 'End' ? tabs.length - 1 : null;
      if (target === null) return;
      event.preventDefault();
      apply(target, true);
    });
  });
  root.insertBefore(list, panels[0]);
  root.dataset.esenEnhanced = 'true';
  apply(0, false);
})();
