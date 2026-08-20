import 'package:esen_seo/esen_seo.dart';
import 'package:esen_seo_stepper_effects_benchmark_app/stepper_effect_transition.dart';
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
                      'Publishing flow',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                      ),
                    ).h1,
                    const SizedBox(height: 16),
                    const Text(
                      'One pure transition selects a complete step and then '
                      'focuses its panel.',
                    ).p,
                    const SizedBox(height: 24),
                    SeoStepper.withEffects(
                      interactionId: 'benchmark-stepper',
                      interactionLabel: 'Publishing flow',
                      effectTransition: transitionBenchmarkStepperEffects,
                      steps: [
                        for (final step in _steps)
                          SeoStep(
                            label: step.label,
                            content: Text(step.content),
                            nodes: [SeoNode(tag: 'p', text: step.content)],
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

const _steps = [
  (label: 'Draft', content: 'Write the complete article before review.'),
  (label: 'Review', content: 'Check facts, links and the semantic outline.'),
  (
    label: 'Publish',
    content: 'Release the approved document to every reader.',
  ),
];
