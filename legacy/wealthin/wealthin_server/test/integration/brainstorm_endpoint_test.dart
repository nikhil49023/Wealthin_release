import 'package:test/test.dart';
import 'package:serverpod_test/serverpod_test.dart';
import 'package:wealthin_server/src/endpoints/brainstorm_endpoint.dart';
import 'package:wealthin_server/src/generated/protocol.dart';

void main() {
  withServerpod('Session', (sessionBuilder, endpoints) {
    var session = sessionBuilder.build();
    var point = BrainstormEndpoint();
    point.initialize(endpoints.brainstorm, session.server);

    test('analyzeIdea returns valid BusinessIdea', () async {
      var result = await point.analyzeIdea(session, 'Test Idea');
      expect(result, isA<BusinessIdea>());
      expect(result.title, equals('Test Idea'));
      expect(result.score, greaterThan(0));
      expect(result.strengths, isNotEmpty);
    });
  },
      // Note: This setup assumes integration test environment. 
      // Adjust according to actual serverpod test setup if different.
      // Since we don't have the full test environment info, this is a placeholder structure.
  );
}
