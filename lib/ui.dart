import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'models.dart';
import 'repo.dart';

// Design B: green, rounded, big touch targets.
const cGreen = Color(0xFF0E7A55);
const cBg = Color(0xFFEDF4EF);
const cInk = Color(0xFF10261C);
const cMut = Color(0xFF4D6256);
const cLine = Color(0xFFC7D8CC);
const cBad = Color(0xFFB42318);
const cWarn = Color(0xFF9A5B00);
const cPh = Color(0xFFDCE9E0);

late Repo repo;

ThemeData buildTheme() {
  final base = ColorScheme.fromSeed(seedColor: cGreen, surface: Colors.white);
  return ThemeData(
    colorScheme: base.copyWith(primary: cGreen, onPrimary: Colors.white),
    scaffoldBackgroundColor: cBg,
    useMaterial3: true,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cLine, width: 2)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: cLine, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 52),
            shape: const StadiumBorder(),
            foregroundColor: cInk,
            side: const BorderSide(color: cLine, width: 2),
            textStyle: const TextStyle(fontWeight: FontWeight.w700))),
  );
}

String fmtDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

Color levelColor(String l) => l == 'bad' ? cBad : (l == 'warn' ? cWarn : cGreen);

Widget tag(String text, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          border: Border.all(color: c), borderRadius: BorderRadius.circular(99)),
      child: Text(text,
          style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    );

Widget placeholderBox(String text) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: cPh, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: const TextStyle(fontSize: 13, color: cInk)),
    );

const wasteChipText = 'Kategori limbah: [menunggu konfirmasi tertulis klien]';

Widget card(Widget child, {Color? border}) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border ?? cLine, width: border == null ? 1 : 2)),
      child: child,
    );

Widget h2(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)));

Widget page(Widget child) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(padding: const EdgeInsets.all(16), child: child)));

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c)
    .showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

Widget flagList(List<Flag> flags) {
  if (flags.isEmpty) {
    return const Text('Tidak ada temuan.', style: TextStyle(color: cMut));
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final f in flags)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
                width: 76,
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: tag(
                        f.level == 'bad'
                            ? 'Risiko'
                            : (f.level == 'warn' ? 'Cek' : 'Aman'),
                        levelColor(f.level)))),
            Expanded(child: Text(f.text)),
          ]),
        ),
    ],
  );
}

// ===========================================================================
// Auth
// ===========================================================================
class AuthPage extends StatefulWidget {
  final VoidCallback onDone;
  const AuthPage({super.key, required this.onDone});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final pass = TextEditingController();
  bool signup = false, busy = false;
  String? err;

  Future<void> run(Future<void> Function() f) async {
    setState(() {
      busy = true;
      err = null;
    });
    try {
      await f();
      widget.onDone();
    } on AppError catch (e) {
      setState(() => err = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: cGreen,
          foregroundColor: Colors.white,
          title: const Text('[Logo klien]  Jemput Ban',
              style: TextStyle(fontWeight: FontWeight.w800))),
      body: SingleChildScrollView(
        child: page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ada ban bekas? Kami jemput.',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          if (repo.isDemo) ...[
            card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              h2('Mode contoh'),
              const Text(
                  'Belum tersambung ke database. Data hanya ada di memori dan hilang saat halaman dimuat ulang. Pilih peran untuk mencoba.'),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: busy ? null : () => run(() => repo.demoLogin(Role.reporter)),
                  child: const Text('Masuk sebagai pelapor')),
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: busy ? null : () => run(() => repo.demoLogin(Role.admin)),
                  child: const Text('Masuk sebagai admin')),
              const SizedBox(height: 8),
              OutlinedButton(
                  onPressed: busy ? null : () => run(() => repo.demoLogin(Role.finance)),
                  child: const Text('Masuk sebagai admin keuangan')),
            ])),
          ] else
            card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              h2(signup ? 'Daftar' : 'Masuk'),
              if (signup) ...[
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama lengkap')),
                const SizedBox(height: 12),
              ],
              TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email')),
              const SizedBox(height: 12),
              TextField(
                  controller: pass,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: const InputDecoration(labelText: 'Kata sandi (min. 8 karakter)')),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: busy
                      ? null
                      : () => run(() => signup
                          ? repo.signUp(name.text.trim(), email.text.trim(), pass.text)
                          : repo.signIn(email.text.trim(), pass.text)),
                  child: Text(signup ? 'Daftar' : 'Masuk')),
              TextButton(
                  onPressed: () => setState(() => signup = !signup),
                  child: Text(signup ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar')),
            ])),
          if (err != null) Text(err!, style: const TextStyle(color: cBad, fontWeight: FontWeight.w600)),
        ])),
      ),
    );
  }
}

