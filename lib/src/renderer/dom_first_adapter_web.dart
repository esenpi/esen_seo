import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'seo_container.dart';

final RegExp domFirstHeadingTag = RegExp(r'^H[1-6]$');
final RegExp _domFirstDecimalIndex = RegExp(r'^(0|[1-9][0-9]{0,8})$');

int? domFirstInitialIndex(web.Element root, int count) {
  final raw = root.getAttribute('data-esen-initial-index');
  if (raw == null || !_domFirstDecimalIndex.hasMatch(raw)) return null;
  final index = int.tryParse(raw);
  return index != null && index >= 0 && index < count ? index : null;
}

web.Element? domFirstContainer(web.Document document) {
  final container = document.getElementById(seoContainerId);
  if (container == null ||
      container.getAttribute(seoDomFirstAttribute) != 'true' ||
      domFirstIdCount(document, seoContainerId) != 1) {
    return null;
  }
  return container;
}

web.Element? domFirstFragmentTarget(
  web.Document document,
  web.Element root,
) {
  final raw = web.window.location.hash;
  if (raw.length < 2 || raw.length > 4097) return null;
  late final String id;
  try {
    id = domFirstDecodeURIComponent(raw.substring(1).toJS).toDart;
  } catch (_) {
    return null;
  }
  if (id.isEmpty || domFirstIdCount(document, id) != 1) return null;
  final target = document.getElementById(id);
  if (target == null || !root.contains(target)) return null;
  return target;
}

bool domFirstHiddenByAncestor(
  web.Element root,
  web.Element container,
) {
  web.Element? current = root;
  while (current != null) {
    final ariaHidden = current.getAttribute('aria-hidden');
    if (current.hasAttribute('inert') ||
        (ariaHidden != null && ariaHidden.trim().toLowerCase() == 'true')) {
      return true;
    }
    if (current == container) return false;
    current = current.parentElement;
  }
  return true;
}

int domFirstIdCount(web.Document document, String id) {
  if (id.isEmpty) return 0;
  final elements = document.querySelectorAll('[id]');
  var count = 0;
  for (var index = 0; index < elements.length; index++) {
    final element = elements.item(index);
    if (element != null && (element as web.Element).id == id) count++;
  }
  return count;
}

@JS('decodeURIComponent')
external JSString domFirstDecodeURIComponent(JSString component);
