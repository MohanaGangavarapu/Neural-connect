import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/graph/presentation/graph_canvas_screen.dart';
import 'package:frontend/features/graph/domain/graph_repository.dart';
import 'package:frontend/features/words/domain/words_repository.dart';
import 'package:frontend/features/notifications/domain/notifications_repository.dart';
import 'package:dio/dio.dart';

class MockGraphRepository extends GraphRepository {
  MockGraphRepository() : super(dio: Dio());

  @override
  Future<Map<String, dynamic>> fetchGraphCanvas() async {
    return {
      'nodes': [
        GraphNode(id: 'resilient', label: 'Word', ownedByMe: true),
        GraphNode(id: 'strong', label: 'Word', ownedByMe: false),
      ],
      'edges': [
        GraphEdge(id: '1', source: 'resilient', target: 'strong', type: 'SYNONYM_OF'),
      ],
    };
  }
}

void main() {
  testWidgets('GraphCanvasScreen displays CustomPaint canvas elements', (WidgetTester tester) async {
    final mockRepo = MockGraphRepository();
    final mockWordsRepo = WordsRepository(dio: Dio());
    final mockNotificationsRepo = NotificationsRepository(dio: Dio());

    await tester.pumpWidget(
      MaterialApp(
        home: GraphCanvasScreen(
          repository: mockRepo,
          wordsRepository: mockWordsRepo,
          notificationsRepository: mockNotificationsRepo,
        ),
      ),
    );

    // Allow UI asynchronous initialization layout pipelines to complete
    await tester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    expect(find.text('your galaxy'), findsOneWidget);
  });
}
