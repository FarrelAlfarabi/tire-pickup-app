import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

String sha256Hex(Uint8List b) => sha256.convert(b).toString();

String maskAccount(String n) =>
    n.length <= 4 ? n : '${'*' * (n.length - 4)}${n.substring(n.length - 4)}';

class AppError implements Exception {
  final String message;
  AppError(this.message);
  @override
  String toString() => message;
}

abstract class Repo {
  bool get isDemo;
  AppUser? get user;
  Future<void> signIn(String email, String password);
  Future<void> signUp(String name, String email, String password);
  Future<void> signOut();
  Future<void> demoLogin(Role role);

  /// Returns the report code, for example R-0001.
  Future<String> submitReport(ReportDraft d);
  Future<List<Report>> myReports();
  Future<List<Report>> allReports();
  Future<Report> decide(Report r, ReportStatus decision, String note,
      {int? countedTotal, double? countedKg});
  Future<Report> markPaid(Report r, String transferRef);
  Future<List<Partner>> partners();
  Future<void> setBlocked(Partner p, bool blocked, String reason);
  Future<Uint8List?> fileBytes(ReportFile f);

  /// Bank details. Only finance (and the owner) can read them. Returns a
  /// masked account number.
  Future<Map<String, String>?> bankFor(Report r);

  /// UU PDP: the user can ask to erase their personal data.
  Future<void> deleteMyData();
}

// ---------------------------------------------------------------------------
// Demo repo: everything lives in memory and disappears on reload.
// ---------------------------------------------------------------------------
class DemoRepo implements Repo {
  AppUser? _user;
  int _seq = 418;
  final List<Report> _reports = [];
  final List<Partner> _partners = [];
  final Map<String, Map<String, String>> _bank = {};

  DemoRepo() {
    final now = DateTime.now();
    Report seed(String code, String name, String type, int m, int c, int t,
            double kg, ReportStatus st, List<Flag> flags, int daysAgo) =>
        Report(
          id: code,
          code: code,
          reporterId: 'seed',
          name: name,
          whatsapp: '08xx-xxxx-xxxx',
          nib: '1234567890123',
          reporterType: type,
          address: 'Jl. Contoh No. 12, [Kota]',
          motor: m,
          car: c,
          truck: t,
          weightKg: kg,
          pickupDate: now.add(const Duration(days: 3)),
          createdAt: now.subtract(Duration(days: daysAgo)),
          status: st,
          flags: flags,
          files: const [
            ReportFile('nib', 'nib-contoh.jpg', 'seed-nib'),
            ReportFile('photo', 'ban-1.jpg', 'seed-p1'),
            ReportFile('photo', 'ban-2.jpg', 'seed-p2'),
          ],
        );
    _reports.addAll([
      seed('R-0415', 'Pengepul Contoh', 'freelancer', 20, 15, 0, 220,
          ReportStatus.submitted, [
        const Flag('weight_range', 'warn',
            'Berat 220 kg di luar kisaran 105 sampai 310 kg [contoh]'),
      ], 4),
      seed('R-0417', 'Ban Sumber Contoh', 'workshop', 10, 50, 0, 410,
          ReportStatus.submitted, const [], 2),
    ]);
    _partners.addAll([
      Partner(
          id: 'p1',
          name: 'Ban Sumber Contoh',
          type: 'workshop',
          address: 'Jl. Contoh No. 3, [Wilayah 1]',
          whatsapp: '08xx-xxxx-xxxx',
          nib: '1234567890123',
          lastPickup: now.subtract(const Duration(days: 20)),
          pickups: 9),
      Partner(
          id: 'p2',
          name: 'Bengkel Contoh Abadi',
          type: 'workshop',
          address: 'Jl. Contoh No. 9, [Wilayah 2]',
          whatsapp: '08xx-xxxx-xxxx',
          nib: '1234567890124',
          blocked: true,
          blockReason: 'Foto ganda terdeteksi',
          lastPickup: now.subtract(const Duration(days: 75)),
          pickups: 1),
    ]);
  }

  @override
  bool get isDemo => true;
  @override
  AppUser? get user => _user;

