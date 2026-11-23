import 'dart:typed_data';

enum Role { reporter, admin, finance }

Role roleFrom(String? s) => switch (s) {
      'admin' => Role.admin,
      'finance' => Role.finance,
      _ => Role.reporter,
    };

enum ReportStatus { submitted, needsFix, approved, rejected }

ReportStatus statusFrom(String s) => switch (s) {
      'needs_fix' => ReportStatus.needsFix,
      'approved' => ReportStatus.approved,
      'rejected' => ReportStatus.rejected,
      _ => ReportStatus.submitted,
    };

String statusDb(ReportStatus s) => switch (s) {
      ReportStatus.needsFix => 'needs_fix',
      ReportStatus.approved => 'approved',
      ReportStatus.rejected => 'rejected',
      ReportStatus.submitted => 'submitted',
    };

String statusLabel(ReportStatus s) => switch (s) {
      ReportStatus.submitted => 'Menunggu pemeriksaan',
      ReportStatus.needsFix => 'Perlu perbaikan',
      ReportStatus.approved => 'Disetujui',
      ReportStatus.rejected => 'Ditolak',
    };

/// Draft rule: expected weight range per tire in kg. The client must confirm
/// these numbers. They are only a sanity check, not a measurement.
const weightRangeKg = {
  'motor': [1.5, 5.0],
  'car': [5.0, 14.0],
  'truck': [30.0, 70.0],
};
const maxTiresPerReport = 500; // draft cap, client to confirm

class AppUser {
  final String id;
  final String name;
  final String email;
  final Role role;
  const AppUser(this.id, this.name, this.email, this.role);
  bool get isStaff => role != Role.reporter;
}

class Flag {
  /// kind: duplicate_photo, duplicate_report, weight_range, count_cap, nib_format, count_mismatch
  final String kind;

  /// level: bad, warn, ok
  final String level;
  final String text;
  const Flag(this.kind, this.level, this.text);
  factory Flag.fromJson(Map<String, dynamic> j) =>
      Flag(j['kind'] as String, j['level'] as String, j['text'] as String);
  int get score => level == 'bad' ? 3 : (level == 'warn' ? 1 : 0);
}

class ReportFile {
  final String kind; // nib, po, photo
  final String name;
  final String hash;
  final String? path; // storage path (Supabase)
  final Uint8List? bytes; // demo mode
  const ReportFile(this.kind, this.name, this.hash, {this.path, this.bytes});
}

class Report {
  final String id;
  final String code;
  final String reporterId;
  final String name;
  final String whatsapp;
  final String nib;
  final String reporterType; // workshop | freelancer
  final String address;
  final int motor, car, truck;
  final double weightKg;
  final DateTime pickupDate;
  final DateTime createdAt;
  final ReportStatus status;
  final String? decisionNote;
  final int? countedTotal;
  final double? countedKg;
  final String paymentStatus; // unpaid | paid
  final String? transferRef;
  final List<Flag> flags;
  final List<ReportFile> files;

  const Report({
    required this.id,
    required this.code,
    required this.reporterId,
    required this.name,
    required this.whatsapp,
    required this.nib,
    required this.reporterType,
    required this.address,
    required this.motor,
    required this.car,
    required this.truck,
    required this.weightKg,
    required this.pickupDate,
    required this.createdAt,
    required this.status,
    this.decisionNote,
    this.countedTotal,
    this.countedKg,
    this.paymentStatus = 'unpaid',
    this.transferRef,
    this.flags = const [],
    this.files = const [],
  });

  int get total => motor + car + truck;
  int get risk => flags.fold(0, (a, f) => a + f.score);
  bool get hasBad => flags.any((f) => f.level == 'bad');

  Report copyWith({
    ReportStatus? status,
    String? decisionNote,
    int? countedTotal,
    double? countedKg,
    String? paymentStatus,
    String? transferRef,
    List<Flag>? flags,
  }) =>
      Report(
        id: id,
        code: code,
        reporterId: reporterId,
        name: name,
        whatsapp: whatsapp,
        nib: nib,
        reporterType: reporterType,
        address: address,
        motor: motor,
        car: car,
        truck: truck,
        weightKg: weightKg,
        pickupDate: pickupDate,
        createdAt: createdAt,
        status: status ?? this.status,
        decisionNote: decisionNote ?? this.decisionNote,
        countedTotal: countedTotal ?? this.countedTotal,
        countedKg: countedKg ?? this.countedKg,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        transferRef: transferRef ?? this.transferRef,
        flags: flags ?? this.flags,
        files: files,
      );
}

class Partner {
  final String id;
  final String name;
  final String type;
  final String address;
  final String whatsapp;
  final String nib;
  final bool blocked;
  final String? blockReason;
  final DateTime? lastPickup;
  final int pickups;
  const Partner({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.whatsapp,
    required this.nib,
    this.blocked = false,
    this.blockReason,
    this.lastPickup,
    this.pickups = 0,
  });
  Partner copyWith({bool? blocked, String? blockReason}) => Partner(
        id: id,
        name: name,
        type: type,
        address: address,
        whatsapp: whatsapp,
        nib: nib,
        blocked: blocked ?? this.blocked,
        blockReason: blockReason ?? this.blockReason,
        lastPickup: lastPickup,
        pickups: pickups,
      );
}

class DraftFile {
  final String kind;
  final String name;
  final Uint8List bytes;
  const DraftFile(this.kind, this.name, this.bytes);
}

class ReportDraft {
  String name = '';
  String whatsapp = '';
  String nib = '';
  String reporterType = 'workshop';
  String address = '';
  int motor = 0, car = 0, truck = 0;
  double weightKg = 0;
  DateTime pickupDate = DateTime.now().add(const Duration(days: 3));
  bool consent = false;
  String bankName = '', accountNo = '', accountHolder = '';
  final List<DraftFile> files = [];

  int get total => motor + car + truck;
}

/// Shared by the demo repo and the UI checks. The SQL function submit_report
/// in supabase/migrations applies the same rules on the server.
List<Flag> localFlags({
  required String nib,
  required int motor,
  required int car,
  required int truck,
  required double weightKg,
}) {
  final out = <Flag>[];
  if (!RegExp(r'^\d{13}$').hasMatch(nib)) {
    out.add(const Flag('nib_format', 'warn',
        'NIB bukan 13 digit. Cek manual ke OSS.'));
  }
  final total = motor + car + truck;
  if (total > maxTiresPerReport) {
    out.add(Flag('count_cap', 'warn',
        'Klaim $total ban, di atas batas $maxTiresPerReport per laporan [batas draf].'));
  }
  final lo = motor * weightRangeKg['motor']![0] +
      car * weightRangeKg['car']![0] +
      truck * weightRangeKg['truck']![0];
  final hi = motor * weightRangeKg['motor']![1] +
      car * weightRangeKg['car']![1] +
      truck * weightRangeKg['truck']![1];
  if (total > 0 && (weightKg < lo || weightKg > hi)) {
    out.add(Flag('weight_range', 'warn',
        'Berat ${weightKg.toStringAsFixed(0)} kg di luar kisaran ${lo.toStringAsFixed(0)} sampai ${hi.toStringAsFixed(0)} kg untuk jumlah ini [kisaran draf].'));
  }
  return out;
}
