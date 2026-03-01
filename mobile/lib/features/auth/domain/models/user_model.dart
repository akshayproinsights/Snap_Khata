class User {
  final String username;
  final String? name;
  final String? email;
  final String r2Bucket;
  final String sheetId;
  final String? dashboardUrl;

  User({
    required this.username,
    this.name,
    this.email,
    required this.r2Bucket,
    required this.sheetId,
    this.dashboardUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] as String? ?? '',
      name: json['name'] as String?,
      email: json['email'] as String?,
      r2Bucket: json['r2_bucket'] as String? ?? '',
      sheetId: json['sheet_id'] as String? ?? '',
      dashboardUrl: json['dashboard_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'name': name,
      'email': email,
      'r2_bucket': r2Bucket,
      'sheet_id': sheetId,
      'dashboard_url': dashboardUrl,
    };
  }

  @override
  String toString() =>
      'User(username: $username, name: $name, email: $email, r2Bucket: $r2Bucket)';
}