  @override
  Future<void> signIn(String email, String password) async =>
      throw AppError('Mode contoh: pakai tombol masuk di layar awal.');
  @override
  Future<void> signUp(String name, String email, String password) async =>
      throw AppError('Mode contoh: pakai tombol masuk di layar awal.');
  @override
  Future<void> signOut() async => _user = null;
  @override
  Future<void> demoLogin(Role role) async {
    _user = role == Role.reporter
        ? const AppUser('u-demo', 'Pelapor Contoh', 'pelapor@contoh.id', Role.reporter)
        : AppUser('a-demo', 'Admin Contoh', 'admin@contoh.id', role);
  }

  @override
  Future<String> submitReport(ReportDraft d) async {
    final u = _user!;
    final files = [
      for (final f in d.files)
        ReportFile(f.kind, f.name, sha256Hex(f.bytes), bytes: f.bytes)
    ];
    final flags = <Flag>[...localFlags(
        nib: d.nib,
        motor: d.motor,
        car: d.car,
        truck: d.truck,
        weightKg: d.weightKg)];
    // Duplicate photo: same SHA-256 as any file in any other report.
    final known = {
      for (final r in _reports)
        for (final f in r.files.where((f) => f.kind == 'photo')) f.hash: r.code
    };
    for (final f in files.where((f) => f.kind == 'photo')) {
      final hit = known[f.hash];
      if (hit != null) {
        flags.add(Flag('duplicate_photo', 'bad',
            'Foto "${f.name}" sama persis dengan foto di laporan $hit.'));
      }
    }
    // Duplicate report: same NIB or same address in the last 30 days.
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final r in _reports) {
      if (r.status == ReportStatus.rejected || r.createdAt.isBefore(cutoff)) continue;
      if (r.nib == d.nib || norm(r.address) == norm(d.address)) {
        flags.add(Flag('duplicate_report', 'warn',
            'NIB atau alamat sama dengan laporan ${r.code} dalam 30 hari terakhir.'));
        break;
      }
    }
    final code = 'R-${(++_seq).toString().padLeft(4, '0')}';
    _bank[code] = {
      'bank': d.bankName,
      'masked': maskAccount(d.accountNo),
      'holder': d.accountHolder,
    };
    _reports.insert(
        0,
        Report(
          id: code,
          code: code,
          reporterId: u.id,
          name: d.name,
          whatsapp: d.whatsapp,
          nib: d.nib,
          reporterType: d.reporterType,
          address: d.address,
          motor: d.motor,
          car: d.car,
          truck: d.truck,
          weightKg: d.weightKg,
          pickupDate: d.pickupDate,
          createdAt: DateTime.now(),
          status: ReportStatus.submitted,
          flags: flags,
          files: files,
        ));
    return code;
  }

  @override
  Future<List<Report>> myReports() async =>
      _reports.where((r) => r.reporterId == _user?.id).toList();
  @override
  Future<List<Report>> allReports() async => List.of(_reports);

  void _replace(Report r) {
    final i = _reports.indexWhere((x) => x.id == r.id);
    if (i >= 0) _reports[i] = r;
  }

  @override
  Future<Report> decide(Report r, ReportStatus decision, String note,
      {int? countedTotal, double? countedKg}) async {
    final flags = r.flags.where((f) => f.kind != 'count_mismatch').toList();
    if (countedTotal != null && r.total > 0) {
      final diff = (countedTotal - r.total).abs() / r.total;
      if (diff > 0.1) {
        flags.add(Flag('count_mismatch', diff > 0.3 ? 'bad' : 'warn',
            'Hitung di lokasi $countedTotal ban, klaim ${r.total} ban.'));
      } else {
        flags.add(Flag('count_mismatch', 'ok',
            'Hitung di lokasi $countedTotal ban, cocok dengan klaim.'));
      }
    }
    final n = r.copyWith(
        status: decision,
        decisionNote: note,
        countedTotal: countedTotal,
        countedKg: countedKg,
        flags: flags);
    _replace(n);
    if (decision == ReportStatus.approved &&
        !_partners.any((p) => p.nib == r.nib)) {
      _partners.add(Partner(
          id: 'p${_partners.length + 1}',
          name: r.name,
          type: r.reporterType,
          address: r.address,
          whatsapp: r.whatsapp,
          nib: r.nib,
          lastPickup: null,
          pickups: 0));
    }
    return n;
  }

  @override
  Future<Report> markPaid(Report r, String transferRef) async {
    final n = r.copyWith(paymentStatus: 'paid', transferRef: transferRef);
    _replace(n);
    return n;
  }

  @override
  Future<List<Partner>> partners() async => List.of(_partners);
  @override
  Future<void> setBlocked(Partner p, bool blocked, String reason) async {
    final i = _partners.indexWhere((x) => x.id == p.id);
    if (i >= 0) _partners[i] = p.copyWith(blocked: blocked, blockReason: reason);
  }

  @override
  Future<Uint8List?> fileBytes(ReportFile f) async => f.bytes;
  @override
  Future<Map<String, String>?> bankFor(Report r) async =>
      _user?.role == Role.finance
          ? (_bank[r.id] ??
              {'bank': 'BCA', 'masked': '******4821', 'holder': '[nama contoh]'})
          : null;
  @override
  Future<void> deleteMyData() async {
    _reports.removeWhere((r) => r.reporterId == _user?.id);
    _user = null;
  }
}