// ===========================================================================
// Shell
// ===========================================================================
class Shell extends StatelessWidget {
  final VoidCallback onLogout;
  const Shell({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final u = repo.user!;
    final tabs = u.isStaff
        ? const [Tab(text: 'Verifikasi'), Tab(text: 'Direktori')]
        : const [Tab(text: 'Lapor'), Tab(text: 'Laporan saya')];
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: cGreen,
          foregroundColor: Colors.white,
          title: const Text('[Logo klien]  Jemput Ban',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          actions: [
            Center(
                child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(u.name, style: const TextStyle(fontSize: 12)))),
            PopupMenuButton<String>(
              tooltip: 'Menu akun',
              onSelected: (v) async {
                if (v == 'out') {
                  await repo.signOut();
                  onLogout();
                } else if (v == 'del') {
                  final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                            title: const Text('Hapus data saya?'),
                            content: const Text(
                                'Laporan, dokumen, dan rekening Anda dihapus atau dianonimkan. Tidak bisa dibatalkan.'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
                              TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
                            ],
                          ));
                  if (ok == true) {
                    try {
                      await repo.deleteMyData();
                      onLogout();
                    } on AppError catch (e) {
                      if (context.mounted) toast(context, e.message);
                    }
                  }
                }
              },
              itemBuilder: (c) => [
                const PopupMenuItem(value: 'out', child: Text('Keluar')),
                if (!u.isStaff) const PopupMenuItem(value: 'del', child: Text('Hapus data saya (UU PDP)')),
              ],
            ),
          ],
          bottom: TabBar(
              tabs: tabs,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white),
        ),
        body: TabBarView(
          children: u.isStaff
              ? [const AdminQueue(), const DirectoryPage()]
              : [const ReportWizard(), const MyReports()],
        ),
      ),
    );
  }
}

// ===========================================================================
// Reporter: wizard
// ===========================================================================
class ReportWizard extends StatefulWidget {
  const ReportWizard({super.key});
  @override
  State<ReportWizard> createState() => _ReportWizardState();
}

class _ReportWizardState extends State<ReportWizard> {
  int step = 0;
  final d = ReportDraft();
  final name = TextEditingController(),
      wa = TextEditingController(),
      nib = TextEditingController(),
      addr = TextEditingController(),
      motor = TextEditingController(text: '0'),
      car = TextEditingController(text: '0'),
      truck = TextEditingController(text: '0'),
      kg = TextEditingController(),
      bank = TextEditingController(),
      accNo = TextEditingController(),
      accName = TextEditingController();
  String? err;
  bool busy = false;
  String? doneCode;

  static const maxBytes = 5 * 1024 * 1024;

  String? validate(int s) {
    if (s == 0) {
      if (name.text.trim().length < 3) return 'Isi nama bengkel atau pelapor.';
      if (wa.text.replaceAll(RegExp(r'\D'), '').length < 9) return 'Isi nomor WhatsApp yang benar.';
      if (!RegExp(r'^\d{13}$').hasMatch(nib.text.trim())) return 'NIB harus 13 digit angka.';
      if (addr.text.trim().length < 10) return 'Isi alamat pengambilan selengkap mungkin.';
    }
    if (s == 1) {
      final m = int.tryParse(motor.text) ?? -1, c = int.tryParse(car.text) ?? -1, t = int.tryParse(truck.text) ?? -1;
      if (m < 0 || c < 0 || t < 0) return 'Jumlah ban harus angka 0 atau lebih.';
      if (m + c + t == 0) return 'Isi minimal satu ban.';
      if ((double.tryParse(kg.text.replaceAll(',', '.')) ?? 0) <= 0) return 'Isi perkiraan berat (kg).';
    }
    if (s == 2) {
      if (!d.files.any((f) => f.kind == 'nib')) return 'Unggah foto atau PDF NIB.';
      if (d.reporterType == 'freelancer' && !d.files.any((f) => f.kind == 'po')) {
        return 'Freelancer wajib mengunggah purchase order dari bengkel.';
      }
      if (d.files.where((f) => f.kind == 'photo').length < 2) return 'Unggah minimal 2 foto tumpukan ban.';
      if (bank.text.trim().isEmpty || accNo.text.trim().isEmpty || accName.text.trim().isEmpty) {
        return 'Isi data rekening untuk pembayaran transfer.';
      }
      if (!d.consent) return 'Centang persetujuan data pribadi dulu.';
    }
    return null;
  }

