import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'features/auth/domain/auth_repository.dart';
import 'features/auth/domain/bloc/auth_bloc.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/onboarding_screen.dart';

import 'features/words/domain/words_repository.dart';
import 'features/words/domain/bloc/words_bloc.dart';
import 'features/words/presentation/dashboard_screen.dart';

import 'features/graph/domain/graph_repository.dart';
import 'features/graph/presentation/graph_canvas_screen.dart';

import 'features/social/domain/social_repository.dart';
import 'features/social/presentation/profile_hub_screen.dart';
import 'features/notifications/domain/notifications_repository.dart';

class AppBlocObserver extends BlocObserver {
  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    debugPrint('🟥 [Bloc Error] in ${bloc.runtimeType}: $error');
    debugPrint(stackTrace.toString());
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change change) {
    super.onChange(bloc, change);
    final state = change.nextState;
    if (state is WordsFailure) {
      debugPrint('🟥 [Words Bloc State Failure]: ${state.message}');
    } else if (state is AuthFailure) {
      debugPrint('🟥 [Auth Bloc State Failure]: ${state.message}');
    }
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = AppBlocObserver();

  // Log uncaught Flutter frame exceptions to the terminal
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🟥 [Uncaught Flutter Error]: ${details.exception}');
    if (details.stack != null) {
      debugPrint(details.stack.toString());
    }
  };

  // Log uncaught asynchronous exceptions to the terminal
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🟥 [Uncaught Async Error]: $error');
    debugPrint(stack.toString());
    return true;
  };

  final dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://vocabflow-backend-vd4v.onrender.com',
    ),
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  const storage = FlutterSecureStorage();

  // Add interceptor to attach JWT Authorization headers dynamically
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await storage.read(key: 'jwt_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
  ));

  final authRepository = AuthRepository(dio: dio, storage: storage);
  final wordsRepository = WordsRepository(dio: dio);
  final graphRepository = GraphRepository(dio: dio);
  final socialRepository = SocialRepository(dio: dio);
  final notificationsRepository = NotificationsRepository(dio: dio);

  runApp(MyApp(
    authRepository: authRepository,
    wordsRepository: wordsRepository,
    graphRepository: graphRepository,
    socialRepository: socialRepository,
    notificationsRepository: notificationsRepository,
  ));
}

class MyApp extends StatefulWidget {
  final AuthRepository authRepository;
  final WordsRepository wordsRepository;
  final GraphRepository graphRepository;
  final SocialRepository socialRepository;
  final NotificationsRepository notificationsRepository;

  const MyApp({
    super.key,
    required this.authRepository,
    required this.wordsRepository,
    required this.graphRepository,
    required this.socialRepository,
    required this.notificationsRepository,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Key _futureBuilderKey = UniqueKey();

  void _refreshOnboarding() {
    setState(() {
      _futureBuilderKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(authRepository: widget.authRepository)..add(CheckAuthRequested()),
        ),
        BlocProvider<WordsBloc>(
          create: (context) => WordsBloc(repository: widget.wordsRepository),
        ),
      ],
      child: MaterialApp(
        title: 'VocabFlow',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF1B2036), // Deep Navy
          primaryColor: const Color(0xFFD2FF26), // Lime Green Accent
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFD2FF26),
            secondary: Color(0xFF2E6BFF), // Electric Blue
            surface: Color(0xFF252B4D), // Dark Navy Card/Panel Background
          ),
        ),
        home: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthSuccess || state is AuthInitial) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
          child: FutureBuilder<bool>(
            key: _futureBuilderKey,
            future: widget.authRepository.isOnboardingCompleted(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFFD2FF26)),
                  ),
                );
              }
              final onboardingCompleted = snapshot.data ?? false;
              if (!onboardingCompleted) {
                return OnboardingScreen(
                  repository: widget.authRepository,
                  onCompleted: _refreshOnboarding,
                );
              }
              return BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) {
                  if (state is AuthSuccess) {
                    return MainNavigationHub(
                      wordsRepository: widget.wordsRepository,
                      graphRepository: widget.graphRepository,
                      socialRepository: widget.socialRepository,
                      notificationsRepository: widget.notificationsRepository,
                      authRepository: widget.authRepository,
                    );
                  }
                  return LoginScreen();
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class MainNavigationHub extends StatefulWidget {
  final WordsRepository wordsRepository;
  final GraphRepository graphRepository;
  final SocialRepository socialRepository;
  final NotificationsRepository notificationsRepository;
  final AuthRepository authRepository;

  const MainNavigationHub({
    super.key,
    required this.wordsRepository,
    required this.graphRepository,
    required this.socialRepository,
    required this.notificationsRepository,
    required this.authRepository,
  });

  @override
  State<MainNavigationHub> createState() => _MainNavigationHubState();
}

class _MainNavigationHubState extends State<MainNavigationHub> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      GraphCanvasScreen(
        repository: widget.graphRepository,
        wordsRepository: widget.wordsRepository,
        notificationsRepository: widget.notificationsRepository,
      ),
      DashboardScreen(
        repository: widget.wordsRepository,
        notificationsRepository: widget.notificationsRepository,
      ),
      ProfileHubScreen(
        repository: widget.socialRepository,
        authRepository: widget.authRepository,
      ),
    ];
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
        if (index == 1) {
          context.read<WordsBloc>().add(const FetchWordsRequested(refresh: true));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD2FF26) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1B2036) : Colors.white60,
              size: 20,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1B2036),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF161A2B), // Slate Slate
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.hub_outlined, 'graph'),
                  _buildNavItem(1, Icons.auto_awesome, 'explore'),
                  _buildNavItem(2, Icons.person_outline, 'crew'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
