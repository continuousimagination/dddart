import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test(
      'deployment uses Events resources, native direct handlers and matching storage',
      () {
    final template =
        loadYaml(File('deploy/cloudformation.yaml').readAsStringSync()) as Map;
    final resources = template['Resources'] as Map;
    expect(resources['EventApi']['Type'], 'AWS::AppSync::Api');
    expect(
      resources.values
          .any((value) => value['Type'] == 'AWS::AppSync::GraphQLApi'),
      isFalse,
    );
    final handlers = resources['Channels']['Properties']['HandlerConfigs'];
    for (final name in ['OnSubscribe', 'OnPublish']) {
      expect(handlers[name]['Behavior'], 'DIRECT');
      expect(
        handlers[name]['Integration']['LambdaConfig']['InvokeType'],
        'REQUEST_RESPONSE',
      );
    }
    final schema = resources['EventTable']['Properties'];
    expect(
      (schema['KeySchema'] as List).map((value) => value['AttributeName']),
      ['pk', 'sk'],
    );
    expect(schema['TimeToLiveSpecification']['AttributeName'], 'expiresAt');
    expect(resources['EventTable']['DeletionPolicy'], 'Retain');
    expect(template['Parameters']['RetentionDays']['Default'], 7);
    expect(
      template['Parameters']['AuthMode']['AllowedValues'],
      containsAll(
        ['AWS_LAMBDA', 'AMAZON_COGNITO_USER_POOLS', 'OPENID_CONNECT'],
      ),
    );
    expect(
      resources['AuthorizerPermission']['Properties']['SourceAccount'],
      isNotNull,
    );
    final authorizerPolicy =
        resources['AuthorizerRole']['Properties']['Policies'] as List;
    expect(
      authorizerPolicy.single['PolicyDocument']['Statement'].single['Action'],
      'dynamodb:GetItem',
    );
    final outputs = template['Outputs'] as Map;
    expect(
      outputs.keys,
      containsAll([
        'HttpEndpoint',
        'RealtimeEndpoint',
        'ControlBaseUrl',
        'TableName',
        'Namespace',
      ]),
    );
    expect(
      outputs.keys
          .any((name) => name.toString().toLowerCase().contains('secret')),
      isFalse,
    );
  });
}
