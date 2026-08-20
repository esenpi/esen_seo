'use client';

import { useEffect, useRef, useState } from 'react';

const steps = [
  ['Draft', 'Write the complete article before review.'],
  ['Review', 'Check facts, links and the semantic outline.'],
  ['Publish', 'Release the approved document to every reader.'],
];

export default function Page() {
  const [selected, setSelected] = useState(0);
  const [enhanced, setEnhanced] = useState(false);
  const panels = useRef([]);
  useEffect(() => setEnhanced(true), []);

  const apply = index => {
    setSelected(index);
    requestAnimationFrame(() => panels.current[index]?.focus());
  };

  return (
    <main>
      <h1>Publishing flow</h1>
      <p>One pure transition selects a complete step and then focuses its panel.</p>
      <div className="esen-seo-stepper" id="benchmark-stepper" data-esen-component="stepper" data-esen-enhanced={enhanced ? 'true' : 'false'} role="region" aria-label="Publishing flow">
        <div className="esen-seo-stepper-controls">
          <button type="button" onClick={() => apply((selected - 1 + steps.length) % steps.length)}>Back</button>
          <span className="esen-seo-stepper-status" aria-live="polite">Step {selected + 1} / {steps.length}</span>
          <button type="button" onClick={() => apply((selected + 1) % steps.length)}>Next</button>
        </div>
        <ol data-esen-step-list="">
          {steps.map(([label, content], index) => (
            <li key={label} data-esen-step="">
              <h2 hidden={enhanced}>{label}</h2>
              <button type="button" aria-current={selected === index ? 'step' : 'false'} aria-controls={`benchmark-stepper-panel-${index}`} onClick={() => apply(index)}>{label}</button>
              <div
                ref={node => { panels.current[index] = node; }}
                id={`benchmark-stepper-panel-${index}`}
                data-esen-step-panel=""
                role="region"
                tabIndex={enhanced && selected === index ? -1 : undefined}
                hidden={enhanced && selected !== index}
              ><p>{content}</p></div>
            </li>
          ))}
        </ol>
      </div>
    </main>
  );
}
