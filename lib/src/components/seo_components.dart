import '../renderer/seo_node.dart';
import 'seo_component_format.dart';
import 'seo_motion.dart';

/// Pure input for one bar in [buildSeoBarChartNodes].
typedef SeoBarChartComponentEntry = ({String label, double value});

/// Pure input for one step in [buildSeoBreadcrumbsNodes].
typedef SeoBreadcrumbComponentEntry = ({String label, String? url});

/// Pure input for one slide in [buildSeoCarouselNodes].
typedef SeoCarouselComponentEntry = ({String label, List<SeoNode> nodes});

/// Pure input for one question in [buildSeoFaqNodes].
typedef SeoFaqComponentEntry = ({String answer, String question});

/// A pure view of an application-specific navigation item.
typedef SeoNavComponentItem<T> = ({
  List<T> children,
  String label,
  String? url,
});

/// Pure input for one segment in [buildSeoPieChartNodes].
typedef SeoPieChartComponentEntry = ({
  int? colorArgb,
  String label,
  double value,
});

/// Pure input for one panel in [buildSeoTabsNodes].
typedef SeoTabComponentEntry = ({String label, List<SeoNode> nodes});

/// Pure input for one step in [buildSeoStepperNodes].
typedef SeoStepperComponentEntry = ({String label, List<SeoNode> nodes});

/// Default ARGB palette used by [buildSeoPieChartNodes].
const List<int> seoPieChartDefaultPaletteArgb = [
  0xFF2563EB,
  0xFFF59E0B,
  0xFF10B981,
  0xFFEF4444,
  0xFF8B5CF6,
  0xFF64748B,
];

/// Builds the semantic mirror nodes for a bar chart.
List<SeoNode> buildSeoBarChartNodes({
  required List<SeoBarChartComponentEntry> data,
  String? title,
  double height = 220,
  int colorArgb = 0xFF2563EB,
  SeoMotionPreset motion = SeoMotionPreset.none,
}) {
  final normalizedHeight = safeDimension(height, 220);
  final values = [for (final entry in data) safeChartValue(entry.value)];
  var max = 0.0;
  for (final value in values) {
    if (value > max) max = value;
  }
  final motionMarker = seoMotionMarker(motion);

  return [
    SeoNode(
      tag: 'figure',
      attributes: {
        'class': 'esen-seo-bar-chart',
        if (motionMarker != null) 'data-esen-motion': motionMarker,
      },
      children: [
        if (title != null) SeoNode(tag: 'figcaption', text: title),
        // The bars are visual only; the table below carries the semantics.
        SeoNode(
          tag: 'div',
          attributes: {
            'aria-hidden': 'true',
            'style': 'display:flex;align-items:flex-end;gap:8px;'
                'height:${cssNumber(normalizedHeight)}px',
          },
          children: [
            for (var i = 0; i < data.length; i++)
              SeoNode(
                tag: 'div',
                attributes: {
                  'title': '${data[i].label}: ${cssNumber(values[i])}',
                  'style': 'flex:1;border-radius:3px 3px 0 0;'
                      'background:${cssColorArgb(colorArgb)};'
                      'height:${cssPercent(values[i], max)}%',
                  if (motionMarker != null) 'data-esen-motion-item': '',
                },
              ),
          ],
        ),
        SeoNode(tag: 'table', children: [
          SeoNode(tag: 'tbody', children: [
            for (var i = 0; i < data.length; i++)
              SeoNode(tag: 'tr', children: [
                SeoNode(tag: 'th', text: data[i].label),
                SeoNode(tag: 'td', text: cssNumber(values[i])),
              ]),
          ]),
        ]),
      ],
    ),
  ];
}

