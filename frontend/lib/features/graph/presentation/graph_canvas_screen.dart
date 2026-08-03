import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/graph_repository.dart';
import '../../words/domain/bloc/words_bloc.dart';
import '../../words/domain/words_repository.dart';
import '../../words/presentation/word_detail_sheet.dart';
import '../../notifications/domain/notifications_repository.dart';
import '../../notifications/presentation/notification_center_screen.dart';

class GraphCanvasScreen extends StatefulWidget {
  final GraphRepository repository;
  final WordsRepository wordsRepository;
  final NotificationsRepository notificationsRepository;

  const GraphCanvasScreen({
    super.key,
    required this.repository,
    required this.wordsRepository,
    required this.notificationsRepository,
  });

  @override
  State<GraphCanvasScreen> createState() => _GraphCanvasScreenState();
}

class _GraphCanvasScreenState extends State<GraphCanvasScreen> {
  List<GraphNode> _nodes = [];
  List<GraphEdge> _edges = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Pan and Zoom Transformation states
  Offset _panOffset = Offset.zero;
  double _scale = 1.0;

  // Tracking details for dragged node
  GraphNode? _draggedNode;

  // Selected node for highlighting immediate relations and fading the rest
  String? _selectedNodeId;

  @override
  void initState() {
    super.initState();
    _loadGraphData();
  }

