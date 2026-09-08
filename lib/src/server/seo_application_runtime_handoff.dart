import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../renderer/seo_dom_first_navigation_application_handoff_runtime.g.dart';
import '../renderer/seo_dom_first_navigation_application_profile_runtime.g.dart';
import '../renderer/seo_dom_first_runtime_handoff.dart';
import '../renderer/seo_dom_first_theme_toggle_runtime.g.dart';
import '../routing/seo_application_runtime.dart';
import '../routing/seo_dom_first_navigation.dart';
import 'seo_runtime_store.dart';

/// The browser-bound envelope derived from one verified application artifact.
final class SeoDomFirstApplicationHandoffPayload {
  SeoDomFirstApplicationHandoffPayload._({
    required this.artifact,
    required this.javascript,
    required this.navigationEntry,
    required this.typedProfile,
  });

  /// Creates the closed payload used by manifest and page delivery.
  factory SeoDomFirstApplicationHandoffPayload.fromArtifact(
    SeoDomFirstRuntimeArtifact artifact, {
    bool typedProfile = false,
  }) {
    final reference = artifact.reference;
    final admitted = typedProfile
        ? reference is SeoDomFirstCollectionApplicationRuntime ||
            reference is SeoDomFirstConfiguratorApplicationRuntime ||
            reference is SeoDomFirstEditorialWorkflowApplicationRuntime ||
            reference is SeoDomFirstApprovalChecklistApplicationRuntime ||
            reference is SeoDomFirstTabsApplicationRuntime
        : reference is SeoDomFirstCollectionApplicationRuntime;
    if (!admitted) {
      throw StateError(
        typedProfile
            ? 'Typed application runtime handoff supports only a standalone '
                'collection, configurator, editorial-workflow or '
                'approval-checklist or tabs runtime.'
            : 'Application runtime handoff supports only a standalone '
                'collection runtime.',
      );
    }
    final javascript = seoDomFirstApplicationHandoffEnvelope(
      artifact.javascript,
      kind: reference.kind,
    );
    final encoded = utf8.encode(javascript);
    if (encoded.isEmpty ||
        encoded.length > seoDomFirstApplicationHandoffEnvelopeMaxBytes) {
      throw StateError(
        'Application runtime "${reference.id}" exceeds the handoff envelope '
        'size budget.',
      );
    }
    final source = utf8.encode(artifact.javascript);
    final digest = sha256.convert(source).toString();
    if (digest != artifact.manifest.sha256 ||
        source.length != artifact.manifest.bytes) {
      throw StateError(
        'Application runtime "${reference.id}" changed after verification.',
      );
    }
    return SeoDomFirstApplicationHandoffPayload._(
      artifact: artifact,
      javascript: javascript,
      navigationEntry: SeoDomFirstNavigationRuntimeEntry(
        kind: reference.kind,
        sha256: digest,
        bytes: source.length,
        applicationId: reference.id,
        contractRevision: artifact.manifest.contractRevision,
      ),
      typedProfile: typedProfile,
    );
  }

  /// The store-verified artifact from which this payload was derived.
  final SeoDomFirstRuntimeArtifact artifact;

  /// Complete classic-script envelope emitted into the direct document.
  ///
  /// [navigationEntry] binds only the verified application source; the browser
  /// appends the same fixed package-owned epilogue after handoff verification.
  final String javascript;

  /// Descriptor embedded in the trusted navigation plan.
  final SeoDomFirstNavigationRuntimeEntry navigationEntry;

  /// Whether this payload belongs to the schema-4 typed profile.
  final bool typedProfile;

  /// Verifies the fixed loader and complete executable profile budgets.
  void validateProfileBudget({required bool includeThemeToggle}) {
    final codec = GZipCodec(level: 9);
    final loader = typedProfile
        ? seoDomFirstNavigationApplicationProfileRuntime
        : seoDomFirstNavigationApplicationHandoffRuntime;
    final loaderBytes = utf8.encode(loader);
    if (codec.encode(loaderBytes).length > 8 * 1024) {
      throw StateError(
        'Application runtime handoff loader exceeds its gzip size budget.',
      );
    }
    final combined = utf8.encode(
      '$javascript$loader'
      '${includeThemeToggle ? seoDomFirstThemeToggleRuntime : ''}',
    );
    if (codec.encode(combined).length > 31 * 1024) {
      throw StateError(
        'Application runtime "${artifact.reference.id}" exceeds the '
        'combined handoff gzip size budget.',
      );
    }
  }
}
