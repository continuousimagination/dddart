/// Consistency policy for generated DynamoDB point reads.
enum DynamoReadConsistency {
  /// Lower-cost reads may observe an older committed value.
  eventual,

  /// Read the latest committed value from the selected table.
  strong,
}