/// Builds the semantic mirror nodes for a breadcrumb trail.
List<SeoNode> buildSeoBreadcrumbsNodes({
  required List<SeoBreadcrumbComponentEntry> items,
  String separator = '/',
  String label = 'Breadcrumb',
}) {
  if (items.isEmpty) return const [];

  String? hrefOf(SeoBreadcrumbComponentEntry item) {
    final value = item.url?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  SeoNode stepNode(int index) {
    final item = items[index];
    final href = hrefOf(item);
    final current = index == items.length - 1
        ? const {'aria-current': 'page'}
        : const <String, String>{};
    if (href == null) {
      return SeoNode(tag: 'span', text: item.label, attributes: {...current});
    }
    return SeoNode(
      tag: 'a',
      text: item.label,
      attributes: {'href': href, ...current},
    );
  }

  return [
    SeoNode(
      tag: 'nav',
      attributes: {'class': 'esen-seo-breadcrumbs', 'aria-label': label},
      children: [
        SeoNode(tag: 'ol', children: [
          for (var i = 0; i < items.length; i++)
            SeoNode(tag: 'li', children: [
              stepNode(i),
              if (i < items.length - 1 && separator.isNotEmpty)
                SeoNode(
                  tag: 'span',
                  text: separator,
                  attributes: const {'aria-hidden': 'true'},
                ),
            ]),
        ]),
      ],
    ),
  ];
}

/// Builds the semantic mirror nodes for a complete carousel.
List<SeoNode> buildSeoCarouselNodes({
  required List<SeoCarouselComponentEntry> slides,
  int headingLevel = 3,
  String? interactionId,
  String interactionLabel = 'Carousel',
  String previousLabel = 'Previous slide',
  String nextLabel = 'Next slide',
  int initialIndex = 0,
}) {
  if (slides.isEmpty) return const [];
  final level = headingLevel.clamp(1, 6);
  final candidate = interactionId?.trim();
  final id = candidate != null && isValidSeoInteractionId(candidate)
      ? candidate
      : null;
  final selectedIndex = initialIndex.clamp(0, slides.length - 1);
  return [
    SeoNode(
      tag: 'div',
      attributes: {
        'class': 'esen-seo-carousel',
        if (id != null) ...{
          'id': id,
          'data-esen-component': 'carousel',
          'data-esen-label': interactionLabel,
          'data-esen-previous-label': previousLabel,
          'data-esen-next-label': nextLabel,
          'data-esen-initial-index': '$selectedIndex',
        },
      },
      children: [
        for (var i = 0; i < slides.length; i++)
          SeoNode(
            tag: 'section',
            attributes: {
              if (id != null) ...{
                'id': '$id-slide-$i',
                'data-esen-carousel-slide': '',
              },
            },
            children: [
              SeoNode(tag: 'h$level', text: slides[i].label),
              ...slides[i].nodes,
            ],
          ),
      ],
    ),
  ];
}

/// Builds the semantic mirror nodes for a data table.
List<SeoNode> buildSeoDataTableNodes({
  required List<String> columns,
  required List<List<String>> rows,
  String? title,
}) {
  if (columns.isEmpty) return const [];

  List<String> cells(List<String> row) => [
        for (var i = 0; i < columns.length; i++) i < row.length ? row[i] : '',
      ];

  return [
    SeoNode(
      tag: 'table',
      attributes: {'class': 'esen-seo-data-table'},
      children: [
        if (title != null) SeoNode(tag: 'caption', text: title),
        SeoNode(tag: 'thead', children: [
          SeoNode(tag: 'tr', children: [
            for (final column in columns) SeoNode(tag: 'th', text: column),
          ]),
        ]),
        SeoNode(tag: 'tbody', children: [
          for (final row in rows)
            SeoNode(tag: 'tr', children: [
              for (final value in cells(row)) SeoNode(tag: 'td', text: value),
            ]),
        ]),
      ],
    ),
  ];
}

/// Builds the semantic mirror nodes for an FAQ section.
List<SeoNode> buildSeoFaqNodes({
  required List<SeoFaqComponentEntry> entries,
  String? title,
  int titleLevel = 2,
}) {
  if (entries.isEmpty) return const [];
  final level = titleLevel.clamp(1, 6);
  final hasTitle = title != null && title.trim().isNotEmpty;
  return [
    SeoNode(
      tag: 'section',
      attributes: const {'class': 'esen-seo-faq'},
      children: [
        if (hasTitle) SeoNode(tag: 'h$level', text: title),
        for (final entry in entries)
          SeoNode(tag: 'details', children: [
            SeoNode(tag: 'summary', text: entry.question),
            SeoNode(tag: 'p', text: entry.answer),
          ]),
      ],
    ),
  ];
}

/// Builds the semantic mirror nodes for an image figure.
List<SeoNode> buildSeoFigureNodes({
  required String src,
  required String alt,
  String? caption,
  int? width,
  int? height,
  bool lazy = false,
}) {
  final normalizedWidth = width != null && width > 0 ? width : null;
  final normalizedHeight = height != null && height > 0 ? height : null;
  return [
    SeoNode(
      tag: 'figure',
      attributes: const {'class': 'esen-seo-figure'},
      children: [
        SeoNode(tag: 'img', attributes: {
          'src': src,
          // An explicit empty alt differs from an omitted alt attribute.
          'alt': alt,
          if (normalizedWidth != null) 'width': '$normalizedWidth',
          if (normalizedHeight != null) 'height': '$normalizedHeight',
          if (lazy) 'loading': 'lazy',
        }),
        if (caption != null && caption.isNotEmpty)
          SeoNode(tag: 'figcaption', text: caption),
      ],
    ),
  ];
}

/// Builds the semantic mirror nodes for a complete, possibly lazy list.
List<SeoNode> buildSeoListViewNodes<T>({
  required List<T> items,
  required List<SeoNode> Function(T item, int index) nodeBuilder,
  String listTag = 'div',
  String? itemTag,
  Map<String, String> attributes = const {},
}) {
  final normalizedListTag = listTag.trim().isEmpty ? 'div' : listTag.trim();
  final explicitItemTag = itemTag?.trim();
  final normalizedItemTag = explicitItemTag != null
      ? (explicitItemTag.isEmpty ? null : explicitItemTag)
      : const {'ul', 'ol', 'menu'}.contains(normalizedListTag.toLowerCase())
          ? 'li'
          : null;
  final children = <SeoNode>[];
  for (var i = 0; i < items.length; i++) {
    final nodes = nodeBuilder(items[i], i);
    if (nodes.isEmpty) continue;
    if (normalizedItemTag == null) {
      children.addAll(nodes);
    } else {
      children.add(SeoNode(tag: normalizedItemTag, children: nodes));
    }
  }
  if (children.isEmpty) return const [];
  return [
    SeoNode(
      tag: normalizedListTag,
      attributes: {'class': 'esen-seo-list', ...attributes},
      children: children,
    ),
  ];
}

/// Builds the semantic mirror nodes for a complete navigation tree.
List<SeoNode> buildSeoNavMenuNodes<T>({
  required List<T> items,
  required SeoNavComponentItem<T> Function(T item) itemView,
  String label = 'Hauptnavigation',
  String? interactionId,
}) {
  if (items.isEmpty) return const [];
  final candidate = interactionId?.trim();
  final id = candidate != null && isValidSeoInteractionId(candidate)
      ? candidate
      : null;

  SeoNode entryNode(SeoNavComponentItem<T> item) {
    final value = item.url?.trim();
    final href = value == null || value.isEmpty ? null : value;
    if (href == null) return SeoNode(tag: 'span', text: item.label);
    return SeoNode(tag: 'a', text: item.label, attributes: {'href': href});
  }

  SeoNode listNode(
    List<T> entries,
    String parentPath, {
    Map<String, String> attributes = const {},
  }) {
    final children = <SeoNode>[];
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final item = itemView(entry);
      final path = parentPath.isEmpty ? '$index' : '$parentPath-$index';
      final hasChildren = item.children.isNotEmpty;
      children.add(SeoNode(
        tag: 'li',
        attributes: {
          if (id != null && hasChildren) 'data-esen-nav-branch': '',
        },
        children: [
          entryNode(item),
          // A submenu belongs inside its parent's list item.
          if (hasChildren)
            listNode(
              item.children,
              path,
              attributes: {
                if (id != null) ...{
                  'id': '$id-submenu-$path',
                  'data-esen-nav-submenu': '',
                },
              },
            ),
        ],
      ));
    }
    return SeoNode(tag: 'ul', attributes: attributes, children: children);
  }

  return [
    // Paragraphs cannot carry an ARIA name; the visible text is complete.
    SeoNode(
      tag: 'nav',
      attributes: {
        'class': 'esen-seo-nav',
        'aria-label': label,
        if (id != null) ...{
          'id': id,
          'data-esen-component': 'nav-menu',
        },
      },
      children: [
        listNode(
          items,
          '',
          attributes: {
            if (id != null) 'data-esen-nav-root-list': '',
          },
        ),
      ],
    ),
  ];
}

