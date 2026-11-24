import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:jemput_ban/models.dart';
import 'package:jemput_ban/repo.dart';

ReportDraft draft(String nib, String addr, int motor, double kg, List<int> photoSeed) {
  final d = ReportDraft()
    ..name = 'Bengkel Uji'
    ..whatsapp = '0812'
    ..nib = nib
    ..address = addr
    ..motor = motor
    ..weightKg = kg
    ..consent = true
    ..bankName = 'BCA'
    ..accountNo = '1234564821'
    ..accountHolder = 'Uji';
  d.files.add(DraftFile('nib', 'nib.png', Uint8List.fromList([9, 9, 9])));
  for (final s in photoSeed) {
    d.files.add(DraftFile('photo', 'p$s.png', Uint8List.fromList([s, s + 1, s + 2])));
  }
  return d;
}

void main() {
  test('duplicate photo, duplicate address, weight range, survey mismatch', () async {
    final repo = DemoRepo();
    await repo.demoLogin(Role.reporter);
    final c1 = await repo.submitReport(draft('1111111111111', 'Jl. Uji 1', 10, 30, [1, 2]));
    final c2 = await repo.submitReport(draft('2222222222222', 'jl uji 1!', 10, 900, [1, 7]));
    final all = await repo.allReports();
    final r1 = all.firstWhere((r) => r.code == c1);
    final r2 = all.firstWhere((r) => r.code == c2);
    expect(r1.flags.where((f) => f.level != 'ok'), isEmpty);
    expect(r2.flags.map((f) => f.kind), containsAll(['duplicate_photo', 'duplicate_report', 'weight_range']));
    expect(r2.hasBad, isTrue);

    await repo.demoLogin(Role.finance);
    final n = await repo.decide(r1, ReportStatus.approved, '', countedTotal: 5);
    expect(n.flags.any((f) => f.kind == 'count_mismatch' && f.level == 'bad'), isTrue);
    expect((await repo.partners()).any((p) => p.nib == '1111111111111'), isTrue);
    expect((await repo.bankFor(n))?['masked'], '******4821');
    final paid = await repo.markPaid(n, 'TRF1');
    expect(paid.paymentStatus, 'paid');

    await repo.demoLogin(Role.admin);
    expect(await repo.bankFor(n), isNull); // plain admin cannot see bank
  });

  test('local flags: nib format and caps', () {
    final f = localFlags(nib: '123', motor: 600, car: 0, truck: 0, weightKg: 1000);
    expect(f.map((x) => x.kind), containsAll(['nib_format', 'count_cap']));
  });
}
