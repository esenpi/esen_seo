import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  const renderer = HtmlRenderer();

  group('pure rich-text builder', () {
    test('keeps nested inline semantics and text order', () {
      final html = renderer.render(buildSeoRichTextNodes(
        spans: const [
          SeoRichTextSpan.text('Use '),
          SeoRichTextSpan.strong(
            text: 'one ',
            children: [SeoRichTextSpan.emphasis(text: 'shared')],
          ),
          SeoRichTextSpan.text(' model with '),
          SeoRichTextSpan.code(text: 'SeoRichText'),
          SeoRichTextSpan.text(' and '),
          SeoRichTextSpan.link(href: ' /docs ', text: 'real links'),
          SeoRichTextSpan.text('.'),
        ],
      ));

      expect(
        html,
        '<p class="esen-seo-rich-text">Use '
        '<strong>one <em>shared</em></strong> model with '
        '<code>SeoRichText</code> and '
        '<a href="/docs">real links</a>.</p>',
      );
    });

    test('escapes text and filters attributes through the normal policy', () {
      final html = renderer.render(buildSeoRichTextNodes(
        attributes: const {'lang': 'de', 'onclick': 'steal()'},
        spans: const [
          SeoRichTextSpan.strong(
            text: '<b>A & B</b>',
            attributes: {'class': 'important', 'onmouseover': 'steal()'},
          ),
        ],
      ));

      expect(
        html,
        '<p class="esen-seo-rich-text" lang="de">'
        '<strong class="important">&lt;b&gt;A &amp; B&lt;/b&gt;</strong>'
        '</p>',
      );
    });

    test('unsafe and blank links become spans on every output path', () {
      final html = renderer.render(buildSeoRichTextNodes(
        spans: const [
          SeoRichTextSpan.link(
            href: 'java\tscript:alert(1)',
            text: 'unsafe',
          ),
          SeoRichTextSpan.text(' / '),
          SeoRichTextSpan.link(href: '   ', text: 'blank'),
        ],
      ));

      expect(
        html,
        '<p class="esen-seo-rich-text"><span>unsafe</span> / '
        '<span>blank</span></p>',
      );
      expect(html, isNot(contains('href')));
      expect(html, isNot(contains('script')));
    });

    test('attribute maps cannot replace the declared href', () {
      final safe = renderer.render(buildSeoRichTextNodes(
        spans: const [
          SeoRichTextSpan.link(
            href: '/safe',
            text: 'safe',
            attributes: {
              'HREF': 'javascript:alert(1)',
              'rel': 'nofollow',
            },
          ),
        ],
      ));
      final unsafe = renderer.render(buildSeoRichTextNodes(
        spans: const [
          SeoRichTextSpan.link(
            href: 'javascript:alert(1)',
            text: 'unsafe',
            attributes: {'href': '/borrowed'},
          ),
        ],
      ));

      expect(
        safe,
        '<p class="esen-seo-rich-text">'
        '<a rel="nofollow" href="/safe">safe</a></p>',
      );
      expect(
        unsafe,
        '<p class="esen-seo-rich-text"><span>unsafe</span></p>',
      );
    });

    test('nested links keep the outer navigation target only', () {
      final html = renderer.render(buildSeoRichTextNodes(
        spans: const [
          SeoRichTextSpan.link(
            href: '/outer',
            text: 'outer ',
            children: [
              SeoRichTextSpan.strong(text: 'strong '),
              SeoRichTextSpan.link(href: '/inner', text: 'inner'),
            ],
          ),
        ],
      ));

      expect(
        html,
        '<p class="esen-seo-rich-text">'
        '<a href="/outer">outer <strong>strong </strong>'
        '<span>inner</span></a></p>',
      );
      expect('href='.allMatches(html), hasLength(1));
    });

    test('line breaks survive while empty spans do not emit empty markup', () {
      final html = renderer.render(buildSeoRichTextNodes(
        spans: const [
          SeoRichTextSpan.strong(),
          SeoRichTextSpan.text('first'),
          SeoRichTextSpan.lineBreak(),
          SeoRichTextSpan.group([]),
          SeoRichTextSpan.text('zweite Zeile mit e\u0301 und مرحبا'),
        ],
      ));

      expect(
        html,
        '<p class="esen-seo-rich-text">first<br/>'
        'zweite Zeile mit e\u0301 und مرحبا</p>',
      );
      expect(renderer.render(buildSeoRichTextNodes(spans: const [])), isEmpty);
    });

    test('refuses cyclic or excessively deep CMS span trees', () {
      final cycle = <SeoRichTextSpan>[];
      cycle.add(SeoRichTextSpan.group(cycle));

      expect(
        () => buildSeoRichTextNodes(spans: cycle),
        throwsA(isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('cyclic'),
        )),
      );
    });
  });

  group('SeoRichText Flutter bridge', () {
    setUp(enableSeoForTests);

    testWidgets('uses one model for native styles and semantic HTML',
        (tester) async {
      const spans = [
        SeoRichTextSpan.strong(text: 'strong'),
        SeoRichTextSpan.text(' '),
        SeoRichTextSpan.emphasis(text: 'emphasis'),
        SeoRichTextSpan.text(' '),
        SeoRichTextSpan.code(text: 'code'),
        SeoRichTextSpan.text(' '),
        SeoRichTextSpan.link(href: '/docs', text: 'docs'),
      ];
      await pumpSeo(tester, const SeoRichText(spans: spans));

      final text = tester.widget<Text>(find.byType(Text));
      final root = text.textSpan! as TextSpan;
      final children = root.children!.cast<TextSpan>().toList();
      expect(children[0].style?.fontWeight, FontWeight.bold);
      expect(children[2].style?.fontStyle, FontStyle.italic);
      expect(children[4].style?.fontFamily, 'monospace');
      expect(children[6].style?.decoration, TextDecoration.underline);
      expect(children[6].recognizer, isNull);
      expect(
        EsenSeo.currentHtml,
        '<p class="esen-seo-rich-text"><strong>strong</strong> '
        '<em>emphasis</em> <code>code</code> '
        '<a href="/docs">docs</a></p>',
      );
    });

    testWidgets('safe link callbacks receive the trimmed target',
        (tester) async {
      String? opened;
      await pumpSeo(
        tester,
        SeoRichText(
          spans: const [
            SeoRichTextSpan.link(
              href: ' https://example.com/docs ',
              text: 'docs',
              children: [SeoRichTextSpan.strong(text: ' now')],
            ),
          ],
          onLinkTap: (href) => opened = href,
        ),
      );

      final root = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
      final link = root.children!.single as TextSpan;
      final nested = link.children!.single as TextSpan;
      expect(link.recognizer, isA<TapGestureRecognizer>());
      expect(nested.recognizer, same(link.recognizer));

      (nested.recognizer! as TapGestureRecognizer).onTap!();
      expect(opened, 'https://example.com/docs');
    });

    testWidgets('unsafe links are neither styled nor tappable in Flutter',
        (tester) async {
      var calls = 0;
      await pumpSeo(
        tester,
        SeoRichText(
          spans: const [
            SeoRichTextSpan.link(
              href: 'javascript:alert(1)',
              text: 'unsafe',
            ),
          ],
          onLinkTap: (_) => calls++,
        ),
      );

      final root = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
      final link = root.children!.single as TextSpan;
      expect(link.style, isNull);
      expect(link.recognizer, isNull);
      expect(calls, 0);
      expect(EsenSeo.currentHtml, isNot(contains('href')));
    });

    testWidgets('updated callbacks replace and dispose link recognizers',
        (tester) async {
      const key = ValueKey('rich-text');
      var firstCalls = 0;
      var secondCalls = 0;
      const spans = [SeoRichTextSpan.link(href: '/docs', text: 'docs')];

      await pumpSeo(
        tester,
        SeoRichText(
          key: key,
          spans: spans,
          onLinkTap: (_) => firstCalls++,
        ),
      );
      final firstRoot =
          tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
      final firstRecognizer =
          (firstRoot.children!.single as TextSpan).recognizer!;

      await pumpSeo(
        tester,
        SeoRichText(
          key: key,
          spans: spans,
          onLinkTap: (_) => secondCalls++,
        ),
      );
      final secondRoot =
          tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
      final secondRecognizer =
          (secondRoot.children!.single as TextSpan).recognizer!;

      expect(secondRecognizer, isNot(same(firstRecognizer)));
      (secondRecognizer as TapGestureRecognizer).onTap!();
      expect(firstCalls, 0);
      expect(secondCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty input renders and mirrors nothing', (tester) async {
      await pumpSeo(tester, const SeoRichText(spans: []));

      expect(find.byType(Text), findsNothing);
      expect(EsenSeo.currentHtml, isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
