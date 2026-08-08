// Der Drift-Guard der Theme-Brücke, verdrahtet wie im README:
// ein gewöhnlicher Test, der bei jedem CI-Lauf prüft, dass
// lib/seo_theme.g.dart noch zum Theme der App passt.
//
// Regenerieren (nach jeder Theme-Änderung):
//   flutter test test/seo_theme_css_test.dart --dart-define=esenSeoUpdate=true
import 'package:esen_seo/esen_seo.dart';
import 'package:esen_seo/testing.dart';
import 'package:example/main.dart';
import 'package:example/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the shell stylesheet matches the app theme', () {
    checkOrUpdateSeoThemeCss(
      seoStylesheetFromTheme(buildLightTheme(), darkTheme: buildDarkTheme()),
    );
  });

  testWidgets('the app really uses the theme the guard watches',
      (tester) async {
    // Das letzte Glied: der Guard misst buildLightTheme() — dieser Test
    // beweist, dass MaterialApp dieselbe Funktion nutzt und nicht ein
    // inline nachgebautes Theme, das lautlos driften könnte.
    await tester.pumpWidget(const EsenSeoExampleApp());
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme, buildLightTheme());
    expect(app.darkTheme, buildDarkTheme());
  });
}