/// Builds the semantic mirror nodes for a pie chart.
List<SeoNode> buildSeoPieChartNodes({
  required List<SeoPieChartComponentEntry> data,
  String? title,
  double diameter = 180,
  List<int> paletteArgb = seoPieChartDefaultPaletteArgb,
}) {
  final normalizedDiameter = safeDimension(diameter, 180);
  final palette =
      paletteArgb.isEmpty ? seoPieChartDefaultPaletteArgb : paletteArgb;
  final values = [for (final entry in data) safeChartValue(entry.value)];
  final colors = [
    for (var i = 0; i < data.length; i++)
      data[i].colorArgb ?? palette[i % palette.length],
  ];
  var total = 0.0;
  for (final value in values) {
    total += value;
  }

  String conicGradient() {
    if (total <= 0) return '#e5e7eb';
    final stops = StringBuffer('conic-gradient(');
    var start = 0.0;
    for (var i = 0; i < data.length; i++) {
      final end = start + values[i];
      if (i > 0) stops.write(',');
      stops
        ..write(cssColorArgb(colors[i]))
        ..write(' ${cssPercent(start, total)}%')
        ..write(' ${cssPercent(end, total)}%');
      start = end;
    }
    stops.write(')');
    return stops.toString();
  }

  return [
    SeoNode(
      tag: 'figure',
      attributes: {'class': 'esen-seo-pie-chart'},
      children: [
        if (title != null) SeoNode(tag: 'figcaption', text: title),
        SeoNode(
          tag: 'div',
          attributes: {
            'aria-hidden': 'true',
            'style': 'width:${cssNumber(normalizedDiameter)}px;'
                'height:${cssNumber(normalizedDiameter)}px;'
                'border-radius:50%;'
                'background:${conicGradient()}',
          },
        ),
        SeoNode(tag: 'table', children: [
          SeoNode(tag: 'tbody', children: [
            for (var i = 0; i < data.length; i++)
              SeoNode(tag: 'tr', children: [
                SeoNode(tag: 'th', text: data[i].label),
                SeoNode(tag: 'td', text: cssNumber(values[i])),
                SeoNode(
                  tag: 'td',
                  text: '${cssPercent(values[i], total)}%',
                ),
              ]),
          ]),
        ]),
      ],
    ),
  ];
}

