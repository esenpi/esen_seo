# Contributing to esen_seo

First of all — thank you for considering a contribution
to esen_seo! 🎉

## Before you start

Please read our [CLA.md](CLA.md) before submitting
a Pull Request. By opening a PR you automatically
agree to its terms.

## How to contribute

### Reporting bugs
- Open a GitHub Issue
- Describe the bug clearly
- Include a minimal reproducible example
- Mention your Flutter/Dart version

### Suggesting features
- Open a GitHub Issue with the label "enhancement"
- Explain the use case
- Explain why it fits the vision of esen_seo

### Submitting a Pull Request

**1. Fork the repository**
```bash
git clone https://github.com/esenpi/esen_seo
cd esen_seo
```

**2. Create a branch**
```bash
git checkout -b feature/my-feature
# or
git checkout -b fix/my-bugfix
```

**3. Make your changes**
- Follow the existing code style
- Add tests for every new feature
- Make sure all tests pass:
```bash
flutter test
```

**4. Commit with a clear message**
```bash
git commit -m "feat: add SeoTextTag.time shorthand"
git commit -m "fix: row style removed for tr tag"
git commit -m "docs: add example for breadcrumbs"
```

**5. Open a Pull Request**
- Describe what you changed and why
- Reference any related Issue: "Closes #42"

## Code Style

- Follow standard Dart/Flutter conventions
- Use `flutter analyze` before committing
- Document public APIs with `///` comments
- No `dart:html` — use `package:web` instead

## What we accept

✅ Bug fixes with a test
✅ New Widget extensions (.seo() on more widgets)
✅ New SeoSchema factories
✅ Performance improvements
✅ Documentation improvements
✅ New BotDetector patterns

❌ Breaking API changes without discussion
❌ Dependencies that don't support WASM
❌ dart:html usage
❌ Code without tests

## Vision

esen_seo is the first step toward a complete
Flutter-based CMS — a WordPress alternative
built entirely in Flutter/Dart.

Every contribution should align with this vision:
real semantic HTML, no tricks, pure Dart.

## Questions?

Open a GitHub Issue or reach out at:
hello@esen.software

## Contributors

Everyone who contributes gets listed in
[CONTRIBUTORS.md](CONTRIBUTORS.md) — your name,
your contribution, forever in the project history.