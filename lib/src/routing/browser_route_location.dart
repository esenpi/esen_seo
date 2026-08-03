/// Selects the application route represented by a browser URL.
///
/// Hash routers encode their route as a slash-prefixed fragment (`#/docs`).
/// Other fragments are ordinary in-page anchors and must not replace the
/// pathname (`/docs#install` still represents `/docs`).
String browserRouteLocation(Uri base) {
  if (base.fragment.startsWith('/')) return base.fragment;
  return base.path.isEmpty ? '/' : base.path;
}