/// Builds the semantic mirror nodes for a rating.
List<SeoNode> buildSeoRatingNodes({
  required double value,
  int max = 5,
  String? label,
}) {
  final scale = max < 1 ? 1 : max;
  final normalizedValue = value.isFinite && value > 0 ? value : 0.0;
  final filled = normalizedValue.clamp(0, scale.toDouble()).floor();
  final stars =
      scale > 20 ? '' : '\u2605' * filled + '\u2606' * (scale - filled);
  final score = '${cssNumber(normalizedValue)}/$scale';
  final scored = label == null ? score : '$score ($label)';
  final text = stars.isEmpty ? scored : '$stars $scored';
  return [
    SeoNode(
      tag: 'p',
      attributes: const {'class': 'esen-seo-rating'},
      text: text,
    ),
  ];
}

/// Builds the complete ordered semantic source for a stepper.
///
/// Every step and body is present without JavaScript. A valid
/// [interactionId] adds inert markers that the package-owned runtime may
/// enhance only after validating the complete structure.
List<SeoNode> buildSeoStepperNodes({
  required List<SeoStepperComponentEntry> steps,
  int headingLevel = 3,
  String? interactionId,
  String interactionLabel = 'Steps',
  String previousLabel = 'Back',
  String nextLabel = 'Next',
  String positionLabel = 'Step',
  int initialIndex = 0,
}) {
  if (steps.isEmpty) return const [];
  final level = headingLevel.clamp(1, 6);
  final candidate = interactionId?.trim();
  final id = candidate != null && isValidSeoInteractionId(candidate)
      ? candidate
      : null;
  final selectedIndex = initialIndex.clamp(0, steps.length - 1);
  return [
    SeoNode(
      tag: 'div',
      attributes: {
        'class': 'esen-seo-stepper',
        if (id != null) ...{
          'id': id,
          'data-esen-component': 'stepper',
          'data-esen-label': interactionLabel,
          'data-esen-previous-label': previousLabel,
          'data-esen-next-label': nextLabel,
          'data-esen-position-label': positionLabel,
          'data-esen-initial-index': '$selectedIndex',
        },
      },
      children: [
        SeoNode(
          tag: 'ol',
          attributes: {
            if (id != null) 'data-esen-step-list': '',
          },
          children: [
            for (var index = 0; index < steps.length; index++)
              SeoNode(
                tag: 'li',
                attributes: {
                  if (id != null) ...{
                    'id': '$id-step-$index',
                    'data-esen-step': '',
                  },
                },
                children: [
                  SeoNode(tag: 'h$level', text: steps[index].label),
                  SeoNode(
                    tag: 'div',
                    attributes: {
                      if (id != null) ...{
                        'id': '$id-panel-$index',
                        'data-esen-step-panel': '',
                      },
                    },
                    children: steps[index].nodes,
                  ),
                ],
              ),
          ],
        ),
      ],
    ),
  ];
}

