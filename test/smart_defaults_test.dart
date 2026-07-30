import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  setUp(enableSeoForTests);

  group('Smart Defaults (SeoMode.safe)', () {
    testWidgets('first untagged Text becomes h1, following ones p',
        (tester) async {
      await pumpSeo(
        tester,
        const Column(
          children: [
            Text('Titel'),
            Text('Erster Absatz'),
            Text('Zweiter Absatz'),
          ],
        ),
      );
      expect(
        EsenSeo.currentHtml,
        '<h1>Titel</h1><p>Erster Absatz</p><p>Zweiter Absatz</p>',
      );
    });

    testWidgets('untagged text after an explicit h1 becomes p', (tester) async {
      await pumpSeo(
        tester,
        Column(
          children: [
            const Text('Titel').seo(SeoTextTag.h1),
            const Text('Ohne Tag'),
          ],
        ),
      );
      expect(EsenSeo.currentHtml, '<h1>Titel</h1><p>Ohne Tag</p>');
    });

    testWidgets('Text().seo() without tag uses smart defaults', (tester) async {
      await pumpSeo(
        tester,
        Column(
          children: [
            const Text('Titel').seo(),
            const Text('Absatz').seo(),
          ],
        ),
      );
      expect(EsenSeo.currentHtml, '<h1>Titel</h1><p>Absatz</p>');
    });

    testWidgets('untagged Image becomes img with semanticLabel as alt',
        (tester) async {
      await pumpSeo(
        tester,
        Image.network(
          'https://example.com/logo.png',
          semanticLabel: 'Logo',
          errorBuilder: (context, error, stackTrace) => const SizedBox(),
        ),
      );
      expect(
        EsenSeo.currentHtml,
        '<img src="https://example.com/logo.png" alt="Logo"/>',
      );
    });

    testWidgets('page without any .seo() call never breaks', (tester) async {
      await pumpSeo(
        tester,
        const Column(
          children: [
            Text('Überschrift'),
            SizedBox(height: 8),
            Text('Inhalt'),
          ],
        ),
      );
      expect(EsenSeo.currentHtml, '<h1>Überschrift</h1><p>Inhalt</p>');
    });
  });

  group('SeoMode.strict', () {
    testWidgets('warns about untagged widgets but still renders them',
        (tester) async {
      enableSeoForTests(mode: SeoMode.strict);

      final warnings = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) warnings.add(message);
      };
      try {
        await pumpSeo(tester, const Text('Ohne Tag'));
      } finally {
        debugPrint = originalDebugPrint;
      }

      expect(EsenSeo.currentHtml, '<h1>Ohne Tag</h1>');
      expect(
        warnings.where((w) => w.contains('[esen_seo]')),
        hasLength(1),
      );
      expect(warnings.single, contains('Text("Ohne Tag")'));
    });

    testWidgets('does not warn for tagged widgets', (tester) async {
      enableSeoForTests(mode: SeoMode.strict);

      final warnings = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) warnings.add(message);
      };
      try {
        await pumpSeo(tester, const Text('Mit Tag').seo(SeoTextTag.h1));
      } finally {
        debugPrint = originalDebugPrint;
      }

      expect(EsenSeo.currentHtml, '<h1>Mit Tag</h1>');
      expect(warnings.where((w) => w.contains('[esen_seo]')), isEmpty);
    });
  });
}
