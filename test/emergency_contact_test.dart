import 'package:collab/features/travel_prep/model/emergency_contact.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('emergency contact persists lock-screen consent', () {
    const contact = EmergencyContact(
      id: '1',
      name: 'Jane Doe',
      relationship: 'Sibling',
      phone: '+60123456789',
      country: 'Malaysia',
      email: 'jane@example.com',
      notes: 'Call first',
      availableWhenLocked: true,
    );

    final restored = EmergencyContact.fromJson(contact.toJson());
    expect(restored.name, contact.name);
    expect(restored.phone, contact.phone);
    expect(restored.availableWhenLocked, isTrue);
  });
}