  void next() {
    final e = validate(step);
    setState(() => err = e);
    if (e == null) {
      if (step == 0) {
        d
          ..name = name.text.trim()
          ..whatsapp = wa.text.trim()
          ..nib = nib.text.trim()
          ..address = addr.text.trim();
      }
      if (step == 1) {
        d
          ..motor = int.parse(motor.text)
          ..car = int.parse(car.text)
          ..truck = int.parse(truck.text)
          ..weightKg = double.parse(kg.text.replaceAll(',', '.'));
      }
      setState(() => step++);
    }
  }

  Future<void> pick(String kind) async {
    final res = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: kind == 'photo' ? ['jpg', 'jpeg', 'png'] : ['jpg', 'jpeg', 'png', 'pdf']);
    final files = kind == 'photo' ? res : res.take(1).toList();
    for (final f in files) {
      final b = await f.readAsBytes();
      if (b.length > maxBytes) {
        if (mounted) toast(context, '${f.name} lebih dari 5 MB.');
        continue;
      }
      setState(() {
        if (kind != 'photo') d.files.removeWhere((x) => x.kind == kind);
        if (kind == 'photo' && d.files.where((x) => x.kind == 'photo').length >= 5) {
          return;
        }
        d.files.add(DraftFile(kind, f.name, b));
      });
    }
  }

  Future<void> submit() async {
    final e = validate(2);
    setState(() => err = e);
    if (e != null) return;
    d
      ..bankName = bank.text.trim()
      ..accountNo = accNo.text.trim()
      ..accountHolder = accName.text.trim();
    setState(() => busy = true);
    try {
      final code = await repo.submitReport(d);
      setState(() => doneCode = code);
    } on AppError catch (e) {
      setState(() => err = e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget field(TextEditingController c, String label,
          {TextInputType? type, int lines = 1, String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
            controller: c,
            keyboardType: type,
            maxLines: lines,
            decoration: InputDecoration(labelText: label, hintText: hint)),
      );

  Widget slot(String kind, String title, String hint) {
    final list = d.files.where((f) => f.kind == kind).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 72),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.all(14)),
        onPressed: () => pick(kind),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(list.isEmpty ? hint : '${list.length} berkas: ${list.map((f) => f.name).join(', ')}',
              style: TextStyle(fontSize: 12, color: list.isEmpty ? cMut : cGreen, fontWeight: FontWeight.w400)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (doneCode != null) {
      return SingleChildScrollView(
          child: page(card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Laporan terkirim', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Nomor laporan: $doneCode', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Tim memeriksa dokumen dan foto, lalu mengabari lewat WhatsApp. Lihat status di tab "Laporan saya".'),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: () => setState(() {
                  doneCode = null;
                  step = 0;
                  d.files.clear();
                  d.consent = false;
                }),
            child: const Text('Buat laporan lain')),
      ]))));
    }
    return SingleChildScrollView(
      child: page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          for (var i = 0; i < 3; i++)
            Expanded(
                child: Container(
                    height: 8,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                        color: i <= step ? cGreen : cLine,
                        borderRadius: BorderRadius.circular(99)))),
        ]),
        const SizedBox(height: 16),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (step == 0) ...[
            h2('Langkah 1 dari 3: Siapa dan di mana'),
            field(name, 'Nama bengkel atau pelapor'),
            field(wa, 'Nomor WhatsApp', type: TextInputType.phone),
            field(nib, 'Nomor NIB (13 digit)', type: TextInputType.number),
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                    initialValue: d.reporterType,
                    decoration: const InputDecoration(labelText: 'Jenis pelapor'),
                    items: const [
                      DropdownMenuItem(value: 'workshop', child: Text('Bengkel atau toko ban')),
                      DropdownMenuItem(value: 'freelancer', child: Text('Freelancer')),
                    ],
                    onChanged: (v) => setState(() => d.reporterType = v ?? 'workshop'))),
            field(addr, 'Alamat lengkap pengambilan', lines: 2),
          ],
          if (step == 1) ...[
            h2('Langkah 2 dari 3: Berapa banyak'),
            Row(children: [
              Expanded(child: field(motor, 'Ban motor', type: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: field(car, 'Ban mobil', type: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: field(truck, 'Ban truk', type: TextInputType.number)),
            ]),
            field(kg, 'Perkiraan berat total (kg)', type: const TextInputType.numberWithOptions(decimal: true)),
            OutlinedButton(
                onPressed: () async {
                  final p = await showDatePicker(
                      context: context,
                      initialDate: d.pickupDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 90)));
                  if (p != null) setState(() => d.pickupDate = p);
                },
                child: Text('Siap diambil: ${fmtDate(d.pickupDate)}')),
            const SizedBox(height: 12),
            placeholderBox(wasteChipText),
          ],
          if (step == 2) ...[
            h2('Langkah 3 dari 3: Bukti dan rekening'),
            slot('nib', 'Foto atau PDF NIB', 'Wajib. JPG, PNG, atau PDF, maks. 5 MB.'),
            slot('po', 'Purchase order dari bengkel',
                d.reporterType == 'freelancer' ? 'Wajib untuk freelancer.' : 'Boleh dilewati untuk bengkel.'),
            slot('photo', 'Foto tumpukan ban (2 sampai 5)', 'Ambil dari sudut berbeda. Foto yang sama tidak bisa dipakai dua kali.'),
            const SizedBox(height: 8),
            h2('Rekening untuk transfer'),
            field(bank, 'Nama bank'),
            field(accNo, 'Nomor rekening', type: TextInputType.number),
            field(accName, 'Atas nama'),
            CheckboxListTile(
              value: d.consent,
              onChanged: (v) => setState(() => d.consent = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                  'Saya setuju data pribadi dan rekening saya dipakai hanya untuk verifikasi dan pembayaran. Rekening hanya dilihat admin keuangan. Saya boleh minta hapus data kapan saja (UU PDP).',
                  style: TextStyle(fontSize: 13)),
            ),
          ],
          if (err != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(err!, style: const TextStyle(color: cBad, fontWeight: FontWeight.w600))),
          const SizedBox(height: 12),
          Row(children: [
            if (step > 0)
              Expanded(
                  child: OutlinedButton(
                      onPressed: busy ? null : () => setState(() {
                            step--;
                            err = null;
                          }),
                      child: const Text('Kembali'))),
            if (step > 0) const SizedBox(width: 8),
            Expanded(
                child: FilledButton(
                    onPressed: busy ? null : (step < 2 ? next : submit),
                    child: Text(step < 2 ? 'Lanjut' : (busy ? 'Mengirim...' : 'Kirim laporan')))),
          ]),
        ])),
      ])),
    );
  }
}

