/// Non-web builds: native reminders come with the store apps (see MASTER_BOOK).
Future<String> requestNotifications() async => 'unsupported';
String notificationStatus() => 'unsupported';
Future<bool> showNotification(String title, String body) async => false;
bool downloadFile(String name, String mime, String text) => false;
