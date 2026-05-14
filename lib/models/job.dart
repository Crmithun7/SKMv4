class Job {
  final dynamic id;
  final String companyCode;
  final String jobName;
  final Map<String, dynamic> raw;

  Job({
    required this.id,
    required this.companyCode,
    required this.jobName,
    required this.raw,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'],
      companyCode: json['company_code']?.toString() ?? '',
      jobName: (json['job_name'] ?? json['job_title'] ?? json['title'] ?? 'Job #${json['id']}')
          .toString(),
      raw: json,
    );
  }
}