// ===========================================================================
// Reporter: my reports
// ===========================================================================
class MyReports extends StatefulWidget {
  const MyReports({super.key});
  @override
  State<MyReports> createState() => _MyReportsState();
}

class _MyReportsState extends State<MyReports> {
  late Future<List<Report>> f = repo.myReports();
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() => f = repo.myReports()),
      child: FutureBuilder<List<Report>>(
        future: f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) return page(Text('Gagal memuat: ${s.error}'));
          final list = s.data!;
          return ListView(children: [
            page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Laporan saya', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
                TextButton(onPressed: () => setState(() => f = repo.myReports()), child: const Text('Muat ulang')),
              ]),
              const SizedBox(height: 8),
              if (list.isEmpty) const Text('Belum ada laporan.'),
              for (final r in list)
                card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${r.code} · ${r.total} ban', style: const TextStyle(fontWeight: FontWeight.w700))),
                    tag(statusLabel(r.status),
                        r.status == ReportStatus.approved ? cGreen : (r.status == ReportStatus.rejected ? cBad : cWarn)),
                  ]),
                  Text('Dikirim ${fmtDate(r.createdAt)} · ambil ${fmtDate(r.pickupDate)}',
                      style: const TextStyle(color: cMut, fontSize: 12)),
                  if (r.decisionNote != null && r.decisionNote!.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Text('Catatan tim: ${r.decisionNote}')),
                  if (r.paymentStatus == 'paid')
                    const Padding(padding: EdgeInsets.only(top: 8), child: Text('Pembayaran sudah ditransfer.')),
                ])),
            ])),
          ]);
        },
      ),
    );
  }
}

