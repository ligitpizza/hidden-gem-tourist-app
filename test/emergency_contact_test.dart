import 'package:collab/features/travel_prep/model/emergency_contact.dart';
import 'package:collab/features/travel_prep/model/emergency_contact_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('emergency contact persists lock-screen consent', () {
    final restored = EmergencyContact.fromJson(contact.toJson());
    expect(restored.name, contact.name);
    expect(restored.phone, contact.phone);
    expect(restored.availableWhenLocked, isTrue);
  });

  test('Supabase row codec maps every persisted field', () {
    final row = EmergencyContactRowCodec.toRow(
      contact,
      userId: 'user-a',
      position: 3,
    );
    final restored = EmergencyContactRowCodec.fromRow(row);

    expect(row['user_id'], 'user-a');
    expect(row['position'], 3);
    expect(restored.toJson(), contact.toJson());
  });

  test('existing local contacts migrate to an empty cloud account', () async {
    SharedPreferences.setMockInitialValues({
      'travel_emergency_contacts_user-a': '[${_json(contact)}]',
    });
    final remote = _FakeEmergencyContactRemote();
    final repository = EmergencyContactRepository(
      userId: 'user-a',
      remote: remote,
    );

    expect((await repository.load()).single.toJson(), contact.toJson());
    expect(remote.values['user-a']!.single.toJson(), contact.toJson());
    expect(remote.replaceCalls, 1);

    await repository.load();
    expect(remote.replaceCalls, 1);
  });

  test('cloud contacts refresh the local cache in cloud order', () async {
    final second = _contact(id: '2', name: 'Aminah');
    final remote = _FakeEmergencyContactRemote()
      ..values['user-a'] = [second, contact];
    final repository = EmergencyContactRepository(
      userId: 'user-a',
      remote: remote,
    );

    expect((await repository.load()).map((item) => item.id), [
      second.id,
      contact.id,
    ]);
    remote.values['user-a'] = [];
    expect(await repository.load(), isEmpty);
  });

  test('save synchronizes adds, edits, deletes, and delete-all', () async {
    final remote = _FakeEmergencyContactRemote();
    final repository = EmergencyContactRepository(
      userId: 'user-a',
      remote: remote,
    );

    await repository.save([contact]);
    expect(remote.values['user-a']!.single.toJson(), contact.toJson());

    final edited = _contact(id: contact.id, name: 'Jane Updated');
    await repository.save([edited]);
    expect(remote.values['user-a']!.single.toJson(), edited.toJson());

    await repository.save([]);
    expect(remote.values['user-a'], isEmpty);
  });

  test('failed cloud save remains local and retries on load', () async {
    final remote = _FakeEmergencyContactRemote()..failReplace = true;
    final repository = EmergencyContactRepository(
      userId: 'user-a',
      remote: remote,
    );

    await repository.save([contact]);
    expect((await repository.load()).single.toJson(), contact.toJson());
    expect(remote.values['user-a'], isNull);

    remote.failReplace = false;
    expect((await repository.load()).single.toJson(), contact.toJson());
    expect(remote.values['user-a']!.single.toJson(), contact.toJson());
  });

  test('local emergency-contact caches are isolated by user ID', () async {
    final first = EmergencyContactRepository(userId: 'user-a');
    final second = EmergencyContactRepository(userId: 'user-b');

    await first.save([contact]);
    expect((await first.load()).single.toJson(), contact.toJson());
    expect(await second.load(), isEmpty);
  });
}

String _json(EmergencyContact value) =>
    '''
{"id":"${value.id}","name":"${value.name}","relationship":"${value.relationship}","phone":"${value.phone}","country":"${value.country}","email":"${value.email}","notes":"${value.notes}","availableWhenLocked":${value.availableWhenLocked}}
'''
        .trim();

EmergencyContact _contact({required String id, required String name}) =>
    EmergencyContact(
      id: id,
      name: name,
      relationship: 'Family',
      phone: '+601100000$id',
      country: 'Malaysia',
      availableWhenLocked: false,
    );

class _FakeEmergencyContactRemote implements EmergencyContactRemoteDataSource {
  final Map<String, List<EmergencyContact>> values = {};
  bool failReplace = false;
  int replaceCalls = 0;

  @override
  Future<List<EmergencyContact>> fetchAll(String userId) async =>
      List.of(values[userId] ?? const []);

  @override
  Future<void> replaceAll(
    String userId,
    List<EmergencyContact> contacts,
  ) async {
    replaceCalls++;
    if (failReplace) throw StateError('offline');
    values[userId] = List.of(contacts);
  }
}
