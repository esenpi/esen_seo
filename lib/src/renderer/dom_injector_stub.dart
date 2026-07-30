import 'seo_node.dart';

/// No-op DOM injector for platforms without a DOM (mobile, desktop, tests).
///
/// The web implementation lives in `dom_injector_web.dart` and is selected
/// through a conditional import in the [SeoController].
void injectSeoNodes(List<SeoNode> nodes) {}

/// No-op counterpart of the web head injection.
void injectMetaNodes(List<SeoNode> nodes) {}

/// No-op counterpart of the web title handling.
void applyDocumentTitle(String title) {}
