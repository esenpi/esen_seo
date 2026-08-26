import 'seo_action_form_markup.dart';
import 'seo_node.dart';
import 'tag_policy.dart';

/// Where a rendered fragment is going to land.
enum SeoRenderTarget {
  /// Inside `<body>` — the ordinary tag and attribute policy applies.
  body,

  /// Inside `<head>` — only the head elements esen_seo manages are
  /// allowed, and nothing else gets in.
  head,
}

/// Renders a tree of [SeoNode]s into a clean, semantic HTML string.
///
/// Pure Dart with no platform dependencies, so it runs everywhere:
/// in the browser, on the Dart server and in unit tests.
///
/// **The renderer is the choke point for safety.** Tags and attributes
/// are filtered here, not by the caller, because every path to HTML —
/// the Flutter mirror, the SSR middleware and the prerenderer — ends up
/// in this class. A node tree assembled from untrusted data (a CMS
/// block, say) can therefore not smuggle a `<script>`, an `onerror=`
/// handler or a broken-out attribute into the output, no matter which
/// path it took to get here.
class HtmlRenderer {
  /// A renderer for body content.
  const HtmlRenderer()
      : target = SeoRenderTarget.body,
        _domFirst = false;

  /// A renderer for a permanent DOM-first body.
  const HtmlRenderer.domFirst()
      : target = SeoRenderTarget.body,
        _domFirst = true;

  /// A renderer for the document head — used by `SeoMeta`, whose tags
  /// (`title`, `meta`, `link`, …) the body policy deliberately blocks.
  const HtmlRenderer.head()
      : target = SeoRenderTarget.head,
        _domFirst = false;

  /// Which policy this renderer applies.
  final SeoRenderTarget target;

  final bool _domFirst;

  /// Renders a list of top-level nodes into one HTML fragment.
  String render(List<SeoNode> nodes) {
    final buffer = StringBuffer();
    for (final node in nodes) {
      _write(buffer, node);
    }
    return buffer.toString();
  }

  /// Renders a single node including all of its children.
  String renderNode(SeoNode node) {
    final buffer = StringBuffer();
    _write(buffer, node);
    return buffer.toString();
  }

  /// The tag [node] actually becomes under the **body** policy, or
  /// `null` for a pure text node, which renders as escaped text rather
  /// than as an element.
  ///
  /// This is the render decision itself, exposed: the audit walks this
  /// same view, so what it checks is the HTML that ships rather than
  /// the raw tree. An `<img>` carrying text really renders as a
  /// `<span>`, and an `<a>` inside an `<a>` really loses its link —
  /// [inAnchor] mirrors that nesting. Auditing the raw tree reported a
  /// broken image on a node the renderer had already turned into
  /// something else entirely.
  static String? effectiveBodyTag(SeoNode node, {bool inAnchor = false}) {
    // Ein leerer Tag ist ein Textknoten — aber nur ohne Kinder. Mit
    // Kindern wäre er ein Wrapper, dessen Inhalt sonst spurlos
    // verschwindet (der Controller fängt das ab, der Renderer muss es
    // auch tun, weil die Server-Pfade nicht durch ihn laufen).
    if (node.isTextOnly && node.children.isEmpty) return null;

    // JSON-LD is the one script that is content rather than code.
    // Anything else not on the allow list degrades to a neutral
    // container instead of taking the page down with it.
    var tag = node.tag == 'script' && _isJsonLd(effectiveAttributeNames(node))
        ? 'script'
        : (normalizeSeoTag(node.tag) ?? 'div');

    // Ein <a> in einem <a> lässt der HTML-Parser nicht stehen: Er
    // schließt den äußeren Link und hängt dessen Beschriftung daneben —
    // der Link des Entwicklers wäre weg. Der innere wird zum span.
    if (tag == 'a' && inAnchor) tag = 'span';

    // Ein leeres Element kann keinen Inhalt tragen; als span geht
    // nichts verloren.
    final hasContent =
        node.text != null || node.rawText != null || node.children.isNotEmpty;
    if (SeoNode.voidElements.contains(tag) && hasContent) tag = 'span';

    return tag;
  }

