abstract final class ApiEndpoints {
  static Uri exampleResource(String id) {
    return Uri(pathSegments: <String>['', 'example-resources', id]);
  }
}
