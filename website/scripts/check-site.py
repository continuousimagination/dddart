"""Check the actual Pages output, including subpath routing and source links."""

import json
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urljoin, urlsplit

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
REPO = ROOT.parent
ORIGIN = "https://continuousimagination.github.io"
BASE = "/dddart/"
errors = []


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__(convert_charrefs=True)
        self.path = path
        self.ids = set()
        self.references = []
        self.h1_count = 0
        self.description = None
        self.canonical = None
        self.title = ""
        self.in_title = False
        self.feed(path.read_text())

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if "id" in attrs:
            if attrs["id"] in self.ids:
                errors.append(f"{self.path.relative_to(DIST)}: duplicate id {attrs['id']}")
            self.ids.add(attrs["id"])
        if tag == "h1":
            self.h1_count += 1
        if tag == "title":
            self.in_title = True
        if tag == "meta" and attrs.get("name") == "description":
            self.description = attrs.get("content")
        if tag == "link" and attrs.get("rel") == "canonical":
            self.canonical = attrs.get("href")
        if tag in {"a", "link"} and attrs.get("href"):
            self.references.append(attrs["href"])
        if tag in {"img", "script", "source"} and attrs.get("src"):
            self.references.append(attrs["src"])

    def handle_endtag(self, tag):
        if tag == "title":
            self.in_title = False

    def handle_data(self, data):
        if self.in_title:
            self.title += data


pages = {path: Page(path) for path in DIST.rglob("*.html")}
if not pages:
    raise SystemExit("No HTML output. Build the website first.")


def public_path(path):
    relative = path.relative_to(DIST).as_posix()
    if relative.endswith("index.html"):
        relative = relative[:-len("index.html")]
    return BASE + relative


reference_count = 0
for path, page in pages.items():
    label = path.relative_to(DIST)
    expected = ORIGIN + public_path(path)
    if page.h1_count != 1:
        errors.append(f"{label}: expected one h1, found {page.h1_count}")
    if not page.title or not page.description:
        errors.append(f"{label}: missing title/description")
    if page.canonical != expected:
        errors.append(f"{label}: canonical {page.canonical!r} != {expected!r}")
    for reference in page.references:
        reference_count += 1
        url = urlsplit(urljoin(expected, reference))
        if url.netloc == "github.com" and url.path.startswith("/continuousimagination/dddart/"):
            parts = url.path.split("/")
            if len(parts) > 5 and parts[3] in {"blob", "tree", "edit"}:
                source = REPO / unquote("/".join(parts[5:]))
                if not source.exists():
                    errors.append(f"{label}: missing repository source {reference}")
        if url.scheme in {"mailto", "tel", "data"} or url.netloc != urlsplit(ORIGIN).netloc:
            continue
        if not url.path.startswith(BASE):
            errors.append(f"{label}: link escapes Pages subpath: {reference}")
            continue
        local = DIST / unquote(url.path[len(BASE):])
        if local.is_dir():
            local /= "index.html"
        if not local.is_file():
            errors.append(f"{label}: missing local target {reference}")
            continue
        if url.fragment and local in pages and unquote(url.fragment) not in pages[local].ids:
            errors.append(f"{label}: missing fragment {reference}")

search = json.loads((DIST / "search-index.json").read_text())
source_docs = list((ROOT / "src/content/docs").glob("*.md"))
if len(search) != len(source_docs):
    errors.append("Search index and source-document counts differ")
if len({entry["url"] for entry in search}) != len(search):
    errors.append("Search index has duplicate URLs")
for entry in search:
    if not all(entry.get(key) for key in ["title", "description", "section", "url", "text"]):
        errors.append(f"Incomplete search entry: {entry.get('url')}")
    target = DIST / entry["url"].removeprefix(BASE) / "index.html"
    if target not in pages:
        errors.append(f"Search points to missing page: {entry['url']}")

if errors:
    raise SystemExit("\n".join(errors))
print(f"Checked {len(pages)} HTML pages, {reference_count} links/assets, "
      f"and {len(search)} searchable guides. All checks passed.")