// ===========================================================================
// Admin: queue + detail
// ===========================================================================
class AdminQueue extends StatefulWidget {
  const AdminQueue({super.key});
  @override
  State<AdminQueue> createState() => _AdminQueueState();
}

class _AdminQueueState extends State<AdminQueue> {
  late Future<List<Report>> f = repo.allReports();
  String filter = 'open';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Report>>(
      future: f,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return page(Text('Gagal memuat: ${s.error}'));
        var list = s.data!;
        list = switch (filter) {
          'open' => list.where((r) => r.status == ReportStatus.submitted || r.status == ReportStatus.needsFix).toList(),
          'approved' => list.where((r) => r.status == ReportStatus.approved).toList(),
          'rejected' => list.where((r) => r.status == ReportStatus.rejected).toList(),
          _ => list,
        };
        list.sort((a, b) => b.risk.compareTo(a.risk));
        return ListView(children: [
          page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Perlu diperiksa', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final e in const {'open': 'Perlu diperiksa', 'approved': 'Disetujui', 'rejected': 'Ditolak', 'all': 'Semua'}.entries)
                ChoiceChip(
                    label: Text(e.value),
                    selected: filter == e.key,
                    onSelected: (_) => setState(() => filter = e.key)),
            ]),
            const SizedBox(height: 12),
            if (list.isEmpty) const Text('Tidak ada laporan.'),
            for (final r in list)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminDetail(report: r)));
                  setState(() => f = repo.allReports());
                },
                child: card(
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${r.code} · ${r.name}', style: const TextStyle(fontWeight: FontWeight.w700))),
                        tag(r.hasBad ? 'Risiko' : (r.risk > 0 ? 'Cek' : 'Aman'),
                            r.hasBad ? cBad : (r.risk > 0 ? cWarn : cGreen)),
                      ]),
                      Text('${r.total} ban · ${r.weightKg.toStringAsFixed(0)} kg · ${statusLabel(r.status)}',
                          style: const TextStyle(color: cMut, fontSize: 13)),
                      if (r.flags.where((x) => x.level != 'ok').isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('${r.flags.where((x) => x.level != 'ok').length} temuan',
                                style: TextStyle(color: r.hasBad ? cBad : cWarn, fontSize: 13, fontWeight: FontWeight.w600))),
                    ]),
                    border: r.hasBad ? cBad : null),
              ),
          ])),
        ]);
      },
    );
  }
}

class AdminDetail extends StatefulWidget {
  final Report report;
  const AdminDetail({super.key, required this.report});
  @override
  State<AdminDetail> createState() => _AdminDetailState();
}

class _AdminDetailState extends State<AdminDetail> {
  late Report r = widget.report;
  final counted = TextEditingController(),
      countedKg = TextEditingController(),
      note = TextEditingController(),
      ref = TextEditingController();
  bool busy = false;
  Map<String, String>? bank;
  bool bankLoaded = false;

  @override
  void initState() {
    super.initState();
    if (repo.user?.role == Role.finance) {
      repo.bankFor(r).then((b) {
        if (mounted) setState(() {
              bank = b;
              bankLoaded = true;
            });
      });
    }
  }

