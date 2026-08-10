import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/material.dart';

void main() {
  EsenSeo.init();
  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    const Text(
                      'Rendering targets',
                      style:
                          TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
                    ).h1,
                    const SizedBox(height: 16),
                    const Text(
                      'One data model, three complete panels and accessible tab controls.',
                    ).p,
                    const SizedBox(height: 24),
                    SeoTabs(
                      interactionId: 'benchmark-tabs',
                      interactionLabel: 'Rendering targets',
                      tabs: [
                        for (final panel in _panels)
                          SeoTab(
                            label: panel.label,
                            content: Text(panel.content),
                            nodes: [SeoNode(tag: 'p', text: panel.content)],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

const _panels = [
  (
    label: 'Flutter',
    content: 'The same data renders as a native Flutter tab on every platform.'
  ),
  (
    label: 'HTML',
    content: 'Every panel is present as semantic HTML before JavaScript runs.'
  ),
  (
    label: 'JavaScript',
    content:
        'The visible web page gains accessible tab controls after validation.'
  ),
];
