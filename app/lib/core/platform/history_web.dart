import 'package:web/web.dart' as web;

/// If the app is opened directly on a deep link (e.g. #/lesson/x after a refresh), put the map
/// underneath it in the browser history, so browser back / iOS swipe-back returns to the map
/// instead of leaving the app.
void seedRootHistory() {
  final h = web.window.location.hash;
  if (h.isEmpty || h == '#' || h == '#/') return;
  final base = web.window.location.href.split('#').first;
  web.window.history.replaceState(null, '', '$base#/');
  web.window.history.pushState(null, '', '$base$h');
}

/// In-app Back on the web walks the browser history (so a later browser/iOS back
/// does not re-open the screen we just left). Returns false when not handled.
bool historyBack() {
  if (web.window.history.length <= 1) return false;
  web.window.history.back();
  return true;
}
