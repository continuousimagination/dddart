# Maintain DDDart documentation

Use [the documentation index](../../docs/README.md) for user guides. When you
change a behavior, update its package or contract guide and check the example
that demonstrates it. Keep dependency constraints in the example pubspec and
tool settings in their manifests. Link to those files from the guides.

## Edit a guide or example

- Put complete standalone applications under [docs/quickstarts](../../docs/quickstarts/).
  Keep package-specific instructions next to the package or its examples. Put
  release notes in the package changelog and use GitHub for issues and reviews.
- Register new Markdown, MDX, or RST documents in
  [surfaces.json](surfaces.json). Release notes use the historical category;
  user and contributor guides use the current category.
- Use a link to a complete program if the reader needs setup, multiple files,
  or an external service. For inline Dart, put the complete checked file
  between `<!-- dddart-source: repository/relative/path -->` and
  `<!-- /dddart-source -->` around the fenced block. Commands and expected
  output can use the same format.
- Record how each sample runs in the
  [shared validation inventory](../validation/inventory.json). Its example
  README lists the corresponding programs and their requirements. Put
  standalone file names, commands, required services, and expected output in
  [workflows.json](../../docs/quickstarts/workflows.json).

## Check your changes

Run from the repository root:

```sh
bash tool/documentation/validate.sh sync
bash tool/documentation/validate.sh check
bash tool/documentation/self_test.sh --static
```

Use `sync` after editing an included source file. The fast check compares
inclusions to their sources, validates document links and anchors, checks
sample tables and the homepage examples, and compares public exports and
package listings with their sources. It also rejects copied dependency
constraints and tool version instructions. For website routes and search, see
[website checks](../../website/README.md#preview-and-test).

## Exercise a standalone application

```sh
bash tool/documentation/validate.sh run json --source=git
bash tool/documentation/validate.sh all --service-kind=none
bash tool/documentation/validate.sh all --service-kind=mysql
bash tool/documentation/validate.sh all --service-kind=mongo
bash tool/documentation/validate.sh all --service-kind=dynamodb
bash tool/documentation/self_test.sh
```

Use Bash, jq, Git, and standard Unix tools for the fast checks. Execution also
needs Dart, Node, tar, and GNU `timeout` (provided by `coreutils` on macOS).
Resolve dependencies with `dart pub get` and check the example pubspecs and
[website manifest](../../website/package.json) for the runtime constraints.

The default mode stages each DDDart dependency from a Pub archive, then
executes the example in a fresh application directory. It resolves dependencies,
runs generation and analysis where required, checks output, and removes the
temporary files. In Git mode the example uses its actual manifest and verifies
the resolved lockfile revision. The
[core example pubspec](../../docs/quickstarts/core/pubspec.yaml.txt) pins the
shared Git revision; the check requires every standalone example to use it.
Keep those Git entries aligned when updating the pin.

Start the disposable services described in the corresponding
[quickstarts](../../docs/QUICKSTARTS.md) for service lanes. Plain `all` requires
all declared services. Native/liveness checks that need deployment or
credentials are covered separately in each package guide.

The [Documentation workflow](../../.github/workflows/documentation.yml) runs
the fast check. The [Test workflow](../../.github/workflows/test.yml) defines the
execution lanes. See [Actions](https://github.com/continuousimagination/dddart/actions)
for current workflow status. Run the affected execution lanes locally
when changing API behavior or example code. Local archive and Git runs test
those sources; a hosted release needs separate verification against the
published packages.
