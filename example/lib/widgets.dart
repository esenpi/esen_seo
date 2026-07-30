// Gemeinsame UI-Bausteine der Example App. Alle Bausteine nutzen selbst
// .seo() — die App ist gleichzeitig die Demo des Packages.
import 'package:esen_seo/esen_seo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Gemeinsames Seitengerüst: Navigation oben, zentrierte Spalte,
/// maximal 760px breit.
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SiteNav(),
                  const SizedBox(height: 32),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kopfnavigation — als echtes `<nav>` mit `<a href>`-Links gespiegelt.
class SiteNav extends StatelessWidget {
  const SiteNav({super.key});

  void _go(BuildContext context, String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        // Explizit .span getaggt, damit der Markenname nicht per Smart
        // Default zur <h1> der Seite wird.
        Text(
          'esen_seo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: colors.primary,
          ),
        ).span,
        const Spacer(),
        SeoLink(label: 'Home', href: '/', onTap: () => _go(context, '/')),
        const SizedBox(width: 20),
        SeoLink(
          label: 'Demo',
          href: '/demo',
          onTap: () => _go(context, '/demo'),
        ),
        const SizedBox(width: 20),
        SeoLink(
          label: 'Docs',
          href: '/docs',
          onTap: () => _go(context, '/docs'),
        ),
      ],
    ).nav;
  }
}

/// Ein tappbarer Link, der als echtes `<a href>` gespiegelt wird.
class SeoLink extends StatelessWidget {
  const SeoLink({
    super.key,
    required this.label,
    required this.href,
    required this.onTap,
  });

  final String label;
  final String href;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // GestureDetector().seo(href: ...) → <a href="...">label</a>
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    ).seo(href: href);
  }
}

/// Dunkler Code-Block mit Copy-Button — gespiegelt als `<pre>`.
class CodeBlock extends StatelessWidget {
  const CodeBlock(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.inverseSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 44, 16),
            child: Text(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: const ['Menlo', 'Courier New'],
                fontSize: 13,
                height: 1.6,
                color: colors.onInverseSurface,
              ),
            ).seo(SeoTextTag.pre),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: IconButton(
              tooltip: 'Copy',
              iconSize: 16,
              color: colors.onInverseSurface.withValues(alpha: 0.7),
              icon: const Icon(Icons.copy),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied to clipboard'),
                      width: 220,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Ein Dokumentations-Abschnitt: `<section>` mit `<h2>`-Überschrift.
class DocSection extends StatelessWidget {
  const DocSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 14,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall).h2,
        ...children,
      ],
    ).section;
  }
}

/// Ein Fließtext-Absatz — gespiegelt als `<p>`.
class Para extends StatelessWidget {
  const Para(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(height: 1.55, fontSize: 15)).p;
  }
}

/// Eine Aufzählung — gespiegelt als `<ul>` mit `<li>`-Einträgen.
class Bullets extends StatelessWidget {
  const Bullets(this.items, {super.key});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        for (final item in items)
          Text('•  $item', style: const TextStyle(height: 1.4)).li,
      ],
    ).ul;
  }
}
