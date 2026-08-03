import 'package:dio/dio.dart';
import '../../words/domain/dio_error_extension.dart';

class SocialUser {
  final String id;
  final String username;
  final String relationship;

  SocialUser({
    required this.id,
    required this.username,
    required this.relationship,
  });

  factory SocialUser.fromJson(Map<String, dynamic> json) {
    return SocialUser(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      relationship: json['relationship'] ?? 'NONE',
    );
  }
}

class UserProfileInfo {
  final String username;
  final String displayName;
  final String bio;
  final String avatarUrl;
  final String learningLevel;

  UserProfileInfo({
    required this.username,
    required this.displayName,
    required this.bio,
    required this.avatarUrl,
    required this.learningLevel,
  });

  factory UserProfileInfo.fromJson(Map<String, dynamic> json) {
    return UserProfileInfo(
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      bio: json['bio'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
      learningLevel: json['learningLevel'] ?? 'Novice',
    );
  }
}

class StreakStats {
  final int currentStreak;
  final int longestStreak;
  final int wordsAddedThisWeek;
  final List<WeeklyProgressItem> weeklyProgress;
  final Map<String, int> calendar;

  StreakStats({
    required this.currentStreak,
    required this.longestStreak,
    required this.wordsAddedThisWeek,
    required this.weeklyProgress,
    required this.calendar,
  });

  factory StreakStats.fromJson(Map<String, dynamic> json) {
    final rawCalendar = json['calendar'] ?? {};
    final Map<String, int> calendarMap = {};
    if (rawCalendar is Map) {
      rawCalendar.forEach((k, v) {
        calendarMap[k.toString()] = (v is num) ? v.toInt() : 0;
      });
    }

    return StreakStats(
      currentStreak: json['currentStreak'] ?? 0,
      longestStreak: json['longestStreak'] ?? 0,
      wordsAddedThisWeek: json['wordsAddedThisWeek'] ?? 0,
      weeklyProgress: (json['weeklyProgress'] as List? ?? [])
          .map((item) => WeeklyProgressItem.fromJson(item))
          .toList(),
      calendar: calendarMap,
    );
  }
}

class WeeklyProgressItem {
  final String date;
  final int count;

  WeeklyProgressItem({
    required this.date,
    required this.count,
  });

  factory WeeklyProgressItem.fromJson(Map<String, dynamic> json) {
    return WeeklyProgressItem(
      date: json['date'] ?? '',
      count: json['count'] ?? 0,
    );
  }
}

class JoinedCrew {
  final String name;
  final String avatar;
  final int memberCount;
  final String role;

  JoinedCrew({
    required this.name,
    required this.avatar,
    required this.memberCount,
    required this.role,
  });

  factory JoinedCrew.fromJson(Map<String, dynamic> json) {
    return JoinedCrew(
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '🧙',
      memberCount: json['memberCount'] ?? 1,
      role: json['role'] ?? 'Member',
    );
  }
}

class BookmarkedWordPreview {
  final String id;
  final String word;
  final String definition;
  final String createdAt;

  BookmarkedWordPreview({
    required this.id,
    required this.word,
    required this.definition,
    required this.createdAt,
  });