  Future<void> decide(ReportStatus s) async {
    if (s != ReportStatus.approved && note.text.trim().isEmpty) {
      toast(context, 'Tulis alasan untuk pelapor.');
      return;
    }
    setState(() => busy = true);
    try {
      final n = await repo.decide(r, s, note.text.trim(),
          countedTotal: int.tryParse(counted.text),
          countedKg: double.tryParse(countedKg.text.replaceAll(',', '.')));
      setState(() => r = n);
      if (mounted) toast(context, 'Keputusan tersimpan: ${statusLabel(s)}');
    } on AppError catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> pay() async {
    if (ref.text.trim().isEmpty) {
      toast(context, 'Isi nomor referensi transfer.');
      return;
    }
    setState(() => busy = true);
    try {
      final n = await repo.markPaid(r, ref.text.trim());
      setState(() => r = n);
    } on AppError catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFinance = repo.user?.role == Role.finance;
    return Scaffold(
      appBar: AppBar(
          backgroundColor: cGreen,
          foregroundColor: Colors.white,
          title: Text('${r.code} · ${r.name}', style: const TextStyle(fontSize: 16))),
      body: SingleChildScrollView(
        child: page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            h2('Pelapor'),
            Text('${r.name} (${r.reporterType == 'workshop' ? 'bengkel/toko' : 'freelancer'})'),
            Text('WhatsApp: ${r.whatsapp}'),
            Text('NIB: ${r.nib}'),
            Text(r.address),
            const SizedBox(height: 8),
            Text('Klaim: ${r.motor} motor, ${r.car} mobil, ${r.truck} truk = ${r.total} ban, ${r.weightKg.toStringAsFixed(0)} kg'),
            Text('Siap diambil: ${fmtDate(r.pickupDate)}'),
            Text('Status: ${statusLabel(r.status)}'),
            const SizedBox(height: 8),
            placeholderBox('$wasteChipText\nIzin angkut: [menunggu konfirmasi tertulis klien]'),
          ])),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            h2('Pemeriksaan kecurangan'),
            flagList(r.flags),
          ]), border: r.hasBad ? cBad : null),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            h2('Bukti'),
            Wrap(spacing: 10, runSpacing: 10, children: [for (final f in r.files) FileTile(file: f)]),
          ])),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            h2('Hasil survei di lokasi'),
            Row(children: [
              Expanded(child: TextField(controller: counted, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jumlah ban dihitung'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: countedKg, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Berat timbang (kg)'))),
            ]),
            const SizedBox(height: 12),
            TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Catatan atau alasan untuk pelapor')),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(onPressed: busy ? null : () => decide(ReportStatus.approved), child: const Text('Setujui')),
              OutlinedButton(onPressed: busy ? null : () => decide(ReportStatus.needsFix), child: const Text('Minta perbaikan')),
              OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: cBad, side: const BorderSide(color: cBad, width: 2)),
                  onPressed: busy ? null : () => decide(ReportStatus.rejected),
                  child: const Text('Tolak')),
            ]),
            if (r.decisionNote != null && r.decisionNote!.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text('Catatan tersimpan: ${r.decisionNote}', style: const TextStyle(color: cMut))),
          ])),
          if (r.status == ReportStatus.approved)
            card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              h2('Pembayaran (transfer manual)'),
              placeholderBox('Nominal: Rp [___]  DRAF. Harga belum disetujui.'),
              const SizedBox(height: 8),
              if (!isFinance)
                const Text('Data rekening hanya terlihat oleh admin keuangan.', style: TextStyle(color: cMut))
              else if (!bankLoaded)
                const Text('Memuat rekening...')
              else if (bank == null)
                const Text('Rekening tidak ditemukan.')
              else
                Text('${bank!['bank']} · ${bank!['masked']} · a.n. ${bank!['holder']}'),
              const SizedBox(height: 8),
              if (r.paymentStatus == 'paid')
                Text('Sudah dibayar. Referensi: ${r.transferRef}', style: const TextStyle(color: cGreen, fontWeight: FontWeight.w700))
              else if (isFinance) ...[
                TextField(controller: ref, decoration: const InputDecoration(labelText: 'Nomor referensi transfer')),
                const SizedBox(height: 8),
                FilledButton(onPressed: busy ? null : pay, child: const Text('Tandai sudah ditransfer')),
              ] else
                const Text('Menunggu admin keuangan.'),
            ])),
        ])),
      ),
    );
  }
}