  /// [node]'s attributes under the same name normalization the renderer
  /// applies before writing: trimmed and lower-cased, a later duplicate
  /// replacing an earlier one. An audit reading the raw map looks at a
  /// key the output may never carry.
  static Map<String, String> effectiveAttributeNames(SeoNode node) {
    final attributes = <String, String>{};
    node.attributes.forEach((name, value) {
      attributes[name.trim().toLowerCase()] = value;
    });
    return attributes;
  }

  /// No real document nests this deep; a tree that does is broken —
  /// usually a resolver that built a self-referential node. Refusing
  /// with a diagnosable error beats the alternative on both sides:
  /// silent truncation would ship an incomplete page, and recursing on
  /// would end in a StackOverflowError that names nothing.
  static const int maxDepth = 500;

  /// Writes [node] into [buffer] — one shared buffer for the whole
  /// tree instead of one string allocation per node.
  void _write(
    StringBuffer buffer,
    SeoNode node, {
    bool inAnchor = false,
    int depth = 0,
  }) {
    if (depth > maxDepth) {
      throw StateError(
        'SeoNode tree nests deeper than $maxDepth levels — is a resolver '
        'building a self-referential tree? Refusing to render it rather '
        'than overflowing the stack mid-request.',
      );
    }
    final actionForm = internalSeoActionFormMarkup(node);
    if (_domFirst &&
        actionForm != null &&
        isValidInternalSeoActionFormMarkup(actionForm)) {
      _writeActionForm(buffer, actionForm);
      return;
    }
    if (node.isTextOnly && node.children.isEmpty) {
      buffer.write(escapeText(node.text ?? ''));
      return;
    }

    // Namen einmal normalisieren: Zwei Schlüssel, die sich nur in der
    // Schreibweise unterscheiden, würden sonst zweimal ausgegeben — und
    // HTML nimmt das erste, während unsere Prüfung das zweite ansah.
    final attributes = effectiveAttributeNames(node);

    String? tag;
    if (target == SeoRenderTarget.body) {
      tag = effectiveBodyTag(node, inAnchor: inAnchor);
    } else {
      tag = _resolveHeadTag(node, attributes);
      if (tag != null) {
        final hasContent = node.text != null ||
            node.rawText != null ||
            node.children.isNotEmpty;
        if (SeoNode.voidElements.contains(tag) && hasContent) tag = 'span';
      }
    }
    if (tag == null) return; // nichts, was hier stehen dürfte

    // Ein abgelehntes Element verliert mit seiner Identität auch seine
    // Attribute: `action` oder `values` gehören zu dem Element, das es
    // nicht sein darf, und haben auf einem <div> nichts zu suchen.
    final refused = tag != node.tag.trim().toLowerCase();

    buffer
      ..write('<')
      ..write(tag);
    if (!refused) {
      attributes.forEach((name, value) {
        // Namen werden hier geprüft, nicht escaped: Ein Name, der die
        // Policy nicht besteht, hat im Dokument nichts verloren — ein
        // escapetes `x" onmouseover="…` wäre bloß kaputtes Markup.
        if (!isAllowedSeoAttribute(name, value)) return;
        if (target == SeoRenderTarget.head && !_allowedHeadAttribute(name)) {
          return;
        }
        buffer
          ..write(' ')
          ..write(name)
          ..write('="')
          ..write(escapeAttribute(value))
          ..write('"');
      });
    }

    if (SeoNode.voidElements.contains(tag)) {
      buffer.write('/>');
      return;
    }

    buffer.write('>');
    if (node.text != null) buffer.write(escapeText(node.text!));
    if (node.rawText != null) {
      // Verbatim only where it is the point: a JSON-LD payload, whose
      // `<` is escaped so it cannot close the element or start markup.
      // Anywhere else rawText is content, and content gets escaped —
      // otherwise this one field bypasses tag policy, attribute policy
      // and text escaping all at once.
      buffer.write(_isJsonLd(attributes)
          ? escapeJsonLd(node.rawText!)
          : escapeText(node.rawText!));
    }
    // A JSON-LD element holds a string, not markup: rendering children
    // into it would close the script early.
    if (!_isJsonLd(attributes) || node.tag != 'script') {
      final nested = inAnchor || tag == 'a';
      for (final child in node.children) {
        _write(buffer, child, inAnchor: nested, depth: depth + 1);
      }
    }
    buffer
      ..write('</')
      ..write(tag)
      ..write('>');
  }

