/// A check-in/check-out event that couldn't reach the server (no signal,
/// airplane mode, etc.) and is waiting to be resent once connectivity is
/// back. Holds exactly what [EventService.sendEvent] needs to replay the
/// call later, plus bookkeeping for the local queue.
class PendingEvent {
  final String id;
  final String flag;
  final String companyCode;
  final String employeeId;
  final String employeeName;
  final String? prCode;
  final String? employeeDomain;
  final String zoneName;
  final String attendanceDate;
  final String attendanceTime;
  final String? selfieImgBase64;
  final String? jobId;
  final String? jobName;
  final String? accessToken;
  final double? latitude;
  final double? longitude;
  final String? managerId;
  final String? managerName;
  final String queuedAt;

  PendingEvent({
    required this.id,
    required this.flag,
    required this.companyCode,
    required this.employeeId,
    required this.employeeName,
    this.prCode,
    this.employeeDomain,
    required this.zoneName,
    required this.attendanceDate,
    required this.attendanceTime,
    this.selfieImgBase64,
    this.jobId,
    this.jobName,
    this.accessToken,
    this.latitude,
    this.longitude,
    this.managerId,
    this.managerName,
    required this.queuedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'flag': flag,
        'company_code': companyCode,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'pr_code': prCode,
        'employee_domain': employeeDomain,
        'zone_name': zoneName,
        'attendance_date': attendanceDate,
        'attendance_time': attendanceTime,
        'selfie_img': selfieImgBase64,
        'job_id': jobId,
        'job_name': jobName,
        'access_token': accessToken,
        'latitude': latitude,
        'longitude': longitude,
        'manager_id': managerId,
        'manager_name': managerName,
        'queued_at': queuedAt,
      };

  factory PendingEvent.fromJson(Map<String, dynamic> json) => PendingEvent(
        id: json['id'] as String,
        flag: json['flag'] as String,
        companyCode: json['company_code'] as String,
        employeeId: json['employee_id'] as String,
        employeeName: json['employee_name'] as String,
        prCode: json['pr_code'] as String?,
        employeeDomain: json['employee_domain'] as String?,
        zoneName: json['zone_name'] as String? ?? '',
        attendanceDate: json['attendance_date'] as String,
        attendanceTime: json['attendance_time'] as String,
        selfieImgBase64: json['selfie_img'] as String?,
        jobId: json['job_id'] as String?,
        jobName: json['job_name'] as String?,
        accessToken: json['access_token'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        managerId: json['manager_id'] as String?,
        managerName: json['manager_name'] as String?,
        queuedAt: json['queued_at'] as String? ?? '',
      );
}
