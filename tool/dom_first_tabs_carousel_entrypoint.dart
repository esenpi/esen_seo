import 'dart:js_interop';

import 'package:esen_seo/src/renderer/dom_first_carousel_adapter_web.dart';
import 'package:esen_seo/src/renderer/dom_first_tabs_adapter_web.dart';
import 'package:web/web.dart' as web;

void _enhance() {
  enhanceSeoDomFirstTabs();
  enhanceSeoDomFirstCarousels();
}

void main() {
  web.document.documentElement?.addEventListener(
    'esen-seo:navigation',
    ((web.Event _) => _enhance()).toJS,
  );
  _enhance();
}
