import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../words_repository.dart';

// Events
abstract class WordsEvent extends Equatable {
  const WordsEvent();
  @override
  List<Object?> get props => [];
}

class FetchWordsRequested extends WordsEvent {
  final String? query;
  final String? partOfSpeech;
  final bool onlyBookmarks;
  final bool refresh;

  const FetchWordsRequested({
    this.query,
    this.partOfSpeech,
    this.onlyBookmarks = false,
    this.refresh = false,
  });

  @override
  List<Object?> get props => [query, partOfSpeech, onlyBookmarks, refresh];
}

class ToggleBookmarkRequested extends WordsEvent {
  final String wordId;
  const ToggleBookmarkRequested(this.wordId);

  @override
  List<Object> get props => [wordId];
}

class AddWordRequested extends WordsEvent {
  final String word;
  const AddWordRequested(this.word);

  @override
  List<Object> get props => [word];
}

// States
abstract class WordsState extends Equatable {
  const WordsState();
  @override
  List<Object?> get props => [];
}

class WordsInitial extends WordsState {}

class WordsLoading extends WordsState {
  final bool isFirstPage;
  const WordsLoading({required this.isFirstPage});

  @override
  List<Object> get props => [isFirstPage];
}

class WordsLoaded extends WordsState {
  final List<WordModel> words;
  final bool hasReachedMax;
  final int totalCount;
  final Set<String> bookmarkedWordIds;
  final String? query;
  final String? partOfSpeech;
  final bool onlyBookmarks;
  final int nextPage;

  const WordsLoaded({
    required this.words,
    required this.hasReachedMax,
    required this.totalCount,
    required this.bookmarkedWordIds,
    this.query,
    this.partOfSpeech,
    this.onlyBookmarks = false,
    required this.nextPage,
  });

  WordsLoaded copyWith({
    List<WordModel>? words,
    bool? hasReachedMax,
    int? totalCount,
    Set<String>? bookmarkedWordIds,
    String? query,
    String? partOfSpeech,
    bool? onlyBookmarks,
    int? nextPage,
  }) {
    return WordsLoaded(
      words: words ?? this.words,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      totalCount: totalCount ?? this.totalCount,
      bookmarkedWordIds: bookmarkedWordIds ?? this.bookmarkedWordIds,
      query: query ?? this.query,
      partOfSpeech: partOfSpeech ?? this.partOfSpeech,
      onlyBookmarks: onlyBookmarks ?? this.onlyBookmarks,
      nextPage: nextPage ?? this.nextPage,
    );
  }

  @override
  List<Object?> get props => [words, hasReachedMax, totalCount, bookmarkedWordIds, query, partOfSpeech, onlyBookmarks, nextPage];
}

class WordsFailure extends WordsState {
  final String message;
  const WordsFailure(this.message);

  @override
  List<Object> get props => [message];
}

// BLoC
class WordsBloc extends Bloc<WordsEvent, WordsState> {
  final WordsRepository _repository;

  WordsBloc({required WordsRepository repository})
      : _repository = repository,
        super(WordsInitial()) {
    on<FetchWordsRequested>(_onFetchWords);
    on<ToggleBookmarkRequested>(_onToggleBookmark);
    on<AddWordRequested>(_onAddWord);
  }

  Future<void> _onFetchWords(FetchWordsRequested event, Emitter<WordsState> emit) async {
    final currentState = state;
    
    // Check if we need to load from page 1
    final isRefresh = event.refresh || currentState is! WordsLoaded;
    final int pageToLoad = isRefresh ? 1 : (currentState as WordsLoaded).nextPage;

    if (!isRefresh && (currentState as WordsLoaded).hasReachedMax) return;

    emit(WordsLoading(isFirstPage: pageToLoad == 1));

    try {
      final result = await _repository.searchWords(
        query: event.query,
        page: pageToLoad,
        limit: 10,
        partOfSpeech: event.partOfSpeech,
        onlyBookmarks: event.onlyBookmarks,
      );

      final List<WordModel> newWords = result['words'];
      final int total = result['total'];
      final List<String> backendBookmarks = result['bookmarkedWordIds'] ?? [];

      List<WordModel> words;
      Set<String> bookmarks;

      if (isRefresh) {
        words = newWords;
        bookmarks = Set.from(backendBookmarks);
      } else {
        final loadedState = currentState as WordsLoaded;
        words = List.of(loadedState.words)..addAll(newWords);
        bookmarks = Set.from(loadedState.bookmarkedWordIds)..addAll(backendBookmarks);
      }

      final hasReachedMax = words.length >= total || newWords.isEmpty;

      emit(WordsLoaded(
        words: words,
        hasReachedMax: hasReachedMax,
        totalCount: total,
        bookmarkedWordIds: bookmarks,
        query: event.query,
        partOfSpeech: event.partOfSpeech,
        onlyBookmarks: event.onlyBookmarks,
        nextPage: pageToLoad + 1,
      ));
    } catch (e) {
      emit(WordsFailure(e.toString()));
    }
  }

  Future<void> _onToggleBookmark(ToggleBookmarkRequested event, Emitter<WordsState> emit) async {
    final currentState = state;
    if (currentState is WordsLoaded) {
      try {
        final isBookmarked = await _repository.toggleBookmark(event.wordId);
        final newBookmarks = Set<String>.from(currentState.bookmarkedWordIds);
        
        if (isBookmarked) {
          newBookmarks.add(event.wordId);
        } else {
          newBookmarks.remove(event.wordId);
        }

        emit(currentState.copyWith(bookmarkedWordIds: newBookmarks));
      } catch (e) {
        emit(WordsFailure(e.toString()));
      }
    }
  }

  Future<void> _onAddWord(AddWordRequested event, Emitter<WordsState> emit) async {
    try {
      await _repository.addWord(event.word);
      add(const FetchWordsRequested(refresh: true));
    } catch (e) {
      emit(WordsFailure(e.toString()));
    }
  }
}
