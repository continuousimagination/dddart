# Develop the DDDart website

The [public documentation](https://continuousimagination.github.io/dddart/) is
built with Astro and served by GitHub Pages. The Node constraint and site
dependencies are in [package.json](package.json).

## Preview and test

From this directory:

```sh
npm ci
ASTRO_TELEMETRY_DISABLED=1 npm run dev
ASTRO_TELEMETRY_DISABLED=1 npm run check
```

Follow the printed local URL under `/dddart/`. Use `npm run preview` for the
built site. The check builds the site, verifies links, anchors, metadata,
assets and search data, and runs the site checker regression tests. It uses
Bash, jq and `xmllint` (on Ubuntu, install `libxml2-utils`).
[Documentation validation](../tool/documentation/README.md) checks that Dart
examples still work.

## Edit a guide

Guides are in [src/content/docs](src/content/docs/). Use the title as the
navigation label; frontmatter also declares a description, section, and
order. The layout supplies the page title, so start body headings at h2.
Use site links rooted at `/dddart/`.

Keep the site focused on how to use DDDart. Link to the repository's
[complete quickstarts](../docs/QUICKSTARTS.md) for setup and to package guides
for adapter-specific details. Publish inline Dart through the checked source
inclusion format. The [core example pubspec](../docs/quickstarts/core/pubspec.yaml.txt)
supplies the Git revision for the standalone workflows.

## Publish

The [Website workflow](../.github/workflows/pages.yml) builds and checks the
site when its inputs change. It deploys from `main` to GitHub Pages. The
[Documentation workflow](../.github/workflows/documentation.yml) checks guides
throughout the repository. See [Actions](https://github.com/continuousimagination/dddart/actions)
for current runs.
