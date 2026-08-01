import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import '../renderer/dom_injector_stub.dart'
    if (dart.library.js_interop) '../renderer/dom_injector_web.dart'
    as injector;
import '../meta/seo_meta.dart';
import '../renderer/html_renderer.dart';
import '../renderer/image_source.dart';
import '../renderer/seo_node.dart';
import '../renderer/tag_policy.dart';
import '../widgets/seo_widget.dart';

/// Controls how esen_seo treats widgets that carry no `.seo()` tag.
enum SeoMode {
  /// Render everything, even widgets without `.seo()`, using smart defaults.
  /// The page never breaks.
  safe,

  /// Like [safe], but additionally print a warning for every widget that
  /// is missing its `.seo()` call.
  strict,
}

/// Public entry point of the esen_seo package.
///
/// ```dart
/// void main() {
///   EsenSeo.init(mode: SeoMode.safe);
///   runApp(const MyApp());
/// }
/// ```
///
/// Calling [init] is optional — the pipeline starts automatically as soon
/// as the first `.seo()` widget is mounted. Use [init] to pick a [SeoMode]
/// or to cover apps that rely purely on smart defaults.
class EsenSeo {
  const EsenSeo._();

  /// Starts the SEO pipeline and selects the [SeoMode].
  ///
  /// With [cleanUrls] the app uses path URLs (`/demo`) instead of hash
  /// fragments (`/#/demo`) — crawlers ignore fragments, so this is
  /// strongly recommended for SEO. No-op on non-web platforms.
  static void init({SeoMode mode = SeoMode.safe, bool cleanUrls = false}) {
    if (cleanUrls) usePathUrlStrategy();
    WidgetsFlutterBinding.ensureInitialized();
    SeoController.instance.init(mode: mode);
  }

  /// Rebuilds the semantic HTML from the current widget tree immediately.
  static void refresh() => SeoController.instance.refresh();

  /// Sets the page metadata: `<title>`, description, OpenGraph, Twitter Card.
  ///
  /// ```dart
  /// EsenSeo.setMeta(const SeoMeta(
  ///   title: 'Willkommen',
  ///   description: 'Flutter Apps mit echtem SEO.',
  /// ));
  /// ```
  ///
  /// Call it again with new values on navigation — the previously injected
  /// tags are replaced.
  static void setMeta(SeoMeta meta) => SeoController.instance.setMeta(meta);

  /// The most recently generated HTML fragment.
  static String get currentHtml => SeoController.instance.lastHtml;

  /// The most recently generated `<head>` fragment from [setMeta].
  static String get currentHeadHtml => SeoController.instance.lastHeadHtml;
}

/// Internal singleton that walks the element tree, applies smart defaults,
/// renders the HTML and hands it to the DOM injector.
class SeoController {
  SeoController._();

  /// The single controller instance shared by all `.seo()` widgets.
  static final SeoController instance = SeoController._();

  /// Forces the pipeline on in unit tests, where [kIsWeb] is false.
  @visibleForTesting
  static bool debugForceEnable = false;

  /// Whether the SEO pipeline is active on this platform.
  static bool get enabled => kIsWeb || debugForceEnable;

  SeoMode _mode = SeoMode.safe;
  String _lastHtml = '';
  String _lastHeadHtml = '';
  SeoMeta? _meta;
  bool _regenerationScheduled = false;
  bool _hasInjected = false;

  /// The most recently generated HTML fragment.
  String get lastHtml => _lastHtml;

  /// The most recently generated `<head>` fragment.
  String get lastHeadHtml => _lastHeadHtml;

  /// The metadata from the last [setMeta] call, e.g. for the SSR server.
  SeoMeta? get meta => _meta;

  /// Whether [refresh] has injected into the DOM at least once.
  @visibleForTesting
  bool get debugHasInjected => _hasInjected;

  /// Selects the [SeoMode] and schedules a first render.
  void init({SeoMode mode = SeoMode.safe}) {
    _mode = mode;
    markDirty();
  }