// ---------------------------------------------------------------------------
// Supabase repo: auth, tables, storage. Rules are enforced by row level
// security and the SQL functions in supabase/migrations.
// ---------------------------------------------------------------------------
class SupabaseRepo implements Repo {
  final SupabaseClient _c = Supabase.instance.client;
  AppUser? _user;

  @override
  bool get isDemo => false;
  @override
  AppUser? get user => _user;

  Future<void> _loadProfile() async {
    final u = _c.auth.currentUser;
    if (u == null) {
      _user = null;
      return;
    }
    final p = await _c.from('profiles').select().eq('id', u.id).maybeSingle();
    _user = AppUser(u.id, (p?['full_name'] as String?) ?? (u.email ?? ''),
        u.email ?? '', roleFrom(p?['role'] as String?));
  }

  Future<void> restore() => _loadProfile();

  @override
  Future<void> signIn(String email, String password) async {
    try {
      await _c.auth.signInWithPassword(email: email, password: password);
      await _loadProfile();
    } on AuthException catch (e) {
      throw AppError(e.message);
    }
  }

  @override
  Future<void> signUp(String name, String email, String password) async {
    try {
      final r = await _c.auth
          .signUp(email: email, password: password, data: {'full_name': name});
      if (r.session == null) {
        throw AppError('Cek email Anda untuk konfirmasi, lalu masuk.');
      }
      await _loadProfile();
    } on AuthException catch (e) {
      throw AppError(e.message);
    }
  }

  @override
  Future<void> signOut() async {
    await _c.auth.signOut();
    _user = null;
  }

  @override
  Future<void> demoLogin(Role role) async =>
      throw AppError('Mode contoh tidak aktif.');

  @override
  Future<String> submitReport(ReportDraft d) async {
    final uid = _user!.id;
    final files = <Map<String, dynamic>>[];
    for (final f in d.files) {
      final safe = f.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final path = '$uid/${DateTime.now().microsecondsSinceEpoch}-$safe';
      await _c.storage.from('proofs').uploadBinary(path, f.bytes);
      files.add({
        'kind': f.kind,
        'name': f.name,
        'path': path,
        'hash': sha256Hex(f.bytes),
      });
    }
    try {
      final res = await _c.rpc('submit_report', params: {
        'p': {
          'name': d.name,
          'whatsapp': d.whatsapp,
          'nib': d.nib,
          'reporter_type': d.reporterType,
          'address': d.address,
          'motor': d.motor,
          'car': d.car,
          'truck': d.truck,
          'weight_kg': d.weightKg,
          'pickup_date': d.pickupDate.toIso8601String().substring(0, 10),
          'consent': d.consent,
          'bank': {
            'bank': d.bankName,
            'account_no': d.accountNo,
            'holder': d.accountHolder,
          },
          'files': files,
        }
      });
      return res as String;
    } on PostgrestException catch (e) {
      throw AppError(e.message);
    }
  }

  static const _sel = '*, report_flags(*), report_files(*)';

