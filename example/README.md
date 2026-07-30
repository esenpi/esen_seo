# esen_seo example

A small Flutter Web page that mirrors its widget tree as real semantic
HTML, sets meta tags / OpenGraph / JSON-LD and ships with a bot-aware
SSR server.

## Run the app

```sh
flutter run -d chrome
```

Open the DOM inspector and look for `#esen-seo-content` at the end of
`<body>` — that is the semantic mirror of the page. The `<head>` contains
the injected meta tags and the JSON-LD schema.

## Run the SSR server

```sh
flutter build web
dart run bin/server.dart
```

Then compare what bots and users receive:

```sh
curl -A "Googlebot/2.1" http://localhost:8080   # semantic HTML document
curl -A "Mozilla/5.0"   http://localhost:8080   # Flutter web app
curl http://localhost:8080/sitemap.xml          # generated from seo_routes.dart
```

## Or: prerender for static hosting (no server)

```sh
flutter build web
dart run bin/prerender.dart
```

This bakes meta tags and semantic HTML for every route directly into
`build/web` (`index.html`, `demo/index.html`, `sitemap.xml`,
`robots.txt`) — deploy the folder to any static host and the HTML is in
the page source for everyone.
