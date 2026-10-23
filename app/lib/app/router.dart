import '../features/leitner/leitner_screen.dart';
import '../features/map/map_home.dart';
import '../features/onboarding/placement_screen.dart';
import '../features/onboarding/howto.dart';
import '../features/course/course_screen.dart';
import '../features/course/lesson_screen.dart';
import '../features/course/practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/conversation/conversation_screen.dart';
import '../features/home/home_screen.dart';
import '../features/place/place_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/premium/premium_screen.dart';
import '../features/grammar/school_screen.dart';
import '../features/grammar/topic_screen.dart';
import '../features/legal/legal_screen.dart';
import '../features/cinema/cinema_screen.dart';
import '../features/cinema/scene_screen.dart';
import '../features/lifeuk/lifeuk_screen.dart';
import '../features/lifeuk/luk_quiz_screen.dart';
import '../features/messages/inbox_screen.dart';
import '../features/seasons/seasons_screen.dart';
import '../features/driving/driving_screen.dart';
import '../features/theory/theory_screen.dart';
import '../features/theory/thy_quiz_screen.dart';
import '../features/messages/thread_screen.dart';
import '../features/missions/mission_screen.dart';
import '../features/park/game_screen.dart';
import '../features/park/park_screen.dart';
import '../features/missions/missions_screen.dart';
import '../features/radio/radio_screen.dart';
import '../features/radio/segment_screen.dart';
import '../features/library/library_screen.dart';
import '../features/library/reader_screen.dart';
import '../features/motivation/progress_screen.dart';
import '../features/premium/certificate_screen.dart';
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
    GoRoute(path: '/', pageBuilder: (_, s) => _fade(const MapHome(), s)),
    GoRoute(path: '/family', pageBuilder: (_, s) => _fade(const HomeScreen(), s)),
    GoRoute(path: '/placement', pageBuilder: (_, s) => _fade(const PlacementScreen(), s)),
    GoRoute(path: '/howto', pageBuilder: (_, s) => _fade(const HowToScreen(), s)),
    GoRoute(path: '/onboarding', pageBuilder: (_, s) => _fade(const OnboardingScreen(), s)),
    GoRoute(path: '/legal', pageBuilder: (_, s) => _fade(LegalScreen(key: ValueKey('legal-${s.uri.queryParameters['tab']}'), tab: s.uri.queryParameters['tab'] ?? 'privacy'), s)),
    GoRoute(path: '/school', pageBuilder: (_, s) => _fade(const SchoolScreen(), s)),
    GoRoute(path: '/school/:level', pageBuilder: (_, s) => _fade(ClassScreen(key: ValueKey('class-${s.pathParameters['level']}'), code: s.pathParameters['level']!), s)),
    GoRoute(path: '/grammar/:id', pageBuilder: (_, s) => _fade(TopicScreen(key: ValueKey('grammar-${s.pathParameters['id']}'), id: s.pathParameters['id']!), s)),
    GoRoute(path: '/library', pageBuilder: (_, s) => _fade(const LibraryScreen(), s)),
    GoRoute(path: '/read/:book', pageBuilder: (_, s) => _fade(ReaderScreen(key: ValueKey('read-${s.pathParameters['book']}-${s.uri.queryParameters['ch']}'), bookId: s.pathParameters['book']!, chapter: int.tryParse(s.uri.queryParameters['ch'] ?? '') ?? 0), s)),
    GoRoute(path: '/cinema', pageBuilder: (_, s) => _fade(const CinemaScreen(), s)),
    GoRoute(path: '/lifeuk', pageBuilder: (_, s) => _fade(const LukScreen(), s)),
    GoRoute(path: '/lifeuk/mock', pageBuilder: (_, s) => _fade(LukQuizScreen(key: ValueKey('luk-mock-${s.uri.queryParameters['r']}')), s)),
    GoRoute(path: '/lifeuk/:ch', pageBuilder: (_, s) => _fade(LukChapterScreen(id: s.pathParameters['ch']!), s)),
    GoRoute(path: '/lifeuk/:ch/cards', pageBuilder: (_, s) => _fade(LukCardsScreen(key: ValueKey('luk-cards-${s.pathParameters['ch']}'), id: s.pathParameters['ch']!), s)),
    GoRoute(path: '/lifeuk/:ch/quiz', pageBuilder: (_, s) => _fade(LukQuizScreen(key: ValueKey('luk-q-${s.pathParameters['ch']}-${s.uri.queryParameters['r']}'), chapter: s.pathParameters['ch']!), s)),
    GoRoute(path: '/park', pageBuilder: (_, s) => _fade(const ParkScreen(), s)),
    GoRoute(path: '/park/:level/:game', pageBuilder: (_, s) => _fade(ParkGameScreen(key: ValueKey('park-${s.pathParameters['level']}-${s.pathParameters['game']}-${s.uri.queryParameters['r']}'), level: s.pathParameters['level']!, game: s.pathParameters['game']!), s)),
    GoRoute(path: '/messages', pageBuilder: (_, s) => _fade(const InboxScreen(), s)),
    GoRoute(path: '/driving', pageBuilder: (_, s) => _fade(const DrivingScreen(), s)),
    GoRoute(path: '/driving/:id', pageBuilder: (_, s) => _fade(DrivingLessonScreen(key: ValueKey('drv-${s.pathParameters['id']}-${s.uri.queryParameters['r']}'), id: s.pathParameters['id']!), s)),
    GoRoute(path: '/theory', pageBuilder: (_, s) => _fade(const ThyScreen(), s)),
    GoRoute(path: '/theory/mock', pageBuilder: (_, s) => _fade(ThyQuizScreen(key: ValueKey('thy-mock-${s.uri.queryParameters['r']}')), s)),
    GoRoute(path: '/theory/:ch', pageBuilder: (_, s) => _fade(ThyChapterScreen(id: s.pathParameters['ch']!), s)),
    GoRoute(path: '/theory/:ch/cards', pageBuilder: (_, s) => _fade(ThyCardsScreen(key: ValueKey('thy-cards-${s.pathParameters['ch']}'), id: s.pathParameters['ch']!), s)),
    GoRoute(path: '/theory/:ch/quiz', pageBuilder: (_, s) => _fade(ThyQuizScreen(key: ValueKey('thy-q-${s.pathParameters['ch']}-${s.uri.queryParameters['r']}'), chapter: s.pathParameters['ch']!), s)),
    GoRoute(path: '/seasons', pageBuilder: (_, s) => _fade(const SeasonsScreen(), s)),
    GoRoute(path: '/seasons/:id', pageBuilder: (_, s) => _fade(SeasonEventScreen(key: ValueKey('sea-${s.pathParameters['id']}-${s.uri.queryParameters['r']}'), id: s.pathParameters['id']!), s)),
    GoRoute(path: '/messages/:id', pageBuilder: (_, s) => _fade(ThreadScreen(key: ValueKey('thread-${s.pathParameters['id']}-${s.uri.queryParameters['r']}'), id: s.pathParameters['id']!), s)),
    GoRoute(path: '/missions', pageBuilder: (_, s) => _fade(const MissionsScreen(), s)),
    GoRoute(path: '/missions/:id', pageBuilder: (_, s) => _fade(MissionScreen(key: ValueKey('mission-${s.pathParameters['id']}'), id: s.pathParameters['id']!), s)),
    GoRoute(path: '/radio', pageBuilder: (_, s) => _fade(const RadioScreen(), s)),
    GoRoute(path: '/radio/:id', pageBuilder: (_, s) => _fade(SegmentScreen(key: ValueKey('radio-${s.pathParameters['id']}'), id: s.pathParameters['id']!), s)),
    GoRoute(path: '/cinema/:id', pageBuilder: (_, s) => _fade(SceneScreen(key: ValueKey('cine-${s.pathParameters['id']}'), id: s.pathParameters['id']!), s)),
    GoRoute(path: '/progress', pageBuilder: (_, s) => _fade(const ProgressScreen(), s)),
    GoRoute(path: '/premium', pageBuilder: (_, s) => _fade(PremiumScreen(key: ValueKey('premium-${s.uri.queryParameters['pack']}'), pack: s.uri.queryParameters['pack']), s)),
    GoRoute(path: '/certificate/:level', pageBuilder: (_, s) => _fade(CertificateScreen(key: ValueKey('cert-${s.pathParameters['level']}'), level: int.tryParse(s.pathParameters['level']!) ?? 1), s)),
    GoRoute(path: '/leitner', pageBuilder: (_, s) => _fade(const LeitnerScreen(), s)),
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
