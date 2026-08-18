import 'package:flutter_test/flutter_test.dart';
import 'package:medirecord/core/database/database_helper.dart';
import 'package:medirecord/shared/models/patient.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Patient p(String id, String first, String last, String phone) => Patient(
        id: id,
        firstName: first,
        lastName: last,
        age: 30,
        gender: 'Male',
        phone: phone,
        address: null,
        bloodGroup: null,
        emergencyContactName: null,
        emergencyContactPhone: null,
        photoUrl: null,
        createdBy: 'test',
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      );

  test('duplicate detection groups same phone', () async {
    final db = DatabaseHelper();
    await db.insertPatient(p('a', 'Ali', 'Hassan', '07700000001'));
    await db.insertPatient(p('b', 'Ali', 'Hassan', '07700000001'));
    final groups = await db.findDuplicatePatients();
    expect(groups, isNotEmpty,
        reason: 'two patients with same name/phone must form a group');
    expect(groups.any((g) => g.any((m) => m['id'] == 'a') && g.any((m) => m['id'] == 'b')),
        isTrue, reason: 'group must contain both ids');
  });

  test('merge removes the duplicate from storage', () async {
    final db = DatabaseHelper();
    await db.insertPatient(p('keep', 'Ali', 'Hassan', '07700000001'));
    await db.insertPatient(p('remove', 'Ali', 'Hassan', '07700000001'));
    final r = await db.mergePatients('keep', 'remove');
    expect(r, 1, reason: 'merge must report success');
    final all = await db.getAllPatients();
    expect(all.any((x) => x.id == 'remove'), isFalse,
        reason: 'duplicate must be deleted from storage');
    expect(all.any((x) => x.id == 'keep'), isTrue,
        reason: 'kept patient must survive');
    expect(all.length, 1, reason: 'exactly one patient must remain');
  });
}
