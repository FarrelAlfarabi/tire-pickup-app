import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'imaging.dart';
import 'models.dart';
import 'repo.dart';

// ===========================================================================
// Design B: green, rounded, big touch targets, phone first.
// Spacing uses a 4/8 rhythm. Colors are tokens. Status is never color only:
// every status has an icon and a word.
// ===========================================================================
const cGreen = Color(0xFF0E7A55);
const cGreenDark = Color(0xFF0A5C41);
const cBg = Color(0xFFEDF4EF);
const cInk = Color(0xFF10261C);
const cMut = Color(0xFF4A5E52); // 6.3:1 on white, 5.4:1 on cBg
const cLine = Color(0xFFB9CDBF);
const cBad = Color(0xFFB42318);
const cWarn = Color(0xFF8F5200);
const cPh = Color(0xFFDCE9E0);
const cBadBg = Color(0xFFFDECEA);
const cWarnBg = Color(0xFFFFF4D6);

const double gap = 8, gapL = 16, gapXL = 24;

late Repo repo;

ThemeData buildTheme() {
  final base = ColorScheme.fromSeed(seedColor: cGreen, surface: Colors.white);
  OutlineInputBorder border(Color c, [double w = 2]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
  return ThemeData(
    colorScheme: base.copyWith(primary: cGreen, onPrimary: Colors.white, error: cBad),
    scaffoldBackgroundColor: cBg,
    useMaterial3: true,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, height: 1.4, color: cInk),
      bodySmall: TextStyle(fontSize: 14, height: 1.4, color: cMut),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cInk),
      titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: cInk),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border(cLine),
      enabledBorder: border(cLine),
      focusedBorder: border(cGreen, 3),
      errorBorder: border(cBad),
      focusedErrorBorder: border(cBad, 3),
      errorStyle: const TextStyle(color: cBad, fontSize: 13, fontWeight: FontWeight.w600),
      labelStyle: const TextStyle(color: cMut),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape: const StadiumBorder(),
            foregroundColor: cInk,
            side: const BorderSide(color: cLine, width: 2),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
    textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: cGreenDark,
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
    navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: cPh,
        height: 68,
        labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cInk))),
    appBarTheme: const AppBarTheme(
        backgroundColor: cGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false),
    chipTheme: ChipThemeData(
        side: const BorderSide(color: cLine, width: 1.5),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cInk),
        selectedColor: cPh,
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
  );
}

String fmtDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

Color levelColor(String l) => l == 'bad' ? cBad : (l == 'warn' ? cWarn : cGreen);
IconData levelIcon(String l) =>
    l == 'bad' ? Icons.error_outline : (l == 'warn' ? Icons.warning_amber_rounded : Icons.check_circle_outline);
String levelLabel(String l) => l == 'bad' ? 'Risiko' : (l == 'warn' ? 'Cek' : 'Aman');

IconData statusIcon(ReportStatus s) => switch (s) {
      ReportStatus.submitted => Icons.hourglass_top,
      ReportStatus.needsFix => Icons.edit_note,
      ReportStatus.approved => Icons.check_circle_outline,
      ReportStatus.rejected => Icons.cancel_outlined,
    };
Color statusColor(ReportStatus s) => switch (s) {
      ReportStatus.approved => cGreen,
      ReportStatus.rejected => cBad,
      _ => cWarn,
    };

/// Pill with icon and word. Color is a hint, never the only signal.
Widget pill(String text, Color c, {IconData? icon}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          border: Border.all(color: c, width: 1.5), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 16, color: c), const SizedBox(width: 4)],
        Flexible(child: Text(text, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w700))),
      ]),
    );

Widget statusPill(ReportStatus s) => pill(statusLabel(s), statusColor(s), icon: statusIcon(s));

Widget placeholderBox(String text) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cPh, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.info_outline, size: 18, color: cMut)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: cInk))),
      ]),
    );

const wasteChipText = 'Kategori limbah: menunggu konfirmasi tertulis dari klien. Belum menjadi keputusan.';

Widget card(Widget child, {Color? border, EdgeInsets? margin, VoidCallback? onTap}) {
  final box = Container(
    width: double.infinity,
    padding: const EdgeInsets.all(gapL),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border ?? cLine, width: border == null ? 1 : 2)),
    child: child,
  );
  return Padding(
    padding: margin ?? const EdgeInsets.only(bottom: 12),
    child: onTap == null
        ? box
        : Material(
            color: Colors.transparent,
            child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: box)),
  );
}

Widget h2(String t) => Padding(
    padding: const EdgeInsets.only(bottom: gap),
    child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cInk)));

Widget page(Widget child, {double maxWidth = 640, EdgeInsets? padding}) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding ?? const EdgeInsets.all(gapL), child: child)));

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c)
    .showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

Widget errorBanner(String msg) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: cBadBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: cBad)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, color: cBad, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: cBad, fontWeight: FontWeight.w600))),
      ]),
    );

Widget emptyState(IconData icon, String title, String body, {String? action, VoidCallback? onAction}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: gapXL),
      child: Column(children: [
        Icon(icon, size: 56, color: cMut),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(body, textAlign: TextAlign.center, style: const TextStyle(color: cMut)),
        if (action != null) ...[
          const SizedBox(height: gapL),
          FilledButton(onPressed: onAction, child: Text(action)),
        ],
      ]),
    );

Future<bool> confirm(BuildContext context, String title, String body, String label, {bool danger = false}) async {
  final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
              TextButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: Text(label, style: TextStyle(color: danger ? cBad : cGreenDark))),
            ],
          ));
  return ok == true;
}

