class UserProfile {
  const UserProfile({
    this.name = '',
    this.email = '',
    this.allergies = '',
    this.emergencyContact = '',
  });

  final String name;
  final String email;
  final String allergies;
  final String emergencyContact;

  UserProfile copyWith({
    String? name,
    String? email,
    String? allergies,
    String? emergencyContact,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      allergies: allergies ?? this.allergies,
      emergencyContact: emergencyContact ?? this.emergencyContact,
    );
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'email': email,
        'allergies': allergies,
        'emergencyContact': emergencyContact,
      };

  factory UserProfile.fromJson(Map<String, Object?> json) {
    return UserProfile(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      allergies: json['allergies'] as String? ?? '',
      emergencyContact: json['emergencyContact'] as String? ?? '',
    );
  }
}
