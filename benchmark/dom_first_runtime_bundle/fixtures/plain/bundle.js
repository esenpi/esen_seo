(() => {
  const tabsRoot = document.getElementById('benchmark-tabs');
  const tabPanels = [...tabsRoot.querySelectorAll(':scope > section')];
  let tabIndex = 0;
  const tabList = document.createElement('div');
  tabList.className = 'esen-seo-tab-list';
  tabList.setAttribute('role', 'tablist');
  tabList.setAttribute('aria-label', 'Rendering modes');
  const tabButtons = tabPanels.map((panel, index) => {
    const heading = panel.firstElementChild;
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'esen-seo-tab';
    button.id = `benchmark-tabs-tab-${index}`;
    button.textContent = heading.textContent;
    button.setAttribute('role', 'tab');
    button.setAttribute('aria-controls', panel.id);
    button.addEventListener('click', () => applyTab(index, false));
    button.addEventListener('keydown', event => {
      const next = {
        ArrowRight: Math.min(tabIndex + 1, tabPanels.length - 1),
        ArrowLeft: Math.max(tabIndex - 1, 0),
        Home: 0,
        End: tabPanels.length - 1,
      }[event.key];
      if (next === undefined) return;
      event.preventDefault();
      applyTab(next, true);
    });
    panel.setAttribute('role', 'tabpanel');
    panel.setAttribute('aria-labelledby', button.id);
    heading.hidden = true;
    tabList.appendChild(button);
    return button;
  });
  function applyTab(index, moveFocus) {
    tabIndex = index;
    tabButtons.forEach((button, current) => {
      const selected = current === tabIndex;
      button.setAttribute('aria-selected', selected ? 'true' : 'false');
      button.tabIndex = selected ? 0 : -1;
      tabPanels[current].hidden = !selected;
    });
    if (moveFocus) tabButtons[tabIndex].focus();
  }
  tabsRoot.insertBefore(tabList, tabPanels[0]);
  tabsRoot.dataset.esenEnhanced = 'true';
  applyTab(0, false);

  const carousel = document.getElementById('benchmark-carousel');
  const slides = [...carousel.querySelectorAll(':scope > section')];
  let slideIndex = 0;
  const carouselControls = document.createElement('div');
  carouselControls.className = 'esen-seo-carousel-controls';
  const previousSlide = control(carouselControls, 'Previous slide', '\u2039');
  const carouselStatus = document.createElement('span');
  carouselStatus.className = 'esen-seo-carousel-status';
  carouselStatus.setAttribute('aria-live', 'polite');
  carouselControls.appendChild(carouselStatus);
  const nextSlide = control(carouselControls, 'Next slide', '\u203a');
  previousSlide.addEventListener('click', () => applySlide(slideIndex === 0 ? slides.length - 1 : slideIndex - 1));
  nextSlide.addEventListener('click', () => applySlide(slideIndex === slides.length - 1 ? 0 : slideIndex + 1));
  for (const button of [previousSlide, nextSlide]) {
    button.addEventListener('keydown', event => {
      const next = {
        ArrowRight: slideIndex === slides.length - 1 ? 0 : slideIndex + 1,
        ArrowLeft: slideIndex === 0 ? slides.length - 1 : slideIndex - 1,
        Home: 0,
        End: slides.length - 1,
      }[event.key];
      if (next === undefined || event.repeat) return;
      event.preventDefault();
      event.stopPropagation();
      applySlide(next);
    });
  }
  function applySlide(index) {
    slideIndex = index;
    slides.forEach((slide, current) => { slide.hidden = current !== index; });
    carouselStatus.textContent = `${slideIndex + 1} / ${slides.length}`;
  }
  carousel.insertBefore(carouselControls, slides[0]);
  carousel.setAttribute('role', 'region');
  carousel.setAttribute('aria-label', 'Delivery stages');
  carousel.dataset.esenEnhanced = 'true';
  applySlide(0);

  const stepper = document.getElementById('benchmark-stepper');
  const steps = [...stepper.querySelectorAll(':scope > ol > li')];
  const stepPanels = steps.map(step => step.querySelector('[data-esen-step-panel]'));
  let stepIndex = 0;
  const stepButtons = steps.map((step, index) => {
    const heading = step.firstElementChild;
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'esen-seo-step-button';
    button.textContent = heading.textContent;
    button.setAttribute('aria-controls', stepPanels[index].id);
    button.addEventListener('click', () => applyStep(index, true));
    step.insertBefore(button, heading);
    stepPanels[index].setAttribute('role', 'region');
    heading.hidden = true;
    return button;
  });
  const stepControls = document.createElement('div');
  stepControls.className = 'esen-seo-stepper-controls';
  const previousStep = control(stepControls, 'Back', 'Back');
  const stepStatus = document.createElement('span');
  stepStatus.className = 'esen-seo-stepper-status';
  stepStatus.setAttribute('aria-live', 'polite');
  stepControls.appendChild(stepStatus);
  const nextStep = control(stepControls, 'Next', 'Next');
  previousStep.addEventListener('click', () => applyStep(stepIndex === 0 ? steps.length - 1 : stepIndex - 1, true));
  nextStep.addEventListener('click', () => applyStep(stepIndex === steps.length - 1 ? 0 : stepIndex + 1, true));
  function applyStep(index, focusPanel) {
    stepIndex = index;
    stepButtons.forEach((button, current) => {
      button.setAttribute('aria-current', current === stepIndex ? 'step' : 'false');
      stepPanels[current].hidden = current !== stepIndex;
      stepPanels[current].removeAttribute('tabindex');
    });
    stepStatus.textContent = `Step ${stepIndex + 1} / ${steps.length}`;
    if (focusPanel) {
      stepPanels[stepIndex].tabIndex = -1;
      stepPanels[stepIndex].focus();
    }
  }
  stepper.insertBefore(stepControls, stepper.firstChild);
  stepper.setAttribute('role', 'region');
  stepper.setAttribute('aria-label', 'Publishing flow');
  stepper.dataset.esenEnhanced = 'true';
  applyStep(0, false);

  function control(parent, label, text) {
    const button = document.createElement('button');
    button.type = 'button';
    button.setAttribute('aria-label', label);
    button.textContent = text;
    parent.appendChild(button);
    return button;
  }
})();
