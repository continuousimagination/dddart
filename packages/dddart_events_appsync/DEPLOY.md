# Deploy the AppSync event example

The [CloudFormation template](deploy/cloudformation.yaml)
uses AppSync **Events**, DIRECT REQUEST_RESPONSE Lambda handlers and optional
custom/Cognito/OIDC authentication. The complete
[custom runtime](example/lambda.dart) awaits
invocation processing and adapts Function URL requests to the same Shelf routes.
It uses a DynamoDB-backed **example** ACL policy; replace that policy with domain
repositories for a production application.

## Prepare AWS and build the runtime

Choose the AWS account and region, and sign in to AWS CLI. Use an existing
ECR repository with permission to push an image. For built-in JWTs, create a
Secrets Manager JSON secret containing the issuer's signing key under
`jwtSecret`. Pass its ARN to the template.

```bash
# From the workspace root. IMAGE_URI points at an ECR repository:unique-tag.
aws ecr get-login-password --region "$AWS_REGION" | \
  docker login --username AWS --password-stdin "$ECR_REGISTRY"
docker buildx build --platform linux/amd64 --push -t "$IMAGE_URI" \
  -f packages/dddart_events_appsync/deploy/Dockerfile .
aws cloudformation deploy --region "$AWS_REGION" \
  --stack-name dddart-events \
  --template-file packages/dddart_events_appsync/deploy/cloudformation.yaml \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides ImageUri="$IMAGE_URI" AuthMode=AWS_LAMBDA \
    JwtSecretArn="$JWT_SECRET_ARN" TokenIssuer="$TOKEN_ISSUER" \
    TokenAudience="$TOKEN_AUDIENCE" AllowedOrigins="$APP_ORIGIN"
aws cloudformation describe-stacks --region "$AWS_REGION" \
  --stack-name dddart-events --query 'Stacks[0].Outputs'
```

The image uses Dart AOT and Lambda's provided AL2023 base, rather than assuming an
AWS-managed Dart runtime. Update with a fresh image tag through the same deploy
command. A secret-value update also needs a Lambda configuration/stack update to
refresh the resolved environment value; publishing into Secrets Manager alone
does not replace a warm runtime's environment.

## Choose a provider and storage

Set `AuthMode=AMAZON_COGNITO_USER_POOLS`, `CognitoUserPoolId`, `CognitoRegion`,
`TokenIssuer`, `TokenAudience`, and `NativeJwksUri` for an existing Cognito pool.
For OIDC, set `AuthMode=OPENID_CONNECT` with issuer, audience and JWKS URI. No pool
is created. Clients use the same appropriate ID token for HTTP and AppSync.

To use an existing table, set `ExistingTableName` and follow the
[event table schema](../dddart_events_dynamodb/README.md#table-schema).
`RetentionDays` sets payload and rotation retention. The default
`CreateControlUrl=true` creates a Function URL whose routes require application
Bearer authentication. Set it to false and supply `ExistingControlBaseUrl` when
registering the routes on your own server. Outputs include event HTTP/realtime
endpoints, namespace, table, control URL, handler ARN and backend relay role;
signing secrets are never outputs.

## Check live delivery

To authorize the reference application's smoke aggregate, an operator writes an
ACL item in the output table: `pk = 'acl#' + reference.toKey(registry.identityCodecs)`,
`sk = 'acl'`, `subscribers` and `publishers` are DynamoDB String Sets of verified
token subject IDs. The full example is deny-by-default. Compute that key with the
public `AggregateReference.toKey` API, never a hand-invented UUID encoding.
Update ACLs before publishing `ExampleChanged(message: 'access-changed', ...)` to
exercise the example's registered rotation trigger. Regular events use another
message value. This ACL schema is application example data, not a core contract.

After configuring an existing deployment/ACL/token, explicitly opt in to the
finite [AWS smoke program](example/aws_smoke.dart):

```bash
export DDDART_RUN_AWS_SMOKE=true
# Set DDDART_CONTROL_URL, DDDART_EVENT_HTTP, DDDART_EVENT_REALTIME,
# DDDART_TOKEN, DDDART_AGGREGATE_ID, and optionally DDDART_NAMESPACE /
# DDDART_AGGREGATE_KIND (defaults: aggregates / game).
dart run packages/dddart_events_appsync/example/aws_smoke.dart
```

It watches an authorized aggregate, publishes one occurrence, waits for live
delivery, then closes resources. It creates no AWS infrastructure. Do not point
it at an aggregate where that example event would be inappropriate.

## Remove test resources

Delete the stack with `aws cloudformation delete-stack --stack-name dddart-events`
in the chosen region. **New event tables are retained** on deletion/replacement;
record their output names beforehand and explicitly remove retained tables/data
only when no longer needed. Existing tables, signing secrets, Cognito/OIDC
providers and ECR repositories/images remain operator-owned. Removing the stack
does not automatically remove them.
