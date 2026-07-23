import 'package:dio/dio.dart';
import 'dio_error_extension.dart';

class WordModel {
  final String id;
  final String word;
  final String partOfSpeech;
  final String definition;
  final String exampleSentence;
  final List<String> meanings;
  final List<String> abbreviations;
  final List<String> synonyms;
  final List<String> antonyms;
  final List<String> hypernyms;
  final List<String> hyponyms;
  final List<String> meronyms;
  final List<String> holonyms;
  final List<String> relatedTerms;
  final List<String> similarWords;
  final List<String> homonyms;
  final String phonetic;

  WordModel({
    required this.id,
    required this.word,
    required this.partOfSpeech,
    required this.definition,
    required this.exampleSentence,
    this.meanings = const [],
    this.abbreviations = const [],
    this.synonyms = const [],
    this.antonyms = const [],
    this.hypernyms = const [],
    this.hyponyms = const [],
    this.meronyms = const [],
    this.holonyms = const [],
    this.relatedTerms = const [],
    this.similarWords = const [],
    this.homonyms = const [],
    this.phonetic = '',
  });

  factory WordModel.fromJson(Map<String, dynamic> json) {
    return WordModel(
      id: json['id'] ?? '',
      word: json['word'] ?? '',
      partOfSpeech: json['partOfSpeech'] ?? '',
      definition: json['definition'] ?? '',
      exampleSentence: json['exampleSentence'] ?? '',
      meanings: List<String>.from(json['meanings'] ?? []),
      abbreviations: List<String>.from(json['abbreviations'] ?? []),
      synonyms: List<String>.from(json['synonyms'] ?? []),
      antonyms: List<String>.from(json['antonyms'] ?? []),
      hypernyms: List<String>.from(json['hypernyms'] ?? []),
      hyponyms: List<String>.from(json['hyponyms'] ?? []),
      meronyms: List<String>.from(json['meronyms'] ?? []),
      holonyms: List<String>.from(json['holonyms'] ?? []),
      relatedTerms: List<String>.from(json['relatedTerms'] ?? []),
      similarWords: List<String>.from(json['similarWords'] ?? []),
      homonyms: List<String>.from(json['homonyms'] ?? []),
      phonetic: json['phonetic'] ?? '',
    );
  }
}

class WordsRepository {
  final Dio _dio;

  WordsRepository({required Dio dio}) : _dio = dio;

  Future<Map<String, dynamic>> searchWords({
    String? query,
    int page = 1,
    int limit = 10,
    String? partOfSpeech,
    bool onlyBookmarks = false,
  }) async {
    try {
      final response = await _dio.get('/api/v1/words/search', queryParameters: {
        if (query != null && query.isNotEmpty) 'query': query,
        'page': page,
        'limit': limit,
        if (partOfSpeech != null && partOfSpeech != 'All') 'partOfSpeech': partOfSpeech,
        'onlyBookmarks': onlyBookmarks.toString(),
      });

      if (response.statusCode == 200) {
        final data = response.data['data'];
        final List wordsJson = data['words'] ?? [];
        final List<WordModel> words = wordsJson.map((w) => WordModel.fromJson(w)).toList();
        final List bookmarkIdsJson = data['bookmarkedWordIds'] ?? [];
        final List<String> bookmarkedWordIds = bookmarkIdsJson.map((id) => id.toString()).toList();
        return {
          'words': words,
          'total': data['total'] ?? 0,
          'bookmarkedWordIds': bookmarkedWordIds,
        };
      }
      throw Exception('Failed to load words');
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<bool> toggleBookmark(String wordId) async {
    try {
      final response = await _dio.post('/api/v1/words/$wordId/bookmark');
      if (response.statusCode == 200) {
        return response.data['data']['isBookmarked'] ?? false;
      }
      throw Exception('Failed to toggle bookmark');
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<Map<String, dynamic>> addWord(String word) async {
    try {
      final response = await _dio.post('/api/v1/words', data: {
        'word': word,
      });
      if (response.statusCode == 201) {
        return response.data['data'] ?? {};
      }
      throw Exception('Failed to add word');
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<List<Map<String, dynamic>>> fetchWordRelationships(String word) async {
    try {
      final response = await _dio.get('/api/v1/words/${Uri.encodeComponent(word)}/relationships');
      if (response.statusCode == 200) {
        final List data = response.data['data'] ?? [];
        return data.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      throw Exception('Failed to load word relationships');
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<void> addCustomRelationship(String word1, String word2, String type) async {
    try {
      await _dio.post('/api/v1/words/relationships', data: {
        'word1': word1,
        'word2': word2,
        'type': type,
      });
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<void> deleteCustomRelationship(String word1, String word2, String type) async {
    try {
      await _dio.delete('/api/v1/words/relationships', data: {
        'word1': word1,
        'word2': word2,
        'type': type,
      });
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<WordModel> fetchWordDetail(String word) async {
    try {
      final response = await _dio.get('/api/v1/words/detail/${Uri.encodeComponent(word.trim().toLowerCase())}');
      if (response.statusCode == 200) {
        return WordModel.fromJson(response.data['data']);
      }
      throw Exception('Failed to load word detail');
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<void> updateExampleSentence(String word, String newSentence) async {
    try {
      await _dio.put('/api/v1/words/${Uri.encodeComponent(word.trim().toLowerCase())}/example', data: {
        'exampleSentence': newSentence,
      });
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }
}
