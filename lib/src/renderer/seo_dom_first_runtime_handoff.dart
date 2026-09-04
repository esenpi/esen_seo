import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'seo_dom_first_collection_runtime.g.dart';

const String seoDomFirstLoadableRuntimeAttribute =
    'data-esen-seo-dom-first-loadable-runtime';
const String seoDomFirstRuntimeSha256Attribute = 'data-esen-seo-runtime-sha256';
const String seoDomFirstRuntimeReadyAttribute = 'data-esen-seo-runtime-ready';
const String seoDomFirstRuntimeKindAttribute = 'data-esen-seo-runtime-kind';
const String seoDomFirstRuntimeContractAttribute =
    'data-esen-seo-runtime-contract';
const String seoDomFirstCollectionRuntimeKind = 'collection';
const String seoDomFirstApplicationRuntimeOwner = 'application';
const int seoDomFirstLoadableRuntimeMaxBytes = 128 * 1024;
const int seoDomFirstApplicationHandoffEnvelopeMaxBytes = 512 * 1024 + 256;

/// Package-owned suffix joined only after application-source verification.
const String seoDomFirstApplicationHandoffEpilogue =
    '\n;delete document.documentElement.dataset.esenCollectionPending;'
    'document.currentScript&&document.currentScript.setAttribute('
    '"$seoDomFirstRuntimeReadyAttribute","true")';

/// Package-owned Configurator suffix joined only after source verification.
const String seoDomFirstConfiguratorApplicationHandoffEpilogue =
    '\n;delete document.documentElement.dataset.esenInteractionPending;'
    'document.currentScript&&document.currentScript.setAttribute('
    '"$seoDomFirstRuntimeReadyAttribute","true")';

/// The complete classic-script body admitted by the first runtime handoff.
final String seoDomFirstCollectionHandoffRuntime =
    '$seoDomFirstCollectionRuntime;'
    'delete document.documentElement.dataset.esenCollectionPending;'
    'document.currentScript&&document.currentScript.setAttribute('
    '"$seoDomFirstRuntimeReadyAttribute","true")';

final int seoDomFirstCollectionHandoffRuntimeBytes =
    utf8.encode(seoDomFirstCollectionHandoffRuntime).length;

final String seoDomFirstCollectionHandoffRuntimeSha256 =
    sha256.convert(utf8.encode(seoDomFirstCollectionHandoffRuntime)).toString();

/// Wraps one verified application artifact in the fixed handoff-ready envelope.
String seoDomFirstApplicationHandoffEnvelope(
  String javascript, {
  String kind = seoDomFirstCollectionRuntimeKind,
}) =>
    '$javascript${seoDomFirstApplicationHandoffEpilogueFor(kind)}';

/// Returns the closed package suffix for an admitted application handoff kind.
String seoDomFirstApplicationHandoffEpilogueFor(String kind) => switch (kind) {
      seoDomFirstCollectionRuntimeKind => seoDomFirstApplicationHandoffEpilogue,
      'configurator' => seoDomFirstConfiguratorApplicationHandoffEpilogue,
      _ => throw ArgumentError.value(
          kind,
          'kind',
          'must be collection or configurator',
        ),
    };
