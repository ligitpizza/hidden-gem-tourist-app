class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.relationship,
    required this.phone,
    required this.country,
    required this.availableWhenLocked,
    this.email = '',
    this.notes = '',
  });

  final String id;
  final String name;
  final String relationship;
  final String phone;
  final String country;
  final String email;
  final String notes;
  final bool availableWhenLocked;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'relationship': relationship,
    'phone': phone,
    'country': country,
    'email': email,
    'notes': notes,
    'availableWhenLocked': availableWhenLocked,
  };

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: '${json['id']}',
        name: '${json['name'] ?? ''}',
        relationship: '${json['relationship'] ?? ''}',
        phone: '${json['phone'] ?? ''}',
        country: '${json['country'] ?? ''}',
        email: '${json['email'] ?? ''}',
        notes: '${json['notes'] ?? ''}',
        availableWhenLocked: json['availableWhenLocked'] == true,
      );
}
