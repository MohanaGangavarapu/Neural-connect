import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/social_repository.dart';
import 'social_directory_screen.dart';
import 'admin_console_screen.dart';
import '../../auth/domain/bloc/auth_bloc.dart';
import '../../auth/domain/auth_repository.dart';

class ProfileHubScreen extends StatefulWidget {
  final SocialRepository repository;
  final AuthRepository authRepository;

  const ProfileHubScreen({
    super.key,
    required this.repository,
    required this.authRepository,
  });

  @override
  State<ProfileHubScreen> createState() => _ProfileHubScreenState();
}

class _ProfileHubScreenState extends State<ProfileHubScreen> {
  ProfileStats? _stats;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await widget.repository.fetchProfileStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('user no longer exists') ||
            errStr.contains('user not found') ||
            errStr.contains('401') ||
            errStr.contains('unauthorized')) {
          context.read<AuthBloc>().add(LogoutRequested());
          return;
        }
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _confirmAccountDeletion(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you absolutely sure you want to permanently delete your VocabFlow account? This will detach all nodes, erase your history, and cannot be undone.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthBloc>().add(DeleteAccountRequested());
            },
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _openEditProfileSheet(BuildContext context) {
    final nameController = TextEditingController(text: _stats!.profile.displayName);
    final bioController = TextEditingController(text: _stats!.profile.bio);
    String selectedAvatar = _stats!.profile.avatarUrl;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B2036),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final presets = ['🧙', '🦊', '🚀', '🦉', '🦁', '🤖', '🐙', '💡', '🌟', '👾', '🌈', '🎓'];
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Profile Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Georgia',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Select Avatar / Emoji', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: presets.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final p = presets[index];
                          final isSelected = selectedAvatar == p;
                          return GestureDetector(
                            onTap: () {
                              setSheetState(() {
                                selectedAvatar = p;
                              });
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFD2FF26) : const Color(0xFF252B4D),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFD2FF26) : Colors.white24,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                p,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Or Enter Custom Avatar Image URL', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: selectedAvatar.startsWith('http') ? selectedAvatar : ''),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'https://example.com/avatar.png',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF252B4D),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      onChanged: (val) {
                        if (val.trim().isNotEmpty) {
                          selectedAvatar = val.trim();
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text('Display Name', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter display name',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF252B4D),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Bio', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bioController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Tell us about your learning goals...',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: const Color(0xFF252B4D),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD2FF26),
                          foregroundColor: const Color(0xFF1B2036),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                setSheetState(() {
                                  isSaving = true;
                                });
                                try {
                                  await widget.repository.updateProfile(
                                    nameController.text.trim(),
                                    bioController.text.trim(),
                                    selectedAvatar.trim(),
                                  );
                                  Navigator.pop(context);
                                  _loadStats();
                                } catch (e) {
                                  setSheetState(() {
                                    isSaving = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to update: $e')),
                                  );
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Color(0xFF1B2036), strokeWidth: 2),
                              )
                            : const Text('Save Profile Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final profile = _stats!.profile;
    final hasAvatarUrl = profile.avatarUrl.startsWith('http');
    final isEmoji = profile.avatarUrl.isNotEmpty && !hasAvatarUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF252B4D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF1B2036),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD2FF26), width: 2),
                ),
                alignment: Alignment.center,
                child: hasAvatarUrl
                    ? ClipOval(
                        child: Image.network(
                          profile.avatarUrl,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white54, size: 40),
                        ),
                      )
                    : (isEmoji
                        ? Text(profile.avatarUrl, style: const TextStyle(fontSize: 38))
                        : Text(
                            profile.displayName.isNotEmpty
                                ? profile.displayName[0].toUpperCase()
                                : (profile.username.isNotEmpty ? profile.username[0].toUpperCase() : '?'),
                            style: const TextStyle(color: Color(0xFFD2FF26), fontSize: 32, fontWeight: FontWeight.bold),
                          )),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            profile.displayName.isNotEmpty ? profile.displayName : profile.username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Georgia',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFFD2FF26), size: 20),
                          onPressed: () => _openEditProfileSheet(context),
                        ),
                      ],
                    ),
                    Text(
                      '@${profile.username}',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E6BFF).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF2E6BFF).withOpacity(0.4)),
                          ),
                          child: Text(
                            profile.learningLevel.toUpperCase(),
                            style: const TextStyle(color: Color(0xFF2E6BFF), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD2FF26).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFD2FF26).withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department, color: Color(0xFFD2FF26), size: 12),
                              const SizedBox(width: 4),
                              Text(
                                '${_stats!.streak.currentStreak} DAY STREAK',
                                style: const TextStyle(color: Color(0xFFD2FF26), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (profile.bio.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B2036),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                profile.bio,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _buildMiniStatCard('TOTAL WORDS', _stats!.totalWords.toString(), Icons.menu_book, const Color(0xFFD2FF26)),
        _buildMiniStatCard('CURRENT STREAK', '${_stats!.streak.currentStreak}d', Icons.local_fire_department, const Color(0xFFFF5252)),
        _buildMiniStatCard('LONGEST STREAK', '${_stats!.streak.longestStreak}d', Icons.emoji_events, const Color(0xFFFFC107)),
        _buildMiniStatCard('BOOKMARKS', _stats!.totalBookmarks.toString(), Icons.bookmark, const Color(0xFF2E6BFF)),
      ],
    );
  }

  Widget _buildMiniStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF252B4D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCalendar() {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 104));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252B4D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Activity Calendar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                ),
              ),
              Text(
                '${_stats!.streak.wordsAddedThisWeek} words this week',
                style: const TextStyle(
                  color: Color(0xFFD2FF26),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1,
              ),
              itemCount: 105,
              itemBuilder: (context, index) {
                final cellDate = startDate.add(Duration(days: index));
                final dateStr = "${cellDate.year}-${cellDate.month.toString().padLeft(2, '0')}-${cellDate.day.toString().padLeft(2, '0')}";
                final count = _stats!.streak.calendar[dateStr] ?? 0;

                Color cellColor;
                if (count == 0) {
                  cellColor = const Color(0xFF1B2036);
                } else if (count == 1) {
                  cellColor = const Color(0xFFD2FF26).withOpacity(0.25);
                } else if (count == 2) {
                  cellColor = const Color(0xFFD2FF26).withOpacity(0.55);
                } else {
                  cellColor = const Color(0xFFD2FF26);
                }

                return Tooltip(
                  message: '$count words learned on ${cellDate.day}/${cellDate.month}',
                  child: Container(
                    decoration: BoxDecoration(
                      color: cellColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Less ', style: TextStyle(color: Colors.grey, fontSize: 10)),
              _buildLegendBox(const Color(0xFF1B2036)),
              const SizedBox(width: 2),
              _buildLegendBox(const Color(0xFFD2FF26).withOpacity(0.25)),
              const SizedBox(width: 2),
              _buildLegendBox(const Color(0xFFD2FF26).withOpacity(0.55)),
              const SizedBox(width: 2),
              _buildLegendBox(const Color(0xFFD2FF26)),
              const SizedBox(width: 4),
              const Text(' More', style: TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendBox(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final progress = _stats!.streak.weeklyProgress;
    int maxCount = 1;
    for (var item in progress) {
      if (item.count > maxCount) maxCount = item.count;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252B4D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Growth',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: progress.map((item) {
              final double heightFactor = item.count / maxCount;
              String label = '';
              try {
                final parsed = DateTime.parse(item.date);
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                label = days[parsed.weekday - 1];
              } catch (_) {}

              return Column(
                children: [
                  Text(
                    '${item.count}',
                    style: TextStyle(
                      color: item.count > 0 ? const Color(0xFFD2FF26) : Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 24,
                    height: 80 * heightFactor + 4,
                    decoration: BoxDecoration(
                      color: item.count > 0 ? const Color(0xFFD2FF26) : const Color(0xFF1B2036),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      gradient: item.count > 0
                          ? const LinearGradient(
                              colors: [Color(0xFF2E6BFF), Color(0xFFD2FF26)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDistribution() {
    final cats = _stats!.categories;
    final total = cats.noun + cats.verb + cats.adjective + cats.adverb + cats.other;

    Widget buildRow(String label, int count, Color color) {
      final double percent = total > 0 ? count / total : 0.0;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(
                  '$count (${(percent * 100).toStringAsFixed(0)}%)',
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: const Color(0xFF1B2036),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252B4D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vocabulary Categories',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 16),
          buildRow('Nouns', cats.noun, const Color(0xFFD2FF26)),
          buildRow('Verbs', cats.verb, const Color(0xFF2E6BFF)),
          buildRow('Adjectives', cats.adjective, const Color(0xFFFF5252)),
          buildRow('Adverbs', cats.adverb, const Color(0xFFE040FB)),
          buildRow('Others', cats.other, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildCrewsSection() {
    final crews = _stats!.crews;
    if (crews.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Joined Crews',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Georgia',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: crews.length,
            itemBuilder: (context, index) {
              final crew = crews[index];
              return Container(
                width: 180,
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF252B4D),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1B2036),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        crew.avatar,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            crew.name,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${crew.memberCount} members',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            crew.role,
                            style: const TextStyle(color: Color(0xFFD2FF26), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentBookmarks() {
    final bookmarks = _stats!.recentBookmarks;
    if (bookmarks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Bookmarks',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Georgia',
          ),
        ),
        const SizedBox(height: 12),
        ...bookmarks.map((b) => Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF252B4D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        b.word,
                        style: const TextStyle(
                          color: Color(0xFFD2FF26),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.bookmark, color: Color(0xFF2E6BFF), size: 16),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    b.definition,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildConnectionsSection(BuildContext context) {
    final friends = _stats!.recentConnections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Connections',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SocialDirectoryScreen(repository: widget.repository),
                  ),
                );
              },
              child: const Text(
                'Explore Directory ↗',
                style: TextStyle(color: Color(0xFFD2FF26), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (friends.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF252B4D),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text(
              'No connections added yet. Find peers to see details.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF252B4D),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: friends.map((f) {
                final hasUrl = f.avatarUrl.startsWith('http');
                final isEmoji = f.avatarUrl.isNotEmpty && !hasUrl;
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  child: Tooltip(
                    message: f.displayName.isNotEmpty ? f.displayName : f.username,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF1B2036),
                      child: hasUrl
                          ? ClipOval(
                              child: Image.network(
                                f.avatarUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white54, size: 20),
                              ),
                            )
                          : (isEmoji
                              ? Text(f.avatarUrl, style: const TextStyle(fontSize: 20))
                              : Text(
                                  f.displayName.isNotEmpty
                                      ? f.displayName[0].toUpperCase()
                                      : f.username[0].toUpperCase(),
                                  style: const TextStyle(color: Color(0xFFD2FF26), fontWeight: FontWeight.bold),
                                )),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildAchievementsSection() {
    final achievements = _stats!.achievements;
    if (achievements.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Unlocked Milestones',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Georgia',
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: achievements.length,
          itemBuilder: (context, index) {
            final ach = achievements[index];
            final color = ach.unlocked ? const Color(0xFFD2FF26) : Colors.grey;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF252B4D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: ach.unlocked ? const Color(0xFFD2FF26).withOpacity(0.3) : Colors.white.withOpacity(0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        ach.unlocked ? Icons.verified : Icons.lock_outline,
                        color: color,
                        size: 20,
                      ),
                      Text(
                        '${(ach.progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ach.name,
                        style: TextStyle(
                          color: ach.unlocked ? Colors.white : Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ach.description,
                        style: const TextStyle(color: Colors.white38, fontSize: 9, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: ach.progress,
                      backgroundColor: const Color(0xFF1B2036),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Account deletion failed: ${state.message}')),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1B2036), // Deep Navy
        appBar: AppBar(
          backgroundColor: const Color(0xFF161A2B), // Darker Navy
          title: const Text(
            'my profile workspace',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Georgia'),
          ),
          elevation: 0,
        ),
        body: RefreshIndicator(
          onRefresh: _loadStats,
          color: const Color(0xFFD2FF26),
          backgroundColor: const Color(0xFF252B4D),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFD2FF26)))
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadStats,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(context),
                          const SizedBox(height: 24),
                          _buildStatsGrid(),
                          const SizedBox(height: 24),
                          _buildStreakCalendar(),
                          const SizedBox(height: 24),
                          _buildWeeklyChart(),
                          const SizedBox(height: 24),
                          _buildCategoryDistribution(),
                          const SizedBox(height: 24),
                          _buildCrewsSection(),
                          const SizedBox(height: 24),
                          _buildRecentBookmarks(),
                          const SizedBox(height: 24),
                          _buildConnectionsSection(context),
                          const SizedBox(height: 24),
                          _buildAchievementsSection(),
                          const SizedBox(height: 32),
                          // action card to find/add friends
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF252B4D), // Navy Slate
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Grow Your Crew',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Georgia'),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Connect with other learners, share your vocabulary galaxy, and see what words they are dropping.',
                                  style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFD2FF26), // Lime Green
                                    foregroundColor: const Color(0xFF1B2036),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    minimumSize: const Size(double.infinity, 48),
                                    elevation: 0,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => SocialDirectoryScreen(repository: widget.repository),
                                      ),
                                    );
                                  },
                                  child: const Text('Find Connections ↗', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Admin Console Tile
                          if (_stats!.isAdmin) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF252B4D), // Navy Slate
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFD2FF26).withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'System Administration',
                                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Georgia'),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Access database statistics, monitor user counts, and trigger system-wide tasks.',
                                    style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                                  ),
                                  const SizedBox(height: 20),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFD2FF26), // Lime Green
                                      foregroundColor: const Color(0xFF1B2036),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      minimumSize: const Size(double.infinity, 48),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AdminConsoleScreen(repository: widget.repository),
                                        ),
                                      );
                                    },
                                    child: const Text('Admin Console ↗', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          // Danger Zone / Account Deletion Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D1B28), // Dark Reddish Slate
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Danger Zone',
                                  style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Georgia'),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Permanently delete your account and all associated data from both MongoDB and the Neo4j Aura graph. This action is irreversible.',
                                  style: TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    minimumSize: const Size(double.infinity, 48),
                                    elevation: 0,
                                  ),
                                  onPressed: () => _confirmAccountDeletion(context),
                                  child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}
