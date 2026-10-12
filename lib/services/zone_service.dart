import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/error_utils.dart';
import '../models/zone.dart';

/// The company's zones plus its zone control switch.
class ZoneSetup {
  final List<Zone> zones;

  /// When true the company only allows check-in / check-out inside one of
  /// [zones] (zone control, set by the admin on the Company Zones page).
  final bool restrictToZones;

  const ZoneSetup({required this.zones, required this.restrictToZones});
}

class ZoneService {
  static const String _baseUrl = 'https://api.skm-tas.com';
  static const String _cacheKey = 'zone_setup_';

  /// Fetches the company's configured geofence zones (with their linked
  /// project, via the admin zones-advance join) and its zone control switch.
  /// The last good reply is cached, so zone control still works offline.
  static Future<ZoneSetup> getZoneSetup(String companyCode) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$_baseUrl/api/v1/admin_and_super_admin/zones-advance'
          '?company_code=${Uri.encodeQueryComponent(companyCode)}',
        ),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception(slowNetworkMessage),
      );

      if (response.statusCode != 200) {
        throw Exception(serverErrorMessage(response,
            fallback: "Couldn't load your work zones. Please try again."));
      }

      final setup = _parse(response.body);
      if (setup == null) throw Exception(badReplyMessage);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_cacheKey$companyCode', response.body);
      } catch (_) {}
      return setup;
    } catch (e) {
      final cached = await _cached(companyCode);
      if (cached != null) return cached;
      rethrow;
    }
  }

  static Future<ZoneSetup?> _cached(String companyCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final body = prefs.getString('$_cacheKey$companyCode');
      return body == null ? null : _parse(body);
    } catch (_) {
      return null;
    }
  }

  static ZoneSetup? _parse(String body) {
    try {
      final data = jsonDecode(body);
      if (data is! Map) return null;
      final List<dynamic> list = data['zones'] ?? [];
      return ZoneSetup(
        zones: list
            .map((e) => Zone.fromJson(e as Map<String, dynamic>))
            .where((z) => z.isActive)
            .toList(),
        restrictToZones: data['restrict_to_zones'] == true,
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns the zone whose geofence (lat/lng/radius, radius in meters)
  /// contains the given point, or null if the point falls outside every
  /// configured zone (or the company has none). When a point falls inside
  /// more than one overlapping zone, the closest center wins.
  static Zone? matchZone(List<Zone> zones, double lat, double lng) {
    Zone? best;
    double? bestDistance;

    for (final zone in zones) {
      if (zone.latitude == null || zone.longitude == null || zone.radius == null) {
        continue;
      }

      final distance = Geolocator.distanceBetween(
        lat,
        lng,
        zone.latitude!,
        zone.longitude!,
      );

      if (distance <= zone.radius!) {
        if (bestDistance == null || distance < bestDistance) {
          best = zone;
          bestDistance = distance;
        }
      }
    }

    return best;
  }
}
