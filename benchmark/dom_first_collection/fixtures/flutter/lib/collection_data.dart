import 'package:esen_seo/core.dart';

final class BenchmarkCollectionItem {
  const BenchmarkCollectionItem({
    required this.title,
    required this.searchText,
    required this.category,
    required this.sortKey,
    required this.description,
  });

  final String title;
  final String searchText;
  final String category;
  final int sortKey;
  final String description;
}

const benchmarkCollectionItems = [
  BenchmarkCollectionItem(
    title: 'Dart Rendering Guide',
    searchText: 'dart flutter rendering semantic',
    category: 'Guides',
    sortKey: 120,
    description: 'Render one Dart model into native widgets and semantic HTML.',
  ),
  BenchmarkCollectionItem(
    title: 'CSS Token Guide',
    searchText: 'css design tokens styling',
    category: 'Guides',
    sortKey: 110,
    description: 'Keep visual tokens aligned across permanent web documents.',
  ),
  BenchmarkCollectionItem(
    title: 'JavaScript State Guide',
    searchText: 'javascript state transition progressive',
    category: 'Guides',
    sortKey: 100,
    description: 'Compile bounded transitions for progressive interaction.',
  ),
  BenchmarkCollectionItem(
    title: 'Browser History Guide',
    searchText: 'browser history url back forward',
    category: 'Guides',
    sortKey: 90,
    description: 'Restore canonical collection state from browser History.',
  ),
  BenchmarkCollectionItem(
    title: 'Accessible Tabs Guide',
    searchText: 'accessible keyboard aria tabs',
    category: 'Guides',
    sortKey: 80,
    description: 'Preserve semantic controls and predictable keyboard input.',
  ),
  BenchmarkCollectionItem(
    title: 'Collection Search Guide',
    searchText: 'collection search filter pagination',
    category: 'Guides',
    sortKey: 70,
    description: 'Search complete static content without hiding it from bots.',
  ),
  BenchmarkCollectionItem(
    title: 'Static HTML Guide',
    searchText: 'static html prerender seo',
    category: 'Guides',
    sortKey: 60,
    description: 'Deliver readable content before any script executes.',
  ),
  BenchmarkCollectionItem(
    title: 'Deployment Guide',
    searchText: 'deployment server static hosting',
    category: 'Guides',
    sortKey: 50,
    description: 'Choose static output or a pure server delivery path.',
  ),
  BenchmarkCollectionItem(
    title: 'Release 0.11',
    searchText: 'release application runtime carousel stepper',
    category: 'Releases',
    sortKey: 40,
    description: 'Application-owned transitions reach more components.',
  ),
  BenchmarkCollectionItem(
    title: 'Runtime Notes',
    searchText: 'runtime size csp hash validation',
    category: 'Notes',
    sortKey: 30,
    description: 'Runtime manifests bind identity, bytes and policy.',
  ),
  BenchmarkCollectionItem(
    title: 'Security Policy',
    searchText: 'security policy validation allow list',
    category: 'Notes',
    sortKey: 20,
    description: 'All mutations pass the package-owned apply boundary.',
  ),
  BenchmarkCollectionItem(
    title: 'Roadmap',
    searchText: 'roadmap effects routing forms',
    category: 'Notes',
    sortKey: 10,
    description: 'Future slices remain behind explicit admission gates.',
  ),
];

List<SeoCollectionComponentEntry> benchmarkCollectionEntries() => [
      for (final item in benchmarkCollectionItems)
        (
          title: item.title,
          searchText: item.searchText,
          categories: [item.category],
          sortKey: item.sortKey,
          nodes: [
            SeoNode(tag: 'h2', text: item.title),
            SeoNode(tag: 'p', text: item.description),
          ],
        ),
    ];

List<SeoNode> benchmarkBodyNodes() => [
      SeoNode(tag: 'main', attributes: const {
        'id': 'catalog'
      }, children: [
        SeoNode(tag: 'h1', text: 'Publishing library'),
        SeoNode(
          tag: 'p',
          text: 'Twelve complete resources with searchable, shareable state.',
        ),
        ...buildSeoCollectionNodes(
          items: benchmarkCollectionEntries(),
          interactionId: 'benchmark-collection',
          interactionLabel: 'Publishing library',
          pageSize: 4,
          synchronizeUrl: true,
        ),
      ]),
    ];
