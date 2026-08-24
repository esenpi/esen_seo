import 'package:esen_seo/src/components/seo_configurator_component.dart';
import 'package:esen_seo/src/components/seo_configurator_transition.dart';
import 'package:esen_seo/src/renderer/html_renderer.dart';
import 'package:esen_seo/src/renderer/seo_node.dart';
import 'package:flutter_test/flutter_test.dart';

const _constraints = SeoConfiguratorConstraints(
  choiceCount: 3,
  minQuantity: 1,
  maxQuantity: 20,
);

const _initialState = SeoConfiguratorState(
  choiceIndex: 0,
  quantity: 1,
  optionEnabled: false,
);

SeoConfiguratorView _pricingView(SeoConfiguratorState state) {
  const base = [1900, 4900, 9900];
  const additional = [900, 700, 500];
  final cents = base[state.choiceIndex] +
      (state.quantity - 1) * additional[state.choiceIndex] +
      (state.optionEnabled ? 1500 : 0);
  return SeoConfiguratorView(
    priceText: '${cents ~/ 100} EUR',
    summaryText:
        'Plan ${state.choiceIndex + 1}, ${state.quantity} sites, support '
        '${state.optionEnabled ? "on" : "off"}',
    announcementText: 'Price ${cents ~/ 100} EUR',
    activeChoiceRegion: state.choiceIndex,
    optionRegionVisible: state.optionEnabled,
  );
}

List<SeoConfiguratorComponentChoice> _choices({
  List<String> labels = const ['Solo', 'Team', 'Agency'],
}) =>
    [
      for (var index = 0; index < labels.length; index++)
        (
          label: labels[index],
          nodes: [SeoNode(tag: 'p', text: 'Description $index')],
        ),
    ];

