# dddart website

The public homepage and documentation are built with Astro and published to
https://continuousimagination.github.io/dddart/ by GitHub Pages. Source lives in
this repository; no separate website repository or hosting subscription is needed.

## Work locally

Use Node 24.15 or later in the Node 24 line:

Site validation also uses Bash, jq and libxml2's `xmllint`. macOS includes
`xmllint`; on Ubuntu install `jq libxml2-utils`. The workflow installs the HTML
parser explicitly. No additional scripting runtime is needed.

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
The layout supplies the page's h1; start content headings at h2. Publish Dart code through checked source inclusions; link to complete examples
instead of copying incomplete fragments. Do not present a
source-only or external-service example as a verified standalone program.

The initial guides target library revision
`56607ac8d3913b8e896ac03f8ecff58473d62ce2`. Update source references, the installation
revision, `public/downloads/git-dependencies.yaml`, and the relevant example checks
together when the library changes. All current repository documentation and library Dartdoc participate in the
documentation gate; historical work records are explicitly marked.

## Publish

`.github/workflows/pages.yml` builds and checks changes to `website/**`,
`docs/quickstarts/**` (imported by the homepage), `tool/documentation/common.sh`,
or the Pages workflow itself. Matching main pushes deploy automatically;
unrelated library changes do not rebuild or redeploy the site.
The separate `.github/workflows/documentation.yml` checks documentation across
the repository on every main-targeting PR/main push and has no deployment job.
The Website workflow also supports manual dispatch. Only `website/dist` is uploaded.
Pull requests have read-only permissions and do not deploy. The deploy job alone
receives Pages and OpenID Connect write permissions.

Pages uses **GitHub Actions** as its build source, with HTTPS enforced. Actions was
disabled repository-wide when this site was prepared. With the repository owner's
approval, Actions is now enabled and the pre-existing Dart `Test` workflow remains
disabled, preserving that workflow's prior effective state. Re-enable the test
workflow separately if desired.

## Verification scope

The initial docs were developed by reviewing all public package families and their
implementations, examples, tests, and validation inventory. Standalone core,
configuration, JSON, and SQLite snippets were extracted and exercised; representative
client compositions were compiled to JavaScript. The public example catalog records
the scope and distinguishes local verification from live provider/device testing.
No live AWS or Slack resources are needed for the website build.

## Dart snippets and workflows

From the repository root, run `bash tool/documentation/validate.sh check` for
published-source, surface-inventory and local-link drift, then the relevant execution lane described
in [the documentation gate](../tool/documentation/README.md). The active
Documentation workflow runs the fast check for library/generator changes too;
the disabled Test workflow defines the heavier execution gates, which must be run
locally. `npm run check` builds the site, checks its HTML metadata, links, anchors,
source references and search index, then runs 13 regression tests against
temporary copies of that output. It does not replace the isolated Dart consumer gate.
