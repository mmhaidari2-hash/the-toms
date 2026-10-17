import '../features/course/course_screen.dart';
import '../features/course/lesson_screen.dart';
import '../features/course/practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/conversation/conversation_screen.dart';
import '../features/home/home_screen.dart';
import '../features/place/place_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/diary/diary_screen.dart';

CustomTransitionPage<void> _fade(Widget child, GoRouterState s) => CustomTransitionPage(
  key: s.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 380),
  transitionsBuilder: (_, a, _, c) => FadeTransition(
    opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
    child: SlideTransition(
      position: Tween(begin: const Offset(0, .04), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: c,
    ),
  ),
);

final router = GoRouter(
  routes: [
    GoRoute(path: '/', pageBuilder: (_, s) => _fade(const HomeScreen(), s)),
    GoRoute(path: '/onboarding', pageBuilder: (_, s) => _fade(const OnboardingScreen(), s)),
    GoRoute(path: '/diary', pageBuilder: (_, s) => _fade(const DiaryScreen(), s)),
    GoRoute(
      path: '/replay/:i',
      pageBuilder: (_, s) => _fade(ReplayScreen(index: int.tryParse(s.pathParameters['i']!) ?? 0), s),
    ),
    GoRoute(
      path: '/place/:id',
      pageBuilder: (_, s) => _fade(PlaceScreen(key: ValueKey('place-${s.pathParameters['id']}'), placeId: s.pathParameters['id']!), s),
    ),
    GoRoute(
      path: '/chat/:id',
      pageBuilder: (_, s) => _fade(ConversationScreen(key: ValueKey('chat-${s.pathParameters['id']}'), sceneId: s.pathParameters['id']!), s),
    ),
    GoRoute(path: '/course', pageBuilder: (_, s) => _fade(CourseScreen(key: ValueKey('course-${s.uri.queryParameters['level']}'), level: int.tryParse(s.uri.queryParameters['level'] ?? '')), s)),
    GoRoute(path: '/pack/:id', pageBuilder: (_, s) => _fade(PackScreen(key: ValueKey('pack-${s.pathParameters['id']}'), id: s.pathParameters['id']!), s)),
    GoRoute(path: '/lesson/:id', pageBuilder: (_, s) => _fade(LessonScreen(key: ValueKey('lesson-${s.pathParameters['id']}'), lessonId: s.pathParameters['id']!), s)),
    GoRoute(path: '/practice/:id', pageBuilder: (_, s) => _fade(PracticeScreen(key: ValueKey('practice-${s.pathParameters['id']}'), id: s.pathParameters['id']!), s)),
  ],
);
