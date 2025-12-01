/// Traverses object graphs for serialization and deserialization.
class GraphTraverser {
  /// Creates a graph traverser.
  const GraphTraverser();

  /// Traverses an object graph depth-first.
  void traverse(
    Object root,
    void Function(Object node, int depth) visitor,
  ) {
    _traverseRecursive(root, visitor, 0, <Object>{});
  }

  void _traverseRecursive(
    Object node,
    void Function(Object node, int depth) visitor,
    int depth,
    Set<Object> visited,
  ) {
    // Prevent infinite loops
    if (visited.contains(node)) {
      return;
    }
    visited.add(node);

    visitor(node, depth);

    // TODO(later): Implement recursive traversal of fields
    // This will be implemented when needed in later tasks
  }
}