  factory BookmarkedWordPreview.fromJson(Map<String, dynamic> json) {
    return BookmarkedWordPreview(
      id: json['id'] ?? json['_id'] ?? '',
      word: json['word'] ?? '',
      definition: json['definition'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }
}

class ConnectionPreview {
  final String id;
  final String username;
  final String displayName;
  final String avatarUrl;

  ConnectionPreview({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
  });

  factory ConnectionPreview.fromJson(Map<String, dynamic> json) {
    return ConnectionPreview(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? '',
      avatarUrl: json['avatarUrl'] ?? '',
    );
  }
}

class CategoryCounts {
  final int noun;
  final int verb;
  final int adjective;
  final int adverb;
  final int other;

  CategoryCounts({
    required this.noun,
    required this.verb,
    required this.adjective,
    required this.adverb,
    required this.other,
  });

  factory CategoryCounts.fromJson(Map<String, dynamic> json) {
    return CategoryCounts(
      noun: json['noun'] ?? 0,
      verb: json['verb'] ?? 0,
      adjective: json['adjective'] ?? 0,
      adverb: json['adverb'] ?? 0,
      other: json['other'] ?? 0,
    );
  }
}

class AchievementItem {
  final String id;
  final String name;
  final String description;
  final bool unlocked;
  final double progress;

  AchievementItem({
    required this.id,
    required this.name,
    required this.description,
    required this.unlocked,
    required this.progress,
  });

  factory AchievementItem.fromJson(Map<String, dynamic> json) {
    return AchievementItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      unlocked: json['unlocked'] ?? false,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ProfileStats {
  final int totalWords;
  final int totalBookmarks;
  final int totalFriends;
  final bool isAdmin;
  final UserProfileInfo profile;
  final StreakStats streak;
  final List<JoinedCrew> crews;
  final List<BookmarkedWordPreview> recentBookmarks;
  final List<ConnectionPreview> recentConnections;
  final CategoryCounts categories;
  final List<AchievementItem> achievements;

  ProfileStats({
    required this.totalWords,
    required this.totalBookmarks,
    required this.totalFriends,
    required this.isAdmin,
    required this.profile,
    required this.streak,
    required this.crews,
    required this.recentBookmarks,
    required this.recentConnections,
    required this.categories,
    required this.achievements,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) {
    return ProfileStats(
      totalWords: json['totalWords'] ?? 0,
      totalBookmarks: json['totalBookmarks'] ?? 0,
      totalFriends: json['totalFriends'] ?? 0,
      isAdmin: json['isAdmin'] ?? false,
      profile: UserProfileInfo.fromJson(json['profile'] ?? {}),
      streak: StreakStats.fromJson(json['streak'] ?? {}),
      crews: (json['crews'] as List? ?? [])
          .map((c) => JoinedCrew.fromJson(c))
          .toList(),
      recentBookmarks: (json['recentBookmarks'] as List? ?? [])
          .map((b) => BookmarkedWordPreview.fromJson(b))
          .toList(),
      recentConnections: (json['recentConnections'] as List? ?? [])
          .map((c) => ConnectionPreview.fromJson(c))
          .toList(),
      categories: CategoryCounts.fromJson(json['categories'] ?? {}),
      achievements: (json['achievements'] as List? ?? [])
          .map((a) => AchievementItem.fromJson(a))
          .toList(),
    );
  }
}

class SocialRepository {
  final Dio _dio;

  SocialRepository({required Dio dio}) : _dio = dio;

  Future<List<SocialUser>> fetchUsersDirectory() async {
    try {
      final response = await _dio.get('/api/v1/social/users');
      if (response.statusCode == 200) {
        final List list = response.data['data'] ?? [];
        return list.map((u) => SocialUser.fromJson(u)).toList();
      }
      throw Exception('Failed to load user directory');
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<void> sendRequest(String targetUsername) async {
    try {
      await _dio.post('/api/v1/social/friends/request', data: {
        'targetUsername': targetUsername,
      });
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<void> respondRequest(String requesterId, String action) async {
    try {
      await _dio.put('/api/v1/social/friends/respond', data: {
        'requesterId': requesterId,
        'action': action,
      });
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<ProfileStats> fetchProfileStats() async {
    try {
      final response = await _dio.get('/api/v1/social/profile/stats');
      if (response.statusCode == 200) {
        return ProfileStats.fromJson(response.data['data']);
      }
      throw Exception('Failed to load profile stats');
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<void> updateProfile(String displayName, String bio, String avatarUrl) async {
    try {
      await _dio.put('/api/v1/social/profile', data: {
        'displayName': displayName,
        'bio': bio,
        'avatarUrl': avatarUrl,
      });
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<Map<String, dynamic>> fetchAdminStats() async {
    try {
      final response = await _dio.get('/api/v1/admin/stats');
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data['data'] ?? {});
      }
      throw Exception('Failed to load admin stats');
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }

  Future<void> triggerInactivityCheck() async {
    try {
      await _dio.post('/api/v1/admin/trigger-inactivity-check');
    } on DioException catch (e) {
      throw Exception(e.errorMessage);
    }
  }
}
