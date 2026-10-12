import 'package:flutter_test/flutter_test.dart';
import 'package:skmcam/models/zone.dart';

void main() {
  group('Zone.fromJson', () {
    test('parses a fully populated zone', () {
      final zone = Zone.fromJson({
        'zone_id': 1,
        'zone_name': 'Main Site',
        'latitude': 12.9716,
        'longitude': 77.5946,
        'radius': 150,
        'project_id': 7,
        'project_code': 'PRJ-7',
        'project_name': 'Metro Line',
        'is_active': true,
      });

      expect(zone.zoneName, 'Main Site');
      expect(zone.latitude, 12.9716);
      expect(zone.longitude, 77.5946);
      expect(zone.radius, 150.0);
      expect(zone.projectName, 'Metro Line');
      expect(zone.isActive, isTrue);
    });

    test('parses numeric fields given as strings', () {
      final zone = Zone.fromJson({
        'zone_id': 'z1',
        'zone_name': 'Site B',
        'latitude': '12.34',
        'longitude': '56.78',
        'radius': '100',
        'is_active': true,
      });

      expect(zone.latitude, 12.34);
      expect(zone.longitude, 56.78);
      expect(zone.radius, 100.0);
    });

    test('defaults zone_name to empty string and lat/lng/radius to null when missing', () {
      final zone = Zone.fromJson({'is_active': false});

      expect(zone.zoneName, '');
      expect(zone.latitude, isNull);
      expect(zone.longitude, isNull);
      expect(zone.radius, isNull);
      expect(zone.projectName, isNull);
      expect(zone.isActive, isFalse);
    });

    test('treats any non-true is_active value as inactive', () {
      expect(Zone.fromJson({'zone_name': 'A', 'is_active': null}).isActive, isFalse);
      expect(Zone.fromJson({'zone_name': 'A', 'is_active': 'true'}).isActive, isFalse);
      expect(Zone.fromJson({'zone_name': 'A'}).isActive, isFalse);
    });
  });
}
