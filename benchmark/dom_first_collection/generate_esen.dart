import 'dart:io';

import 'package:esen_seo/server.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln(
      'Usage: dart run benchmark/dom_first_collection/generate_esen.dart OUT',
    );
    exitCode = 64;
    return;
  }
  final css = await File(
    'benchmark/dom_first_collection/fixtures/shared.css',
  ).readAsString();
  const runtimeReference =
      SeoDomFirstApplicationRuntime.collection('benchmark-collection');
  final runtime = await SeoDirectoryRuntimeStore(
    'benchmark/dom_first_collection/fixtures/application/'
    'build/esen_seo/runtimes',
  ).load(runtimeReference);
  final html = SeoPage.domFirstFromNodes(
    meta: const SeoMeta(title: 'Collection history benchmark'),
    body: _body,
    stylesheet: css,
    applicationRuntime: runtime,
  ).toHtmlDocument();
  final output = File(arguments.single);
  await output.parent.create(recursive: true);
  await output.writeAsString(html);
}

final _body = [
  SeoNode(tag: 'main', attributes: const {
    'id': 'catalog'
  }, children: [
    SeoNode(tag: 'h1', text: 'Publishing library'),
    SeoNode(
      tag: 'p',
      text: 'Twelve complete resources with searchable, shareable state.',
    ),
    ...buildSeoCollectionNodes(
      items: [
        for (final item in _items)
          (
            title: item.title,
            searchText: item.searchText,
            categories: item.categories,
            sortKey: item.sortKey,
            nodes: [
              SeoNode(tag: 'h2', text: item.title),
              SeoNode(tag: 'p', text: item.description),
            ],
          ),
      ],
      interactionId: 'benchmark-collection',
      interactionLabel: 'Publishing library',
      pageSize: 4,
      synchronizeUrl: true,
    ),
  ]),
];

const _items = <({
  String title,
  String searchText,
  List<String> categories,
  int sortKey,
  String description,
})>[
  (
    title: 'Dart Rendering Guide',
    searchText: 'dart flutter rendering semantic',
    categories: ['Guides'],
    sortKey: 120,
    description: 'Render one Dart model into native widgets and semantic HTML.',
  ),
  (
    title: 'CSS Token Guide',
    searchText: 'css design tokens styling',
    categories: ['Guides'],
    sortKey: 110,
    description: 'Keep visual tokens aligned across permanent web documents.',
  ),
  (
    title: 'JavaScript State Guide',
    searchText: 'javascript state transition progressive',
    categories: ['Guides'],
    sortKey: 100,
    description: 'Compile bounded transitions for progressive interaction.',
  ),
  (
    title: 'Browser History Guide',
    searchText: 'browser history url back forward',
    categories: ['Guides'],
    sortKey: 90,
    description: 'Restore canonical collection state from browser History.',
  ),
  (
    title: 'Accessible Tabs Guide',
    searchText: 'accessible keyboard aria tabs',
    categories: ['Guides'],
    sortKey: 80,
    description: 'Preserve semantic controls and predictable keyboard input.',
  ),
  (
    title: 'Collection Search Guide',
    searchText: 'collection search filter pagination',
    categories: ['Guides'],
    sortKey: 70,
    description: 'Search complete static content without hiding it from bots.',
  ),
  (
    title: 'Static HTML Guide',
    searchText: 'static html prerender seo',
    categories: ['Guides'],
    sortKey: 60,
    description: 'Deliver readable content before any script executes.',
  ),
  (
    title: 'Deployment Guide',
    searchText: 'deployment server static hosting',
    categories: ['Guides'],
    sortKey: 50,
    description: 'Choose static output or a pure server delivery path.',
  ),
  (
    title: 'Release 0.11',
    searchText: 'release application runtime carousel stepper',
    categories: ['Releases'],
    sortKey: 40,
    description: 'Application-owned transitions reach more components.',
  ),
  (
    title: 'Runtime Notes',
    searchText: 'runtime size csp hash validation',
    categories: ['Notes'],
    sortKey: 30,
    description: 'Runtime manifests bind identity, bytes and policy.',
  ),
  (
    title: 'Security Policy',
    searchText: 'security policy validation allow list',
    categories: ['Notes'],
    sortKey: 20,
    description: 'All mutations pass the package-owned apply boundary.',
  ),
  (
    title: 'Roadmap',
    searchText: 'roadmap effects routing forms',
    categories: ['Notes'],
    sortKey: 10,
    description: 'Future slices remain behind explicit admission gates.',
  ),
];