  /// Sets the page metadata and injects it into the document `<head>`.
  void setMeta(SeoMeta meta) {
    _meta = meta;
    if (!enabled) return;
    final nodes = meta.toNodes();
    _lastHeadHtml = const HtmlRenderer().render(nodes);
    injector.injectMetaNodes(nodes);
  }

  /// Resets all state between tests.
  @visibleForTesting
  void resetForTest({SeoMode mode = SeoMode.safe}) {
    _mode = mode;
    _lastHtml = '';
    _lastHeadHtml = '';
    _meta = null;
    _regenerationScheduled = false;
    _hasInjected = false;
  }

  /// Schedules a regeneration for the end of the current frame.
  ///
  /// Called by every [SeoWidget] on mount, update and dispose. Multiple
  /// calls within one frame collapse into a single regeneration.
  void markDirty() {
    if (!enabled || _regenerationScheduled) return;
    _regenerationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _regenerationScheduled = false;
      refresh();
    });
  }

  /// Walks the element tree, renders the HTML and injects it into the DOM.
  void refresh() {
    if (!enabled) return;
    final root = WidgetsBinding.instance.rootElement;
    if (root == null) return;

    // MaterialApp's Title widget overwrites document.title on rebuild —
    // re-assert the meta title on every refresh so it stays visible.
    final metaTitle = _meta?.title;
    if (metaTitle != null) injector.applyDocumentTitle(metaTitle);

    final nodes = collectNodes(root);
    final html = const HtmlRenderer().render(nodes);
    // Die erste Injection muss auch bei leerem Baum laufen — sie startet
    // den visibleShell-Handoff. Erst danach darf unverändertes HTML
    // übersprungen werden.
    if (_hasInjected && html == _lastHtml) return;

    _lastHtml = html;
    injector.injectSeoNodes(nodes);
    _hasInjected = true;
  }

  /// Mirrors the element tree below [root] as a list of [SeoNode]s.
  @visibleForTesting
  List<SeoNode> collectNodes(Element root) {
    final state = _TraversalState(_mode);
    return _childrenOf(root, state, inLink: false);
  }

  List<SeoNode> _childrenOf(
    Element element,
    _TraversalState state, {
    required bool inLink,
  }) {
    final nodes = <SeoNode>[];
    element.visitChildren((child) {
      nodes.addAll(_visit(child, state, inLink: inLink));
    });
    return nodes;
  }

  List<SeoNode> _visit(
    Element element,
    _TraversalState state, {
    required bool inLink,
  }) {
    final widget = element.widget;

    // Widgets that are kept in the tree but not shown (e.g. inactive
    // navigator routes) must not leak into the page's HTML.
    if (widget is Offstage && widget.offstage) return const [];

    if (widget is SeoWidget) {
      final attributes = state.resolveAttributes(widget.attributes);
      switch (widget.type) {
        case SeoElementType.custom:
          // Die deklarierte Übersetzung ersetzt den kompletten Subtree —
          // dessen Widgets würden den Inhalt sonst doppelt spiegeln.
          return [
            for (final node in widget.nodes ?? const <SeoNode>[])
              _sanitizeNode(node, state),
          ];
        case SeoElementType.text:
          return [
            _textNode(
              widget.tag,
              widget.content ?? '',
              state,
              inLink: inLink,
              attributes: attributes,
            ),
          ];
        case SeoElementType.image:
          return [SeoNode(tag: 'img', attributes: attributes)];
        case SeoElementType.link:
          return [
            SeoNode(
              tag: widget.tag ?? 'a',
              attributes: attributes,
              children: _childrenOf(element, state, inLink: true),
            ),
          ];
        case SeoElementType.container:
          return [
            SeoNode(
              tag: widget.tag == null
                  ? 'div'
                  : state.resolveTag(widget.tag!, fallback: 'div'),
              attributes: attributes,
              children: _childrenOf(element, state, inLink: inLink),
            ),
          ];
      }
    }

    if (widget is Text) {
      final content = widget.data ?? widget.textSpan?.toPlainText() ?? '';
      state.warnUntagged('Text("$content")');
      return [_textNode(null, content, state, inLink: inLink)];
    }

    if (widget is Image) {
      final src = seoImageSource(widget.image);
      state.warnUntagged('Image($src)');
      return [
        SeoNode(
          tag: 'img',
          attributes: {'src': src, 'alt': widget.semanticLabel ?? ''},
        ),
      ];
    }

    return _childrenOf(element, state, inLink: inLink);
  }

  /// Applies the tag and attribute policy to a declared node tree —
  /// custom translations get exactly the same safety net as `.seo()`
  /// calls: blocked tags fall back to `div`, blocked attributes are
  /// dropped, and raw (unescaped) text never enters from user land.
  SeoNode _sanitizeNode(SeoNode node, _TraversalState state) {
    // Ein leerer Tag ist ein reiner Textknoten — aber nur, wenn nichts
    // darunter hängt. Mit Kindern wäre es ein Wrapper, dessen Inhalt
    // sonst spurlos verschwände; der fällt auf div zurück wie jeder
    // andere unbrauchbare Tag auch.
    if (node.isTextOnly && node.children.isEmpty) {
      return SeoNode.text(node.text ?? '');
    }
    final tag = state.resolveTag(node.tag, fallback: 'div');
    // Eine deklarierte Überschrift zählt für die Smart Defaults genauso
    // wie eine getaggte — sonst vergibt die Seite ein zweites <h1>.
    state.noteTag(tag);
    return SeoNode(
      tag: tag,
      text: node.text,
      attributes: state.resolveAttributes(node.attributes),
      children: [
        for (final child in node.children) _sanitizeNode(child, state),
      ],
    );
  }

  SeoNode _textNode(
    String? tag,
    String content,
    _TraversalState state, {
    required bool inLink,
    Map<String, String>? attributes,
  }) {
    if (tag != null) {
      final safeTag = state.resolveTag(tag, fallback: 'span');
      state.noteTag(safeTag);
      return SeoNode(tag: safeTag, text: content, attributes: attributes);
    }
    // Inside a link the text becomes the anchor label instead of its own
    // paragraph: <a href="...">label</a>.
    if (inLink) return SeoNode.text(content);
    return SeoNode(
      tag: state.nextSmartTextTag(),
      text: content,
      attributes: attributes,
    );
  }
}