Widget flagList(List<Flag> flags) {
  if (flags.isEmpty) {
    return const Row(children: [
      Icon(Icons.check_circle_outline, color: cGreen, size: 20),
      SizedBox(width: 8),
      Text('Tidak ada temuan.', style: TextStyle(color: cMut)),
    ]);
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final f in flags)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: f.level == 'bad' ? cBadBg : (f.level == 'warn' ? cWarnBg : cPh),
              borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(levelIcon(f.level), color: levelColor(f.level), size: 22),
            const SizedBox(width: 10),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(levelLabel(f.level),
                  style: TextStyle(color: levelColor(f.level), fontWeight: FontWeight.w800, fontSize: 13)),
              Text(f.text),
            ])),
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
  final formKey = GlobalKey<FormState>();
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

  Widget roleButton(Role r, IconData icon, String title, String sub, {bool primary = false}) {
    final child = Row(children: [
      Icon(icon, size: 28),
      const SizedBox(width: 12),
      Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Text(sub, style: TextStyle(fontSize: 13, color: primary ? Colors.white70 : cMut, fontWeight: FontWeight.w400)),
      ])),
      const Icon(Icons.chevron_right),
    ]);
    final style = ButtonStyle(
        minimumSize: WidgetStateProperty.all(const Size(double.infinity, 68)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16, vertical: 10)));
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: primary
            ? FilledButton(
                style: style, onPressed: busy ? null : () => run(() => repo.demoLogin(r)), child: child)
            : OutlinedButton(
                style: style, onPressed: busy ? null : () => run(() => repo.demoLogin(r)), child: child));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: gapL),
            Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: cGreen, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.local_shipping_outlined, color: Colors.white)),
              const SizedBox(width: 12),
              const Text('[Logo klien] Jemput Ban', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: gapXL),
            const Text('Ada ban bekas? Kami jemput.',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.15)),
            const SizedBox(height: gap),
            const Text('Laporkan ban bekas dari bengkel Anda. Tim kami memeriksa dan menjemputnya.',
                style: TextStyle(color: cMut, fontSize: 16)),
            const SizedBox(height: gapXL),
            if (repo.isDemo) ...[
              card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                h2('Coba aplikasi (mode contoh)'),
                const Text(
                    'Belum tersambung ke database. Data hanya ada di layar ini dan hilang saat halaman dimuat ulang. Pilih peran:'),
                const SizedBox(height: 12),
                roleButton(Role.reporter, Icons.edit_note, 'Pelapor', 'Bengkel atau freelancer yang melapor ban', primary: true),
                roleButton(Role.admin, Icons.fact_check_outlined, 'Admin', 'Memeriksa laporan, menyetujui atau menolak'),
                roleButton(Role.finance, Icons.account_balance_wallet_outlined, 'Admin keuangan',
                    'Melihat rekening dan mencatat transfer'),
              ])),
            ] else
              card(Form(
                  key: formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    h2(signup ? 'Daftar' : 'Masuk'),
                    if (signup) ...[
                      TextFormField(
                          controller: name,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Nama lengkap'),
                          validator: (v) => (v ?? '').trim().length < 3 ? 'Isi nama lengkap.' : null),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(labelText: 'Email'),
                        validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim())
                            ? null
                            : 'Isi email yang benar.'),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: pass,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(labelText: 'Kata sandi (minimal 8 karakter)'),
                        validator: (v) => (v ?? '').length < 8 ? 'Minimal 8 karakter.' : null),
                    const SizedBox(height: 16),
                    if (err != null) errorBanner(err!),
                    FilledButton(
                        onPressed: busy
                            ? null
                            : () {
                                if (!formKey.currentState!.validate()) return;
                                run(() => signup
                                    ? repo.signUp(name.text.trim(), email.text.trim(), pass.text)
                                    : repo.signIn(email.text.trim(), pass.text));
                              },
                        child: Text(busy ? 'Mohon tunggu...' : (signup ? 'Daftar' : 'Masuk'))),
                    TextButton(
                        onPressed: () => setState(() => signup = !signup),
                        child: Text(signup ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar')),
                  ]))),
            if (err != null && repo.isDemo) errorBanner(err!),
          ])),
        ),
      ),
    );
  }
}

// ===========================================================================
// Shell: bottom navigation (phone first), account menu on top
// ===========================================================================
class Shell extends StatefulWidget {
  final VoidCallback onLogout;
  const Shell({super.key, required this.onLogout});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  int tick = 0; // bump to reload list pages

  void go(int i) => setState(() {
        index = i;
        tick++;
      });

