/// Typed references to application-authored DOM-first browser logic.
library;

/// One application runtime selected by a DOM-first route.
///
/// The route stores only this validated logical identity. JavaScript remains
/// outside the route table and is loaded through the server runtime store.
sealed class SeoDomFirstApplicationRuntime {
  const SeoDomFirstApplicationRuntime._(this.id);

  /// Uses an application-authored transition with the package tabs adapter.
  const factory SeoDomFirstApplicationRuntime.tabs(String id) =
      SeoDomFirstTabsApplicationRuntime;

  /// Uses an application-authored transition with the package carousel adapter.
  const factory SeoDomFirstApplicationRuntime.carousel(String id) =
      SeoDomFirstCarouselApplicationRuntime;

  /// Uses application-authored logic with the package collection adapter.
  const factory SeoDomFirstApplicationRuntime.collection(String id) =
      SeoDomFirstCollectionApplicationRuntime;

  /// Uses an application-authored transition with the package stepper adapter.
  const factory SeoDomFirstApplicationRuntime.stepper(String id) =
      SeoDomFirstStepperApplicationRuntime;

  /// The logical build-artifact identity.
  final String id;

  /// The closed runtime kind written to the verified manifest.
  String get kind;

  @override
  bool operator ==(Object other) =>
      other is SeoDomFirstApplicationRuntime &&
      other.runtimeType == runtimeType &&
      other.id == id;

  @override
  int get hashCode => Object.hash(runtimeType, id);
}

/// An application-authored transition executed by the tabs adapter.
final class SeoDomFirstTabsApplicationRuntime
    extends SeoDomFirstApplicationRuntime {
  const SeoDomFirstTabsApplicationRuntime(super.id) : super._();

  @override
  String get kind => 'tabs';
}

/// An application-authored transition executed by the carousel adapter.
final class SeoDomFirstCarouselApplicationRuntime
    extends SeoDomFirstApplicationRuntime {
  const SeoDomFirstCarouselApplicationRuntime(super.id) : super._();

  @override
  String get kind => 'carousel';
}

/// An application-authored transition executed by the collection adapter.
final class SeoDomFirstCollectionApplicationRuntime
    extends SeoDomFirstApplicationRuntime {
  const SeoDomFirstCollectionApplicationRuntime(super.id) : super._();

  @override
  String get kind => 'collection';
}

/// An application-authored transition executed by the stepper adapter.
final class SeoDomFirstStepperApplicationRuntime
    extends SeoDomFirstApplicationRuntime {
  const SeoDomFirstStepperApplicationRuntime(super.id) : super._();

  @override
  String get kind => 'stepper';
}

/// Whether [id] is safe as a logical identity and artifact file component.
bool isValidSeoApplicationRuntimeId(String id) =>
    _applicationRuntimeId.hasMatch(id);

final RegExp _applicationRuntimeId = RegExp(r'^[a-z][a-z0-9_-]{0,63}$');
