import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

@JS()
external JSObject get globalThis;

String localTimeZoneName() {
  final intl = globalThis.getProperty<JSObject>('Intl'.toJS);
  final dateTimeFormat = intl.getProperty<JSFunction>('DateTimeFormat'.toJS);
  final formatter = dateTimeFormat.callAsConstructor<JSObject>();
  final resolvedOptions = formatter.callMethod<JSObject>(
    'resolvedOptions'.toJS,
  );
  return resolvedOptions.getProperty<JSString>('timeZone'.toJS).toDart;
}

Future<void> showBrowserNotification(String title, String body) async {
  web.Notification(
    title,
    web.NotificationOptions(body: body, icon: '/icons/Icon-192.png'),
  );
}
