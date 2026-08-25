import 'package:esen_seo/server.dart';
import 'package:esen_seo/src/renderer/seo_action_form_markup.dart';
import 'package:esen_seo/src/renderer/seo_node.dart'
    show buildInternalSeoActionFormNode;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('action form plan', () {
    test('prepares the closed field set with kind-specific defaults', () {
      final plan = prepareSeoActionForm(_definition());

      expect(plan, isNotNull);
      expect(plan!.fields.map((field) => field.maxLength), [512, 254, 4096, 0]);
      expect(plan.endpointPath, '/_esen_seo/forms/contact');
    });

    test('rejects invalid identity, return targets and duplicate names', () {
      expect(
        prepareSeoActionForm(_definition(actionId: '../contact')),
        isNull,
      );
      expect(
        prepareSeoActionForm(_definition(returnPath: 'https://evil.test')),
        isNull,
      );
      expect(
        prepareSeoActionForm(_definition(fields: const [
          SeoActionFormField(
            name: 'same',
            label: 'One',
            kind: SeoActionFormFieldKind.text,
          ),
          SeoActionFormField(
            name: 'same',
            label: 'Two',
            kind: SeoActionFormFieldKind.text,
          ),
        ])),
        isNull,
      );
      expect(prepareSeoActionForm(_definition(heading: 'Hello 👋')), isNotNull);
      expect(
          prepareSeoActionForm(_definition(heading: 'Hello\nthere')), isNull);
    });

    test('validates values without admitting unknown or unsafe input', () {
      final plan = prepareSeoActionForm(_definition())!;

      final valid = validateSeoActionFormValues(plan, {
        'name': '  Ada  ',
        'email': 'ada@example.com',
        'message': 'Hello\r\nworld',
        'consent': 'accepted',
      });
      expect(valid.isValid, isTrue);
      expect(valid.values!.text('name'), 'Ada');
      expect(valid.values!.text('message'), 'Hello\nworld');
      expect(valid.values!.consent('consent'), isTrue);

      expect(
        validateSeoActionFormValues(plan, {'unknown': 'value'}).malformed,
        isTrue,
      );
      expect(
        validateSeoActionFormValues(plan, {
          'name': 'Ada\u202e',
        }).malformed,
        isTrue,
      );
      expect(
        validateSeoActionFormValues(plan, {
          'name': 'Ada',
          'email': 'not-an-email',
        }).errors,
        containsPair('email', 'Enter a valid email address.'),
      );
    });

    test('rejects malformed application results', () {
      final plan = prepareSeoActionForm(_definition())!;

      expect(
        canonicalizeSeoActionFormResult(
          plan,
          const SeoActionFormResult.success('Sent.'),
        ),
        isNotNull,
      );
      expect(
        canonicalizeSeoActionFormResult(
          plan,
          const SeoActionFormResult(
            outcome: SeoActionFormOutcome.success,
            message: 'Sent.',
            fieldErrors: {'email': 'Wrong'},
          ),
        ),
        isNull,
      );
      expect(
        canonicalizeSeoActionFormResult(
          plan,
          const SeoActionFormResult.rejected(
            'No.',
            fieldErrors: {'not_declared': 'Wrong'},
          ),
        ),
        isNull,
      );
    });
  });

  group('action form rendering', () {
    test('ordinary body rendering keeps the non-interactive summary', () {
      final nodes = buildSeoActionFormNodes(_definition());

      final html = const HtmlRenderer().render(nodes);

      expect(html, contains('<section class="esen-seo-action-form-summary">'));
      expect(html, isNot(contains('<form')));
      expect(html, isNot(contains('<input')));
      expect(html, isNot(contains('<button')));
    });

    test('DOM-first rendering emits only the opaque package form', () {
      final nodes = buildSeoActionFormNodes(_definition(
        heading: 'Contact <team>',
      ));

      final html = const HtmlRenderer.domFirst().render(nodes);

      expect(html, contains('<form method="post"'));
      expect(html, contains('action="/_esen_seo/forms/contact"'));
      expect(html, contains('Contact &lt;team&gt;'));
      expect(html, contains('type="email"'));
      expect(html, contains('type="checkbox"'));
      expect(html, contains('<textarea'));
      expect(html, isNot(contains('<script')));
    });

    test('free form nodes remain refused in DOM-first rendering', () {
      final html = const HtmlRenderer.domFirst().render([
        SeoNode(
          tag: 'form',
          attributes: const {'action': 'https://evil.test'},
          children: [
            SeoNode(tag: 'input', attributes: const {'name': 'x'})
          ],
        ),
      ]);

      expect(html, '<div><div></div></div>');
    });

    test('invalid opaque markup degrades to the static summary', () {
      final fallback = SeoNode(tag: 'section', text: 'Safe fallback');
      final node = buildInternalSeoActionFormNode(
        fallback: fallback,
        markup: const SeoActionFormMarkup(
          actionId: '../escape',
          headingLevel: 2,
          heading: 'Heading',
          description: 'Description',
          submitLabel: 'Send',
          pendingLabel: 'Sending',
          failureLabel: 'Try again later',
          statusLabel: 'Status',
          fields: [],
        ),
      );

      expect(
        const HtmlRenderer.domFirst().render([node]),
        '<section>Safe fallback</section>',
      );
    });

    test('SeoPage uses the privileged renderer only for DOM-first pages', () {
      final nodes = buildSeoActionFormNodes(_definition());

      expect(
        SeoPage.fromNodes(body: nodes).toHtmlDocument(),
        isNot(contains('<form')),
      );
      expect(
        SeoPage.domFirstFromNodes(body: nodes).toHtmlDocument(),
        contains('<form method="post"'),
      );
    });
  });
}

SeoActionFormDefinition _definition({
  String actionId = 'contact',
  String returnPath = '/contact/',
  String heading = 'Contact us',
  List<SeoActionFormField>? fields,
}) =>
    SeoActionFormDefinition(
      actionId: actionId,
      returnPath: returnPath,
      heading: heading,
      description: 'We reply soon.',
      submitLabel: 'Send',
      pendingLabel: 'Sending',
      failureLabel: 'Try again later',
      statusLabel: 'Submission status',
      fields: fields ??
          const [
            SeoActionFormField(
              name: 'name',
              label: 'Name',
              kind: SeoActionFormFieldKind.text,
              required: true,
              autocomplete: SeoActionFormAutocomplete.name,
            ),
            SeoActionFormField(
              name: 'email',
              label: 'Email',
              kind: SeoActionFormFieldKind.email,
              required: true,
              autocomplete: SeoActionFormAutocomplete.email,
            ),
            SeoActionFormField(
              name: 'message',
              label: 'Message',
              kind: SeoActionFormFieldKind.multiline,
              required: true,
            ),
            SeoActionFormField(
              name: 'consent',
              label: 'I consent',
              kind: SeoActionFormFieldKind.consent,
              required: true,
            ),
          ],
    );