class FileTile extends StatefulWidget {
  final ReportFile file;
  const FileTile({super.key, required this.file});
  @override
  State<FileTile> createState() => _FileTileState();
}

class _FileTileState extends State<FileTile> {
  late Future<Uint8List?> f = repo.fileBytes(widget.file);
  @override
  Widget build(BuildContext context) {
    final kind = {'nib': 'NIB', 'po': 'PO', 'photo': 'Foto'}[widget.file.kind];
    return SizedBox(
      width: 150,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 110,
          decoration: BoxDecoration(color: cPh, borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: FutureBuilder<Uint8List?>(
              future: f,
              builder: (c, s) {
                final b = s.data;
                if (b != null) return Image.memory(b, fit: BoxFit.cover, width: 150, height: 110, errorBuilder: (_, _, _) => const Text('Berkas'));
                return Text(widget.file.name.toLowerCase().endsWith('.pdf') ? 'PDF' : 'Contoh', style: const TextStyle(color: cMut));
              }),
        ),
        Text('$kind · ${widget.file.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        Text('sha256 ${widget.file.hash.length > 10 ? widget.file.hash.substring(0, 10) : widget.file.hash}', style: const TextStyle(fontSize: 11, color: cMut)),
      ]),
    );
  }
}

// ===========================================================================
// Directory
// ===========================================================================
class DirectoryPage extends StatefulWidget {
  const DirectoryPage({super.key});
  @override
  State<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends State<DirectoryPage> {
  late Future<List<Partner>> f = repo.partners();
  String q = '';

  Future<void> toggleBlock(Partner p) async {
    String reason = '';
    if (!p.blocked) {
      final c = TextEditingController();
      final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text('Blokir ${p.name}?'),
                content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Alasan (wajib)')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Blokir')),
                ],
              ));
      if (ok != true || c.text.trim().isEmpty) return;
      reason = c.text.trim();
    }
    try {
      await repo.setBlocked(p, !p.blocked, reason);
      setState(() => f = repo.partners());
    } on AppError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Partner>>(
      future: f,
      builder: (c, s) {
        if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (s.hasError) return page(Text('Gagal memuat: ${s.error}'));
        final list = s.data!
            .where((p) => (p.name + p.address).toLowerCase().contains(q.toLowerCase()))
            .toList();
        return ListView(children: [
          page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Mitra kita', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
                decoration: const InputDecoration(labelText: 'Cari nama atau wilayah'),
                onChanged: (v) => setState(() => q = v)),
            const SizedBox(height: 12),
            if (list.isEmpty) const Text('Belum ada mitra. Mitra muncul setelah laporan disetujui.'),
            for (final p in list)
              card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                  tag(p.blocked ? 'Diblokir' : 'Disetujui', p.blocked ? cBad : cGreen),
                ]),
                Text('${p.type == 'workshop' ? 'Bengkel/toko' : 'Freelancer'} · ${p.address}', style: const TextStyle(color: cMut, fontSize: 13)),
                Text('Ambil terakhir: ${p.lastPickup == null ? 'belum ada' : fmtDate(p.lastPickup!)} · ${p.pickups} kali',
                    style: const TextStyle(color: cMut, fontSize: 13)),
                if (p.blocked && p.blockReason != null) Text('Alasan blokir: ${p.blockReason}', style: const TextStyle(color: cBad, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (!p.blocked)
                    FilledButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: p.whatsapp));
                          if (context.mounted) toast(context, 'Nomor WhatsApp disalin: ${p.whatsapp}');
                        },
                        child: const Text('Salin WhatsApp untuk pesan ulang')),
                  OutlinedButton(onPressed: () => toggleBlock(p), child: Text(p.blocked ? 'Buka blokir' : 'Blokir')),
                ]),
              ])),
            const Text('Rating mitra: [kriteria belum ditentukan klien]', style: TextStyle(color: cMut, fontSize: 12)),
          ])),
        ]);
      },
    );
  }
}
