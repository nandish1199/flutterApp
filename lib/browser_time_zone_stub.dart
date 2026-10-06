String localTimeZoneName() =>
    throw UnsupportedError('A browser time zone is only available on web.');

Future<void> showBrowserNotification(String title, String body) async {
  throw UnsupportedError('Browser notifications are only available on web.');
}
