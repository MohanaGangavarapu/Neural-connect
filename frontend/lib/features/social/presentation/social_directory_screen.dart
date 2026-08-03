import 'package:flutter/material.dart';
import '../domain/social_repository.dart';

class SocialDirectoryScreen extends StatefulWidget {
  final SocialRepository repository;

  const SocialDirectoryScreen({super.key, required this.repository});

  @override
  State<SocialDirectoryScreen> createState() => _SocialDirectoryScreenState();
}

class _SocialDirectoryScreenState extends State<SocialDirectoryScreen> {
  List<SocialUser> _users = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    try {
      final list = await widget.repository.fetchUsersDirectory();
      setState(() {
        _users = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendRequest(String username) async {
    try {
      await widget.repository.sendRequest(username);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to $username')),
      );
      _loadDirectory();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2036),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161A2B),
        title: const Text(
          'find connections',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Georgia'),
        ),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD2FF26)))
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final item = _users[index];
                    return Card(
                      color: const Color(0xFF252B4D),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.white.withOpacity(0.03)),
                      ),
                      child: ListTile(
                        title: Text(
                          item.username,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          item.relationship,
                          style: const TextStyle(color: Colors.white38),
                        ),
                        trailing: item.relationship == 'NONE'
                            ? ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD2FF26),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _sendRequest(item.username),
                                child: const Text('Add Friend', style: TextStyle(color: Color(0xFF1B2036), fontWeight: FontWeight.bold)),
                              )
                            : item.relationship == 'PENDING_SENT'
                                ? const Text('Pending', style: TextStyle(color: Colors.white60))
                                : const Icon(Icons.check_circle, color: Color(0xFFD2FF26)),
                      ),
                    );
                  },
                ),
    );
  }
}
