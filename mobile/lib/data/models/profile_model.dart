class UserProfile {
  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String? avatarPath;

  const UserProfile({
    required this.id,
    this.email = '',
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.avatarPath,
  });

  String get displayLabel {
    if (fullName != null && fullName!.trim().isNotEmpty) return fullName!.trim();
    if (email.trim().isNotEmpty) return email.trim();
    if (phone != null && phone!.trim().isNotEmpty) return phone!.trim();
    return 'Varanti User';
  }

  String get initials {
    final source = displayLabel;
    final parts = source.split(RegExp(r'[\s@._-]+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'V';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName: json['full_name']?.toString(),
      phone: json['phone']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      avatarPath: json['avatar_path']?.toString(),
    );
  }

  UserProfile copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? avatarPath,
  }) {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarPath: avatarPath ?? this.avatarPath,
    );
  }
}
