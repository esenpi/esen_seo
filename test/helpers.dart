import 'package:esen_seo/src/controller/seo_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Turns the SEO pipeline on for tests (where kIsWeb is false) and
/// resets the controller state.
void enableSeoForTests({SeoMode mode = SeoMode.safe}) {
  SeoController.debugForceEnable = true;
  SeoController.instance.resetForTest(mode: mode);
}

/// Pumps [widget] inside a minimal app shell and regenerates the HTML.
Future<void> pumpSeo(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(
    Directionality(textDirection: TextDirection.ltr, child: widget),
  );
  EsenSeo.refresh();
}
