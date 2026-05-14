class Employee {
  final String accessToken;
  final String employeeId;
  final String employeeName;
  final String companyCode;
  final String companyName;
  final String? employeeImg;
  final String? companyLogo;
  final List<String> roles;
  final List<String> permissions;
  final String? prCode;
  final String? employeeDomain;

  Employee({
    required this.accessToken,
    required this.employeeId,
    required this.employeeName,
    required this.companyCode,
    required this.companyName,
    this.employeeImg,
    this.companyLogo,
    required this.roles,
    required this.permissions,
    this.prCode,
    this.employeeDomain,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      accessToken: json['access_token']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      employeeName: json['employee_name']?.toString() ?? '',
      companyCode: json['company_code']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      employeeImg: json['employee_img']?.toString(),
      companyLogo: json['company_logo']?.toString(),
      roles: List<String>.from((json['roles'] ?? []).map((e) => e.toString())),
      permissions: List<String>.from((json['permissions'] ?? []).map((e) => e.toString())),
      prCode: json['pr_code']?.toString(),
      employeeDomain: json['employee_domain']?.toString(),
    );
  }
}
