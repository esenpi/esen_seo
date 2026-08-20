(() => {
  const root = document.getElementById('benchmark-stepper');
  const entries = [...root.querySelectorAll(':scope > ol > li')];
  const panels = entries.map(entry => entry.querySelector('[data-esen-step-panel]'));
  let selected = 0;

  const controls = document.createElement('div');
  controls.className = 'esen-seo-stepper-controls';
  const control = (label, action) => {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = label;
    button.addEventListener('click', action);
    controls.appendChild(button);
    return button;
  };
  const previous = control('Back', () => apply((selected - 1 + entries.length) % entries.length, true));
  const status = document.createElement('span');
  status.className = 'esen-seo-stepper-status';
  status.setAttribute('aria-live', 'polite');
  controls.appendChild(status);
  const next = control('Next', () => apply((selected + 1) % entries.length, true));

  const buttons = entries.map((entry, index) => {
    const heading = entry.firstElementChild;
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = heading.textContent;
    button.setAttribute('aria-controls', panels[index].id);
    button.addEventListener('click', () => apply(index, true));
    entry.insertBefore(button, heading);
    heading.hidden = true;
    panels[index].setAttribute('role', 'region');
    return button;
  });

  function apply(index, focusPanel) {
    selected = index;
    buttons.forEach((button, buttonIndex) => {
      const active = buttonIndex === selected;
      button.setAttribute('aria-current', active ? 'step' : 'false');
      panels[buttonIndex].hidden = !active;
      panels[buttonIndex].removeAttribute('tabindex');
    });
    status.textContent = `Step ${selected + 1} / ${entries.length}`;
    previous.disabled = false;
    next.disabled = false;
    if (focusPanel) {
      panels[selected].tabIndex = -1;
      panels[selected].focus();
    }
  }

  root.insertBefore(controls, root.firstChild);
  root.setAttribute('role', 'region');
  root.setAttribute('aria-label', 'Publishing flow');
  root.dataset.esenEnhanced = 'true';
  apply(0, false);
})();
