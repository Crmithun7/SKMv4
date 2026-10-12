import 'package:flutter_test/flutter_test.dart';
import 'package:skmcam/models/zone.dart';
import 'package:skmcam/services/zone_service.dart';

Zone _zone(String name, {double? lat, double? lng, double? radius}) {
  return Zone(
    zoneId: name,
    zoneName: name,
    latitude: lat,
    longitude: lng,
    radius: radius,
    isActive: true,
  );
}

void main() {
  group('ZoneService.matchZone', () {
    test('returns null when there are no zones', () {
      expect(ZoneService.matchZone([], 12.9716, 77.5946), isNull);
    });

    test('returns null when the point is outside every zone', () {
      final zones = [_zone('Site A', lat: 12.9716, lng: 77.5946, radius: 50)];
      // ~11km away — well outside a 50m radius.
      final match = ZoneService.matchZone(zones, 13.0827, 80.2707);
      expect(match, isNull);
    });

    test('matches the zone containing the point', () {
      final zones = [_zone('Site A', lat: 12.9716, lng: 77.5946, radius: 200)];
      final match = ZoneService.matchZone(zones, 12.9716, 77.5946);
      expect(match?.zoneName, 'Site A');
    });

    test('picks the closest zone when the point falls inside multiple overlapping zones', () {
      final zones = [
        _zone('Far', lat: 12.9720, lng: 77.5950, radius: 500),
        _zone('Near', lat: 12.9716, lng: 77.5946, radius: 500),
      ];
      final match = ZoneService.matchZone(zones, 12.9716, 77.5946);
      expect(match?.zoneName, 'Near');
    });

    test('skips zones missing latitude, longitude or radius', () {
      final zones = [
        _zone('No radius', lat: 12.9716, lng: 77.5946, radius: null),
        _zone('No lat', lat: null, lng: 77.5946, radius: 100),
        _zone('Complete', lat: 12.9716, lng: 77.5946, radius: 100),
      ];
      final match = ZoneService.matchZone(zones, 12.9716, 77.5946);
      expect(match?.zoneName, 'Complete');
    });
  });
}
