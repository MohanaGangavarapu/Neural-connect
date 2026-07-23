import 'package:flutter/material.dart';
import '../domain/words_repository.dart';

class WordDetailSheet extends StatefulWidget {
  final WordsRepository repository;
  final String word;
  final String partOfSpeech;
  final String definition;
  final String exampleSentence;
  final bool isBookmarked;
  final VoidCallback onBookmarkToggle;

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

  const WordDetailSheet({
    super.key,
    required this.repository,
    required this.word,
    required this.partOfSpeech,
    required this.definition,
    required this.isBookmarked,
    required this.onBookmarkToggle,
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

  @override
  State<WordDetailSheet> createState() => _WordDetailSheetState();
}

class _WordDetailSheetState extends State<WordDetailSheet> {
  late bool _isBookmarked;
  List<Map<String, dynamic>> _relationships = [];
  bool _loadingRelations = true;
  String? _relationsError;

  late String _currentExampleSentence;
  late TextEditingController _exampleController;
  bool _isSavingExample = false;

  @override
  void initState() {
    super.initState();
    _isBookmarked = widget.isBookmarked;
    _currentExampleSentence = widget.exampleSentence;
    _exampleController = TextEditingController(text: widget.exampleSentence);
    _loadRelationships();
  }

  @override
  void dispose() {
    _exampleController.dispose();
    super.dispose();
  }

  Future<void> _saveExampleSentence() async {
    final text = _exampleController.text.trim();
    setState(() {
      _isSavingExample = true;
    });
    try {
      await widget.repository.updateExampleSentence(widget.word, text);
      if (mounted) {
        setState(() {
          _currentExampleSentence = text;
          _isSavingExample = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Example sentence updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingExample = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _loadRelationships() async {
    if (!mounted) return;
    setState(() {
      _loadingRelations = true;
      _relationsError = null;
    });
    try {
      final relations = await widget.repository.fetchWordRelationships(widget.word);
      if (mounted) {
        setState(() {
          _relationships = relations;
          _loadingRelations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _relationsError = e.toString();
          _loadingRelations = false;
        });
      }
    }
  }

  void _showAddRelationshipDialog() {
    final word2Controller = TextEditingController();
    String selectedType = 'ROOT_OF';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: const Color(0xFF1B2036),
          title: const Text(
            'Add Connection Link',
            style: TextStyle(color: Colors.white, fontFamily: 'Georgia', fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: word2Controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Target Word',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFD2FF26))),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                dropdownColor: const Color(0xFF1B2036),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Relation Type',
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                items: ['ROOT_OF', 'USED_WITH', 'SYNONYM_OF', 'ANTONYM_OF']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setStateDialog(() {
                      selectedType = val;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD2FF26),
                foregroundColor: const Color(0xFF1B2036),
              ),
              onPressed: () async {
                final target = word2Controller.text.trim();
                if (target.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Adding relationship link...')),
                  );
                  try {
                    await widget.repository.addCustomRelationship(widget.word, target, selectedType);
                    _loadRelationships();
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Relationship added successfully!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to add: $e')),
                    );
                  }
                }
              },
              child: const Text('Link'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteRelationship(String target, String type) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Deleting relationship link...')),
    );
    try {
      await widget.repository.deleteCustomRelationship(widget.word, target, type);
      _loadRelationships();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relationship deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white, // White Sheet for high contrast
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.word[0].toUpperCase() + widget.word.substring(1),
                        style: const TextStyle(
                          color: Color(0xFF1B2036), // Deep Navy
                          fontSize: 32,
                          fontFamily: 'Georgia',
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E6BFF).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF2E6BFF).withOpacity(0.2)),
                            ),
                            child: Text(
                              widget.partOfSpeech.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF2E6BFF), // Electric Blue
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (widget.phonetic.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              widget.phonetic,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: const Color(0xFF2E6BFF), // Electric Blue
                  size: 32,
                ),
                onPressed: () {
                  setState(() {
                    _isBookmarked = !_isBookmarked;
                  });
                  widget.onBookmarkToggle();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'DEFINITION',
            style: TextStyle(
              color: Colors.black38,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.definition,
            style: const TextStyle(
              color: Color(0xFF1B2036),
              fontSize: 16,
              height: 1.5,
            ),
          ),
          if (widget.meanings.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'MEANINGS',
              style: TextStyle(
                color: Colors.black38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            ...widget.meanings.map((meaning) => Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Color(0xFF2E6BFF), fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(
                      meaning,
                      style: const TextStyle(color: Color(0xFF1B2036), fontSize: 15, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
          ],
          if (widget.abbreviations.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'ABBREVIATIONS',
              style: TextStyle(
                color: Colors.black38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.abbreviations.map((abbr) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD2FF26).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD2FF26).withOpacity(0.3)),
                ),
                child: Text(
                  abbr,
                  style: const TextStyle(color: Color(0xFF1B2036), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              )).toList(),
            ),
          ],
          if (widget.synonyms.isNotEmpty ||
              widget.antonyms.isNotEmpty ||
              widget.hypernyms.isNotEmpty ||
              widget.hyponyms.isNotEmpty ||
              widget.meronyms.isNotEmpty ||
              widget.holonyms.isNotEmpty ||
              widget.relatedTerms.isNotEmpty ||
              widget.similarWords.isNotEmpty ||
              widget.homonyms.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'LEXICAL RELATIONSHIPS',
              style: TextStyle(
                color: Colors.black38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            if (widget.synonyms.isNotEmpty) ...[
              const Text('Synonyms', style: TextStyle(color: Color(0xFF1B2036), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.synonyms.map((s) => Chip(
                  label: Text(s, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: const Color(0xFF2E6BFF),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.antonyms.isNotEmpty) ...[
              const Text('Antonyms', style: TextStyle(color: Color(0xFF1B2036), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.antonyms.map((a) => Chip(
                  label: Text(a, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.hypernyms.isNotEmpty) ...[
              const Text('Hypernyms (General Terms)', style: TextStyle(color: Color(0xFF1B2036), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.hypernyms.map((h) => Chip(
                  label: Text(h, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: Colors.blueGrey,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.hyponyms.isNotEmpty) ...[
              const Text('Hyponyms (Specific Terms)', style: TextStyle(color: Color(0xFF1B2036), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.hyponyms.map((h) => Chip(
                  label: Text(h, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.meronyms.isNotEmpty) ...[
              const Text('Meronyms (Part Terms)', style: TextStyle(color: Color(0xFF1B2036), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.meronyms.map((m) => Chip(
                  label: Text(m, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: Colors.deepOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.holonyms.isNotEmpty) ...[
              const Text('Holonyms (Whole Terms)', style: TextStyle(color: Color(0xFF1B2036), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.holonyms.map((h) => Chip(
                  label: Text(h, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: Colors.brown,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.relatedTerms.isNotEmpty) ...[
              const Text('Related Terms', style: TextStyle(color: Color(0xFF1B2036), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.relatedTerms.map((rt) => Chip(
                  label: Text(rt, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: Colors.teal,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.similarWords.isNotEmpty) ...[
              const Text('Similar Words', style: TextStyle(color: Color(0xFF1B2036), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.similarWords.map((sw) => Chip(
                  label: Text(sw, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: const Color(0xFF006064), // Cyan [800]
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.homonyms.isNotEmpty) ...[
              const Text('Homonyms (Sounds Like)', style: TextStyle(color: Color(0xFF1B2036), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.homonyms.map((h) => Chip(
                  label: Text(h, style: const TextStyle(color: Colors.white, fontSize: 11)),
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ],
          if (_currentExampleSentence.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'THREAD · 1 SENTENCE',
              style: TextStyle(
                color: Colors.black38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            
            // Custom blue card matching the UI design
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2E6BFF), // Electric Blue Card
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFD2FF26), // Lime Green
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'AC',
                          style: TextStyle(color: Color(0xFF1B2036), fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'alex',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD2FF26), // Lime Green Badge
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'SEED',
                          style: TextStyle(color: Color(0xFF1B2036), fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        '2h',
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '"$_currentExampleSentence"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // Custom Riff Notes Section Card (Lime Green Card)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFD2FF26), // Lime Green Card
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'your turn, learner',
                      style: TextStyle(color: Color(0xFF1B2036), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      '${_exampleController.text.length} / 280',
                      style: const TextStyle(color: Color(0xFF1B2036), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1B2036).withOpacity(0.12)),
                  ),
                  child: TextField(
                    controller: _exampleController,
                    maxLines: 3,
                    maxLength: 280,
                    style: const TextStyle(color: Color(0xFF1B2036), fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: const InputDecoration(
                      hintText: 'riff in a sentence — make this word yours',
                      hintStyle: TextStyle(color: Colors.black45, fontSize: 13, fontStyle: FontStyle.italic),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                    onChanged: (val) {
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _isSavingExample ? null : _saveExampleSentence,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B2036), // Deep Navy
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: _isSavingExample
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Add as Example', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          
          // Custom Relationships Section
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CONNECTIONS / RELATIONS',
                style: TextStyle(
                  color: Colors.black38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              TextButton.icon(
                onPressed: _showAddRelationshipDialog,
                icon: const Icon(Icons.add, size: 14, color: Color(0xFF2E6BFF)),
                label: const Text('Add Link', style: TextStyle(color: Color(0xFF2E6BFF), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loadingRelations)
            const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E6BFF))))
          else if (_relationsError != null)
            Text('Failed to load relations: $_relationsError', style: const TextStyle(color: Colors.red, fontSize: 12))
          else if (_relationships.isEmpty)
            const Text('No connections mapped yet.', style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _relationships.map((rel) {
                final target = rel['targetWord'] ?? '';
                final type = rel['type'] ?? 'SYNONYM_OF';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2036).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1B2036).withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${target[0].toUpperCase() + target.substring(1)} ',
                        style: const TextStyle(color: Color(0xFF1B2036), fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        '($type)',
                        style: const TextStyle(color: Colors.black38, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => _deleteRelationship(target, type),
                        child: const Icon(Icons.close, size: 14, color: Colors.red),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 24),
        ],
      ),
     ),
    );
  }
}