  void _writeActionForm(
    StringBuffer buffer,
    SeoActionFormMarkup form,
  ) {
    if (form.flow case final flow?) {
      _writeActionFlow(buffer, form, flow);
      return;
    }
    final actionId = form.actionId;
    final rootId = 'esen-action-form-$actionId';
    buffer
      ..write('<section id="')
      ..write(rootId)
      ..write('" class="esen-seo-action-form" ')
      ..write('data-esen-component="action-form" ')
      ..write('data-esen-action-form-root="')
      ..write(actionId)
      ..write('"><h')
      ..write(form.headingLevel)
      ..write('>')
      ..write(escapeText(form.heading))
      ..write('</h')
      ..write(form.headingLevel)
      ..write('><p class="esen-seo-action-form-description">')
      ..write(escapeText(form.description))
      ..write('</p><form method="post" accept-charset="UTF-8" action="')
      ..write(internalSeoActionFormEndpointPrefix)
      ..write(actionId)
      ..write('" data-esen-action-form="')
      ..write(actionId)
      ..write('" data-esen-failure-label="')
      ..write(escapeAttribute(form.failureLabel))
      ..write('">');

    for (final (index, field) in form.fields.indexed) {
      _writeActionFormField(buffer, rootId, index, field);
    }

    buffer
      ..write('<button type="submit" data-esen-action-form-submit ')
      ..write('data-esen-pending-label="')
      ..write(escapeAttribute(form.pendingLabel))
      ..write('">')
      ..write(escapeText(form.submitLabel))
      ..write('</button><p class="esen-seo-action-form-status" ')
      ..write('data-esen-action-form-status role="status" ')
      ..write('aria-live="polite" aria-atomic="true" aria-label="')
      ..write(escapeAttribute(form.statusLabel))
      ..write('"></p></form></section>');
  }

  void _writeActionFlow(
    StringBuffer buffer,
    SeoActionFormMarkup form,
    SeoActionFlowMarkup flow,
  ) {
    final actionId = form.actionId;
    final rootId = 'esen-action-flow-$actionId';
    final stepHeadingLevel = form.headingLevel < 6 ? form.headingLevel + 1 : 6;
    buffer
      ..write('<section id="')
      ..write(rootId)
      ..write('" class="esen-seo-action-flow" ')
      ..write('data-esen-component="action-flow" ')
      ..write('data-esen-layout-stable="true" ')
      ..write('data-esen-action-flow-root="')
      ..write(actionId)
      ..write('"><h')
      ..write(form.headingLevel)
      ..write('>')
      ..write(escapeText(form.heading))
      ..write('</h')
      ..write(form.headingLevel)
      ..write('><p class="esen-seo-action-form-description">')
      ..write(escapeText(form.description))
      ..write('</p><ol class="esen-seo-action-flow-progress" aria-label="')
      ..write(escapeAttribute(flow.progressLabel))
      ..write('">');
    for (final (index, step) in flow.steps.indexed) {
      buffer
        ..write('<li data-esen-action-flow-progress="')
        ..write(index)
        ..write('">')
        ..write(escapeText(step.label))
        ..write('</li>');
    }
    buffer
      ..write('</ol><form method="post" accept-charset="UTF-8" action="')
      ..write(internalSeoActionFormEndpointPrefix)
      ..write(actionId)
      ..write('" data-esen-action-flow="')
      ..write(actionId)
      ..write('" data-esen-failure-label="')
      ..write(escapeAttribute(form.failureLabel))
      ..write('">');
    for (final (stepIndex, step) in flow.steps.indexed) {
      final headingId = '$rootId-step-$stepIndex-heading';
      buffer
        ..write('<section class="esen-seo-action-flow-step" ')
        ..write('data-esen-action-flow-step="')
        ..write(stepIndex)
        ..write('" aria-labelledby="')
        ..write(headingId)
        ..write('"><h')
        ..write(stepHeadingLevel)
        ..write(' id="')
        ..write(headingId)
        ..write('" tabindex="-1">')
        ..write(escapeText(step.label))
        ..write('</h')
        ..write(stepHeadingLevel)
        ..write('><p>')
        ..write(escapeText(step.description))
        ..write('</p>');
      for (var offset = 0; offset < step.fieldCount; offset++) {
        final fieldIndex = step.firstFieldIndex + offset;
        _writeActionFormField(
          buffer,
          rootId,
          fieldIndex,
          form.fields[fieldIndex],
        );
      }
      buffer.write('</section>');
    }
    buffer
      ..write('<div class="esen-seo-action-flow-navigation" ')
      ..write('data-esen-action-flow-navigation hidden>')
      ..write('<button type="button" data-esen-action-flow-previous>')
      ..write(escapeText(flow.previousLabel))
      ..write('</button><button type="button" data-esen-action-flow-next>')
      ..write(escapeText(flow.nextLabel))
      ..write('</button></div><button type="submit" ')
      ..write('data-esen-action-form-submit data-esen-pending-label="')
      ..write(escapeAttribute(form.pendingLabel))
      ..write('">')
      ..write(escapeText(form.submitLabel))
      ..write('</button><p class="esen-seo-action-form-status" ')
      ..write('data-esen-action-form-status role="status" ')
      ..write('aria-live="polite" aria-atomic="true" aria-label="')
      ..write(escapeAttribute(form.statusLabel))
      ..write('"></p></form></section>');
  }

