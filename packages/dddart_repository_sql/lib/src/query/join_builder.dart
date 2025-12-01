import 'package:dddart_repository_sql/src/dialect/sql_dialect.dart';
import 'package:dddart_repository_sql/src/schema/table_definition.dart';

/// Builds SQL JOIN queries for loading aggregate graphs.
///
/// This class generates SELECT queries with JOIN clauses to load
/// aggregate roots along with their nested entities in a single query.
class JoinBuilder {
  /// Creates a join builder.
  const JoinBuilder();

  /// Generates a SELECT query with JOINs for an aggregate root.
  ///
  /// Creates a query that loads the aggregate root and all its related
  /// entities using JOIN clauses. Uses LEFT JOIN for nullable relationships
  /// to ensure the root is returned even if related entities don't exist.
  ///
  /// Example:
  /// ```dart
  /// final query = builder.buildLoadQuery(orderTable, schema, dialect);
  /// // Returns:
  /// // SELECT orders.*, order_items.*
  /// // FROM orders
  /// // LEFT JOIN order_items ON order_items.order_id = orders.id
  /// // WHERE orders.id = ?
  /// ```
  String buildLoadQuery(
    TableDefinition rootTable,
    Map<Type, TableDefinition> schema,
    SqlDialect dialect,
  ) {
    final joins = buildJoinClauses(rootTable, schema, dialect);

    // Build SELECT clause with all columns from all tables
    final selectColumns = <String>[];

    // Add root table columns
    for (final column in rootTable.columns) {
      selectColumns.add('${rootTable.tableName}.${column.name}');
    }

    // Add columns from joined tables
    for (final join in joins) {
      // Extract table name from join clause
      final tableName = _extractTableNameFromJoin(join.table);
      final joinedTable = _findTableByName(tableName, schema);

      if (joinedTable != null) {
        for (final column in joinedTable.columns) {
          selectColumns.add('$tableName.${column.name}');
        }
      }
    }

    // Build the complete query
    final buffer = StringBuffer();
    buffer.write('SELECT ${selectColumns.join(', ')} ');
    buffer.write('FROM ${rootTable.tableName} ');

    // Add JOIN clauses
    for (final join in joins) {
      buffer.write(_formatJoinClause(join));
      buffer.write(' ');
    }

    // Add WHERE clause for ID lookup
    buffer.write('WHERE ${rootTable.tableName}.id = ?');

    return buffer.toString();
  }

  /// Generates JOIN clauses for related tables.
  ///
  /// Analyzes the table's foreign keys to determine which tables need to be
  /// joined. Uses LEFT JOIN for nullable relationships to ensure the parent
  /// row is returned even if child rows don't exist.
  ///
  /// Example:
  /// ```dart
  /// final joins = builder.buildJoinClauses(orderTable, schema, dialect);
  /// // Returns: [
  /// //   JoinClause(
  /// //     type: JoinType.left,
  /// //     table: 'order_items',
  /// //     onCondition: 'order_items.order_id = orders.id',
  /// //   ),
  /// // ]
  /// ```
  List<JoinClause> buildJoinClauses(
    TableDefinition table,
    Map<Type, TableDefinition> schema,
    SqlDialect dialect,
  ) {
    final joins = <JoinClause>[];

    // Find all tables that reference this table (child entities)
    for (final entry in schema.entries) {
      final candidateTable = entry.value;

      // Skip the table itself
      if (candidateTable.tableName == table.tableName) {
        continue;
      }

      // Skip aggregate roots (they're not part of this aggregate)
      if (candidateTable.isAggregateRoot) {
        continue;
      }

      // Check if this table has a foreign key pointing to our table
      for (final fk in candidateTable.foreignKeys) {
        if (fk.referencedTable == table.tableName) {
          // This table references our table - add a JOIN
          final join = JoinClause(
            type:
                JoinType.left, // Use LEFT JOIN to handle optional relationships
            table: candidateTable.tableName,
            onCondition:
                '${candidateTable.tableName}.${fk.columnName} = ${table.tableName}.${fk.referencedColumn}',
          );
          joins.add(join);
        }
      }
    }

    return joins;
  }

  /// Extracts the table name from a join clause table reference.
  String _extractTableNameFromJoin(String tableRef) {
    // Handle potential aliases (e.g., "table AS alias")
    final parts = tableRef.split(' ');
    return parts.first;
  }

  /// Finds a table definition by table name.
  TableDefinition? _findTableByName(
    String tableName,
    Map<Type, TableDefinition> schema,
  ) {
    for (final entry in schema.entries) {
      if (entry.value.tableName == tableName) {
        return entry.value;
      }
    }
    return null;
  }

  /// Formats a JOIN clause as SQL.
  String _formatJoinClause(JoinClause join) {
    final joinType = _formatJoinType(join.type);
    return '$joinType ${join.table} ON ${join.onCondition}';
  }

  /// Formats a JOIN type as SQL keyword.
  String _formatJoinType(JoinType type) {
    switch (type) {
      case JoinType.inner:
        return 'INNER JOIN';
      case JoinType.left:
        return 'LEFT JOIN';
      case JoinType.right:
        return 'RIGHT JOIN';
      case JoinType.fullOuter:
        return 'FULL OUTER JOIN';
    }
  }
}
