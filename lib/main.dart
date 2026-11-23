import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repo.dart';
import 'ui.dart';

/// Set at build time:
///   flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// Without them the app runs in demo mode with in-memory sample data.
const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
    final r = SupabaseRepo();
    await r.restore();
    repo = r;
  } else {
    repo = DemoRepo();
  }
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  void refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jemput Ban',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Column(children: [
        if (repo.isDemo)
          Material(
              color: const Color(0xFFFFF4D6),
              child: SafeArea(
                  bottom: false,
                  child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                          'Mode contoh: data tidak tersimpan. Teks [dalam kurung siku] adalah placeholder. Harga masih DRAF.',
                          style: const TextStyle(fontSize: 12, color: cInk))))),
        Expanded(
            child: repo.user == null
                ? AuthPage(onDone: refresh)
                : Shell(onLogout: refresh)),
      ]),
    );
  }
}
