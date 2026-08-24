/// Typed references to application-authored DOM-first browser logic.
library;

/// Closed adapter kinds accepted by application runtime builds.
enum SeoDomFirstApplicationRuntimeKind {
  tabs('tabs'),
  carousel('carousel'),
  collection('collection'),
  configurator('configurator'),
  stepper('stepper'),
  stepperEffects('stepper-effects');

  const SeoDomFirstApplicationRuntimeKind(this.value);

  /// Stable value written to bundle manifests.
  final String value;

  /// Parses a manifest or configuration value without guessing aliases.
  static SeoDomFirstApplicationRuntimeKind? tryParse(String value) {
    for (final kind in values) {
      if (kind.value == value) return kind;
    }
    return null;
  }

  String get _ownershipFamily => switch (this) {
        SeoDomFirstApplicationRuntimeKind.stepper ||
        SeoDomFirstApplicationRuntimeKind.stepperEffects =>
          'stepper',
        _ => value,
      };
}

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

  /// Uses an application transition and projection with fixed package slots.
  const factory SeoDomFirstApplicationRuntime.configurator(String id) =
      SeoDomFirstConfiguratorApplicationRuntime;

  /// Uses an application-authored transition with the package stepper adapter.
  const factory SeoDomFirstApplicationRuntime.stepper(String id) =
      SeoDomFirstStepperApplicationRuntime;

  /// Uses an application-authored stepper transition with closed effects.
  const factory SeoDomFirstApplicationRuntime.stepperEffects(String id) =
      SeoDomFirstStepperEffectsApplicationRuntime;

  /// Uses one artifact containing two or three bundle-capable families.
  ///
  /// Collection runtimes remain standalone because their measured JavaScript
  /// floor leaves no room for a second adapter inside the fixed artifact
  /// budget.
  factory SeoDomFirstApplicationRuntime.bundle(
    String id, {
    required Iterable<SeoDomFirstApplicationRuntimeKind> members,
  }) {
    if (!isValidSeoApplicationRuntimeId(id)) {
      throw ArgumentError.value(
        id,
        'id',
        'must start with a lowercase letter and contain at most 64 lowercase '
            'letters, digits, underscores or dashes',
      );
    }
    final ordered = members.toList();
    if (ordered.length < 2 || ordered.length > 3) {
      throw ArgumentError.value(
        ordered,
        'members',
        'must contain between two and three adapter families',
      );
    }
    final exactKinds = <SeoDomFirstApplicationRuntimeKind>{};
    final families = <String>{};
    for (final member in ordered) {
      if (member == SeoDomFirstApplicationRuntimeKind.collection ||
          member == SeoDomFirstApplicationRuntimeKind.configurator) {
        throw ArgumentError.value(
          ordered,
          'members',
          '${member.value} runtimes must use a standalone artifact',
        );
      }
      if (!exactKinds.add(member) || !families.add(member._ownershipFamily)) {
        throw ArgumentError.value(
          ordered,
          'members',
          'must contain each adapter family exactly once',
        );
      }
    }
    ordered.sort((left, right) => left.index.compareTo(right.index));
    return SeoDomFirstApplicationRuntimeBundle._(
      id,
      List<SeoDomFirstApplicationRuntimeKind>.unmodifiable(ordered),
    );
  }

  /// The logical build-artifact identity.
  final String id;

  /// The closed runtime kind written to the verified manifest.
  String get kind;

  /// Adapter kinds initialized by this artifact in canonical order.
  List<SeoDomFirstApplicationRuntimeKind> get memberKinds;

  @override
  bool operator ==(Object other) =>
      other is SeoDomFirstApplicationRuntime &&
      other.runtimeType == runtimeType &&
      other.id == id &&
      _sameKinds(other.memberKinds, memberKinds);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        id,
        Object.hashAll(memberKinds),
      );
}

/// An application-authored transition executed by the tabs adapter.
final class SeoDomFirstTabsApplicationRuntime
    extends SeoDomFirstApplicationRuntime {
  const SeoDomFirstTabsApplicationRuntime(super.id) : super._();

  @override
  String get kind => 'tabs';

  @override
  List<SeoDomFirstApplicationRuntimeKind> get memberKinds =>
      const [SeoDomFirstApplicationRuntimeKind.tabs];
}

/// An application-authored transition executed by the carousel adapter.
final class SeoDomFirstCarouselApplicationRuntime
    extends SeoDomFirstApplicationRuntime {
  const SeoDomFirstCarouselApplicationRuntime(super.id) : super._();

  @override
  String get kind => 'carousel';

  @override
  List<SeoDomFirstApplicationRuntimeKind> get memberKinds =>
      const [SeoDomFirstApplicationRuntimeKind.carousel];
}

/// An application-authored transition executed by the collection adapter.
final class SeoDomFirstCollectionApplicationRuntime
    extends SeoDomFirstApplicationRuntime {
  const SeoDomFirstCollectionApplicationRuntime(super.id) : super._();

  @override
  String get kind => 'collection';

  @override
  List<SeoDomFirstApplicationRuntimeKind> get memberKinds =>
      const [SeoDomFirstApplicationRuntimeKind.collection];
}

/// An application-authored transition and fixed-slot view projection.
final class SeoDomFirstConfiguratorApplicationRuntime
    extends SeoDomFirstApplicationRuntime {
  const SeoDomFirstConfiguratorApplicationRuntime(super.id) : super._();

  @override
  String get kind => 'configurator';

  @override
  List<SeoDomFirstApplicationRuntimeKind> get memberKinds =>
      const [SeoDomFirstApplicationRuntimeKind.configurator];
}

/// An application-authored transition executed by the stepper adapter.
final class SeoDomFirstStepperApplicationRuntime
    extends SeoDomFirstApplicationRuntime {
  const SeoDomFirstStepperApplicationRuntime(super.id) : super._();

  @override
  String get kind => 'stepper';

  @override
  List<SeoDomFirstApplicationRuntimeKind> get memberKinds =>
      const [SeoDomFirstApplicationRuntimeKind.stepper];
}

/// An application-authored state and effect transition for the stepper.
final class SeoDomFirstStepperEffectsApplicationRuntime
    extends SeoDomFirstApplicationRuntime {
  const SeoDomFirstStepperEffectsApplicationRuntime(super.id) : super._();

  @override
  String get kind => 'stepper-effects';

  @override
  List<SeoDomFirstApplicationRuntimeKind> get memberKinds =>
      const [SeoDomFirstApplicationRuntimeKind.stepperEffects];
}

/// A route-scoped artifact containing two or three bundle-capable families.
final class SeoDomFirstApplicationRuntimeBundle
    extends SeoDomFirstApplicationRuntime {
  SeoDomFirstApplicationRuntimeBundle._(super.id, this.memberKinds) : super._();

  @override
  String get kind => 'bundle';

  @override
  final List<SeoDomFirstApplicationRuntimeKind> memberKinds;
}

/// Whether [id] is safe as a logical identity and artifact file component.
bool isValidSeoApplicationRuntimeId(String id) =>
    _applicationRuntimeId.hasMatch(id);

final RegExp _applicationRuntimeId = RegExp(r'^[a-z][a-z0-9_-]{0,63}$');

bool _sameKinds(
  List<SeoDomFirstApplicationRuntimeKind> left,
  List<SeoDomFirstApplicationRuntimeKind> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
