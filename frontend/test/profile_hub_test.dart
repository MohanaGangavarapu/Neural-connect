import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/social/presentation/profile_hub_screen.dart';
import 'package:frontend/features/social/domain/social_repository.dart';
import 'package:frontend/features/auth/domain/auth_repository.dart';
import 'package:frontend/features/auth/domain/bloc/auth_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

class MockSocialRepository extends SocialRepository {
  MockSocialRepository() : super(dio: Dio());

  @override
  Future<ProfileStats> fetchProfileStats() async {
    return ProfileStats(
      totalWords: 15,
      totalBookmarks: 4,
      totalFriends: 3,
      isAdmin: false,
      profile: UserProfileInfo(
        username: 'testuser',
        displayName: 'Test User',
        bio: 'Hello world',
        avatarUrl: '',
        learningLevel: 'Scholar',
      ),
      streak: StreakStats(
        currentStreak: 5,
        longestStreak: 10,
        wordsAddedThisWeek: 8,
        weeklyProgress: [
          WeeklyProgressItem(date: '2026-06-21', count: 2),
        ],
        calendar: {
          '2026-06-21': 2,
        },
      ),
      crews: [
        JoinedCrew(
          name: 'Word Wizards',
          avatar: '🧙',
          memberCount: 9,
          role: 'Member',
        ),
      ],
      recentBookmarks: [
        BookmarkedWordPreview(
          id: '1',
          word: 'flamboyant',
          definition: 'tending to attract attention because of their exuberance',
          createdAt: '2026-06-21T00:00:00.000Z',
        ),
      ],
      recentConnections: [
        ConnectionPreview(
          id: '2',
          username: 'friend1',
          displayName: 'Friend One',
          avatarUrl: '',
        ),
      ],
      categories: CategoryCounts(
        noun: 5,
        verb: 4,
        adjective: 3,
        adverb: 2,
        other: 1,
      ),
      achievements: [
        AchievementItem(
          id: 'first_word',
          name: 'First Word Added',
          description: 'Ingested your first word to the vocabulary galaxy.',
          unlocked: true,
          progress: 1.0,
        ),
      ],
    );
  }
}

void main() {
  testWidgets('ProfileHubScreen displays summary count indicators cleanly', (WidgetTester tester) async {
    final mockRepo = MockSocialRepository();
    final mockAuthRepo = AuthRepository(dio: Dio(), storage: const FlutterSecureStorage());
    final authBloc = AuthBloc(authRepository: mockAuthRepo);

    await tester.pumpWidget(
      BlocProvider<AuthBloc>(
        create: (context) => authBloc,
        child: MaterialApp(
          home: ProfileHubScreen(
            repository: mockRepo,
            authRepository: mockAuthRepo,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('TOTAL WORDS'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });
}