  Future<void> menu(String v) async {
    if (v == 'out') {
      await repo.signOut();
      widget.onLogout();
    } else if (v == 'del') {
      final ok = await confirm(context, 'Hapus data saya?',
          'Laporan, dokumen, dan rekening Anda dihapus atau dianonimkan. Tidak bisa dibatalkan.', 'Hapus',
          danger: true);
      if (!ok) return;
      try {
        await repo.deleteMyData();
        widget.onLogout();
      } on AppError catch (e) {
        if (mounted) toast(context, e.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = repo.user!;
    final staff = u.isStaff;
    final dest = staff
        ? const [
            NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check), label: 'Verifikasi'),
            NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Direktori'),
          ]
        : const [
            NavigationDestination(icon: Icon(Icons.edit_note), selectedIcon: Icon(Icons.edit_note), label: 'Lapor'),
            NavigationDestination(icon: Icon(Icons.list_alt_outlined), selectedIcon: Icon(Icons.list_alt), label: 'Laporan saya'),
          ];
    final pages = staff
        ? [AdminQueue(key: ValueKey('q$tick')), DirectoryPage(key: ValueKey('d$tick'))]
        : [ReportWizard(onGoToList: () => go(1)), MyReports(key: ValueKey('m$tick'), onNew: () => go(0))];
    return Scaffold(
      appBar: AppBar(
        title: const Text('[Logo klien] Jemput Ban', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          Flexible(
              child: Center(
                  child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(u.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))))),
          PopupMenuButton<String>(
            tooltip: 'Menu akun',
            onSelected: menu,
            itemBuilder: (c) => [
              PopupMenuItem(value: 'out', child: Text(staff ? 'Keluar (${_roleName(u.role)})' : 'Keluar')),
              if (!staff) const PopupMenuItem(value: 'del', child: Text('Hapus data saya (UU PDP)')),
            ],
          ),
        ],
      ),
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: NavigationBar(
          selectedIndex: index, onDestinationSelected: go, destinations: dest),
    );
  }

  String _roleName(Role r) => r == Role.finance ? 'keuangan' : 'admin';
}

// ===========================================================================
// Reporter: wizard
// ===========================================================================
class ReportWizard extends StatefulWidget {
  final VoidCallback onGoToList;
  const ReportWizard({super.key, required this.onGoToList});
  @override
  State<ReportWizard> createState() => _ReportWizardState();
}

class _ReportWizardState extends State<ReportWizard> {
  int step = 0;
  final d = ReportDraft();
  final keys = [GlobalKey<FormState>(), GlobalKey<FormState>(), GlobalKey<FormState>()];
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
  final scroll = ScrollController();
  String? err, uploadErr, consentErr, doneCode;
  bool busy = false, processing = false;

  static const maxPdfBytes = 5 * 1024 * 1024;
  static const maxRawBytes = 25 * 1024 * 1024;
  static const stepNames = ['Data', 'Ban', 'Bukti'];

  int _n(TextEditingController c) => int.tryParse(c.text) ?? 0;

  void toTop() {
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  void next() {
    setState(() => err = null);
    if (!(keys[step].currentState?.validate() ?? false)) return;
    if (step == 0) {
      d
        ..name = name.text.trim()
        ..whatsapp = wa.text.trim()
        ..nib = nib.text.trim()
        ..address = addr.text.trim();
    }
    if (step == 1) {
      d
        ..motor = _n(motor)
        ..car = _n(car)
        ..truck = _n(truck)
        ..weightKg = double.parse(kg.text.replaceAll(',', '.'));
    }
    setState(() => step++);
    toTop();
  }

  void back() {
    setState(() {
      step--;
      err = null;
    });
    toTop();
  }

  Future<void> pick(String kind) async {
    setState(() => uploadErr = null);
    final List<PlatformFile> res;
    try {
      res = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: kind == 'photo' ? ['jpg', 'jpeg', 'png'] : ['jpg', 'jpeg', 'png', 'pdf']);
    } catch (_) {
      return;
    }
    final files = kind == 'photo' ? res : res.take(1).toList();
    for (final f in files) {
      if (kind == 'photo' && d.files.where((x) => x.kind == 'photo').length >= 5) {
        if (mounted) toast(context, 'Maksimal 5 foto.');
        break;
      }
      setState(() => processing = true);
      await Future<void>.delayed(const Duration(milliseconds: 30)); // let the spinner paint
      try {
        var b = await f.readAsBytes();
        var fname = f.name;
        final isPdf = fname.toLowerCase().endsWith('.pdf');
        if (b.length > maxRawBytes) throw AppError('$fname terlalu besar (maks. 25 MB).');
        if (isPdf) {
          if (b.length > maxPdfBytes) throw AppError('$fname lebih dari 5 MB. Perkecil PDF atau foto saja.');
        } else {
          b = compressPhoto(b);
          fname = '${fname.replaceAll(RegExp(r'\.[^.]+$'), '')}.jpg';
        }
        setState(() {
          if (kind != 'photo') d.files.removeWhere((x) => x.kind == kind);
          d.files.add(DraftFile(kind, fname, b));
        });
      } on AppError catch (e) {
        if (mounted) setState(() => uploadErr = e.message);
      } finally {
        if (mounted) setState(() => processing = false);
      }
    }
  }

  void removeFile(DraftFile f) => setState(() => d.files.remove(f));

  String? _uploadProblem() {
    if (!d.files.any((f) => f.kind == 'nib')) return 'Unggah foto atau PDF NIB.';
    if (d.reporterType == 'freelancer' && !d.files.any((f) => f.kind == 'po')) {
      return 'Freelancer wajib mengunggah purchase order dari bengkel.';
    }
    if (d.files.where((f) => f.kind == 'photo').length < 2) return 'Unggah minimal 2 foto tumpukan ban.';
    return null;
  }