/// Builds the semantic mirror nodes for a tab group.
List<SeoNode> buildSeoTabsNodes({
  required List<SeoTabComponentEntry> tabs,
  int headingLevel = 3,
  String? interactionId,
  String interactionLabel = 'Tabs',
  int initialIndex = 0,
}) {
  if (tabs.isEmpty) return const [];
  final level = headingLevel.clamp(1, 6);
  final candidate = interactionId?.trim();
  final id = candidate != null && isValidSeoInteractionId(candidate)
      ? candidate
      : null;
  final selectedIndex = initialIndex.clamp(0, tabs.length - 1);
  return [
    SeoNode(
      tag: 'div',
      attributes: {
        'class': 'esen-seo-tabs',
        if (id != null) ...{
          'id': id,
          'data-esen-component': 'tabs',
          'data-esen-label': interactionLabel,
          'data-esen-initial-index': '$selectedIndex',
        },
      },
      children: [
        for (var i = 0; i < tabs.length; i++)
          SeoNode(
            tag: 'section',
            attributes: {
              if (id != null) ...{
                'id': '$id-panel-$i',
                'data-esen-tab-panel': '',
              },
            },
            children: [
              SeoNode(tag: 'h$level', text: tabs[i].label),
              ...tabs[i].nodes,
            ],
          ),
      ],
    ),
  ];
}

/// Builds the semantic mirror nodes for a testimonial.
List<SeoNode> buildSeoTestimonialNodes({
  required String quote,
  String? author,
  String? role,
  String? sourceUrl,
}) {
  final attributionParts = [
    if (author != null && author.isNotEmpty) author,
    if (role != null && role.isNotEmpty) role,
  ];
  final attribution =
      attributionParts.isEmpty ? null : attributionParts.join(', ');
  return [
    SeoNode(
      tag: 'figure',
      attributes: const {'class': 'esen-seo-testimonial'},
      children: [
        SeoNode(
          tag: 'blockquote',
          attributes: {
            if (sourceUrl != null && sourceUrl.isNotEmpty) 'cite': sourceUrl,
          },
          children: [SeoNode(tag: 'p', text: quote)],
        ),
        // Attribution belongs beside the blockquote, not inside the quote.
        if (attribution != null)
          SeoNode(tag: 'figcaption', text: '\u2014 $attribution'),
      ],
    ),
  ];
}
