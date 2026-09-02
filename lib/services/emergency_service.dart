import 'package:url_launcher/url_launcher.dart';

class EmergencyService {
  const EmergencyService();

  /// Zimbabwe national emergency number.
  static const emergencyNumber = '999';

  Future<bool> callEmergencyServices() async {
    return launchUrl(Uri(scheme: 'tel', path: emergencyNumber));
  }

  Future<bool> findNearestClinic() async {
    return launchUrl(
      Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=nearest+clinic',
      ),
      mode: LaunchMode.externalApplication,
    );
  }
}
