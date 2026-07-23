import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/bloc/words_bloc.dart';
import '../domain/words_repository.dart';
import 'word_detail_sheet.dart';
import '../../notifications/domain/notifications_repository.dart';
import '../../notifications/presentation/notification_center_screen.dart';

class DashboardScreen extends StatefulWidget {
  final WordsRepository repository;
  final NotificationsRepository notificationsRepository;
  const DashboardScreen({
    super.key,
    required this.repository,
    required this.notificationsRepository,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _selectedPOS = 'All';
  bool _onlyBookmarks = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchWords();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      final state = context.read<WordsBloc>().state;
      if (state is WordsLoaded && !state.hasReachedMax) {
        context.read<WordsBloc>().add(FetchWordsRequested(
          query: _searchController.text,
          partOfSpeech: _selectedPOS,
          onlyBookmarks: _onlyBookmarks,
        ));
      }
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  void _fetchWords({bool refresh = false}) {
    context.read<WordsBloc>().add(FetchWordsRequested(
      query: _searchController.text,
      partOfSpeech: _selectedPOS,
      onlyBookmarks: _onlyBookmarks,
      refresh: refresh,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2036), // Deep Navy
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A2B), // Darker Navy
        elevation: 0,
        title: const Text(
          'explore words',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontFamily: 'Georgia',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFFD2FF26)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NotificationCenterScreen(repository: widget.notificationsRepository),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(
              _onlyBookmarks ? Icons.bookmark : Icons.bookmark_border,
              color: const Color(0xFFD2FF26), // Lime Green
            ),
            onPressed: () {
              setState(() {
                _onlyBookmarks = !_onlyBookmarks;
              });
              _fetchWords(refresh: true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Panel
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => _fetchWords(refresh: true),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search words...',
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF161A2B), // Dark Navy
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFD2FF26), width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A2B), // Dark Navy
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedPOS,
                    dropdownColor: const Color(0xFF161A2B),
                    underline: const SizedBox(),
                    style: const TextStyle(color: Colors.white),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    items: <String>['All', 'Noun', 'Verb', 'Adjective', 'Adverb']
                        .map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedPOS = newValue;
                        });
                        _fetchWords(refresh: true);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Words Grid / List View
          Expanded(
            child: BlocBuilder<WordsBloc, WordsState>(
              builder: (context, state) {
                if (state is WordsInitial || (state is WordsLoading && state.isFirstPage)) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFD2FF26)),
                  );
                }

                List<WordModel> words = [];
                bool hasReachedMax = false;

                if (state is WordsLoaded) {
                  words = state.words;
                  hasReachedMax = state.hasReachedMax;
                } else if (state is WordsFailure) {
                  return Center(
                    child: Text(
                      'Failed to load vocabulary: ${state.message}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (words.isEmpty) {
                  return const Center(
                    child: Text(
                      'No words found in your collection.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 100), // Space for floating bottom navigation
                  itemCount: hasReachedMax ? words.length : words.length + 1,
                  itemBuilder: (context, index) {
                    if (index >= words.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(color: Color(0xFFD2FF26)),
                        ),
                      );
                    }

                    final item = words[index];
                    final isBookmarked = state is WordsLoaded && state.bookmarkedWordIds.contains(item.id);

                    return Card(
                      color: const Color(0xFF252B4D), // Navy Slate Card
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.white.withOpacity(0.03)),
                      ),
                      child: ListTile(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (sheetContext) => BlocProvider.value(
                              value: context.read<WordsBloc>(),
                              child: WordDetailSheet(
                                repository: widget.repository,
                                word: item.word,
                                partOfSpeech: item.partOfSpeech,
                                definition: item.definition,
                                exampleSentence: item.exampleSentence,
                                meanings: item.meanings,
                                abbreviations: item.abbreviations,
                                synonyms: item.synonyms,
                                antonyms: item.antonyms,
                                hypernyms: item.hypernyms,
                                hyponyms: item.hyponyms,
                                meronyms: item.meronyms,
                                holonyms: item.holonyms,
                                relatedTerms: item.relatedTerms,
                                similarWords: item.similarWords,
                                homonyms: item.homonyms,
                                phonetic: item.phonetic,
                                isBookmarked: isBookmarked,
                                onBookmarkToggle: () {
                                  context.read<WordsBloc>().add(ToggleBookmarkRequested(item.id));
                                },
                              ),
                            ),
                          );
                        },
                        title: Text(
                          item.word[0].toUpperCase() + item.word.substring(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          item.definition,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                            color: const Color(0xFFD2FF26), // Lime Green bookmark
                          ),
                          onPressed: () {
                            context.read<WordsBloc>().add(ToggleBookmarkRequested(item.id));
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD2FF26),
        onPressed: () {
          final textController = TextEditingController();
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Add Word to Learn', style: TextStyle(color: Colors.white)),
              content: TextField(
                controller: textController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Enter word...',
                  hintStyle: TextStyle(color: Colors.grey),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFD2FF26)),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () async {
                    final word = textController.text.trim();
                    if (word.isNotEmpty) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Color(0xFFD2FF26), strokeWidth: 2),
                              ),
                              SizedBox(width: 16),
                              Text('AI is parsing and linking word...'),
                            ],
                          ),
                          duration: Duration(seconds: 4),
                        ),
                      );
                      try {
                        await widget.repository.addWord(word);
                        if (mounted) {
                          context.read<WordsBloc>().add(const FetchWordsRequested(refresh: true));
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('"$word" successfully linked to your galaxy!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Add', style: TextStyle(color: Color(0xFFD2FF26))),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }
}