  Future<void> submit() async {
    setState(() {
      err = null;
      uploadErr = _uploadProblem();
      consentErr = d.consent ? null : 'Centang persetujuan data pribadi untuk mengirim.';
    });
    final formOk = keys[2].currentState?.validate() ?? false;
    if (!formOk || uploadErr != null || consentErr != null) return;
    d
      ..bankName = bank.text.trim()
      ..accountNo = accNo.text.trim()
      ..accountHolder = accName.text.trim();
    setState(() => busy = true);
    try {
      final code = await repo.submitReport(d);
      setState(() => doneCode = code);
      toTop();
    } on AppError catch (e) {
      setState(() => err = e.message);
    } catch (_) {
      setState(() => err = 'Gagal mengirim. Periksa sambungan internet lalu coba lagi. Data Anda masih ada di layar.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void reset() => setState(() {
        doneCode = null;
        step = 0;
        d.files.clear();
        d.consent = false;
        for (final c in [name, wa, nib, addr, kg, bank, accNo, accName]) {
          c.clear();
        }
        motor.text = '0';
        car.text = '0';
        truck.text = '0';
        err = uploadErr = consentErr = null;
      });

  Widget field(TextEditingController c, String label,
      {TextInputType? type,
      int lines = 1,
      String? hint,
      String? helper,
      bool digits = false,
      int? maxLen,
      String? Function(String?)? validator,
      List<String>? autofill}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
          controller: c,
          keyboardType: type,
          maxLines: lines,
          maxLength: maxLen,
          autofillHints: autofill,
          textInputAction: lines > 1 ? TextInputAction.newline : TextInputAction.next,
          inputFormatters: digits ? [FilteringTextInputFormatter.digitsOnly] : null,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          decoration: InputDecoration(labelText: label, hintText: hint, helperText: helper, helperMaxLines: 3, counterText: '')),
    );
  }

  Widget stepper() {
    return Row(children: [
      for (var i = 0; i < 3; i++) ...[
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              height: 8,
              decoration: BoxDecoration(color: i <= step ? cGreen : cLine, borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 4),
          Text(stepNames[i],
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: i == step ? FontWeight.w800 : FontWeight.w500,
                  color: i <= step ? cInk : cMut)),
        ])),
        if (i < 2) const SizedBox(width: 8),
      ],
    ]);
  }

  Widget uploadTile(String kind, String title, String hint, {required bool required, bool multi = false}) {
    final list = d.files.where((f) => f.kind == kind).toList();
    final has = list.isNotEmpty;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: has ? cGreen : cLine, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(has ? Icons.check_circle : Icons.upload_file, color: has ? cGreen : cMut),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
          pill(required ? 'Wajib' : 'Opsional', required ? cWarn : cMut),
        ]),
        const SizedBox(height: 4),
        Text(hint, style: const TextStyle(fontSize: 14, color: cMut)),
        if (has) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 10, runSpacing: 4, children: [
            for (final f in list)
              SizedBox(
                width: 96,
                child: Column(children: [
                  Container(
                    width: 96,
                    height: 80,
                    decoration: BoxDecoration(color: cPh, borderRadius: BorderRadius.circular(10)),
                    clipBehavior: Clip.antiAlias,
                    alignment: Alignment.center,
                    child: f.name.toLowerCase().endsWith('.pdf')
                        ? const Icon(Icons.picture_as_pdf, size: 36, color: cMut)
                        : Image.memory(f.bytes, width: 96, height: 80, fit: BoxFit.cover, gaplessPlayback: true),
                  ),
                  Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  TextButton(
                      style: TextButton.styleFrom(foregroundColor: cBad, minimumSize: const Size(48, 48)),
                      onPressed: () => removeFile(f),
                      child: const Text('Hapus')),
                ]),
              ),
          ]),
        ],
        const SizedBox(height: 4),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
          onPressed: processing ? null : () => pick(kind),
          icon: Icon(multi ? Icons.add_a_photo_outlined : Icons.attach_file),
          label: Text(has ? (multi ? 'Tambah foto' : 'Ganti berkas') : (multi ? 'Pilih foto' : 'Pilih berkas')),
        ),
      ]),
    );
  }

  Widget summary() => card(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        h2('Ringkasan laporan'),
        Text('${d.name} · ${d.reporterType == 'workshop' ? 'bengkel/toko' : 'freelancer'}'),
        Text('${d.motor} motor, ${d.car} mobil, ${d.truck} truk = ${d.total} ban'),
        Text('Perkiraan ${d.weightKg.toStringAsFixed(0)} kg · siap diambil ${fmtDate(d.pickupDate)}'),
      ]),
      margin: const EdgeInsets.only(bottom: 12));

  Widget stepBody() {
    switch (step) {
      case 0:
        return Form(
            key: keys[0],
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              h2('Siapa dan di mana'),
              field(name, 'Nama bengkel atau pelapor',
                  autofill: const [AutofillHints.organizationName],
                  validator: (v) => (v ?? '').trim().length < 3 ? 'Isi nama bengkel atau pelapor.' : null),
              field(wa, 'Nomor WhatsApp',
                  type: TextInputType.phone,
                  digits: true,
                  autofill: const [AutofillHints.telephoneNumber],
                  helper: 'Tim kami menghubungi lewat nomor ini.',
                  validator: (v) => (v ?? '').length < 9 ? 'Isi nomor WhatsApp yang benar.' : null),
              field(nib, 'Nomor NIB (13 digit)',
                  type: TextInputType.number,
                  digits: true,
                  maxLen: 13,
                  helper: 'Ada di dokumen NIB dari OSS.',
                  validator: (v) => RegExp(r'^\d{13}$').hasMatch(v ?? '') ? null : 'NIB harus 13 digit angka.'),
              Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                      initialValue: d.reporterType,
                      decoration: const InputDecoration(labelText: 'Jenis pelapor'),
                      items: const [
                        DropdownMenuItem(value: 'workshop', child: Text('Bengkel atau toko ban')),
                        DropdownMenuItem(value: 'freelancer', child: Text('Freelancer')),
                      ],
                      onChanged: (v) => setState(() => d.reporterType = v ?? 'workshop'))),
              field(addr, 'Alamat lengkap pengambilan',
                  lines: 2,
                  autofill: const [AutofillHints.fullStreetAddress],
                  helper: 'Jalan, nomor, kelurahan, kota.',
                  validator: (v) => (v ?? '').trim().length < 10 ? 'Isi alamat selengkap mungkin.' : null),
            ]));
      case 1:
        String? count(String? v) => (v == null || v.isEmpty) ? 'Isi 0 jika tidak ada.' : null;
        return Form(
            key: keys[1],
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              h2('Berapa banyak ban'),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: field(motor, 'Motor', type: TextInputType.number, digits: true, validator: count)),
                const SizedBox(width: 8),
                Expanded(child: field(car, 'Mobil', type: TextInputType.number, digits: true, validator: count)),
                const SizedBox(width: 8),
                Expanded(child: field(truck, 'Truk', type: TextInputType.number, digits: true, validator: count)),
              ]),
              FormField<int>(
                  validator: (_) => _n(motor) + _n(car) + _n(truck) == 0 ? 'Isi minimal satu ban.' : null,
                  builder: (s) => s.hasError
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(s.errorText!, style: const TextStyle(color: cBad, fontWeight: FontWeight.w600)))
                      : const SizedBox.shrink()),
              field(kg, 'Perkiraan berat total (kg)',
                  type: const TextInputType.numberWithOptions(decimal: true),
                  helper: 'Boleh perkiraan. Tim menimbang saat ambil.',
                  validator: (v) => (double.tryParse((v ?? '').replaceAll(',', '.')) ?? 0) <= 0
                      ? 'Isi perkiraan berat dalam kg.'
                      : null),
              OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  onPressed: () async {
                    final p = await showDatePicker(
                        context: context,
                        initialDate: d.pickupDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 90)));
                    if (p != null) setState(() => d.pickupDate = p);
                  },
                  label: Text('Siap diambil: ${fmtDate(d.pickupDate)}')),
              const SizedBox(height: 16),
              placeholderBox(wasteChipText),
            ]));
      default:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          summary(),
          h2('Bukti'),
          uploadTile('nib', 'Foto atau PDF NIB', 'JPG, PNG, atau PDF (maks. 5 MB).', required: true),
          uploadTile('po', 'Purchase order dari bengkel',
              d.reporterType == 'freelancer' ? 'Wajib untuk freelancer.' : 'Boleh dilewati untuk bengkel.',
              required: d.reporterType == 'freelancer'),
          uploadTile('photo', 'Foto tumpukan ban (2 sampai 5)',
              'Foto dari sudut berbeda. Foto yang sama tidak bisa dipakai dua kali. Foto diperkecil otomatis.',
              required: true, multi: true),
          if (processing)
            const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3)),
                  SizedBox(width: 12),
                  Text('Memproses foto...'),
                ])),
          if (uploadErr != null) errorBanner(uploadErr!),
          Form(
              key: keys[2],
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 8),
                h2('Rekening untuk transfer'),
                field(bank, 'Nama bank',
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Isi nama bank.' : null),
                field(accNo, 'Nomor rekening',
                    type: TextInputType.number,
                    digits: true,
                    validator: (v) => (v ?? '').length < 5 ? 'Isi nomor rekening yang benar.' : null),
                field(accName, 'Atas nama',
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Isi nama pemilik rekening.' : null),
              ])),
          Container(
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: consentErr != null ? cBad : cLine, width: 2)),
            child: CheckboxListTile(
              value: d.consent,
              onChanged: (v) => setState(() {
                d.consent = v ?? false;
                if (d.consent) consentErr = null;
              }),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                  'Saya setuju data pribadi dan rekening saya dipakai hanya untuk verifikasi dan pembayaran. Rekening hanya dilihat admin keuangan. Saya boleh minta hapus data kapan saja (UU PDP).',
                  style: TextStyle(fontSize: 14)),
            ),
          ),
          if (consentErr != null)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(consentErr!, style: const TextStyle(color: cBad, fontWeight: FontWeight.w600))),
        ]);
    }
  }

  Widget successView() => SingleChildScrollView(
      child: page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.check_circle, color: cGreen, size: 48),
          const SizedBox(height: gap),
          const Text('Laporan terkirim', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Row(children: [
            Text('Nomor laporan: $doneCode', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            IconButton(
                tooltip: 'Salin nomor laporan',
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: doneCode!));
                  if (mounted) toast(context, 'Nomor laporan disalin.');
                }),
          ]),
        ])),
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          h2('Apa selanjutnya'),
          _next(1, 'Tim memeriksa dokumen dan foto.'),
          _next(2, 'Tim survei ke lokasi dan menghitung ban.'),
          _next(3, 'Anda dikabari lewat WhatsApp: disetujui, perlu perbaikan, atau ditolak, dengan alasannya.'),
          _next(4, 'Jika disetujui, pembayaran lewat transfer ke rekening Anda. Nominal: [harga draf, belum final].'),
        ])),
        FilledButton(onPressed: widget.onGoToList, child: const Text('Lihat status laporan')),
        const SizedBox(height: gap),
        OutlinedButton(onPressed: reset, child: const Text('Buat laporan lain')),
      ])));

  Widget _next(int n, String t) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 14, backgroundColor: cGreen, child: Text('$n', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
        const SizedBox(width: 10),
        Expanded(child: Text(t)),
      ]));

  @override
  Widget build(BuildContext context) {
    if (doneCode != null) return successView();
    return Column(children: [
      Expanded(
        child: SingleChildScrollView(
          controller: scroll,
          child: page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ada ban bekas? Kami jemput.',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: 4),
            Text('Langkah ${step + 1} dari 3', style: const TextStyle(color: cMut, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            stepper(),
            const SizedBox(height: gapL),
            if (err != null) errorBanner(err!),
            card(stepBody()),
          ])),
        ),
      ),
      Material(
        color: Colors.white,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: gapL, vertical: 12),
                child: Row(children: [
                  if (step > 0) ...[
                    Expanded(
                        flex: 4,
                        child: OutlinedButton(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                            onPressed: busy ? null : back,
                            child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Kembali')))),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                      flex: 5,
                      child: FilledButton(
                          onPressed: (busy || processing) ? null : (step < 2 ? next : submit),
                          child: Text(step < 2 ? 'Lanjut' : (busy ? 'Mengirim...' : 'Kirim laporan')))),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ===========================================================================
// Reporter: my reports
// ===========================================================================
class MyReports extends StatefulWidget {
  final VoidCallback onNew;
  const MyReports({super.key, required this.onNew});
  @override
  State<MyReports> createState() => _MyReportsState();
}

class _MyReportsState extends State<MyReports> {
  late Future<List<Report>> f = repo.myReports();
  void reload() => setState(() => f = repo.myReports());

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => reload(),
      child: FutureBuilder<List<Report>>(
        future: f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) {
            return ListView(children: [
              page(emptyState(Icons.wifi_off, 'Gagal memuat laporan', 'Periksa internet Anda lalu coba lagi.',
                  action: 'Coba lagi', onAction: reload))
            ]);
          }
          final list = s.data!;
          return ListView(children: [
            page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: Text('Laporan saya', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
                TextButton.icon(onPressed: reload, icon: const Icon(Icons.refresh), label: const Text('Muat ulang')),
              ]),
              const SizedBox(height: gap),
              if (list.isEmpty)
                emptyState(Icons.inbox_outlined, 'Belum ada laporan', 'Laporkan ban bekas yang siap diambil.',
                    action: 'Buat laporan', onAction: widget.onNew),
              for (final r in list)
                card(
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${r.code} · ${r.total} ban', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                  ]),
                  const SizedBox(height: 6),
                  statusPill(r.status),
                  const SizedBox(height: 8),
                  Text('Dikirim ${fmtDate(r.createdAt)} · siap diambil ${fmtDate(r.pickupDate)}',
                      style: const TextStyle(color: cMut, fontSize: 14)),
                  if (r.decisionNote != null && r.decisionNote!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    placeholderBox('Catatan tim: ${r.decisionNote}'),
                  ],
                  if (r.paymentStatus == 'paid')
                    const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Row(children: [
                          Icon(Icons.payments_outlined, color: cGreen, size: 20),
                          SizedBox(width: 8),
                          Text('Pembayaran sudah ditransfer.'),
                        ])),
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
  void reload() => setState(() => f = repo.allReports());

  bool _open(Report r) => r.status == ReportStatus.submitted || r.status == ReportStatus.needsFix;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => reload(),
      child: FutureBuilder<List<Report>>(
        future: f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) {
            return ListView(children: [
              page(emptyState(Icons.wifi_off, 'Gagal memuat laporan', 'Periksa internet Anda lalu coba lagi.',
                  action: 'Coba lagi', onAction: reload))
            ]);
          }
          final all = s.data!;
          final nOpen = all.where(_open).length;
          final nRisk = all.where((r) => _open(r) && r.hasBad).length;
          var list = switch (filter) {
            'open' => all.where(_open).toList(),
            'approved' => all.where((r) => r.status == ReportStatus.approved).toList(),
            'rejected' => all.where((r) => r.status == ReportStatus.rejected).toList(),
            _ => List.of(all),
          };
          list.sort((a, b) => b.risk.compareTo(a.risk));
          return ListView(children: [
            page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Laporan masuk', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _stat('$nOpen', 'Perlu diperiksa', Icons.hourglass_top, cWarn)),
                const SizedBox(width: 12),
                Expanded(child: _stat('$nRisk', 'Berisiko tinggi', Icons.error_outline, cBad)),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final e in const {'open': 'Perlu diperiksa', 'approved': 'Disetujui', 'rejected': 'Ditolak', 'all': 'Semua'}.entries)
                  ChoiceChip(
                      label: Text(e.value), selected: filter == e.key, onSelected: (_) => setState(() => filter = e.key)),
              ]),
              const SizedBox(height: 12),
              if (list.isEmpty)
                emptyState(Icons.inbox_outlined, 'Tidak ada laporan', 'Laporan baru dari pelapor muncul di sini.'),
              for (final r in list) _item(r),
            ])),
          ]);
        },
      ),
    );
  }

  Widget _stat(String n, String label, IconData icon, Color c) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: cLine)),
      child: Row(children: [
        Icon(icon, color: c),
        const SizedBox(width: 10),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(n, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
          Text(label, style: const TextStyle(fontSize: 13, color: cMut)),
        ])),
      ]));

  Widget _item(Report r) {
    final issues = r.flags.where((x) => x.level != 'ok').toList();
    return card(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text('${r.code} · ${r.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
            const SizedBox(width: 8),
            pill(r.hasBad ? 'Risiko' : (r.risk > 0 ? 'Cek' : 'Aman'), r.hasBad ? cBad : (r.risk > 0 ? cWarn : cGreen),
                icon: r.hasBad ? Icons.error_outline : (r.risk > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline)),
          ]),
          const SizedBox(height: 4),
          Text('${r.total} ban · ${r.weightKg.toStringAsFixed(0)} kg · ${r.reporterType == 'workshop' ? 'bengkel/toko' : 'freelancer'}',
              style: const TextStyle(color: cMut)),
          const SizedBox(height: 6),
          statusPill(r.status),
          if (issues.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(issues.first.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: levelColor(issues.first.level), fontSize: 14)),
            if (issues.length > 1)
              Text('+${issues.length - 1} temuan lain', style: const TextStyle(color: cMut, fontSize: 13)),
          ],
        ]),
        border: r.hasBad ? cBad : null,
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminDetail(report: r)));
          reload();
        });
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
  String? noteErr, refErr;
  Map<String, String>? bank;
  bool bankLoaded = false;

  static const reasons = ['Foto ganda', 'Berat tidak wajar', 'NIB tidak cocok', 'Dokumen kurang jelas', 'Jumlah tidak sesuai'];

  @override
  void initState() {
    super.initState();
    if (repo.user?.role == Role.finance) {
      repo.bankFor(r).then((b) {
        if (mounted) {
          setState(() {
            bank = b;
            bankLoaded = true;
          });
        }
      });
    }
  }

  Future<void> decide(ReportStatus s) async {
    if (s != ReportStatus.approved && note.text.trim().isEmpty) {
      setState(() => noteErr = 'Tulis alasan agar pelapor tahu apa yang harus dilakukan.');
      return;
    }
    setState(() => noteErr = null);
    final label = statusLabel(s).toLowerCase();
    final ok = await confirm(
        context,
        s == ReportStatus.approved ? 'Setujui laporan ${r.code}?' : (s == ReportStatus.rejected ? 'Tolak laporan ${r.code}?' : 'Minta perbaikan ${r.code}?'),
        s == ReportStatus.approved
            ? 'Pelapor masuk ke direktori mitra. Pembayaran tetap manual oleh admin keuangan.'
            : 'Pelapor menerima alasan Anda. Status menjadi "$label".',
        s == ReportStatus.approved ? 'Setujui' : (s == ReportStatus.rejected ? 'Tolak' : 'Kirim'),
        danger: s == ReportStatus.rejected);
    if (!ok) return;
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
      setState(() => refErr = 'Isi nomor referensi transfer.');
      return;
    }
    setState(() {
      refErr = null;
      busy = true;
    });
    try {
      final n = await repo.markPaid(r, ref.text.trim());
      setState(() => r = n);
    } on AppError catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _kv(String k, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 104, child: Text(k, style: const TextStyle(color: cMut))),
        Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
      ]));

  @override
  Widget build(BuildContext context) {
    final isFinance = repo.user?.role == Role.finance;
    return Scaffold(
      appBar: AppBar(title: Text('${r.code} · ${r.name}', style: const TextStyle(fontSize: 17))),
      body: SingleChildScrollView(
        child: page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [statusPill(r.status)]),
          const SizedBox(height: 12),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            h2('Pelapor'),
            _kv('Nama', r.name),
            _kv('Jenis', r.reporterType == 'workshop' ? 'Bengkel / toko ban' : 'Freelancer'),
            _kv('WhatsApp', r.whatsapp),
            _kv('NIB', r.nib),
            _kv('Alamat', r.address),
            const Divider(height: 24),
            _kv('Klaim', '${r.motor} motor, ${r.car} mobil, ${r.truck} truk = ${r.total} ban'),
            _kv('Berat', '${r.weightKg.toStringAsFixed(0)} kg'),
            _kv('Siap diambil', fmtDate(r.pickupDate)),
            const SizedBox(height: 8),
            placeholderBox('$wasteChipText\nIzin angkut: menunggu konfirmasi tertulis dari klien.'),
          ])),
          card(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                h2('Pemeriksaan kecurangan'),
                flagList(r.flags),
              ]),
              border: r.hasBad ? cBad : null),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            h2('Bukti'),
            Wrap(spacing: 10, runSpacing: 10, children: [for (final f in r.files) FileTile(file: f)]),
          ])),
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            h2('Hasil survei di lokasi'),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: TextField(
                      controller: counted,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: 'Ban dihitung'))),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: countedKg,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Berat timbang (kg)'))),
            ]),
            const SizedBox(height: 16),
            const Text('Alasan atau catatan untuk pelapor', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, runSpacing: 0, children: [
              for (final x in reasons)
                ActionChip(
                    label: Text(x),
                    onPressed: () => setState(() {
                          note.text = note.text.isEmpty ? x : '${note.text}. $x';
                          note.selection = TextSelection.collapsed(offset: note.text.length);
                          noteErr = null;
                        })),
            ]),
            const SizedBox(height: 8),
            TextField(
                controller: note,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Catatan', errorText: noteErr)),
            if (r.decisionNote != null && r.decisionNote!.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Tersimpan: ${r.decisionNote}', style: const TextStyle(color: cMut))),
          ])),
          if (r.status == ReportStatus.approved)
            card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              h2('Pembayaran (transfer manual)'),
              placeholderBox('Nominal: Rp [___] DRAF. Harga belum disetujui.'),
              const SizedBox(height: 8),
              if (!isFinance)
                const Text('Data rekening hanya terlihat oleh admin keuangan.', style: TextStyle(color: cMut))
              else if (!bankLoaded)
                const Text('Memuat rekening...')
              else if (bank == null)
                const Text('Rekening tidak ditemukan.')
              else
                _kv('Rekening', '${bank!['bank']} · ${bank!['masked']} · a.n. ${bank!['holder']}'),
              const SizedBox(height: 8),
              if (r.paymentStatus == 'paid')
                Row(children: [
                  const Icon(Icons.check_circle, color: cGreen, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Sudah dibayar. Referensi: ${r.transferRef}', style: const TextStyle(color: cGreen, fontWeight: FontWeight.w700))),
                ])
              else if (isFinance) ...[
                TextField(controller: ref, decoration: InputDecoration(labelText: 'Nomor referensi transfer', errorText: refErr)),
                const SizedBox(height: 8),
                FilledButton(onPressed: busy ? null : pay, child: const Text('Tandai sudah ditransfer')),
              ] else
                const Text('Menunggu admin keuangan.'),
            ])),
          const SizedBox(height: 8),
        ])),
      ),
      bottomNavigationBar: Material(
        color: Colors.white,
        elevation: 8,
        child: SafeArea(
          child: Align(
            heightFactor: 1,
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: gapL, vertical: 12),
                child: Row(children: [
                  Expanded(
                      flex: 3,
                      child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: cBad,
                              side: const BorderSide(color: cBad, width: 2),
                              minimumSize: const Size(0, 52),
                              padding: const EdgeInsets.symmetric(horizontal: 4)),
                          onPressed: busy ? null : () => decide(ReportStatus.rejected),
                          child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Tolak')))),
                  const SizedBox(width: 8),
                  Expanded(
                      flex: 4,
                      child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 52), padding: const EdgeInsets.symmetric(horizontal: 4)),
                          onPressed: busy ? null : () => decide(ReportStatus.needsFix),
                          child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Perbaikan')))),
                  const SizedBox(width: 8),
                  Expanded(
                      flex: 4,
                      child: FilledButton(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 52), padding: const EdgeInsets.symmetric(horizontal: 4)),
                          onPressed: busy ? null : () => decide(ReportStatus.approved),
                          child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Setujui')))),
                ]),
              ),
            ),
          ),
        ),
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
    final isPdf = widget.file.name.toLowerCase().endsWith('.pdf');
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
                if (b != null) {
                  return Image.memory(b, fit: BoxFit.cover, width: 150, height: 110,
                      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: cMut));
                }
                return Icon(isPdf ? Icons.picture_as_pdf : Icons.image_outlined, size: 36, color: cMut);
              }),
        ),
        Text('$kind · ${widget.file.name}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
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
  void reload() => setState(() => f = repo.partners());

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
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Blokir', style: TextStyle(color: cBad))),
                ],
              ));
      if (ok != true) return;
      if (c.text.trim().isEmpty) {
        if (mounted) toast(context, 'Alasan blokir wajib diisi.');
        return;
      }
      reason = c.text.trim();
    } else {
      final ok = await confirm(context, 'Buka blokir ${p.name}?', 'Mitra bisa melapor dan dihubungi lagi.', 'Buka blokir');
      if (!ok) return;
    }
    try {
      await repo.setBlocked(p, !p.blocked, reason);
      reload();
    } on AppError catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  String _initials(String n) {
    final parts = n.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => reload(),
      child: FutureBuilder<List<Partner>>(
        future: f,
        builder: (c, s) {
          if (s.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (s.hasError) {
            return ListView(children: [
              page(emptyState(Icons.wifi_off, 'Gagal memuat direktori', 'Periksa internet Anda lalu coba lagi.',
                  action: 'Coba lagi', onAction: reload))
            ]);
          }
          final list = s.data!.where((p) => (p.name + p.address).toLowerCase().contains(q.toLowerCase())).toList();
          return ListView(children: [
            page(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Mitra kita', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              TextField(
                  decoration: const InputDecoration(labelText: 'Cari nama atau wilayah', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) => setState(() => q = v)),
              const SizedBox(height: 12),
              if (list.isEmpty)
                emptyState(Icons.groups_outlined, q.isEmpty ? 'Belum ada mitra' : 'Tidak ditemukan',
                    q.isEmpty ? 'Mitra muncul di sini setelah laporan disetujui.' : 'Coba kata kunci lain.'),
              for (final p in list)
                card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(
                        radius: 22,
                        backgroundColor: p.blocked ? cBadBg : cPh,
                        child: Text(_initials(p.name), style: TextStyle(fontWeight: FontWeight.w800, color: p.blocked ? cBad : cGreenDark))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      Text('${p.type == 'workshop' ? 'Bengkel/toko' : 'Freelancer'} · ${p.address}', style: const TextStyle(color: cMut, fontSize: 14)),
                    ])),
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    pill(p.blocked ? 'Diblokir' : 'Disetujui', p.blocked ? cBad : cGreen,
                        icon: p.blocked ? Icons.block : Icons.verified_outlined),
                    Text('Ambil terakhir: ${p.lastPickup == null ? 'belum ada' : fmtDate(p.lastPickup!)} · ${p.pickups} kali',
                        style: const TextStyle(color: cMut, fontSize: 14)),
                  ]),
                  if (p.blocked && p.blockReason != null) ...[
                    const SizedBox(height: 6),
                    Text('Alasan blokir: ${p.blockReason}', style: const TextStyle(color: cBad, fontSize: 14)),
                  ],
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    if (!p.blocked)
                      FilledButton.icon(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: p.whatsapp));
                            if (context.mounted) toast(context, 'Nomor WhatsApp disalin: ${p.whatsapp}');
                          },
                          label: const Text('Salin WhatsApp')),
                    OutlinedButton(onPressed: () => toggleBlock(p), child: Text(p.blocked ? 'Buka blokir' : 'Blokir')),
                  ]),
                ])),
              const SizedBox(height: 4),
              const Text('Rating mitra: kriteria belum ditentukan klien.', style: TextStyle(color: cMut, fontSize: 13)),
            ])),
          ]);
        },
      ),
    );
  }
}
