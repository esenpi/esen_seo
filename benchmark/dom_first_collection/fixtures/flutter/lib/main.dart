import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/material.dart';

import 'collection_data.dart';

void main() {
  EsenSeo.init();
  runApp(const BenchmarkApp());
}

class BenchmarkApp extends StatelessWidget {
  const BenchmarkApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      const Text(
                        'Publishing library',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                        ),
                      ).h1,
                      const SizedBox(height: 16),
                      const Text(
                        'Twelve complete resources with searchable, '
                        'shareable state.',
                      ).p,
                      const SizedBox(height: 24),
                      SeoCollection(
                        interactionId: 'benchmark-collection',
                        interactionLabel: 'Publishing library',
                        pageSize: 4,
                        synchronizeUrl: true,
                        items: [
                          for (final item in benchmarkCollectionItems)
                            SeoCollectionEntry(
                              title: item.title,
                              searchText: item.searchText,
                              categories: [item.category],
                              sortKey: item.sortKey,
                              content: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title),
                                  Text(item.description),
                                ],
                              ),
                              nodes: [
                                SeoNode(tag: 'h2', text: item.title),
                                SeoNode(tag: 'p', text: item.description),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
