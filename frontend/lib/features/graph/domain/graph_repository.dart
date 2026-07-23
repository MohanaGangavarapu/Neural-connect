import 'package:dio/dio.dart';
import '../../words/domain/dio_error_extension.dart';

class GraphNode {
  final String id;
  final String label;
  final bool ownedByMe;
  double x;
  double y;

  GraphNode({
    required this.id,
    required this.label,
    required this.ownedByMe,
    this.x = 0.0,
    this.y = 0.0,
  });

  factory GraphNode.fromJson(Map<String, dynamic> json) {
    return GraphNode(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
      ownedByMe: json['ownedByMe'] ?? false,
    );
  }
}

class GraphEdge {
  final String id;
  final String source;
  final String target;
  final String type;

  GraphEdge({
    required this.id,
    required this.source,
    required this.target,
    required this.type,
  });

  factory GraphEdge.fromJson(Map<String, dynamic> json) {
    return GraphEdge(
      id: json['id'] ?? '',
      source: json['source'] ?? '',
      target: json['target'] ?? '',
      type: json['type'] ?? '',
    );
  }
}

class GraphRepository {
  final Dio _dio;

  GraphRepository({required Dio dio}) : _dio = dio;

  Dio get dio => _dio;

  Future<Map<String, dynamic>> fetchGraphCanvas() async {
    try {
      final response = await _dio.get('/api/v1/graph/canvas');
      if (response.statusCode == 200) {
        final data = response.data['data'];
        final List nodesJson = data['nodes'] ?? [];
        final List edgesJson = data['edges'] ?? [];

        final List<GraphNode> nodes = nodesJson.map((n) => GraphNode.fromJson(n)).toList();
        final List<GraphEdge> edges = edgesJson.map((e) => GraphEdge.fromJson(e)).toList();

        return {
          'nodes': nodes,
          'edges': edges,
        };
      }
      throw Exception('Failed to load graph canvas');
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }
}
