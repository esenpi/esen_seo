import 'package:esen_seo/esen_seo.dart';
import 'package:esen_seo_runtime_bundle_benchmark_app/runtime_transitions.dart';
import 'package:flutter/material.dart';

import 'benchmark_data.dart';

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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 56),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Application runtime bundle',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                      ),
                    ).h1,
                    const SizedBox(height: 12),
                    const Text(
                      'Three independent pure transitions enhance one '
                      'complete page.',
                    ).p,
                    const SizedBox(height: 24),
                    const Text(
                      'Rendering modes',
                      style: TextStyle(fontSize: 20),
                    ).h2,
                    const SizedBox(height: 10),
                    SeoTabs(
                      interactionId: 'benchmark-tabs',
                      interactionLabel: 'Rendering modes',
                      transition: transitionBenchmarkTabs,
                      tabs: [
                        for (final item in benchmarkTabs)
                          SeoTab(
                            label: item.label,
                            content: Text(item.content),
                            nodes: [SeoNode(tag: 'p', text: item.content)],
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Delivery stages',
                      style: TextStyle(fontSize: 20),
                    ).h2,
                    const SizedBox(height: 10),
                    SeoCarousel(
                      height: 96,
                      interactionId: 'benchmark-carousel',
                      interactionLabel: 'Delivery stages',
                      transition: transitionBenchmarkCarousel,
                      slides: [
                        for (final item in benchmarkSlides)
                          SeoCarouselSlide(
                            label: item.label,
                            content: Align(
                              alignment: Alignment.topLeft,
                              child: Text(item.content),
                            ),
                            nodes: [SeoNode(tag: 'p', text: item.content)],
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Publishing flow',
                      style: TextStyle(fontSize: 20),
                    ).h2,
                    const SizedBox(height: 10),
                    SeoStepper.withEffects(
                      interactionId: benchmarkStepperInteractionId,
                      interactionLabel: 'Publishing flow',
                      effectTransition: transitionBenchmarkStepperEffects,
                      steps: [
                        for (final item in benchmarkSteps)
                          SeoStep(
                            label: item.label,
                            content: Text(item.content),
                            nodes: [SeoNode(tag: 'p', text: item.content)],
                          ),
                      ],
                    ),
                  ],
                ).main,
              ),
            ),
          ),
        ),
      );
}