  Future<void> _loadGraphData() async {
    try {
      final data = await widget.repository.fetchGraphCanvas();
      final List<GraphNode> nodes = data['nodes'];
      final List<GraphEdge> edges = data['edges'];

      // Lay out nodes spatially to group them and distribute radially
      _runForceDirectedLayout(nodes, edges);

      setState(() {
        _nodes = nodes;
        _edges = edges;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // Fruchterman-Reingold Force-Directed Layout Algorithm
  void _runForceDirectedLayout(List<GraphNode> nodes, List<GraphEdge> edges) {
    if (nodes.isEmpty) return;

    final random = Random(42);
    final size = MediaQuery.of(context).size;
    final double centerX = size.width / 2;
    // Account for top app bar (~60px) and bottom legend overlay/nav bar (~180px)
    final double centerY = (size.height - 240.0) / 2;

    final int numNodes = nodes.length;

    // Start with a small central cluster so repulsion expands them organically
    for (var node in nodes) {
      node.x = centerX + (random.nextDouble() - 0.5) * 80;
      node.y = centerY + (random.nextDouble() - 0.5) * 80;
    }

    // Keep rest length k compact so nodes fit neatly within viewable area
    final double availableDimension = min(size.width, max(200.0, size.height - 240.0));
    final double k = (availableDimension / (sqrt(numNodes) + 1.2)).clamp(50.0, 100.0);
    double temp = k * 1.5;

    // 100 simulation iterations to group clusters spatially and minimize overlaps
    const int iterations = 100;
    for (int iter = 0; iter < iterations; iter++) {
      final List<double> dispX = List.filled(numNodes, 0.0);
      final List<double> dispY = List.filled(numNodes, 0.0);

      // A. Calculate repulsive forces between all pairs of nodes
      for (int i = 0; i < numNodes; i++) {
        final nodeU = nodes[i];
        for (int j = 0; j < numNodes; j++) {
          if (i == j) continue;
          final nodeV = nodes[j];

          double dx = nodeU.x - nodeV.x;
          double dy = nodeU.y - nodeV.y;
          double dist = sqrt(dx * dx + dy * dy);
          if (dist < 1.0) {
            dx = random.nextDouble() - 0.5;
            dy = random.nextDouble() - 0.5;
            dist = sqrt(dx * dx + dy * dy);
          }

          final double fr = (k * k) / dist;
          dispX[i] += (dx / dist) * fr;
          dispY[i] += (dy / dist) * fr;
        }
      }

      // B. Calculate attractive forces along mapped edges
      for (final edge in edges) {
        final int idxSource = nodes.indexWhere((n) => n.id == edge.source);
        final int idxTarget = nodes.indexWhere((n) => n.id == edge.target);

        if (idxSource == -1 || idxTarget == -1) continue;

        final nodeU = nodes[idxSource];
        final nodeV = nodes[idxTarget];

        double dx = nodeU.x - nodeV.x;
        double dy = nodeU.y - nodeV.y;
        double dist = sqrt(dx * dx + dy * dy);
        if (dist < 1.0) continue;

        final double fa = (dist * dist) / k;
        final double forceX = (dx / dist) * fa;
        final double forceY = (dy / dist) * fa;

        dispX[idxSource] -= forceX;
        dispY[idxSource] -= forceY;
        dispX[idxTarget] += forceX;
        dispY[idxTarget] += forceY;
      }

      // C. Apply displacement limited by temperature cooling
      for (int i = 0; i < numNodes; i++) {
        final node = nodes[i];
        final double dX = dispX[i];
        final double dY = dispY[i];
        final double dist = sqrt(dX * dX + dY * dY);
        if (dist < 1.0) continue;

        final double limitedDist = min(dist, temp);
        node.x += (dX / dist) * limitedDist;
        node.y += (dY / dist) * limitedDist;
      }

      temp = temp * 0.95;
    }

    // Translate computed layout box coordinates so that it centers on the viewport
    double minX = double.infinity;
    double maxX = -double.infinity;
    double minY = double.infinity;
    double maxY = -double.infinity;

    for (var node in nodes) {
      if (node.x < minX) minX = node.x;
      if (node.x > maxX) maxX = node.x;
      if (node.y < minY) minY = node.y;
      if (node.y > maxY) maxY = node.y;
    }

    final double graphWidth = maxX - minX;
    final double graphHeight = maxY - minY;
    final double graphCenterX = minX + (graphWidth > 0 ? graphWidth / 2 : 0);
    final double graphCenterY = minY + (graphHeight > 0 ? graphHeight / 2 : 0);

    for (var node in nodes) {
      node.x = node.x - graphCenterX + centerX;
      node.y = node.y - graphCenterY + centerY;
    }

    // Guarantee all nodes fit within visible viewport bounds above overlays
    final double maxAllowedWidth = max(100.0, size.width - 120.0);
    final double maxAllowedHeight = max(100.0, size.height - 280.0);

    double scaleFactor = 1.0;
    if (graphWidth > maxAllowedWidth && graphWidth > 0) {
      scaleFactor = min(scaleFactor, maxAllowedWidth / graphWidth);
    }
    if (graphHeight > maxAllowedHeight && graphHeight > 0) {
      scaleFactor = min(scaleFactor, maxAllowedHeight / graphHeight);
    }

    if (scaleFactor < 1.0) {
      for (var node in nodes) {
        node.x = centerX + (node.x - centerX) * scaleFactor;
        node.y = centerY + (node.y - centerY) * scaleFactor;
      }
    }
  }

  GraphNode? _hitTestNode(Offset localPosition) {
    // Transform coordinates back from pan and zoom space to check actual node clicks
    final transformedX = (localPosition.dx - _panOffset.dx) / _scale;
    final transformedY = (localPosition.dy - _panOffset.dy) / _scale;

    for (final node in _nodes) {
      final double distance = sqrt(pow(node.x - transformedX, 2) + pow(node.y - transformedY, 2));
      if (distance <= 36.0) {
        return node;
      }
    }
    return null;
  }

  void _showAddWordSheet(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'what word caught you today?',
                style: TextStyle(
                  color: Color(0xFF1B2036),
                  fontSize: 22,
                  fontFamily: 'Georgia',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: const TextStyle(color: Color(0xFF1B2036), fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Enter word...',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: const Color(0xFFF0F2F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('cancel', style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD2FF26),
                      foregroundColor: const Color(0xFF1B2036),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () async {
                      final word = controller.text.trim();
                      if (word.isNotEmpty) {
                        Navigator.pop(sheetContext);
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
                          await widget.repository.dio.post('/api/v1/words', data: {'word': word});
                          _loadGraphData();
                          if (mounted) {
                            context.read<WordsBloc>().add(const FetchWordsRequested(refresh: true));
                          }
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('"$word" successfully linked to your galaxy!')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('ask ai ✳', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashedLineLegend(Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 3, height: 2, color: color),
        const SizedBox(width: 1),
        Container(width: 3, height: 2, color: color),
        const SizedBox(width: 1),
        Container(width: 3, height: 2, color: color),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1B2036),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFD2FF26))),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF1B2036),
        body: Center(
          child: Text(
            'Error loading canvas: $_errorMessage',
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1B2036),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'your galaxy',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Georgia'),
            ),
            Text(
              '${_nodes.length} NODES · ${_edges.length} LINKS',
              style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in, color: Color(0xFFD2FF26)),
            tooltip: 'Zoom In',
            onPressed: () {
              setState(() {
                _scale = (_scale * 1.25).clamp(0.2, 5.0);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out, color: Color(0xFFD2FF26)),
            tooltip: 'Zoom Out',
            onPressed: () {
              setState(() {
                _scale = (_scale / 1.25).clamp(0.2, 5.0);
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_center_focus, color: Color(0xFFD2FF26)),
            tooltip: 'Reset View',
            onPressed: () {
              setState(() {
                _panOffset = Offset.zero;
                _scale = 1.0;
              });
            },
          ),
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
            icon: const Icon(Icons.refresh, color: Color(0xFFD2FF26)),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _selectedNodeId = null;
                _panOffset = Offset.zero;
                _scale = 1.0;
              });
              _loadGraphData();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                setState(() {
                  final zoomFactor = pointerSignal.scrollDelta.dy > 0 ? 0.9 : 1.1;
                  _scale = (_scale * zoomFactor).clamp(0.2, 5.0);
                });
              }
            },
            child: GestureDetector(
              onScaleStart: (details) {
                final hitNode = _hitTestNode(details.localFocalPoint);
                if (hitNode != null) {
                  _draggedNode = hitNode;
                }
              },
              onScaleUpdate: (details) {
                setState(() {
                  if (_draggedNode != null) {
                    // Drag node around coordinate system
                    final transformedX = (details.localFocalPoint.dx - _panOffset.dx) / _scale;
                    final transformedY = (details.localFocalPoint.dy - _panOffset.dy) / _scale;
                    _draggedNode!.x = transformedX;
                    _draggedNode!.y = transformedY;
                  } else {
                    // Pan and Zoom view transformation
                    _panOffset = _panOffset + details.focalPointDelta;
                    _scale = (_scale * details.scale).clamp(0.2, 5.0);
                  }
                });
              },
              onScaleEnd: (details) {
                _draggedNode = null;
              },
            onTapUp: (details) async {
              final hitNode = _hitTestNode(details.localPosition);
              setState(() {
                _selectedNodeId = hitNode?.id;
              });

              if (hitNode != null) {
                // Fetch full word details from global details API
                try {
                  final response = await widget.repository.dio.get('/api/v1/words/detail/${Uri.encodeComponent(hitNode.id.toLowerCase())}');
                  final item = response.data['data'];
                  
                  if (mounted && item != null) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (sheetContext) => BlocProvider.value(
                        value: context.read<WordsBloc>(),
                        child: WordDetailSheet(
                          repository: widget.wordsRepository,
                          word: item['word'] ?? hitNode.id,
                          partOfSpeech: item['partOfSpeech'] ?? 'noun',
                          definition: item['definition'] ?? 'No definition loaded.',
                          exampleSentence: item['exampleSentence'] ?? '',
                          meanings: List<String>.from(item['meanings'] ?? []),
                          abbreviations: List<String>.from(item['abbreviations'] ?? []),
                          synonyms: List<String>.from(item['synonyms'] ?? []),
                          antonyms: List<String>.from(item['antonyms'] ?? []),
                          hypernyms: List<String>.from(item['hypernyms'] ?? []),
                          hyponyms: List<String>.from(item['hyponyms'] ?? []),
                          meronyms: List<String>.from(item['meronyms'] ?? []),
                          holonyms: List<String>.from(item['holonyms'] ?? []),
                          relatedTerms: List<String>.from(item['relatedTerms'] ?? []),
                          similarWords: List<String>.from(item['similarWords'] ?? []),
                          homonyms: List<String>.from(item['homonyms'] ?? []),
                          phonetic: item['phonetic'] ?? '',
                          isBookmarked: false,
                          onBookmarkToggle: () {
                            context.read<WordsBloc>().add(ToggleBookmarkRequested(item['id'] ?? ''));
                          },
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  // Fallback simple view
                  if (mounted) {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (sheetContext) => Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hitNode.id[0].toUpperCase() + hitNode.id.substring(1),
                              style: const TextStyle(color: Color(0xFF1B2036), fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Georgia'),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              hitNode.ownedByMe ? 'Owned by you' : 'Shared by connection',
                              style: TextStyle(color: hitNode.ownedByMe ? const Color(0xFF008080) : const Color(0xFF8A2BE2), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    );
                  }
                }
              }
            },
            child: ClipRect(
              child: CustomPaint(
                size: Size.infinite,
                painter: GraphPainter(
                  nodes: _nodes,
                  edges: _edges,
                  panOffset: _panOffset,
                  scale: _scale,
                  selectedNodeId: _selectedNodeId,
                ),
              ),
            ),
          ),
        ),

          // Overlay Bottom Panel (Legend and Add Word)
          Positioned(
            left: 16,
            right: 16,
            bottom: 104,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161A2B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'LEGEND',
                          style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Column 1: Nodes
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFD2FF26), shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    const Text('you', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF2E6BFF), shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    const Text('friend', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            // Column 2: Solid Edges
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Container(width: 12, height: 2, color: const Color(0xFF2E6BFF)),
                                    const SizedBox(width: 6),
                                    const Text('Synonym', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(width: 12, height: 2, color: Colors.redAccent),
                                    const SizedBox(width: 6),
                                    const Text('Antonym', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            // Column 3: Dashed / Other Edges
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    _buildDashedLineLegend(Colors.blueGrey),
                                    const SizedBox(width: 6),
                                    const Text('Hyper/Hypo', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Container(width: 12, height: 2, color: Colors.teal),
                                    const SizedBox(width: 6),
                                    const Text('Related', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD2FF26),
                      foregroundColor: const Color(0xFF1B2036),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    onPressed: () => _showAddWordSheet(context),
                    icon: const Icon(Icons.add, size: 18, color: Color(0xFF1B2036)),
                    label: const Text('drop a word', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B2036))),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GraphPainter extends CustomPainter {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final Offset panOffset;
  final double scale;
  final String? selectedNodeId;

  GraphPainter({
    required this.nodes,
    required this.edges,
    required this.panOffset,
    required this.scale,
    this.selectedNodeId,
  });

  Color _getEdgeColor(String type, double opacity) {
    switch (type.toUpperCase()) {
      case 'SYNONYM_OF':
      case 'SYNONYM':
        return const Color(0xFF2E6BFF).withOpacity(opacity); // Electric Blue
      case 'ANTONYM_OF':
      case 'ANTONYM':
        return Colors.redAccent.withOpacity(opacity);
      case 'HYPERNYM_OF':
      case 'HYPERNYM':
        return Colors.blueGrey.withOpacity(opacity);
      case 'HYPONYM_OF':
      case 'HYPONYM':
        return Colors.indigo.withOpacity(opacity);
      case 'MERONYM_OF':
      case 'MERONYM':
        return Colors.deepOrange.withOpacity(opacity);
      case 'HOLONYM_OF':
      case 'HOLONYM':
        return Colors.brown.withOpacity(opacity);
      case 'RELATED_TO':
      case 'RELATED':
        return Colors.teal.withOpacity(opacity);
      case 'SIMILAR_TO':
      case 'SIMILAR':
        return const Color(0xFF006064).withOpacity(opacity); // Cyan [800]
      case 'ABBREVIATION_OF':
      case 'ABBREVIATION':
        return const Color(0xFFD2FF26).withOpacity(opacity); // Neon Lime
      default:
        return Colors.white.withOpacity(opacity * 0.4);
    }
  }

  bool _isEdgeDashed(String type) {
    final uType = type.toUpperCase();
    return uType.contains('HYPERNYM') ||
           uType.contains('HYPONYM') ||
           uType.contains('MERONYM') ||
           uType.contains('HOLONYM') ||
           uType.contains('SIMILAR') ||
           uType.contains('ABBREVIATION');
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, {double dashWidth = 5.0, double dashSpace = 3.0}) {
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double end = min(distance + dashWidth, metric.length);
        final Path extract = metric.extractPath(distance, end);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(panOffset.dx, panOffset.dy);
    canvas.scale(scale);

    final double centerX = size.width / 2;
    final double centerY = (size.height - 180.0) / 2;

    // 0. Draw background concentric grid circles and radiating radar lines
    final double gridOpacity = selectedNodeId != null ? 0.01 : 0.03;
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(gridOpacity)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(Offset(centerX, centerY), 120.0, gridPaint);
    canvas.drawCircle(Offset(centerX, centerY), 240.0, gridPaint);
    canvas.drawCircle(Offset(centerX, centerY), 360.0, gridPaint);

    for (int i = 0; i < 8; i++) {
      final angle = (2 * pi / 8) * i;
      final dx = 400.0 * cos(angle);
      final dy = 400.0 * sin(angle);
      canvas.drawLine(
        Offset(centerX, centerY),
        Offset(centerX + dx, centerY + dy),
        gridPaint,
      );
    }

    // Set of neighbors of the selected node
    final Set<String> neighbors = {};
    if (selectedNodeId != null) {
      for (final edge in edges) {
        if (edge.source == selectedNodeId) {
          neighbors.add(edge.target);
        } else if (edge.target == selectedNodeId) {
          neighbors.add(edge.source);
        }
      }
    }

    // 1. Draw connecting relationship edges
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final edge in edges) {
      final sourceNode = nodes.firstWhere((n) => n.id == edge.source, orElse: () => GraphNode(id: '', label: '', ownedByMe: false));
      final targetNode = nodes.firstWhere((n) => n.id == edge.target, orElse: () => GraphNode(id: '', label: '', ownedByMe: false));

      if (sourceNode.id.isNotEmpty && targetNode.id.isNotEmpty) {
        final bool isHighlighted = selectedNodeId == null ||
            (sourceNode.id == selectedNodeId || targetNode.id == selectedNodeId);

        final double edgeOpacity = isHighlighted ? 0.75 : 0.08;
        final Color edgeColor = _getEdgeColor(edge.type, edgeOpacity);

        final linePaint = Paint()
          ..color = edgeColor
          ..strokeWidth = isHighlighted ? 2.2 : 0.8
          ..style = PaintingStyle.stroke;

        final double midX = (sourceNode.x + targetNode.x) / 2;
        final double midY = (sourceNode.y + targetNode.y) / 2;
        final double dx = targetNode.x - sourceNode.x;
        final double dy = targetNode.y - sourceNode.y;
        final double dist = sqrt(dx * dx + dy * dy);

        double textX = midX;
        double textY = midY;

        final path = Path();
        path.moveTo(sourceNode.x, sourceNode.y);

        if (dist > 10.0) {
          final nx = -dy / dist;
          final ny = dx / dist;
          
          // Subtly curve each edge to separate overlapping lines in dense networks
          final double curveOffset = 25.0;
          final double controlX = midX + nx * curveOffset;
          final double controlY = midY + ny * curveOffset;
          
          path.quadraticBezierTo(controlX, controlY, targetNode.x, targetNode.y);
          
          // Midpoint coordinates on quadratic curve for label placement
          textX = 0.25 * sourceNode.x + 0.5 * controlX + 0.25 * targetNode.x;
          textY = 0.25 * sourceNode.y + 0.5 * controlY + 0.25 * targetNode.y;
        } else {
          path.lineTo(targetNode.x, targetNode.y);
        }

        // Draw curved edge line
        if (_isEdgeDashed(edge.type)) {
          _drawDashedPath(canvas, path, linePaint);
        } else {
          canvas.drawPath(path, linePaint);
        }

        // Draw Relationship Type Badge in the center
        if (isHighlighted && scale > 0.65) {
          textPainter.text = TextSpan(
            text: edge.type.toUpperCase().replaceAll('_OF', '').replaceAll('_TO', ''),
            style: TextStyle(
              color: edgeColor.withOpacity(edgeOpacity * 0.9),
              fontSize: 7.0 / scale,
              fontWeight: FontWeight.bold,
              backgroundColor: const Color(0xFF1B2036).withOpacity(0.85),
            ),
          );
          textPainter.layout();
          textPainter.paint(canvas, Offset(textX - textPainter.width / 2, textY - textPainter.height / 2));
        }
      }
    }

    // 2. Paint Nodes
    for (final node in nodes) {
      final bool isSelected = node.id == selectedNodeId;
      final bool isNeighbor = selectedNodeId != null && neighbors.contains(node.id);
      final bool isFaded = selectedNodeId != null && !isSelected && !isNeighbor;

      final double nodeOpacity = isFaded ? 0.12 : 1.0;

      // Draw glow
      final Color nodeColor = node.ownedByMe ? const Color(0xFFD2FF26) : const Color(0xFF2E6BFF);
      final glowPaint = Paint()
        ..color = nodeColor.withOpacity(isFaded ? 0.02 : (node.ownedByMe ? 0.22 : 0.18))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(node.x, node.y), isSelected ? 32.0 : 28.0, glowPaint);

      // Node base circle
      canvas.drawCircle(
        Offset(node.x, node.y),
        isSelected ? 26.0 : 24.0,
        Paint()..color = nodeColor.withOpacity(nodeOpacity),
      );

      // Emphasize selected node with double border
      if (isSelected) {
        final borderPaint = Paint()
          ..color = Colors.white.withOpacity(nodeOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5;
        canvas.drawCircle(Offset(node.x, node.y), 29.0, borderPaint);
      }

      // Draw monogram (first letter of the word) inside the node circle for high contrast
      if (node.id.isNotEmpty) {
        textPainter.text = TextSpan(
          text: node.id[0].toUpperCase(),
          style: TextStyle(
            color: isFaded
                ? (node.ownedByMe ? const Color(0xFF1B2036).withOpacity(0.2) : Colors.white.withOpacity(0.2))
                : (node.ownedByMe ? const Color(0xFF1B2036) : Colors.white),
            fontSize: isSelected ? 13.0 : 11.0,
            fontWeight: FontWeight.bold,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(node.x - textPainter.width / 2, node.y - textPainter.height / 2),
        );
      }

      // Draw the full word badge below the node (always visible above scale 0.35)
      final bool shouldDrawLabel = scale > 0.35 || isSelected || isNeighbor;
      if (shouldDrawLabel && node.id.isNotEmpty) {
        textPainter.text = TextSpan(
          text: node.id[0].toUpperCase() + node.id.substring(1),
          style: TextStyle(
            color: isFaded
                ? Colors.white.withOpacity(0.25)
                : Colors.white,
            fontSize: isSelected ? 11.0 : 10.0,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        );
        textPainter.layout();

        final double badgeY = node.y + (isSelected ? 38.0 : 34.0);
        final double badgeWidth = textPainter.width + 12.0;
        final double badgeHeight = textPainter.height + 6.0;

        final RRect badgeRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(node.x, badgeY),
            width: badgeWidth,
            height: badgeHeight,
          ),
          const Radius.circular(8.0),
        );

        // Draw badge background to block overlapping grid lines or edges
        canvas.drawRRect(
          badgeRect,
          Paint()
            ..color = const Color(0xFF131722).withOpacity(nodeOpacity * 0.9)
            ..style = PaintingStyle.fill,
        );

        // Draw badge border with node color
        canvas.drawRRect(
          badgeRect,
          Paint()
            ..color = nodeColor.withOpacity(nodeOpacity * 0.75)
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 1.5 : 1.0,
        );

        // Draw label text inside badge
        textPainter.paint(
          canvas,
          Offset(node.x - textPainter.width / 2, badgeY - textPainter.height / 2),
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GraphPainter oldDelegate) {
    return true;
  }
}