  Report _map(Map<String, dynamic> j) => Report(
        id: j['id'] as String,
        code: j['code'] as String,
        reporterId: j['reporter_id'] as String,
        name: j['name'] as String,
        whatsapp: j['whatsapp'] as String,
        nib: j['nib'] as String,
        reporterType: j['reporter_type'] as String,
        address: j['address'] as String,
        motor: j['motor'] as int,
        car: j['car'] as int,
        truck: j['truck'] as int,
        weightKg: (j['weight_kg'] as num).toDouble(),
        pickupDate: DateTime.parse(j['pickup_date'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
        status: statusFrom(j['status'] as String),
        decisionNote: j['decision_note'] as String?,
        countedTotal: j['counted_total'] as int?,
        countedKg: (j['counted_kg'] as num?)?.toDouble(),
        paymentStatus: j['payment_status'] as String,
        transferRef: j['transfer_ref'] as String?,
        flags: [
          for (final f in (j['report_flags'] as List? ?? []))
            Flag.fromJson(Map<String, dynamic>.from(f as Map))
        ],
        files: [
          for (final f in (j['report_files'] as List? ?? []))
            ReportFile(f['kind'] as String, f['name'] as String,
                f['hash'] as String,
                path: f['path'] as String?)
        ],
      );

  @override
  Future<List<Report>> myReports() async {
    final rows = await _c
        .from('reports')
        .select(_sel)
        .eq('reporter_id', _user!.id)
        .order('created_at', ascending: false)
        .limit(100);
    return [for (final r in rows) _map(Map<String, dynamic>.from(r))];
  }

  @override
  Future<List<Report>> allReports() async {
    final rows =
        await _c
            .from('reports')
            .select(_sel)
            .order('created_at', ascending: false)
            .limit(100);
    return [for (final r in rows) _map(Map<String, dynamic>.from(r))];
  }

  Future<Report> _reload(String id) async {
    final row = await _c.from('reports').select(_sel).eq('id', id).single();
    return _map(Map<String, dynamic>.from(row));
  }

  @override
  Future<Report> decide(Report r, ReportStatus decision, String note,
      {int? countedTotal, double? countedKg}) async {
    try {
      await _c.rpc('decide_report', params: {
        'p_id': r.id,
        'p_status': statusDb(decision),
        'p_note': note,
        'p_counted_total': countedTotal,
        'p_counted_kg': countedKg,
      });
    } on PostgrestException catch (e) {
      throw AppError(e.message);
    }
    return _reload(r.id);
  }

  @override
  Future<Report> markPaid(Report r, String transferRef) async {
    try {
      await _c.rpc('mark_paid', params: {'p_id': r.id, 'p_ref': transferRef});
    } on PostgrestException catch (e) {
      throw AppError(e.message);
    }
    return _reload(r.id);
  }

  @override
  Future<List<Partner>> partners() async {
    final rows = await _c.from('partners').select().order('name').limit(200);
    return [
      for (final j in rows)
        Partner(
          id: j['id'] as String,
          name: j['name'] as String,
          type: j['type'] as String,
          address: j['address'] as String,
          whatsapp: j['whatsapp'] as String,
          nib: j['nib'] as String,
          blocked: j['blocked'] as bool,
          blockReason: j['block_reason'] as String?,
          lastPickup: j['last_pickup'] == null
              ? null
              : DateTime.parse(j['last_pickup'] as String),
          pickups: j['pickups'] as int,
        )
    ];
  }

  @override
  Future<void> setBlocked(Partner p, bool blocked, String reason) async {
    try {
      await _c.rpc('set_partner_blocked',
          params: {'p_id': p.id, 'p_blocked': blocked, 'p_reason': reason});
    } on PostgrestException catch (e) {
      throw AppError(e.message);
    }
  }

  @override
  Future<Uint8List?> fileBytes(ReportFile f) async {
    if (f.path == null) return null;
    if (f.name.toLowerCase().endsWith('.pdf')) return null;
    return _c.storage.from('proofs').download(f.path!);
  }

  @override
  Future<Map<String, String>?> bankFor(Report r) async {
    final row = await _c
        .from('bank_accounts')
        .select()
        .eq('report_id', r.id)
        .maybeSingle();
    if (row == null) return null;
    return {
      'bank': row['bank'] as String,
      'masked': maskAccount(row['account_no'] as String),
      'holder': row['holder'] as String,
    };
  }

  @override
  Future<void> deleteMyData() async {
    try {
      await _c.rpc('delete_my_data');
      await signOut();
    } on PostgrestException catch (e) {
      throw AppError(e.message);
    }
  }
}

String prettyJson(Object o) => const JsonEncoder.withIndent('  ').convert(o);
