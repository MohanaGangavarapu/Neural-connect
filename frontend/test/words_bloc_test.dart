import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/words/domain/bloc/words_bloc.dart';
import 'package:frontend/features/words/domain/words_repository.dart';
import 'package:dio/dio.dart';

// Inline mock repository for clean unit test assertion
class MockWordsRepository extends WordsRepository {
  MockWordsRepository() : super(dio: Dio());

  @override
  Future<Map<String, dynamic>> searchWords({
    String? query,
    int page = 1,
    int limit = 10,
    String? partOfSpeech,
    bool onlyBookmarks = false,
  }) async {
    return {
      'words': [
        WordModel(
          id: '1',
          word: 'resilient',
          partOfSpeech: 'adjective',
          definition: 'Able to recover quickly.',
          exampleSentence: 'A resilient community.',
        )
      ],
      'total': 1,
    };
  }

  @override
  Future<bool> toggleBookmark(String wordId) async {
    return true;
  }
}

void main() {
  group('WordsBloc Unit Tests', () {
    late MockWordsRepository mockRepo;
    late WordsBloc wordsBloc;

    setUp(() {
      mockRepo = MockWordsRepository();
      wordsBloc = WordsBloc(repository: mockRepo);
    });

    tearDown(() {
      wordsBloc.close();
    });

    test('initial state should be WordsInitial', () {
      expect(wordsBloc.state, WordsInitial());
    });

    test('should emit WordsLoading and WordsLoaded when fetching succeeds', () async {
      final expectedStates = [
        const WordsLoading(isFirstPage: true),
        isA<WordsLoaded>(),
      ];

      expectLater(wordsBloc.stream, emitsInOrder(expectedStates));
      wordsBloc.add(const FetchWordsRequested(refresh: true));
    });
  });
}
