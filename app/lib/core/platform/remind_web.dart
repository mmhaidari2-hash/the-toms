import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// PWA notifications where the browser allows them (Android Chrome, desktop; iOS 16.4+ only for
/// home-screen apps). There is no reliable way to schedule a notification from a web page without a
/// push server, so the app nudges when it is opened after the reminder time, and offers a calendar
/// (.ics) reminder that works everywhere, including iPhone.
bool get _supported => (web.window as JSObject).has('Notification');

String notificationStatus() => _supported ? web.Notification.permission : 'unsupported';

Future<String> requestNotifications() async {
  if (!_supported) return 'unsupported';
  try {
    return (await web.Notification.requestPermission().toDart).toDart;
  } catch (_) {
    return 'denied';
  }
}

Future<bool> showNotification(String title, String body) async {
  if (notificationStatus() != 'granted') return false;
  try {
    final reg = await web.window.navigator.serviceWorker.ready.toDart;
    await reg.showNotification(title, web.NotificationOptions(body: body, icon: 'icons/nl3-192.png', tag: 'daily')).toDart;
    return true;
  } catch (_) {
    try {
      web.Notification(title, web.NotificationOptions(body: body, icon: 'icons/nl3-192.png'));
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Saves a text file (e.g. reminder.ics). On iPhone, Safari offers "Add to Calendar".
bool downloadFile(String name, String mime, String text) {
  try {
    final blob = web.Blob([text.toJS].toJS, web.BlobPropertyBag(type: mime));
    final url = web.URL.createObjectURL(blob);
    final a = web.HTMLAnchorElement()
      ..href = url
      ..download = name;
    web.document.body!.append(a);
    a.click();
    a.remove();
    return true;
  } catch (_) {
    return false;
  }
}
