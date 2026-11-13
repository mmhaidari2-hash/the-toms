import '../../core/data/providers.dart';
import '../../core/data/repository.dart';
import '../grammar/grammar_data.dart';
import '../grammar/school_screen.dart';
import 'library_data.dart';
import 'reading_state.dart';

/// Which Library shelves are at the learner's level. Since t310 a shelf above the level is NOT a hard lock:
/// a book still opens with an "above your level" notice. Monetisation (Option B) is separate: in a paid
/// build ([ProgressController.paywallOn]) only A1/A2 books and the first book of each section stay free,
/// plus any book already started. While [PremiumConfig.betaFree] is true, [paywallOn] is false and nothing
/// locks.
/// Original rule: which Library shelves are open. Same rule as the Grammar School classes, so a learner meets
/// each level at the same time everywhere: A1 is always open; a higher shelf opens when the course
/// reaches that level, or the previous Grammar class is passed — or when the previous shelf is
/// finished, or a book on it was already started (nobody loses a book they're reading).
class LibraryGate {
  final ProgressController ctrl;
  final GrammarGate grammar;
  final List<Book> books;
  LibraryGate(this.ctrl, ContentBundle? content, List<GTopic> topics, this.books, {bool unlockAll = false})
      : grammar = GrammarGate(ctrl, content, topics, unlockAll: unlockAll);

  List<Book> of(String code) => books.where((b) => b.level == code).toList();
  bool started(Book b) => ctrl.bookDone(b.id) || List.generate(b.chapters.length, (i) => ctrl.readScore(b.id, i)).any((v) => v != null);

  bool shelfOpen(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    if (i <= 0 || grammar.unlockAll) return true;
    final prev = of(Library.levels[i - 1].code);
    if (prev.isNotEmpty && prev.every((b) => ctrl.bookDone(b.id))) return true;
    if (of(code).any(started)) return true;
    return grammar.classOpen(code);
  }

  /// Above the learner's current level: the book still opens (any book can be picked up), with a notice.
  bool aboveLevel(Book b) => !shelfOpen(b.level);

  /// The "above your level" notice (EN, FA).
  static (String, String) aboveNotice(String code) {
    final (en, fa) = why(code);
    return (
      'This book is above your current level ($code). You can still read it — tap any word for help. $en',
      'این کتاب از سطح فعلی‌ات ($code) بالاتر است. باز هم می‌توانی بخوانی‌اش؛ برای کمک روی هر کلمه بزن. $fa',
    );
  }

  /// Why a shelf is not yet at your level (EN, FA).
  static (String, String) why(String code) {
    final i = Library.levels.indexWhere((l) => l.code == code);
    final prev = i > 0 ? Library.levels[i - 1].code : 'A1';
    final lv = Grammar.courseLevel(code);
    return (
      'The $code shelf opens at Level $lv of the course, when you pass Grammar Class $prev, or when you finish the $prev shelf.',
      'قفسهٔ $code در سطح $lv دوره، با قبولی در کلاس گرامر $prev یا با تمام کردن قفسهٔ $prev باز می‌شود.',
    );
  }

  /// Section shelves sorted by CEFR level, then id (stable "first book of the section").
  static List<Book> sectionSorted(List<Book> all, String category) {
    int rank(String lv) {
      final i = Library.levels.indexWhere((l) => l.code == lv);
      return i < 0 ? 99 : i;
    }
    return all.where((b) => b.category == category).toList()
      ..sort((a, b) {
        final c = rank(a.level).compareTo(rank(b.level));
        return c != 0 ? c : a.id.compareTo(b.id);
      });
  }

  /// Free in a paid build: every A1 and A2 book, plus the first book of its section.
  static bool bookFree(Book b, List<Book> all) {
    if (b.level == 'A1' || b.level == 'A2') return true;
    final shelf = sectionSorted(all, b.category);
    return shelf.isNotEmpty && shelf.first.id == b.id;
  }

  static bool alreadyStarted(ProgressController ctrl, Book b) =>
      ctrl.bookStarted(b) || List.generate(b.chapters.length, (i) => ctrl.readScore(b.id, i)).any((v) => v != null);

  /// Hard lock only when the paywall is on, the book is not free, and the learner has not already started it.
  static bool isPremiumLocked(ProgressController ctrl, Book b, List<Book> all) =>
      ctrl.paywallOn && !bookFree(b, all) && !alreadyStarted(ctrl, b);

  bool premiumLocked(Book b) => isPremiumLocked(ctrl, b, books);

  /// Paywall notice on a locked book (EN, FA).
  static const (String, String) premiumNotice = (
    'This book is in the Premium library. A1 and A2 shelves, and the first book of every section, stay free. A book you have already started stays open.',
    'این کتاب در بخش ویژهٔ کتابخانه است. قفسه‌های A1 و A2، و نخستین کتاب هر بخش، رایگان می‌مانند. کتابی که شروع کرده‌ای باز می‌ماند.',
  );

  static const (String, String) premiumRibbon = ('Premium', 'ویژه');

}
