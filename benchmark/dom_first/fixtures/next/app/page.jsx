'use client';

import { useEffect, useRef, useState } from 'react';

const panels = [
  ['Flutter', 'The same data renders as a native Flutter tab on every platform.'],
  ['HTML', 'Every panel is present as semantic HTML before JavaScript runs.'],
  ['JavaScript', 'The visible web page gains accessible tab controls after validation.'],
];

export default function Page() {
  const [selected, setSelected] = useState(0);
  const [enhanced, setEnhanced] = useState(false);
  const refs = useRef([]);
  useEffect(() => setEnhanced(true), []);

  const apply = (index, focus = false) => {
    setSelected(index);
    if (focus) requestAnimationFrame(() => refs.current[index]?.focus());
  };

  return (
    <main>
      <h1>Rendering targets</h1>
      <p>One data model, three complete panels and accessible tab controls.</p>
      <div className="esen-seo-tabs" data-esen-enhanced={enhanced ? 'true' : 'false'}>
        <div className="esen-seo-tab-list" role="tablist" aria-label="Rendering targets">
          {panels.map(([label], index) => (
            <button
              key={label}
              ref={node => { refs.current[index] = node; }}
              id={`benchmark-tabs-tab-${index}`}
              className="esen-seo-tab"
              type="button"
              role="tab"
              aria-controls={`benchmark-tabs-panel-${index}`}
              aria-selected={selected === index}
              tabIndex={selected === index ? 0 : -1}
              onClick={() => apply(index)}
              onKeyDown={event => {
                const target = event.key === 'ArrowRight' ? (selected + 1) % panels.length
                  : event.key === 'ArrowLeft' ? (selected - 1 + panels.length) % panels.length
                  : event.key === 'Home' ? 0 : event.key === 'End' ? panels.length - 1 : null;
                if (target === null) return;
                event.preventDefault();
                apply(target, true);
              }}
            >{label}</button>
          ))}
        </div>
        {panels.map(([label, content], index) => (
          <section
            key={label}
            id={`benchmark-tabs-panel-${index}`}
            role="tabpanel"
            aria-labelledby={`benchmark-tabs-tab-${index}`}
            hidden={enhanced && selected !== index}
          >
            <h2 hidden={enhanced}>{label}</h2><p>{content}</p>
          </section>
        ))}
      </div>
    </main>
  );
}