  void _writeActionFormField(
    StringBuffer buffer,
    String rootId,
    int index,
    SeoActionFormMarkupField field,
  ) {
    final controlId = '$rootId-field-$index';
    final descriptionId = '$controlId-description';
    final errorId = '$controlId-error';
    final describedBy =
        field.description == null ? errorId : '$descriptionId $errorId';
    final kind = switch (field.kind) {
      SeoActionFormMarkupFieldKind.text => 'text',
      SeoActionFormMarkupFieldKind.email => 'email',
      SeoActionFormMarkupFieldKind.multiline => 'multiline',
      SeoActionFormMarkupFieldKind.consent => 'consent',
      SeoActionFormMarkupFieldKind.choice => 'choice',
    };
    buffer
      ..write('<div class="esen-seo-action-form-field" ')
      ..write('data-esen-action-form-field="')
      ..write(index)
      ..write('" data-esen-action-form-kind="')
      ..write(kind)
      ..write('"><label for="')
      ..write(controlId)
      ..write('">')
      ..write(escapeText(field.label))
      ..write('</label>');
    if (field.description case final description?) {
      buffer
        ..write('<p id="')
        ..write(descriptionId)
        ..write('" class="esen-seo-action-form-hint">')
        ..write(escapeText(description))
        ..write('</p>');
    }
    if (field.kind == SeoActionFormMarkupFieldKind.multiline) {
      buffer
        ..write('<textarea id="')
        ..write(controlId)
        ..write('" name="')
        ..write(field.name)
        ..write('" data-esen-action-form-control="')
        ..write(index)
        ..write('" aria-describedby="')
        ..write(describedBy)
        ..write('" minlength="')
        ..write(field.minLength)
        ..write('" maxlength="')
        ..write(field.maxLength)
        ..write('" autocomplete="off"')
        ..write(field.required ? ' required' : '')
        ..write('></textarea>');
    } else if (field.kind == SeoActionFormMarkupFieldKind.choice) {
      buffer
        ..write('<select id="')
        ..write(controlId)
        ..write('" name="')
        ..write(field.name)
        ..write('" data-esen-action-form-control="')
        ..write(index)
        ..write('" aria-describedby="')
        ..write(describedBy)
        ..write('"')
        ..write(field.required ? ' required' : '')
        ..write('><option value="">')
        ..write(escapeText(field.choicePrompt!))
        ..write('</option>');
      for (final option in field.options) {
        buffer
          ..write('<option value="')
          ..write(escapeAttribute(option.value))
          ..write('">')
          ..write(escapeText(option.label))
          ..write('</option>');
      }
      buffer.write('</select>');
    } else {
      final type = switch (field.kind) {
        SeoActionFormMarkupFieldKind.email => 'email',
        SeoActionFormMarkupFieldKind.consent => 'checkbox',
        SeoActionFormMarkupFieldKind.text => 'text',
        SeoActionFormMarkupFieldKind.multiline ||
        SeoActionFormMarkupFieldKind.choice =>
          'text',
      };
      buffer
        ..write('<input id="')
        ..write(controlId)
        ..write('" type="')
        ..write(type)
        ..write('" name="')
        ..write(field.name)
        ..write('" data-esen-action-form-control="')
        ..write(index)
        ..write('" aria-describedby="')
        ..write(describedBy)
        ..write('"');
      if (field.kind == SeoActionFormMarkupFieldKind.consent) {
        buffer.write(' value="accepted"');
      } else {
        buffer
          ..write(' minlength="')
          ..write(field.minLength)
          ..write('" maxlength="')
          ..write(field.maxLength)
          ..write('" autocomplete="')
          ..write(field.autocomplete)
          ..write('"');
      }
      buffer
        ..write(field.required ? ' required' : '')
        ..write('/>');
    }
    buffer
      ..write('<span id="')
      ..write(errorId)
      ..write('" class="esen-seo-action-form-error" ')
      ..write('data-esen-action-form-error="')
      ..write(index)
      ..write('" hidden></span></div>');
  }