/// Mutable state carried through one traversal pass.
class _TraversalState {
  _TraversalState(this.mode);

  final SeoMode mode;
  bool _h1Used = false;

  void noteTag(String tag) {
    if (tag == 'h1') _h1Used = true;
  }

  /// Normalizes an explicit tag and swaps blocked or invalid ones for
  /// [fallback], so the page keeps rendering no matter what.
  String resolveTag(String tag, {required String fallback}) {
    final normalized = normalizeSeoTag(tag);
    if (normalized != null) return normalized;
    if (mode == SeoMode.strict) {
      debugPrint(
        '[esen_seo] strict mode: tag "$tag" is blocked or invalid — '
        'rendered as <$fallback> instead.',
      );
    }
    return fallback;
  }

  /// Normalizes attribute names and silently drops blocked ones
  /// (`onclick` & Co., `javascript:`-URLs, invalid names) — with a
  /// warning in [SeoMode.strict].
  Map<String, String> resolveAttributes(Map<String, String> attributes) {
    if (attributes.isEmpty) return attributes;
    final safe = <String, String>{};
    attributes.forEach((name, value) {
      final normalized = name.trim().toLowerCase();
      if (isAllowedSeoAttribute(normalized, value)) {
        safe[normalized] = value;
      } else if (mode == SeoMode.strict) {
        debugPrint(
          '[esen_seo] strict mode: attribute "$name" is blocked — dropped.',
        );
      }
    });
    return safe;
  }

  /// Smart default: the first text on the page becomes the `<h1>`,
  /// every following one a `<p>`.
  String nextSmartTextTag() {
    if (_h1Used) return 'p';
    _h1Used = true;
    return 'h1';
  }

  void warnUntagged(String description) {
    if (mode != SeoMode.strict) return;
    debugPrint(
      '[esen_seo] strict mode: $description has no .seo() tag — '
      'rendered with smart defaults.',
    );
  }
}
