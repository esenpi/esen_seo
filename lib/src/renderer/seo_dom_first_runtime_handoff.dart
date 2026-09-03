import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'seo_dom_first_collection_runtime.g.dart';

const String seoDomFirstLoadableRuntimeAttribute =
    'data-esen-seo-dom-first-loadable-runtime';
const String seoDomFirstRuntimeSha256Attribute = 'data-esen-seo-runtime-sha256';
const String seoDomFirstRuntimeReadyAttribute = 'data-esen-seo-runtime-ready';
const String seoDomFirstCollectionRuntimeKind = 'collection';
const int seoDomFirstLoadableRuntimeMaxBytes = 128 * 1024;

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