  /// The tag this node may carry in the head, or `null` when it must
  /// be dropped entirely — the head is no place for arbitrary markup.
  static String? _resolveHeadTag(SeoNode node, Map<String, String> attributes) {
    // JSON-LD is the one script that is content rather than code, and
    // it is legal in both head and body.
    if (node.tag == 'script' && _isJsonLd(attributes)) return 'script';
    return _headElements.contains(node.tag) ? node.tag : null;
  }

  /// Checked against the **normalized** attribute map, so a second key
  /// differing only in case cannot slip a `type` past this.
  static bool _isJsonLd(Map<String, String> attributes) =>
      attributes['type'] == 'application/ld+json';

  /// The head elements `SeoMeta` builds. Everything else is refused —
  /// the head is no place for arbitrary markup.
  static const Set<String> _headElements = {'title', 'meta', 'link'};

  /// What those head elements may carry. `http-equiv` would let a
  /// meta tag redirect the page, and a `<base href>` would repoint
  /// every relative URL in the document.
  static const Set<String> _headAttributes = {
    'name',
    'property',
    'content',
    'rel',
    'href',
    'hreflang',
    'type',
    'charset',
    'media',
    'sizes',
    'as',
    'crossorigin',
  };

  static bool _allowedHeadAttribute(String name) =>
      _headAttributes.contains(name);

  static final RegExp _needsTextEscape = RegExp('[&<>]');
  static final RegExp _needsAttributeEscape = RegExp('[&<>"]');

  /// Escapes text content so it is safe inside an HTML element.
  ///
  /// Fast path: most strings contain no special characters and are
  /// returned unchanged without any allocation.
  static String escapeText(String value) {
    if (!_needsTextEscape.hasMatch(value)) return value;
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  /// Escapes a value so it is safe inside a double-quoted HTML attribute.
  static String escapeAttribute(String value) {
    if (!_needsAttributeEscape.hasMatch(value)) return value;
    return escapeText(value).replaceAll('"', '&quot;');
  }

  /// Makes a JSON-LD payload safe to sit inside a `<script>` element.
  ///
  /// Every `<` becomes the JSON escape `\\u003C`. That is lossless for
  /// JSON — `SeoSchema.toJsonString` already does it — and it is the
  /// only reliable rule: guarding just `</script` leaves `<!--<script>`,
  /// which puts the HTML tokenizer into a state where the rest of the
  /// page is swallowed as script data.
  static String escapeJsonLd(String value) => value.replaceAll('<', r'\u003C');
}
