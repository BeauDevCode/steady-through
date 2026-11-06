import 'package:url_launcher/url_launcher.dart';

/// The explicit handoff boundary. Opening an app does not confirm delivery.
abstract class PhoneActions {
  Future<bool> openPhone(String number);
  Future<bool> openSms(String number);
}

class UrlLauncherPhoneActions implements PhoneActions {
  const UrlLauncherPhoneActions();

  Future<bool> _open(String scheme, String number) async {
    try {
      return await launchUrl(Uri(scheme: scheme, path: number));
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openPhone(String number) => _open('tel', number);
  @override
  Future<bool> openSms(String number) => _open('sms', number);
}
