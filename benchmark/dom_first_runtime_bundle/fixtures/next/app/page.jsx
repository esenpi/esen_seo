'use client';

import { useEffect, useRef, useState } from 'react';

const tabs = [
  ['Overview', 'The page starts as complete HTML.'],
  ['Architecture', 'Pure Dart owns every state transition.'],
  ['Delivery', 'One verified artifact enhances the route.'],
];
const slides = [
  ['Semantic source', 'Every slide exists before JavaScript.'],
  ['Verified runtime', 'The manifest binds code and member kinds.'],
  ['Native parity', 'Flutter calls the same Carousel transition.'],
];
const steps = [
  ['Draft', 'Write the complete article before review.'],
  ['Review', 'Check facts, links and semantic structure.'],
  ['Publish', 'Release the approved document to readers.'],
];

export default function Page() {
  const [enhanced, setEnhanced] = useState(false);
  const [tabIndex, setTabIndex] = useState(0);
  const [slideIndex, setSlideIndex] = useState(0);
  const [stepIndex, setStepIndex] = useState(0);
  const stepPanels = useRef([]);
  useEffect(() => setEnhanced(true), []);

  const selectStep = index => {
    setStepIndex(index);
    requestAnimationFrame(() => stepPanels.current[index]?.focus());
  };
  const tabKey = event => {
    const next = {
      ArrowRight: Math.min(tabIndex + 1, tabs.length - 1),
      ArrowLeft: Math.max(tabIndex - 1, 0),
      Home: 0,
      End: tabs.length - 1,
    }[event.key];
    if (next === undefined) return;
    event.preventDefault();
    setTabIndex(next);
  };
  const slideKey = event => {
    const next = {
      ArrowRight: slideIndex === slides.length - 1 ? 0 : slideIndex + 1,
      ArrowLeft: slideIndex === 0 ? slides.length - 1 : slideIndex - 1,
      Home: 0,
      End: slides.length - 1,
    }[event.key];
    if (next === undefined || event.repeat) return;
    event.preventDefault();
    setSlideIndex(next);
  };

  return (
    <main>
      <h1>Application runtime bundle</h1>
      <p>Three independent pure transitions enhance one complete page.</p>
      <h2>Rendering modes</h2>
      <div className="esen-seo-tabs" id="benchmark-tabs" data-esen-component="tabs" data-esen-enhanced={enhanced ? 'true' : 'false'}>
        <div className="esen-seo-tab-list" role="tablist" aria-label="Rendering modes">
          {tabs.map(([label], index) => <button key={label} type="button" className="esen-seo-tab" role="tab" aria-selected={tabIndex === index} tabIndex={tabIndex === index ? 0 : -1} aria-controls={`benchmark-tabs-panel-${index}`} onClick={() => setTabIndex(index)} onKeyDown={tabKey}>{label}</button>)}
        </div>
        {tabs.map(([label, content], index) => <section key={label} id={`benchmark-tabs-panel-${index}`} data-esen-tab-panel="" role="tabpanel" hidden={enhanced && tabIndex !== index}><h3 hidden={enhanced}>{label}</h3><p>{content}</p></section>)}
      </div>
      <h2>Delivery stages</h2>
      <div className="esen-seo-carousel" id="benchmark-carousel" data-esen-component="carousel" data-esen-enhanced={enhanced ? 'true' : 'false'} role="region" aria-label="Delivery stages">
        <div className="esen-seo-carousel-controls">
          <button type="button" aria-label="Previous slide" onClick={() => setSlideIndex(slideIndex === 0 ? slides.length - 1 : slideIndex - 1)} onKeyDown={slideKey}>‹</button>
          <span className="esen-seo-carousel-status" aria-live="polite">{slideIndex + 1} / {slides.length}</span>
          <button type="button" aria-label="Next slide" onClick={() => setSlideIndex(slideIndex === slides.length - 1 ? 0 : slideIndex + 1)} onKeyDown={slideKey}>›</button>
        </div>
        {slides.map(([label, content], index) => <section key={label} id={`benchmark-carousel-slide-${index}`} data-esen-carousel-slide="" hidden={enhanced && slideIndex !== index}><h3>{label}</h3><p>{content}</p></section>)}
      </div>
      <h2>Publishing flow</h2>
      <div className="esen-seo-stepper" id="benchmark-stepper" data-esen-component="stepper" data-esen-enhanced={enhanced ? 'true' : 'false'} role="region" aria-label="Publishing flow">
        <div className="esen-seo-stepper-controls">
          <button type="button" aria-label="Back" onClick={() => selectStep(stepIndex === 0 ? steps.length - 1 : stepIndex - 1)}>Back</button>
          <span className="esen-seo-stepper-status" aria-live="polite">Step {stepIndex + 1} / {steps.length}</span>
          <button type="button" aria-label="Next" onClick={() => selectStep(stepIndex === steps.length - 1 ? 0 : stepIndex + 1)}>Next</button>
        </div>
        <ol data-esen-step-list="">
          {steps.map(([label, content], index) => <li key={label} id={`benchmark-stepper-step-${index}`} data-esen-step=""><button type="button" className="esen-seo-step-button" aria-current={stepIndex === index ? 'step' : 'false'} aria-controls={`benchmark-stepper-panel-${index}`} onClick={() => selectStep(index)}>{label}</button><h3 hidden={enhanced}>{label}</h3><div ref={node => { stepPanels.current[index] = node; }} id={`benchmark-stepper-panel-${index}`} data-esen-step-panel="" role="region" tabIndex={enhanced && stepIndex === index ? -1 : undefined} hidden={enhanced && stepIndex !== index}><p>{content}</p></div></li>)}
        </ol>
      </div>
    </main>
  );
}
