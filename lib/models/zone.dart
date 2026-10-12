class Zone {
  final dynamic zoneId;
  final String zoneName;
  final double? latitude;
  final double? longitude;
  final double? radius; // meters
  final dynamic projectId;
  final String? projectCode;
  final String? projectName;
  final bool isActive;

  Zone({
    required this.zoneId,
    required this.zoneName,
    this.latitude,
    this.longitude,
    this.radius,
    this.projectId,
    this.projectCode,
    this.projectName,
    required this.isActive,
  });

  factory Zone.fromJson(Map<String, dynamic> json) {
    double? toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return Zone(
      zoneId: json['zone_id'],
      zoneName: (json['zone_name'] ?? '').toString(),
      latitude: toDouble(json['latitude']),
      longitude: toDouble(json['longitude']),
      radius: toDouble(json['radius']),
      projectId: json['project_id'],
      projectCode: json['project_code']?.toString(),
      projectName: json['project_name']?.toString(),
      isActive: json['is_active'] == true,
    );
  }
}
