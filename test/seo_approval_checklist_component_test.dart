import 'package:esen_seo/checklist.dart';
import 'package:esen_seo/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builder emits complete no-script content and fixed markers', () {
    final html = _html(interactionId: 'article-checklist');

    expect(html, contains('data-esen-component="approval-checklist"'));
    expect(html, contains('data-esen-initial-checked="0,1,0"'));
    expect(html, contains('data-esen-prepaint-placeholder='));
    expect(html, contains('role="progressbar"'));
    expect(html, contains('aria-valuenow="1"'));
    expect(html, contains('1 / 3'));
    expect(html, contains('Titel und Teaser geprüft'));
    expect(html, contains('Quellen nachvollziehbar'));
    expect(html, contains('Metadaten vollständig'));
    expect('data-esen-checklist-item='.allMatches(html), hasLength(3));
    expect('aria-live="polite"'.allMatches(html), hasLength(1));
  });

  test('missing or invalid id keeps the same content static', () {
    for (final id in <String?>[null, 'Invalid ID']) {
      final html = _html(interactionId: id);
      expect(html, contains('Titel und Teaser geprüft'));
      expect(html, contains('Metadaten vollständig'));
      expect(html, isNot(contains('data-esen-component')));
      expect(html, isNot(contains('data-esen-checklist-')));
      expect(html, isNot(contains('aria-live')));
    }
  });

  test('serializes a complete valid initial state deterministically', () {
    final html = _html(
      interactionId: 'article-checklist',
      state: const SeoApprovalChecklistState(checked: [true, true, true]),
    );

    expect(html, contains('data-esen-initial-checked="1,1,1"'));
    expect(html, contains('aria-valuenow="3"'));
    expect(html, contains('3 / 3'));
    expect(
      'data-esen-placeholder-checked="true"'.allMatches(html),
      hasLength(3),
    );
  });

  test('invalid item data and projection emit no component', () {
    expect(
      buildSeoApprovalChecklistNodes(
        items: const [],
        initialState: const SeoApprovalChecklistState(checked: []),
        project: _view,
      ),
      isEmpty,
    );
    final items = _items();
    expect(
      buildSeoApprovalChecklistNodes(
        items: [items.first, items.first, items.last],
        initialState: const SeoApprovalChecklistState(
          checked: [false, false, false],
        ),
        project: _view,
      ),
      isEmpty,
    );
    expect(
      buildSeoApprovalChecklistNodes(
        items: items,
        initialState: const SeoApprovalChecklistState(checked: [false]),
        project: _view,
      ),
      isEmpty,
    );
    expect(
      buildSeoApprovalChecklistNodes(
        items: items,
        initialState: const SeoApprovalChecklistState(
          checked: [false, true, false],
        ),
        project: (_) => const SeoApprovalChecklistView(
          statusText: ' ',
          summaryText: 'Summary',
          announcementText: 'Announcement',
        ),
      ),
      isEmpty,
    );
  });

  test('placeholder reserves one fixed control per item', () {
    final html = _html(interactionId: 'article-checklist');
    expect(
      'esen-seo-approval-checklist-control-placeholder'.allMatches(html),
      hasLength(3),
    );
    expect(html, contains('data-esen-placeholder-checked="false"'));
    expect(html, contains('data-esen-placeholder-checked="true"'));
  });
}

String _html({
  String? interactionId,
  SeoApprovalChecklistState state = const SeoApprovalChecklistState(
    checked: [false, true, false],
  ),
}) =>
    const HtmlRenderer().render(buildSeoApprovalChecklistNodes(
      items: _items(),
      initialState: state,
      project: _view,
      interactionId: interactionId,
      headingLevel: 1,
      heading: 'Freigabe-Checkliste',
      interactionLabel: 'Prüfpunkte für den Artikel',
      statusLabel: 'Freigabestatus',
      progressLabel: 'Prüffortschritt',
    ));

List<SeoApprovalChecklistItemEntry> _items() => [
      (
        label: 'Inhalt',
        nodes: [SeoNode(tag: 'p', text: 'Titel und Teaser geprüft')],
      ),
      (
        label: 'Quellen',
        nodes: [SeoNode(tag: 'p', text: 'Quellen nachvollziehbar')],
      ),
      (
        label: 'SEO',
        nodes: [SeoNode(tag: 'p', text: 'Metadaten vollständig')],
      ),
    ];

SeoApprovalChecklistView _view(SeoApprovalChecklistState state) {
  final count = seoApprovalChecklistCheckedCount(state);
  return SeoApprovalChecklistView(
    statusText: isSeoApprovalChecklistComplete(state) ? 'Bereit' : 'Offen',
    summaryText: '$count / ${state.checked.length} erledigt',
    announcementText: '$count Prüfpunkte erledigt',
  );
}
