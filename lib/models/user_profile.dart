class UserProfile {
  const UserProfile({
    this.name = '',
    this.email = '',
    this.allergies = '',
    this.medicalConditions = '',
    this.currentMedications = '',
    this.emergencyContact = '',
  });

  final String name;
  final String email;
  final String allergies;
  final String medicalConditions;
  final String currentMedications;
  final String emergencyContact;

  UserProfile copyWith({
    String? name,
    String? email,
    String? allergies,
    String? medicalConditions,
    String? currentMedications,
    String? emergencyContact,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      allergies: allergies ?? this.allergies,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      currentMedications: currentMedications ?? this.currentMedications,
      emergencyContact: emergencyContact ?? this.emergencyContact,
    );
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'email': email,
        'allergies': allergies,
        'medicalConditions': medicalConditions,
        'currentMedications': currentMedications,
        'emergencyContact': emergencyContact,
      };

  factory UserProfile.fromJson(Map<String, Object?> json) {
    return UserProfile(
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      allergies: json['allergies'] as String? ?? '',
      medicalConditions: json['medicalConditions'] as String? ?? '',
      currentMedications: json['currentMedications'] as String? ?? '',
      emergencyContact: json['emergencyContact'] as String? ?? '',
    );
  }
}
