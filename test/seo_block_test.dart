import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A block as a package user would write one: the rows are the single
/// source, both presentations derive from them.
class _Specs extends SeoBlock {
  const _Specs(this.rows);

  final List<(String, String)> rows;

  @override
  Widget buildFlutter(BuildContext context) => Column(
        children: [
          for (final (name, value) in rows) Text('$name: $value'),
        ],
      );

  @override
  List<SeoNode> toSeoNodes() => [
        SeoNode(tag: 'dl', children: [
          for (final (name, value) in rows) ...[
            SeoNode(tag: 'dt', text: name),
            SeoNode(tag: 'dd', text: value),
          ],
        ]),
      ];
}

/// A stateful block: what is on screen changes, the mirror does not.
class _Toggle extends StatefulWidget {
  const _Toggle(this.items);

  final List<String> items;

  @override
  State<_Toggle> createState() => _ToggleState();
}

class _ToggleState extends State<_Toggle> with SeoBlockState<_Toggle> {
  bool _open = false;

  @override
  Widget buildFlutter(BuildContext context) => GestureDetector(
        onTap: () => setState(() => _open = true),
        child: Column(
          children: [
            const Text('Mehr'),
            if (_open)
              for (final item in widget.items) Text(item),
          ],
        ),
      );

  @override
  List<SeoNode> toSeoNodes() => [
        SeoNode(tag: 'ul', children: [
          for (final item in widget.items) SeoNode(tag: 'li', text: item),
        ]),
      ];
}

void main() {
  setUp(enableSeoForTests);

  group('SeoBlock', () {
    testWidgets('renders Flutter and mirrors HTML from one source',
        (tester) async {
      await pumpSeo(
        tester,
        const _Specs([('Gewicht', '8,4 kg'), ('Rahmen', 'Carbon')]),
      );
      expect(find.text('Gewicht: 8,4 kg'), findsOneWidget);
      expect(
        EsenSeo.currentHtml,
        '<dl><dt>Gewicht</dt><dd>8,4 kg</dd>'
        '<dt>Rahmen</dt><dd>Carbon</dd></dl>',
      );
    });

    testWidgets('the declared nodes replace the subtree', (tester) async {
      // Sonst spiegelte der Flutter-Text zusätzlich als Smart Default.
      await pumpSeo(tester, const _Specs([('A', 'B')]));
      expect(EsenSeo.currentHtml, isNot(contains('A: B')));
    });

    testWidgets('the policy applies to declared nodes too', (tester) async {
      await pumpSeo(tester, const _Evil());
      expect(EsenSeo.currentHtml, '<div>böse()</div>');
    });
  });

  group('SeoBlockState', () {
    testWidgets('the mirror is complete regardless of the state',
        (tester) async {
      await pumpSeo(tester, const _Toggle(['A', 'B']));
      // Zu: nur „Mehr" auf dem Schirm …
      expect(find.text('A'), findsNothing);
      final closed = EsenSeo.currentHtml;
      expect(closed, '<ul><li>A</li><li>B</li></ul>');

      // … aufgeklappt ändert sich der Spiegel nicht.
      await tester.tap(find.text('Mehr'));
      await tester.pump();
      EsenSeo.refresh();
      expect(find.text('A'), findsOneWidget);
      expect(EsenSeo.currentHtml, closed);
    });
  });
}

/// A block that declares something the policy must refuse.
class _Evil extends SeoBlock {
  const _Evil();

  @override
  Widget buildFlutter(BuildContext context) => const SizedBox();

  @override
  List<SeoNode> toSeoNodes() => [
        SeoNode(
          tag: 'script',
          text: 'böse()',
          attributes: {'onload': 'böse()'},
        ),
      ];
}
