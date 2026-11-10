# dddart website

The public homepage and documentation are built with Astro and published to
https://continuousimagination.github.io/dddart/ by GitHub Pages. Source lives in
this repository; no separate website repository or hosting subscription is needed.

## Work locally

Use Node 24.15 or later in the Node 24 line:

```bash
cd website
npm ci
ASTRO_TELEMETRY_DISABLED=1 npm run dev
```

Open the printed local URL with `/dddart/` as the path. The site is generated HTML,
with JavaScript only for navigation, search, code tabs, and copying snippets.
Fonts, styles, search data, and assets are served with the site; there are no
external analytics or account services.

```bash
ASTRO_TELEMETRY_DISABLED=1 npm run check
ASTRO_TELEMETRY_DISABLED=1 npm run preview
```

`check` builds the entire site and checks internal routes, assets, fragment links,
metadata, the search index, and repository source references. It checks the public
`/dddart/` base path rather than assuming root hosting.

## Edit documentation

Pages live in `src/content/docs/*.md`. Each has a title, description, section,
and numeric order in frontmatter. Navigation, on-page headings, search data, and
the sitemap derive from these pages. The top-level order is in `src/lib/site.ts`.

Use absolute site links such as `/dddart/docs/events/` and descriptive link labels.
The layout supplies the page's h1; start content headings at h2. Mark incomplete
composition fragments clearly and state their prerequisites. Do not present a
source-only or external-service example as a verified standalone program.

The initial guides target library revision
`b4aacf0671873e729a1a390dc2bb609b80c723e5`. Update source references, the installation
revision, `public/downloads/git-dependencies.yaml`, and the relevant example checks
together when the library changes. The repository's legacy package README examples
are not always current; use implementation and active example fixtures to verify APIs.

## Publish

`.github/workflows/pages.yml` builds and checks website pull requests. Changes under
`website/` or the Pages workflow deploy automatically after reaching `main`.
The Website workflow also supports manual dispatch. Only `website/dist` is uploaded.
Pull requests have read-only permissions and do not deploy. The deploy job alone
receives Pages and OpenID Connect write permissions.

Pages must use **GitHub Actions** as its build source, with HTTPS enforced. The initial
setup enables Actions for this workflow while keeping the pre-existing Dart `Test`
workflow disabled, preserving its effective state when repository Actions were off.
Re-enable that test workflow separately if desired.

## Verification scope

The initial docs were developed by reviewing all public package families and their
implementations, examples, tests, and validation inventory. Standalone core,
configuration, JSON, and SQLite snippets were extracted and exercised; representative
client compositions were compiled to JavaScript. The public example catalog records
the scope and distinguishes local verification from live provider/device testing.
No live AWS or Slack resources are needed for the website build.