void main() {
  const renderer = HtmlRenderer();

  test('emits complete static content and inert fixed markers', () {
    final html = renderer.render(buildSeoConfiguratorNodes(
      choices: _choices(),
      optionNodes: [SeoNode(tag: 'p', text: 'Priority support details')],
      constraints: _constraints,
      initialState: _initialState,
      project: _pricingView,
      interactionId: 'cms-pricing-configurator',
      heading: 'Choose a subscription',
      interactionLabel: 'Subscription calculator',
      choiceGroupLabel: 'Subscriptions',
      quantityLabel: 'Sites',
      optionLabel: 'Priority support',
      priceLabel: 'Price',
      decrementLabel: 'Remove one site',
      incrementLabel: 'Add one site',
    ));

    expect(
      html,
      startsWith(
        '<section class="esen-seo-configurator" '
        'id="cms-pricing-configurator" '
        'data-esen-component="configurator" '
        'data-esen-layout-stable="true" '
        'data-esen-label="Subscription calculator" '
        'data-esen-choice-label="Subscriptions" '
        'data-esen-quantity-label="Sites" '
        'data-esen-option-label="Priority support"',
      ),
    );
    expect(html, contains('data-esen-initial-choice="0"'));
    expect(html, contains('data-esen-initial-quantity="1"'));
    expect(html, contains('data-esen-initial-option="false"'));
    expect(
      html,
      contains('data-esen-prepaint-placeholder="configurator" hidden="" '
          'aria-hidden="true"'),
    );
    expect(html, contains('<span data-esen-configurator-price="">19 EUR'));
    expect(html, contains('<span data-esen-configurator-summary="">'));
    expect(
        'data-esen-configurator-choice-region='.allMatches(html), hasLength(3));
    expect(html, contains('<p>Description 0</p>'));
    expect(html, contains('<p>Description 1</p>'));
    expect(html, contains('<p>Description 2</p>'));
    expect(html, contains('<p>Priority support details</p>'));
    expect(
        html, isNot(contains('id="cms-pricing-configurator-option" hidden')));
    expect('aria-live="polite"'.allMatches(html), hasLength(1));
    expect(html, contains('aria-atomic="true"></span>'));
    expect(html, isNot(contains('<button')));
    expect(html, isNot(contains('<script')));
  });

  test('invalid interaction id leaves valid content entirely static', () {
    final html = renderer.render(buildSeoConfiguratorNodes(
      choices: _choices(),
      optionNodes: [SeoNode(tag: 'p', text: 'Option details')],
      constraints: _constraints,
      initialState: _initialState,
      project: _pricingView,
      interactionId: 'invalid id',
    ));

    expect(html, contains('19 EUR'));
    expect(html, contains('<p>Description 2</p>'));
    expect(html, contains('<p>Option details</p>'));
    expect(html, isNot(contains('data-esen-component')));
    expect(html, isNot(contains('data-esen-configurator-')));
    expect(html, isNot(contains('data-esen-prepaint-placeholder')));
    expect(html, isNot(contains('aria-live')));
  });

  test('serializes the validated initial view deterministically', () {
    List<SeoNode> build() => buildSeoConfiguratorNodes(
          choices: _choices(),
          optionNodes: [SeoNode(tag: 'p', text: 'Option')],
          constraints: _constraints,
          initialState: const SeoConfiguratorState(
            choiceIndex: 1,
            quantity: 3,
            optionEnabled: true,
          ),
          project: _pricingView,
          interactionId: 'pricing',
        );

    final first = renderer.render(build());
    final second = renderer.render(build());
    expect(second.codeUnits, first.codeUnits);
    expect(first, contains('data-esen-initial-choice="1"'));
    expect(first, contains('data-esen-initial-quantity="3"'));
    expect(first, contains('data-esen-initial-option="true"'));
    expect(first, contains('data-esen-initial-visible="true"'));
    expect(first, contains('78 EUR'));
  });

  test('keeps duplicate records distinct and strips bidi label controls', () {
    final duplicateNodes = [SeoNode(tag: 'p', text: 'Same object')];
    final html = renderer.render(buildSeoConfiguratorNodes(
      choices: [
        (label: 'S\u202Eolo', nodes: duplicateNodes),
        (label: 'Team', nodes: duplicateNodes),
        (label: 'Agency', nodes: duplicateNodes),
      ],
      optionNodes: const [],
      constraints: _constraints,
      initialState: _initialState,
      project: _pricingView,
      interactionId: 'pricing',
    ));

    expect(html, isNot(contains('\u202E')));
    expect(html, contains('>Solo</'));
    expect(html, contains('>Team</'));
    expect(html, contains('>Agency</'));
  });

  test('HTML-looking projected text stays escaped slot text', () {
    SeoConfiguratorView project(SeoConfiguratorState state) =>
        SeoConfiguratorView(
          priceText: '<img src=x onerror=alert(1)>',
          summaryText: '<script>alert(1)</script>',
          announcementText: '<b>changed</b>',
          activeChoiceRegion: state.choiceIndex,
          optionRegionVisible: state.optionEnabled,
        );

    final html = renderer.render(buildSeoConfiguratorNodes(
      choices: _choices(),
      optionNodes: const [],
      constraints: _constraints,
      initialState: _initialState,
      project: project,
      interactionId: 'pricing',
    ));

    expect(html, contains('&lt;img src=x onerror=alert(1)&gt;'));
    expect(html, contains('&lt;script&gt;alert(1)&lt;/script&gt;'));
    expect(html, isNot(contains('<img src=x')));
    expect(html, isNot(contains('<script>alert')));
  });

  test('rejects mismatched, malformed and oversized component input', () {
    final valid = _choices();
    final outputs = [
      buildSeoConfiguratorNodes(
        choices: valid.take(2).toList(),
        optionNodes: const [],
        constraints: _constraints,
        initialState: _initialState,
        project: _pricingView,
      ),
      buildSeoConfiguratorNodes(
        choices: _choices(labels: const ['Solo', '   ', 'Agency']),
        optionNodes: const [],
        constraints: _constraints,
        initialState: _initialState,
        project: _pricingView,
      ),
      buildSeoConfiguratorNodes(
        choices: _choices(labels: const ['Solo', ' Solo ', 'Agency']),
        optionNodes: const [],
        constraints: _constraints,
        initialState: _initialState,
        project: _pricingView,
      ),
      buildSeoConfiguratorNodes(
        choices: valid,
        optionNodes: const [],
        constraints: _constraints,
        initialState: _initialState,
        project: _pricingView,
        heading: 'x' * (seoConfiguratorMaxLabelTextLength + 1),
      ),
      buildSeoConfiguratorNodes(
        choices: valid,
        optionNodes: const [],
        constraints: _constraints,
        initialState: _initialState,
        project: (state) => SeoConfiguratorView(
          priceText: '19 EUR',
          summaryText: 'Solo',
          announcementText: '19 EUR',
          activeChoiceRegion: 2,
          optionRegionVisible: state.optionEnabled,
        ),
      ),
    ];

    expect(outputs, everyElement(isEmpty));
  });

  test('enforces aggregate labels and malformed UTF-16 before sanitation', () {
    final manyChoices = [
      for (var index = 0; index < 32; index++)
        (
          label: '$index'.padRight(seoConfiguratorMaxLabelTextLength, 'x'),
          nodes: <SeoNode>[],
        ),
    ];
    const constraints = SeoConfiguratorConstraints(
      choiceCount: 32,
      minQuantity: 0,
      maxQuantity: 0,
    );
    const state = SeoConfiguratorState(
      choiceIndex: 0,
      quantity: 0,
      optionEnabled: false,
    );
    SeoConfiguratorView project(SeoConfiguratorState state) =>
        SeoConfiguratorView(
          priceText: '0 EUR',
          summaryText: 'No quantity',
          announcementText: 'Price 0 EUR',
          activeChoiceRegion: state.choiceIndex,
          optionRegionVisible: state.optionEnabled,
        );

    expect(
      buildSeoConfiguratorNodes(
        choices: manyChoices,
        optionNodes: const [],
        constraints: constraints,
        initialState: state,
        project: project,
      ),
      isEmpty,
    );
    expect(
      buildSeoConfiguratorNodes(
        choices: _choices(),
        optionNodes: const [],
        constraints: _constraints,
        initialState: _initialState,
        project: _pricingView,
        optionLabel: String.fromCharCode(0xD800),
      ),
      isEmpty,
    );
  });

  test('fixed quantity reserves both disabled control boundaries', () {
    const constraints = SeoConfiguratorConstraints(
      choiceCount: 1,
      minQuantity: 4,
      maxQuantity: 4,
    );
    const state = SeoConfiguratorState(
      choiceIndex: 0,
      quantity: 4,
      optionEnabled: false,
    );
    final html = renderer.render(buildSeoConfiguratorNodes(
      choices: [
        (label: 'Fixed', nodes: <SeoNode>[]),
      ],
      optionNodes: const [],
      constraints: constraints,
      initialState: state,
      project: (state) => SeoConfiguratorView(
        priceText: '40 EUR',
        summaryText: 'Four units',
        announcementText: 'Price 40 EUR',
        activeChoiceRegion: state.choiceIndex,
        optionRegionVisible: state.optionEnabled,
      ),
      interactionId: 'fixed-pricing',
    ));

    expect(
      'data-esen-placeholder-disabled="true"'.allMatches(html),
      hasLength(2),
    );
  });
}
