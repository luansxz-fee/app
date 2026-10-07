import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

const kBlue = Color(0xFF2563EB);
const kBlueDark = Color(0xFF1D4ED8);
const kBg = Color(0xFFF6F8FC);

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  static const baseUrl = 'https://medsync-backend-oqms.onrender.com/api';
  final SharedPreferences prefs;
  ApiClient(this.prefs);
  String? get token => prefs.getString('token');

  Future<dynamic> request(String method, String path, {Map<String, dynamic>? body}) async {
    final headers = <String, String>{'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (token != null && token!.isNotEmpty) headers['Authorization'] = 'Bearer $token';
    final uri = Uri.parse('$baseUrl$path');
    http.Response response;
    switch (method) {
      case 'GET': response = await http.get(uri, headers: headers); break;
      case 'POST': response = await http.post(uri, headers: headers, body: jsonEncode(body ?? {})); break;
      case 'PUT': response = await http.put(uri, headers: headers, body: jsonEncode(body ?? {})); break;
      case 'PATCH': response = await http.patch(uri, headers: headers, body: jsonEncode(body ?? {})); break;
      case 'DELETE': response = await http.delete(uri, headers: headers); break;
      default: throw const ApiException('Método HTTP inválido.');
    }
    dynamic data;
    try { data = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body); } catch (_) { data = <String, dynamic>{}; }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = data is Map && data['mensagem'] != null ? data['mensagem'].toString() : 'Não foi possível concluir a operação.';
      throw ApiException(msg);
    }
    return data;
  }
}

class User {
  final String id, name, email;
  final String? avatar;
  const User({required this.id, required this.name, required this.email, this.avatar});
  factory User.fromJson(Map<String, dynamic> j) => User(id: '${j['id'] ?? ''}', name: '${j['nome'] ?? ''}', email: '${j['email'] ?? ''}', avatar: j['avatar']?.toString());
}

class Medication {
  final String id, name, dosage, unit, frequency, category, icon, color, startDate;
  final List<String> times;
  final int stock, stockMax;
  final bool active, reminder;
  final String? endDate, instructions, imageUrl, prescribedBy, sideEffects;
  const Medication({required this.id, required this.name, required this.dosage, required this.unit, required this.frequency, required this.category, required this.icon, required this.color, required this.startDate, required this.times, required this.stock, required this.stockMax, required this.active, required this.reminder, this.endDate, this.instructions, this.imageUrl, this.prescribedBy, this.sideEffects});
  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
    id: '${j['id'] ?? ''}', name: '${j['nome'] ?? ''}', dosage: '${j['dosagem'] ?? ''}', unit: '${j['unidade'] ?? ''}', frequency: '${j['frequencia'] ?? ''}', category: '${j['categoria'] ?? 'Outros'}', icon: '${j['icone'] ?? '💊'}', color: '${j['cor'] ?? '#2563EB'}', startDate: '${j['dataInicio'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now())}', times: (j['horarios'] as List? ?? const []).map((e) => '$e').toList(), stock: int.tryParse('${j['estoqueAtual'] ?? 30}') ?? 30, stockMax: int.tryParse('${j['estoqueMaximo'] ?? 30}') ?? 30, active: j['ativo'] != false, reminder: j['lembreteAtivo'] != false, endDate: j['dataTermino']?.toString(), instructions: j['instrucoes']?.toString(), imageUrl: j['urlImagem']?.toString(), prescribedBy: j['medicoPrescritor']?.toString(), sideEffects: j['efeitosColaterais']?.toString());
  Map<String, dynamic> toApi() => {'nome': name, 'dosagem': dosage, 'unidade': unit, 'frequencia': frequency, 'horarios': times, 'dataInicio': startDate, 'dataTermino': endDate, 'instrucoes': instructions, 'cor': color, 'icone': icon, 'categoria': category, 'estoqueAtual': stock, 'estoqueMaximo': stockMax, 'lembreteAtivo': reminder, 'ativo': active, 'urlImagem': imageUrl, 'medicoPrescritor': prescribedBy, 'efeitosColaterais': sideEffects};
}

class DoseLog {
  final String id, medicationId, time, status, date;
  final String? note;
  const DoseLog({required this.id, required this.medicationId, required this.time, required this.status, required this.date, this.note});
  factory DoseLog.fromJson(Map<String, dynamic> j) => DoseLog(id: '${j['id'] ?? ''}', medicationId: '${j['medicamentoId'] ?? ''}', time: '${j['horarioAgendado'] ?? ''}', status: '${j['situacao'] ?? 'pendente'}', date: '${j['dataDose'] ?? ''}', note: j['observacao']?.toString());
}

class MedStore extends ChangeNotifier {
  final ApiClient api;
  User? user;
  List<Medication> meds = [];
  List<DoseLog> logs = [];
  int adherence7 = 100, adherence30 = 100;
  bool loading = false, dark = false, accessible = false;
  MedStore(this.api);

  Future<void> bootstrap() async {
    dark = api.prefs.getBool('dark') ?? false; accessible = api.prefs.getBool('accessible') ?? false;
    final cached = api.prefs.getString('user'); if (cached != null) user = User.fromJson(jsonDecode(cached));
    if (api.token != null) { try { await refresh(); } catch (_) {} }
    notifyListeners();
  }
  Future<void> refresh() async {
    loading = true; notifyListeners();
    try {
      final u = await api.request('GET', '/auth/eu'); user = User.fromJson(Map<String, dynamic>.from(u['usuario'])); await _saveUser();
      final m = await api.request('GET', '/medicamentos'); meds = (m['dados'] as List? ?? []).map((e) => Medication.fromJson(Map<String, dynamic>.from(e))).toList();
      final l = await api.request('GET', '/registros?dias=30'); logs = (l['dados'] as List? ?? []).map((e) => DoseLog.fromJson(Map<String, dynamic>.from(e))).toList();
      final a = await api.request('GET', '/registros/adesao'); adherence7 = int.tryParse('${a['dados']?['dias7'] ?? 100}') ?? 100; adherence30 = int.tryParse('${a['dados']?['dias30'] ?? 100}') ?? 100;
    } finally { loading = false; notifyListeners(); }
  }
  Future<void> login(String email, String password) async { final r = await api.request('POST', '/auth/login', body: {'email': email.trim(), 'senha': password}); await _setAuth(r); }
  Future<void> register(String name, String email, String password) async { final r = await api.request('POST', '/auth/registrar', body: {'nome': name.trim(), 'email': email.trim(), 'senha': password}); await _setAuth(r); }
  Future<void> _setAuth(Map<String, dynamic> r) async { await api.prefs.setString('token', '${r['token']}'); user = User.fromJson(Map<String, dynamic>.from(r['usuario'])); await _saveUser(); await refresh(); }
  Future<void> _saveUser() async { if (user != null) await api.prefs.setString('user', jsonEncode({'id': user!.id, 'nome': user!.name, 'email': user!.email, 'avatar': user!.avatar})); }
  Future<void> logout() async { await api.prefs.remove('token'); await api.prefs.remove('user'); user = null; meds = []; logs = []; notifyListeners(); }
  Future<void> updateProfile(String name) async { final r = await api.request('PUT', '/auth/eu', body: {'nome': name.trim()}); user = User.fromJson(Map<String, dynamic>.from(r['usuario'])); await _saveUser(); notifyListeners(); }
  Future<void> addMedication(Map<String, dynamic> body) async { await api.request('POST', '/medicamentos', body: body); await refresh(); }
  Future<void> editMedication(String id, Map<String, dynamic> body) async { await api.request('PUT', '/medicamentos/$id', body: body); await refresh(); }
  Future<void> deleteMedication(String id) async { await api.request('DELETE', '/medicamentos/$id'); await refresh(); }
  Future<void> toggleMedication(String id) async { final r = await api.request('PATCH', '/medicamentos/$id/alternar'); final updated = Medication.fromJson(Map<String, dynamic>.from(r['dados'])); final i = meds.indexWhere((m) => m.id == id); if (i >= 0) { meds[i] = updated; notifyListeners(); } }
  Future<void> logDose(String medId, String time, String status, {String? note}) async { await api.request('POST', '/registros', body: {'medicamentoId': medId, 'horarioAgendado': time, 'situacao': status, 'observacao': note}); await refresh(); }
  void setDark(bool v) { dark = v; api.prefs.setBool('dark', v); notifyListeners(); }
  void setAccessible(bool v) { accessible = v; api.prefs.setBool('accessible', v); notifyListeners(); }
}

class AppScope extends InheritedNotifier<MedStore> {
  const AppScope({super.key, required super.notifier, required super.child});
  static MedStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

Future<void> main() async { WidgetsFlutterBinding.ensureInitialized(); final prefs = await SharedPreferences.getInstance(); final store = MedStore(ApiClient(prefs)); await store.bootstrap(); runApp(AppScope(notifier: store, child: const MedSyncApp())); }

class MedSyncApp extends StatelessWidget {
  const MedSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final light = ColorScheme.fromSeed(seedColor: kBlue, brightness: Brightness.light);
    final dark = ColorScheme.fromSeed(seedColor: kBlue, brightness: Brightness.dark);

    ThemeData theme(ColorScheme scheme, {required bool darkMode}) {
      final background = darkMode ? const Color(0xFF07111F) : const Color(0xFFF5F8FC);
      final surface = darkMode ? const Color(0xFF0F1B2D) : Colors.white;
      final elevated = darkMode ? const Color(0xFF132238) : const Color(0xFFF9FBFF);
      final border = darkMode ? const Color(0xFF24344B) : const Color(0xFFE3EAF4);
      return ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: background,
        fontFamily: 'Roboto',
        splashFactory: InkSparkle.splashFactory,
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: kBlue.withValues(alpha: darkMode ? .10 : .08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: border)),
        ),
        dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: darkMode ? const Color(0xFF0B1728) : const Color(0xFFF8FAFD),
          contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: kBlue, width: 1.8)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFEF4444))),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8)),
          labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
        ),
        filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
          backgroundColor: kBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: .05),
        )),
        outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
          foregroundColor: kBlue,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        )),
        textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: kBlue, textStyle: const TextStyle(fontWeight: FontWeight.w800))),
        chipTheme: ChipThemeData(
          backgroundColor: darkMode ? const Color(0xFF17263B) : const Color(0xFFF0F5FC),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        navigationBarTheme: NavigationBarThemeData(
          height: 74,
          backgroundColor: surface,
          indicatorColor: kBlue.withValues(alpha: .12),
          labelTextStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ),
        navigationRailTheme: NavigationRailThemeData(
          backgroundColor: surface,
          selectedIconTheme: const IconThemeData(color: kBlue),
          unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
          selectedLabelTextStyle: const TextStyle(color: kBlue, fontWeight: FontWeight.w900),
          unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700),
          indicatorColor: kBlue.withValues(alpha: .10),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: elevated,
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        )),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MedSync',
      theme: theme(light, darkMode: false),
      darkTheme: theme(dark, darkMode: true),
      themeMode: s.dark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(s.accessible ? 1.12 : 1.0)),
        child: child!,
      ),
      home: s.user == null ? const LandingPage() : const ShellPage(),
    );
  }
}

class LogoMark extends StatelessWidget {
  final double size;
  const LogoMark({super.key, this.size = 64});
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'MedSync',
        image: true,
        child: CustomPaint(size: Size.square(size), painter: _LogoPainter()),
      );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final scale = s.width / 32;
    final center = Offset(s.width / 2, s.height / 2);
    c.drawCircle(center, 15 * scale, Paint()..color = kBlue.withValues(alpha: .15));
    c.drawCircle(center, 15 * scale, Paint()..color = kBlue..style = PaintingStyle.stroke..strokeWidth = 1.5 * scale);
    final wave = Path()..moveTo(8 * scale, 16 * scale)..lineTo(12 * scale, 16 * scale)..lineTo(14.5 * scale, 10 * scale)..lineTo(17.5 * scale, 20 * scale)..lineTo(20 * scale, 14 * scale)..lineTo(24 * scale, 14 * scale);
    c.drawPath(wave, Paint()..color = kBlue..style = PaintingStyle.stroke..strokeWidth = 2 * scale..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    c.drawCircle(center, 2 * scale, Paint()..color = kBlue);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Brand extends StatelessWidget {
  final double logoSize;
  final bool light;
  const Brand({super.key, this.logoSize = 44, this.light = false});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        LogoMark(size: logoSize),
        const SizedBox(width: 11),
        Text('MedSync', style: TextStyle(fontSize: logoSize > 45 ? 25 : 21, fontWeight: FontWeight.w900, letterSpacing: -.8, color: light ? Colors.white : kBlue)),
      ]);
}

class _Ambient extends StatelessWidget {
  final Widget child;
  const _Ambient({required this.child});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(children: [
      Positioned(top: -150, right: -120, child: IgnorePointer(child: Container(width: 390, height: 390, decoration: BoxDecoration(shape: BoxShape.circle, color: kBlue.withValues(alpha: dark ? .12 : .065))))),
      Positioned(bottom: -190, left: -140, child: IgnorePointer(child: Container(width: 430, height: 430, decoration: BoxDecoration(shape: BoxShape.circle, color: kBlue.withValues(alpha: dark ? .08 : .035))))),
      child,
    ]);
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  void login(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  void register(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _Ambient(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, viewport) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1240),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _LandingHeader(onLogin: () => login(context)),
                          const SizedBox(height: 30),
                          LayoutBuilder(
                            builder: (context, content) {
                              final wide = content.maxWidth >= 920;
                              final copy = _LandingCopy(
                                onLogin: () => login(context),
                                onRegister: () => register(context),
                              );
                              final preview = _LandingPreview(dark: dark);

                              if (wide) {
                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(flex: 10, child: copy),
                                    const SizedBox(width: 56),
                                    Expanded(flex: 9, child: preview),
                                  ],
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  copy,
                                  const SizedBox(height: 38),
                                  preview,
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 66),
                          const _LandingFeatureGrid(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LandingHeader extends StatelessWidget {
  final VoidCallback onLogin;
  const _LandingHeader({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 430;
        return Row(
          children: [
            const Brand(logoSize: 46),
            const Spacer(),
            if (!compact)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  'Sua rotina, mais simples',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Entrar'),
            ),
          ],
        );
      },
    );
  }
}

class _LandingCopy extends StatelessWidget {
  final VoidCallback onLogin;
  final VoidCallback onRegister;
  const _LandingCopy({required this.onLogin, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kBlue.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: kBlue.withValues(alpha: .13)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, color: kBlue, size: 16),
              SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Uma nova forma de cuidar da sua rotina',
                  style: TextStyle(color: kBlue, fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Cuidado mais simples.\nRotina mais inteligente.',
          style: text.displayMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.0,
            letterSpacing: -2.2,
          ),
        ),
        const SizedBox(height: 19),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Text(
            'O MedSync transforma seus medicamentos em uma experiência clara, bonita e organizada — para você saber o que fazer, no momento certo.',
            style: text.titleMedium?.copyWith(
              color: muted,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 27),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Pill(icon: Icons.schedule_rounded, text: 'Horários claros'),
            _Pill(icon: Icons.insights_rounded, text: 'Adesão acompanhada'),
            _Pill(icon: Icons.accessibility_new_rounded, text: 'Acessibilidade'),
          ],
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: onLogin,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Entrar no MedSync'),
            ),
            OutlinedButton.icon(
              onPressed: onRegister,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Criar conta'),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            const _AvatarDot(letter: 'M'),
            const _AvatarDot(letter: 'S'),
            const _AvatarDot(letter: 'A'),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Uma experiência pensada para acompanhar você todos os dias.',
                style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LandingPreview extends StatelessWidget {
  final bool dark;
  const _LandingPreview({required this.dark});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .97, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF0E1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: kBlue.withValues(alpha: .18),
              blurRadius: 70,
              offset: const Offset(0, 28),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF101F35) : const Color(0xFFF6F9FE),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kBlue.withValues(alpha: .09),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const LogoMark(size: 44),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bom dia 👋', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text('Visão geral', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  const Icon(Icons.more_horiz_rounded),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(19),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [kBlue, kBlueDark],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.today_rounded, color: Colors.white70, size: 16),
                        SizedBox(width: 7),
                        Text('HOJE', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                        Spacer(),
                        Text('75%', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text('3 de 4 doses', style: TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -.8)),
                    SizedBox(height: 5),
                    Text('Você está no ritmo certo.', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    SizedBox(height: 15),
                    ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                      child: LinearProgressIndicator(
                        value: .75,
                        minHeight: 8,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              const _PreviewDose(name: 'Vitamina D', time: '08:00', done: true),
              const _PreviewDose(name: 'Losartana', time: '13:00', done: true),
              const _PreviewDose(name: 'Metformina', time: '19:00', done: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewDose extends StatelessWidget {
  final String name, time; final bool done;
  const _PreviewDose({required this.name, required this.time, required this.done});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: done ? const Color(0xFF16A34A) : kBlue, size: 20), const SizedBox(width: 10), Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800))), Text(time, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800, fontSize: 12))]));
}

class _Pill extends StatelessWidget {
  final IconData icon; final String text;
  const _Pill({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10), decoration: BoxDecoration(color: kBlue.withValues(alpha: .065), borderRadius: BorderRadius.circular(14), border: Border.all(color: kBlue.withValues(alpha: .10))), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: kBlue, size: 17), const SizedBox(width: 8), Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5))]));
}

class _AvatarDot extends StatelessWidget {
  final String letter;
  const _AvatarDot({required this.letter});
  @override
  Widget build(BuildContext context) => Container(width: 30, height: 30, margin: EdgeInsets.zero, decoration: BoxDecoration(color: kBlue, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2)), child: Center(child: Text(letter, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))));
}

class _LandingFeatureGrid extends StatelessWidget {
  const _LandingFeatureGrid();
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
    final cols = c.maxWidth > 850 ? 3 : c.maxWidth > 520 ? 2 : 1;
    final items = const [
      [Icons.medication_outlined, 'Medicamentos sem bagunça', 'Cadastre doses, horários, estoque e informações importantes em um só lugar.'],
      [Icons.task_alt_rounded, 'Cada dose no seu lugar', 'Registre rapidamente quando tomar e acompanhe o que já foi concluído.'],
      [Icons.insights_outlined, 'Clareza sobre sua rotina', 'Visualize adesão, histórico e alertas sem precisar procurar informações.'],
    ];
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: cols == 1 ? 4.1 : 1.65), itemBuilder: (_, i) => Card(child: Padding(padding: const EdgeInsets.all(19), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: kBlue.withValues(alpha: .09), borderRadius: BorderRadius.circular(15)), child: Icon(items[i][0] as IconData, color: kBlue)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(items[i][1] as String, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)), const SizedBox(height: 6), Text(items[i][2] as String, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45, fontSize: 12))]))]))));
  });
}

class AuthScaffold extends StatelessWidget {
  final String eyebrow, title, subtitle;
  final Widget form;
  final String footer, footerActionText;
  final VoidCallback footerAction;
  const AuthScaffold({super.key, required this.eyebrow, required this.title, required this.subtitle, required this.form, required this.footer, required this.footerAction, required this.footerActionText});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: _Ambient(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: LayoutBuilder(builder: (context, c) {
                  final wide = c.maxWidth >= 850;
                  final intro = Container(
                    padding: const EdgeInsets.all(34),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [kBlue, kBlueDark]),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: kBlue.withValues(alpha: .20), blurRadius: 45, offset: const Offset(0, 20))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Brand(logoSize: 52, light: true),
                      const SizedBox(height: 58),
                      Container(width: 52, height: 52, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.favorite_outline_rounded, color: Colors.white)),
                      const SizedBox(height: 22),
                      const Text('Sua rotina merece\nmais clareza.', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, height: 1.02, letterSpacing: -1.4)),
                      const SizedBox(height: 12),
                      const Text('Um espaço bonito, simples e acolhedor para acompanhar medicamentos e doses.', style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 13.5, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 24),
                      const _AuthCheck(text: 'Rotina organizada'),
                      const _AuthCheck(text: 'Acompanhamento de adesão'),
                      const _AuthCheck(text: 'Experiência acessível'),
                    ]),
                  );
                  final formCard = Container(
                    padding: const EdgeInsets.fromLTRB(30, 30, 30, 25),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF0F1B2D) : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: kBlue.withValues(alpha: dark ? .18 : .10)),
                      boxShadow: [BoxShadow(color: kBlue.withValues(alpha: dark ? .10 : .08), blurRadius: 40, offset: const Offset(0, 18))],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(eyebrow.toUpperCase(), style: const TextStyle(color: kBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
                      const SizedBox(height: 10),
                      Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.8)),
                      const SizedBox(height: 8),
                      Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.45)),
                      const SizedBox(height: 24),
                      form,
                      const SizedBox(height: 20),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Flexible(child: Text(footer, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5))),
                        TextButton(onPressed: footerAction, child: Text(footerActionText)),
                      ]),
                    ]),
                  );
                  if (wide) {
                    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Expanded(child: SizedBox(height: 510, child: intro)),
                      const SizedBox(width: 18),
                      Expanded(child: formCard),
                    ]);
                  }
                  return Column(children: [intro, const SizedBox(height: 16), formCard]);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthCheck extends StatelessWidget { final String text; const _AuthCheck({required this.text}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 11), child: Row(children: [Container(width: 21, height: 21, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), shape: BoxShape.circle), child: const Icon(Icons.check_rounded, color: Colors.white, size: 14)), const SizedBox(width: 9), Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5))])); }

class LoginPage extends StatefulWidget { const LoginPage({super.key}); @override State<LoginPage> createState() => _LoginPageState(); }
class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController(), password = TextEditingController(); bool busy = false, obscure = true;
  @override void dispose() { email.dispose(); password.dispose(); super.dispose(); }
  Future<void> submit() async { if (!email.text.contains('@') || password.text.length < 6) { snack(context, 'Informe um e-mail válido e uma senha com pelo menos 6 caracteres.'); return; } setState(() => busy = true); try { await AppScope.of(context).login(email.text, password.text); if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ShellPage()), (_) => false); } catch (e) { if (mounted) snack(context, e.toString()); } finally { if (mounted) setState(() => busy = false); } }
  @override Widget build(BuildContext context) => AuthScaffold(eyebrow: 'Bem-vindo de volta', title: 'Entre na sua conta', subtitle: 'Continue de onde parou e veja sua rotina de hoje.', footer: 'Ainda não tem conta?', footerAction: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisterPage())), footerActionText: 'Criar conta', form: Column(children: [TextField(controller: email, keyboardType: TextInputType.emailAddress, autofillHints: const [AutofillHints.username, AutofillHints.email], decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.alternate_email_rounded))), const SizedBox(height: 13), TextField(controller: password, obscureText: obscure, autofillHints: const [AutofillHints.password], decoration: InputDecoration(labelText: 'Senha', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(tooltip: obscure ? 'Mostrar senha' : 'Ocultar senha', onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))), const SizedBox(height: 20), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : submit, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login_rounded), label: Text(busy ? 'Entrando...' : 'Entrar com segurança')))]));
}

class RegisterPage extends StatefulWidget { const RegisterPage({super.key}); @override State<RegisterPage> createState() => _RegisterPageState(); }
class _RegisterPageState extends State<RegisterPage> {
  final name = TextEditingController(), email = TextEditingController(), password = TextEditingController(), confirm = TextEditingController(); bool busy = false, obscure = true;
  @override void dispose() { name.dispose(); email.dispose(); password.dispose(); confirm.dispose(); super.dispose(); }
  Future<void> submit() async { if (name.text.trim().length < 2 || !email.text.contains('@') || password.text.length < 6 || password.text != confirm.text) { snack(context, 'Revise nome, e-mail e senhas. A senha deve ter pelo menos 6 caracteres.'); return; } setState(() => busy = true); try { await AppScope.of(context).register(name.text, email.text, password.text); if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const ShellPage()), (_) => false); } catch (e) { if (mounted) snack(context, e.toString()); } finally { if (mounted) setState(() => busy = false); } }
  @override Widget build(BuildContext context) => AuthScaffold(eyebrow: 'Comece agora', title: 'Crie seu espaço', subtitle: 'Leva menos de um minuto para deixar sua rotina mais organizada.', footer: 'Já possui uma conta?', footerAction: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())), footerActionText: 'Entrar', form: Column(children: [TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome completo', prefixIcon: Icon(Icons.person_outline_rounded))), const SizedBox(height: 12), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'E-mail', prefixIcon: Icon(Icons.alternate_email_rounded))), const SizedBox(height: 12), TextField(controller: password, obscureText: obscure, decoration: InputDecoration(labelText: 'Senha', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))), const SizedBox(height: 12), TextField(controller: confirm, obscureText: obscure, decoration: const InputDecoration(labelText: 'Confirmar senha', prefixIcon: Icon(Icons.verified_user_outlined))), const SizedBox(height: 20), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : submit, icon: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.arrow_forward_rounded), label: Text(busy ? 'Criando...' : 'Criar minha conta')))]));
}

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});
  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  int index = 0;
  final pages = const [DashboardPage(), MedicationsPage(), HistoryPage(), ProfilePage()];
  final labels = const ['Visão geral', 'Medicamentos', 'Histórico', 'Perfil'];
  final icons = const [Icons.dashboard_rounded, Icons.medication_rounded, Icons.history_rounded, Icons.person_rounded];

  void go(int value) => setState(() => index = value);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      body: wide
          ? Row(children: [
              _Sidebar(index: index, onSelect: go),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: KeyedSubtree(key: ValueKey(index), child: pages[index]),
                ),
              ),
            ])
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: KeyedSubtree(key: ValueKey(index), child: pages[index]),
            ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: go,
              destinations: [
                for (int i = 0; i < labels.length; i++)
                  NavigationDestination(icon: Icon(icons[i]), selectedIcon: Icon(icons[i]), label: labels[i]),
              ],
            ),
      floatingActionButton: index == 1
          ? FloatingActionButton.extended(
              onPressed: () => showDialog(context: context, builder: (_) => const MedicationForm()),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novo medicamento'),
            )
          : null,
    );
  }
}

class _Sidebar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const _Sidebar({required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final user = s.user;
    final labels = const ['Visão geral', 'Medicamentos', 'Histórico', 'Perfil'];
    final icons = const [Icons.dashboard_rounded, Icons.medication_rounded, Icons.history_rounded, Icons.person_rounded];
    final initial = user?.name.trim().isNotEmpty == true ? user!.name.trim()[0].toUpperCase() : '?';
    return Container(
      width: 272,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Brand(logoSize: 46),
              const SizedBox(height: 38),
              Text('NAVEGAÇÃO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              for (int i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _SideItem(index: i, selected: i == index, label: labels[i], icon: icons[i], onTap: () => onSelect(i)),
                ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kBlue.withValues(alpha: .06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kBlue.withValues(alpha: .10)),
                ),
                child: Row(children: [
                  CircleAvatar(radius: 21, backgroundColor: kBlue, child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900))),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user?.name ?? 'Usuário', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5)),
                    const SizedBox(height: 3),
                    Text('Conta ativa', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5)),
                  ])),
                ]),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .5), borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Expanded(child: _ThemeButton(icon: Icons.light_mode_rounded, label: 'Claro', selected: !s.dark, onTap: () => s.setDark(false))),
                  Expanded(child: _ThemeButton(icon: Icons.dark_mode_rounded, label: 'Escuro', selected: s.dark, onTap: () => s.setDark(true))),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  final int index;
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SideItem({required this.index, required this.selected, required this.label, required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
            decoration: BoxDecoration(color: selected ? kBlue.withValues(alpha: .12) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(icon, size: 20, color: selected ? kBlue : Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w900 : FontWeight.w700, color: selected ? kBlue : null))),
              if (selected) Container(width: 6, height: 6, decoration: const BoxDecoration(color: kBlue, shape: BoxShape.circle)),
            ]),
          ),
        ),
      );
}

class _ThemeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeButton({required this.icon, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: selected ? Theme.of(context).colorScheme.surface : Colors.transparent, borderRadius: BorderRadius.circular(11)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 15, color: selected ? kBlue : Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800))]),
        ),
      );
}

class PageFrame extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget? action;
  final Widget child;
  const PageFrame({super.key, this.eyebrow = 'MEDSYNC', required this.title, required this.subtitle, this.action, required this.child});

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1260),
            child: Padding(
              padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width < 600 ? 16 : 28, 24, MediaQuery.sizeOf(context).width < 600 ? 16 : 28, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                LayoutBuilder(builder: (context, box) {
                  final compact = box.maxWidth < 650;
                  final heading = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(eyebrow, style: const TextStyle(color: kBlue, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 6),
                    Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.8)),
                    const SizedBox(height: 5),
                    Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.35)),
                  ]);
                  if (action == null) return heading;
                  if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [heading, const SizedBox(height: 14), Align(alignment: Alignment.centerLeft, child: action)]);
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: heading), const SizedBox(width: 16), action!]);
                }),
                const SizedBox(height: 22),
                Expanded(child: child),
              ]),
            ),
          ),
        ),
      );
}

class SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? action;
  const SectionCard({super.key, required this.title, this.subtitle = '', required this.icon, required this.child, this.action});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(21),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: kBlue.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: kBlue, size: 21)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                if (subtitle.isNotEmpty) ...[const SizedBox(height: 3), Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11.5, height: 1.35))],
              ])),
              if (action != null) Padding(padding: const EdgeInsets.only(left: 10), child: action!),
            ]),
            const SizedBox(height: 18),
            child,
          ]),
        ),
      );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final active = s.meds.where((m) => m.active).toList();
    final scheduled = <MapEntry<Medication, String>>[];
    for (final med in active) {
      for (final time in med.times) {
        scheduled.add(MapEntry(med, time));
      }
    }
    scheduled.sort((a, b) => a.value.compareTo(b.value));
    final today = DateTime.now();
    final done = s.logs.where((l) {
      final date = DateTime.tryParse(l.date);
      return l.status.toLowerCase() == 'tomada' && date != null && date.year == today.year && date.month == today.month && date.day == today.day;
    }).length.clamp(0, scheduled.length);
    final progress = scheduled.isEmpty ? 0.0 : (done / scheduled.length).clamp(0, 1).toDouble();
    return PageFrame(
      eyebrow: 'CENTRAL DO DIA',
      title: 'Visão geral',
      subtitle: 'Uma leitura clara da sua rotina, sem excesso de informação.',
      action: IconButton(tooltip: 'Atualizar dados', onPressed: s.loading ? null : () => s.refresh(), icon: const Icon(Icons.refresh_rounded)),
      child: RefreshIndicator(
        onRefresh: s.refresh,
        child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
          _DashboardHero(done: done, total: scheduled.length, progress: progress, name: s.user?.name ?? 'Olá'),
          const SizedBox(height: 16),
          _DashboardMetrics(active: active.length, done: done, total: scheduled.length, adherence7: s.adherence7, adherence30: s.adherence30),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Rotina de hoje',
            subtitle: scheduled.isEmpty ? 'Sua agenda começa assim que você cadastrar um medicamento.' : 'Doses organizadas por horário para você não perder o ritmo.',
            icon: Icons.schedule_rounded,
            action: scheduled.isEmpty ? null : _SmallCount('${scheduled.length} ${scheduled.length == 1 ? 'dose' : 'doses'}'),
            child: scheduled.isEmpty
                ? const EmptyState(icon: Icons.medication_outlined, title: 'Nenhuma dose programada', subtitle: 'Adicione um medicamento e defina os horários da sua rotina.')
                : Column(children: [for (int i = 0; i < scheduled.length; i++) Padding(padding: EdgeInsets.only(bottom: i == scheduled.length - 1 ? 0 : 10), child: DoseTile(med: scheduled[i].key, time: scheduled[i].value, onStatus: (status) => AppScope.of(context).logDose(scheduled[i].key.id, scheduled[i].value, status)))]),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, box) {
            final low = active.where((m) => m.stockMax > 0 && m.stock / m.stockMax <= .25).toList();
            final cards = [
              _InsightCard(title: 'Adesão recente', value: '${s.adherence7}%', subtitle: 'últimos 7 dias', progress: s.adherence7 / 100, icon: Icons.trending_up_rounded, color: const Color(0xFF16A34A)),
              _InsightCard(title: 'Estoque em atenção', value: '${low.length}', subtitle: low.isEmpty ? 'Tudo sob controle' : 'itens precisam de reposição', progress: low.isEmpty ? 1 : .25, icon: Icons.inventory_2_outlined, color: low.isEmpty ? const Color(0xFF16A34A) : const Color(0xFFF59E0B)),
            ];
            return box.maxWidth >= 720 ? Row(children: [Expanded(child: cards[0]), const SizedBox(width: 14), Expanded(child: cards[1])]) : Column(children: [cards[0], const SizedBox(height: 14), cards[1]]);
          }),
        ]),
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  final int done;
  final int total;
  final double progress;
  final String name;
  const _DashboardHero({required this.done, required this.total, required this.progress, required this.name});

  @override
  Widget build(BuildContext context) {
    final first = name.trim().split(' ').first;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: kBlue.withValues(alpha: .18), blurRadius: 34, offset: const Offset(0, 15))],
      ),
      child: LayoutBuilder(builder: (context, box) {
        final compact = box.maxWidth < 640;
        final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('OLÁ, ${first.toUpperCase()}', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.3)),
          const SizedBox(height: 9),
          Text(total == 0 ? 'Vamos começar.' : 'Seu dia está em boas mãos.', style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -.6)),
          const SizedBox(height: 6),
          Text(total == 0 ? 'Cadastre sua primeira rotina para acompanhar tudo em um só lugar.' : progress >= 1 ? 'Todas as doses de hoje foram registradas.' : '$done de $total ${total == 1 ? 'dose registrada' : 'doses registradas'} hoje.', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
          const SizedBox(height: 18),
          ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white))),
        ]);
        final ring = Container(
          width: 142, height: 142,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .08), border: Border.all(color: Colors.white.withValues(alpha: .16)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .16), blurRadius: 26, offset: const Offset(0, 10))]),
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(width: 124, height: 124, child: CircularProgressIndicator(value: progress, strokeWidth: 11, strokeCap: StrokeCap.round, backgroundColor: Colors.white.withValues(alpha: .16), valueColor: const AlwaysStoppedAnimation<Color>(Colors.white))),
            Column(mainAxisSize: MainAxisSize.min, children: [Text('${(progress * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -.7)), const SizedBox(height: 2), Text('$done/$total doses', style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800))]),
          ]),
        );
        if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [copy, const SizedBox(height: 22), Align(alignment: Alignment.centerRight, child: ring)]);
        return Row(children: [Expanded(child: copy), const SizedBox(width: 34), ring]);
      }),
    );
  }
}

class _DashboardMetrics extends StatelessWidget {
  final int active, done, total, adherence7, adherence30;
  const _DashboardMetrics({required this.active, required this.done, required this.total, required this.adherence7, required this.adherence30});
  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(label: 'Medicamentos ativos', value: '$active', icon: Icons.medication_rounded, color: kBlue),
      _MetricCard(label: 'Doses de hoje', value: '$done/$total', icon: Icons.task_alt_rounded, color: const Color(0xFF16A34A)),
      _MetricCard(label: 'Adesão • 7 dias', value: '$adherence7%', icon: Icons.insights_rounded, color: const Color(0xFF7C3AED)),
      _MetricCard(label: 'Adesão • 30 dias', value: '$adherence30%', icon: Icons.calendar_month_rounded, color: const Color(0xFFF59E0B)),
    ];
    return LayoutBuilder(builder: (context, box) {
      final columns = box.maxWidth >= 1050 ? 4 : box.maxWidth >= 650 ? 2 : 1;
      if (columns == 1) return Column(children: [for (int i = 0; i < cards.length; i++) Padding(padding: EdgeInsets.only(bottom: i == cards.length - 1 ? 0 : 10), child: cards[i])]);
      return GridView.count(crossAxisCount: columns, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: columns == 4 ? 1.8 : 2.5, children: cards);
    });
  }
}

class _MetricCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MetricCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.surface, color.withValues(alpha: .055)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: .18)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: .07), blurRadius: 22, offset: const Offset(0, 9))],
      ),
      padding: const EdgeInsets.all(17),
      child: Row(children: [
        Container(width: 50, height: 50, decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: .12))), child: Icon(icon, color: color, size: 23)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(value, style: TextStyle(color: color, fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.5)),
          const SizedBox(height: 4),
          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: cs.onSurface, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ])),
      ]),
    );
  }
}

class _SmallCount extends StatelessWidget {
  final String text;
  const _SmallCount(this.text);
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), decoration: BoxDecoration(color: kBlue.withValues(alpha: .07), borderRadius: BorderRadius.circular(99)), child: Text(text, style: const TextStyle(color: kBlue, fontSize: 10, fontWeight: FontWeight.w900)));
}

class _InsightCard extends StatelessWidget {
  final String title, value, subtitle;
  final double progress;
  final IconData icon;
  final Color color;
  const _InsightCard({required this.title, required this.value, required this.subtitle, required this.progress, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), const SizedBox(height: 3), Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 21)), Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)), const SizedBox(height: 9), ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress.clamp(0, 1).toDouble(), minHeight: 5, color: color, backgroundColor: color.withValues(alpha: .08)))])),
      ])));
}

class DoseTile extends StatefulWidget {
  final Medication med;
  final String time;
  final Future<void> Function(String) onStatus;
  const DoseTile({super.key, required this.med, required this.time, required this.onStatus});
  @override
  State<DoseTile> createState() => _DoseTileState();
}

class _DoseTileState extends State<DoseTile> {
  bool busy = false;
  bool taken = false;

  int _minutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> take() async {
    if (busy || taken) return;
    setState(() => busy = true);
    try {
      await widget.onStatus('tomada');
      if (!mounted) return;
      setState(() => taken = true);
      snack(context, 'Dose de ${widget.med.name} registrada.');
    } catch (e) {
      if (mounted) snack(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context);
    final c = parseColor(widget.med.color);
    final today = _todayKey();
    final existing = store.logs.where((l) => l.medicationId == widget.med.id && l.time == widget.time && l.date.startsWith(today)).toList();
    final loggedStatus = existing.isEmpty ? null : existing.last.status.toLowerCase();
    final currentMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    final passed = currentMinutes > _minutes(widget.time);
    final isTaken = taken || loggedStatus == 'tomada' || loggedStatus == 'tomado';
    final isSkipped = !isTaken && (loggedStatus == 'pulada' || loggedStatus == 'skipped');
    final isMissed = !isTaken && !isSkipped && (loggedStatus == 'perdida' || loggedStatus == 'missed' || (loggedStatus == null && passed));
    final statusColorValue = isTaken
        ? const Color(0xFF16A34A)
        : isMissed
            ? const Color(0xFFEF4444)
            : isSkipped
                ? const Color(0xFFF59E0B)
                : kBlue;
    final statusText = isTaken ? 'Tomada' : isMissed ? 'Perdida' : isSkipped ? 'Pulada' : 'Pendente';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMissed
            ? const Color(0xFFEF4444).withValues(alpha: .075)
            : isTaken
                ? const Color(0xFF16A34A).withValues(alpha: .055)
                : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .22),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isMissed ? const Color(0xFFEF4444).withValues(alpha: .42) : isTaken ? const Color(0xFF16A34A).withValues(alpha: .20) : Theme.of(context).dividerColor, width: isMissed ? 1.4 : 1),
      ),
      child: LayoutBuilder(builder: (context, box) {
        final compact = box.maxWidth < 570;
        final info = Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: statusColorValue.withValues(alpha: .11), borderRadius: BorderRadius.circular(14)), child: Center(child: Text(widget.med.icon.isEmpty ? '💊' : widget.med.icon, style: const TextStyle(fontSize: 22)))),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(widget.med.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, color: isMissed ? const Color(0xFFB91C1C) : null))), const SizedBox(width: 8), _TimePill(widget.time, missed: isMissed)]),
            const SizedBox(height: 5),
            Text('${widget.med.dosage} ${widget.med.unit} • ${widget.med.frequency}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11.5)),
            if (isMissed) ...[
              const SizedBox(height: 7),
              const Row(children: [Icon(Icons.error_outline_rounded, size: 15, color: Color(0xFFEF4444)), SizedBox(width: 5), Text('Horário perdido', style: TextStyle(color: Color(0xFFDC2626), fontSize: 11.5, fontWeight: FontWeight.w900))]),
            ] else if (isTaken || isSkipped) ...[
              const SizedBox(height: 7),
              Text(statusText, style: TextStyle(color: statusColorValue, fontSize: 11.5, fontWeight: FontWeight.w900)),
            ],
          ])),
        ]);
        final Widget action = busy
            ? const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2.3))
            : isTaken
                ? Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(13)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_rounded, color: Colors.white, size: 17), SizedBox(width: 5), Text('Tomada', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11))]))
                : isMissed
                    ? Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(13), boxShadow: [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: .18), blurRadius: 12, offset: const Offset(0, 5))]), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.close_rounded, color: Colors.white, size: 17), SizedBox(width: 5), Text('Perdida', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11))]))
                    : FilledButton.icon(onPressed: take, icon: const Icon(Icons.check_rounded, size: 17), label: const Text('Tomar'));
        return compact ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 11), Align(alignment: Alignment.centerRight, child: action)]) : Row(children: [Expanded(child: info), const SizedBox(width: 12), action]);
      }),
    );
  }
}

class _TimePill extends StatelessWidget {
  final String time;
  final bool missed;
  const _TimePill(this.time, {this.missed = false});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: missed ? const Color(0xFFEF4444).withValues(alpha: .10) : Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(99), border: Border.all(color: missed ? const Color(0xFFEF4444).withValues(alpha: .38) : Theme.of(context).dividerColor)), child: Text(time, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: missed ? const Color(0xFFDC2626) : null)));
}

class MedicationsPage extends StatelessWidget {
  const MedicationsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final active = s.meds.where((m) => m.active).length;
    final paused = s.meds.length - active;
    final low = s.meds.where((m) => m.stockMax > 0 && m.stock / m.stockMax <= .25).length;
    return PageFrame(
      eyebrow: 'MINHA ROTINA',
      title: 'Medicamentos',
      subtitle: 'Organize tratamentos, horários e estoque com uma leitura simples.',
      action: FilledButton.icon(onPressed: () => showDialog(context: context, builder: (_) => const MedicationForm()), icon: const Icon(Icons.add_rounded), label: const Text('Novo medicamento')),
      child: RefreshIndicator(
        onRefresh: s.refresh,
        child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
          _MedicationSummary(total: s.meds.length, active: active, paused: paused, low: low),
          const SizedBox(height: 18),
          if (s.meds.isEmpty)
            const SizedBox(height: 360, child: EmptyState(icon: Icons.medication_outlined, title: 'Sua lista está vazia', subtitle: 'Cadastre seu primeiro medicamento para começar a montar sua rotina.'))
          else
            LayoutBuilder(builder: (context, box) {
              final columns = box.maxWidth >= 1100 ? 2 : 1;
              if (columns == 1) return Column(children: [for (int i = 0; i < s.meds.length; i++) Padding(padding: EdgeInsets.only(bottom: i == s.meds.length - 1 ? 0 : 14), child: MedicationCard(med: s.meds[i]))]);
              return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: s.meds.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, mainAxisExtent: 294), itemBuilder: (_, i) => MedicationCard(med: s.meds[i]));
            }),
        ]),
      ),
    );
  }
}

class _MedicationSummary extends StatelessWidget {
  final int total, active, paused, low;
  const _MedicationSummary({required this.total, required this.active, required this.paused, required this.low});
  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(label: 'Cadastrados', value: '$total', icon: Icons.medication_rounded, color: kBlue),
      _MetricCard(label: 'Ativos', value: '$active', icon: Icons.check_circle_rounded, color: const Color(0xFF16A34A)),
      _MetricCard(label: 'Pausados', value: '$paused', icon: Icons.pause_circle_outline_rounded, color: const Color(0xFF64748B)),
      _MetricCard(label: 'Estoque em atenção', value: '$low', icon: Icons.inventory_2_outlined, color: low > 0 ? const Color(0xFFF59E0B) : const Color(0xFF16A34A)),
    ];
    return LayoutBuilder(builder: (context, box) {
      final columns = box.maxWidth >= 1050 ? 4 : box.maxWidth >= 650 ? 2 : 1;
      if (columns == 1) return Column(children: [for (int i = 0; i < cards.length; i++) Padding(padding: EdgeInsets.only(bottom: i == cards.length - 1 ? 0 : 10), child: cards[i])]);
      return GridView.count(crossAxisCount: columns, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: columns == 4 ? 1.8 : 2.5, children: cards);
    });
  }
}

class MedicationCard extends StatefulWidget {
  final Medication med;
  const MedicationCard({super.key, required this.med});
  @override
  State<MedicationCard> createState() => _MedicationCardState();
}

class _MedicationCardState extends State<MedicationCard> {
  bool toggling = false;
  bool removing = false;
  Future<void> toggle() async {
    if (toggling) return;
    setState(() => toggling = true);
    try {
      await AppScope.of(context).toggleMedication(widget.med.id);
      if (mounted) snack(context, widget.med.active ? 'Medicamento pausado.' : 'Medicamento ativado.');
    } catch (e) {
      if (mounted) snack(context, e.toString());
    } finally {
      if (mounted) setState(() => toggling = false);
    }
  }
  Future<void> remove() async {
    if (removing) return;
    final name = widget.med.name;
    if (!await confirmDelete(context, name) || !mounted) return;
    setState(() => removing = true);
    try {
      await AppScope.of(context).deleteMedication(widget.med.id);
      if (mounted) snack(context, 'Medicamento excluído.');
    } catch (e) {
      if (mounted) snack(context, e.toString());
    } finally {
      if (mounted) setState(() => removing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.med;
    final c = parseColor(m.color);
    final ratio = m.stockMax <= 0 ? 0.0 : (m.stock / m.stockMax).clamp(0, 1).toDouble();
    final low = ratio <= .25;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 54, height: 54, decoration: BoxDecoration(color: c.withValues(alpha: .10), borderRadius: BorderRadius.circular(17)), child: Center(child: Text(m.icon.isEmpty ? '💊' : m.icon, style: const TextStyle(fontSize: 26)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(m.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))), const SizedBox(width: 8), StatusBadge(active: m.active)]),
              const SizedBox(height: 5),
              Text('${m.dosage} ${m.unit} • ${m.frequency}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ])),
            PopupMenuButton<String>(tooltip: 'Ações', onSelected: (value) { if (value == 'edit') showDialog(context: context, builder: (_) => MedicationForm(med: m)); if (value == 'delete') remove(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.edit_outlined), title: Text('Editar'))), PopupMenuItem(value: 'delete', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.delete_outline_rounded), title: Text('Excluir')))]),
          ]),
          const SizedBox(height: 15),
          Wrap(spacing: 7, runSpacing: 7, children: [for (final t in m.times) Chip(avatar: const Icon(Icons.schedule_rounded, size: 15), label: Text(t)), if (m.category.isNotEmpty) Chip(label: Text(m.category))]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text('Estoque', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w800)), const Spacer(), Text('${m.stock}/${m.stockMax}', style: TextStyle(color: low ? const Color(0xFFF59E0B) : Theme.of(context).colorScheme.onSurface, fontSize: 11, fontWeight: FontWeight.w900))]),
              const SizedBox(height: 7),
              ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: ratio, minHeight: 7, color: low ? const Color(0xFFF59E0B) : c, backgroundColor: Theme.of(context).dividerColor)),
            ])),
            const SizedBox(width: 14),
            toggling ? const SizedBox(width: 34, height: 34, child: CircularProgressIndicator(strokeWidth: 2.3)) : Switch(value: m.active, onChanged: (_) => toggle()),
          ]),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .25), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(m.reminder ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, size: 17, color: m.reminder ? kBlue : Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(m.reminder ? 'Lembrete ativo para esta rotina.' : 'Lembrete desativado.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant))),
              if (removing) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final bool active;
  const StatusBadge({super.key, required this.active});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5), decoration: BoxDecoration(color: (active ? const Color(0xFF16A34A) : const Color(0xFF64748B)).withValues(alpha: .10), borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: active ? const Color(0xFF16A34A) : const Color(0xFF64748B), shape: BoxShape.circle)), const SizedBox(width: 5), Text(active ? 'ATIVO' : 'PAUSADO', style: TextStyle(color: active ? const Color(0xFF16A34A) : const Color(0xFF64748B), fontSize: 8.5, fontWeight: FontWeight.w900))]));
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final logs = [...s.logs]..sort((a, b) => b.date.compareTo(a.date));
    final taken = s.logs.where((l) => l.status.toLowerCase() == 'tomada').length;
    final missed = s.logs.where((l) => l.status.toLowerCase() == 'perdida').length;
    final skipped = s.logs.where((l) => l.status.toLowerCase() == 'pulada').length;
    final total = s.logs.length;
    return PageFrame(
      eyebrow: 'ACOMPANHAMENTO',
      title: 'Histórico',
      subtitle: 'Entenda sua consistência e acompanhe os registros da sua rotina.',
      action: IconButton(tooltip: 'Atualizar histórico', onPressed: s.loading ? null : () => s.refresh(), icon: const Icon(Icons.refresh_rounded)),
      child: RefreshIndicator(
        onRefresh: s.refresh,
        child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
          _HistorySummary(taken: taken, skipped: skipped, missed: missed),
          const SizedBox(height: 16),
          SectionCard(title: 'Adesão da rotina', subtitle: 'Percentual calculado a partir dos registros disponíveis.', icon: Icons.insights_rounded, child: Column(children: [
            _HistoryBar(label: 'Últimos 7 dias', value: s.adherence7, total: 100, color: const Color(0xFF16A34A), suffix: '%'),
            const SizedBox(height: 18),
            _HistoryBar(label: 'Últimos 30 dias', value: s.adherence30, total: 100, color: kBlue, suffix: '%'),
          ])),
          const SizedBox(height: 16),
          SectionCard(
            title: 'Atividade recente',
            subtitle: total == 0 ? 'Ainda não existem registros.' : 'Os registros mais recentes aparecem primeiro.',
            icon: Icons.history_rounded,
            action: total > 0 ? _SmallCount('$total ${total == 1 ? 'registro' : 'registros'}') : null,
            child: logs.isEmpty ? const EmptyState(icon: Icons.history_toggle_off_rounded, title: 'Sem histórico ainda', subtitle: 'Quando você registrar uma dose, ela aparecerá aqui.') : Column(children: [for (int i = 0; i < logs.take(30).length; i++) Padding(padding: EdgeInsets.only(bottom: i == logs.take(30).length - 1 ? 0 : 9), child: _HistoryRow(log: logs[i], medName: medicationName(s.meds, logs[i].medicationId)))]),
          ),
        ]),
      ),
    );
  }
}

class _HistorySummary extends StatelessWidget {
  final int taken, skipped, missed;
  const _HistorySummary({required this.taken, required this.skipped, required this.missed});
  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(label: 'Tomadas', value: '$taken', icon: Icons.check_circle_rounded, color: const Color(0xFF16A34A)),
      _MetricCard(label: 'Puladas', value: '$skipped', icon: Icons.skip_next_rounded, color: const Color(0xFFF59E0B)),
      _MetricCard(label: 'Perdidas', value: '$missed', icon: Icons.cancel_rounded, color: const Color(0xFFEF4444)),
    ];
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 620) return Column(children: [for (int i = 0; i < cards.length; i++) Padding(padding: EdgeInsets.only(bottom: i == cards.length - 1 ? 0 : 10), child: cards[i])]);
      return Row(children: [for (int i = 0; i < cards.length; i++) Expanded(child: Padding(padding: EdgeInsets.only(right: i == cards.length - 1 ? 0 : 12), child: cards[i]))]);
    });
  }
}

class _HistoryBar extends StatelessWidget {
  final String label, suffix;
  final int value, total;
  final Color color;
  const _HistoryBar({required this.label, required this.value, required this.total, required this.color, required this.suffix});
  @override
  Widget build(BuildContext context) {
    final p = total == 0 ? 0.0 : (value / total).clamp(0, 1).toDouble();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), const Spacer(), Text('$value$suffix', style: TextStyle(color: color, fontWeight: FontWeight.w900))]), const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: p, minHeight: 8, color: color, backgroundColor: color.withValues(alpha: .08))) ]);
  }
}

class _HistoryRow extends StatelessWidget {
  final DoseLog log;
  final String medName;
  const _HistoryRow({required this.log, required this.medName});
  @override
  Widget build(BuildContext context) {
    final c = statusColor(log.status);
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .20), borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).dividerColor)),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: c.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(statusIcon(log.status), color: c, size: 20)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(medName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text('${formatDate(log.date)} • ${log.time}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11))])),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: c.withValues(alpha: .10), borderRadius: BorderRadius.circular(99)), child: Text(statusLabel(log.status), style: TextStyle(color: c, fontSize: 9.5, fontWeight: FontWeight.w900))),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const EmptyState({super.key, required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 78, height: 78, decoration: BoxDecoration(gradient: LinearGradient(colors: [kBlue.withValues(alpha: .13), kBlue.withValues(alpha: .04)]), shape: BoxShape.circle), child: Icon(icon, color: kBlue, size: 34)), const SizedBox(height: 16), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 7), Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5))])));
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController name;
  bool editing = false;
  bool busy = false;
  @override
  void initState() { super.initState(); name = TextEditingController(); }
  @override
  void didChangeDependencies() { super.didChangeDependencies(); if (!editing) name.text = AppScope.of(context).user?.name ?? ''; }
  @override
  void dispose() { name.dispose(); super.dispose(); }
  Future<void> save() async {
    if (name.text.trim().length < 2) { snack(context, 'Informe um nome válido.'); return; }
    setState(() => busy = true);
    try {
      await AppScope.of(context).updateProfile(name.text);
      if (mounted) { setState(() => editing = false); snack(context, 'Perfil atualizado.'); }
    } catch (e) {
      if (mounted) snack(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }
  Future<void> exportData(User u, MedStore s) async {
    final data = jsonEncode({'usuario': {'id': u.id, 'nome': u.name, 'email': u.email}, 'medicamentos': s.meds.map((m) => m.toApi()).toList(), 'registros': s.logs.map((l) => {'id': l.id, 'medicamentoId': l.medicationId, 'horarioAgendado': l.time, 'situacao': l.status, 'data': l.date, 'observacao': l.note}).toList(), 'exportadoEm': DateTime.now().toIso8601String()});
    await SharePlus.instance.share(ShareParams(text: data, subject: 'MedSync - meus dados'));
  }
  Future<void> logout() async {
    await AppScope.of(context).logout();
    if (mounted) Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LandingPage()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final u = s.user;
    if (u == null) return const EmptyState(icon: Icons.person_outline, title: 'Sessão encerrada', subtitle: 'Faça login novamente.');
    final initial = u.name.trim().isEmpty ? '?' : u.name.trim()[0].toUpperCase();
    return PageFrame(
      eyebrow: 'MINHA CONTA',
      title: 'Perfil',
      subtitle: 'Personalize o MedSync e mantenha seus dados sob controle.',
      child: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [kBlue.withValues(alpha: .10), Theme.of(context).colorScheme.surface], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), border: Border.all(color: kBlue.withValues(alpha: .10))),
          child: LayoutBuilder(builder: (context, box) {
            final compact = box.maxWidth < 540;
            final identity = Row(children: [CircleAvatar(radius: 31, backgroundColor: kBlue, child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900))), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5))]))]);
            final button = OutlinedButton.icon(onPressed: () => setState(() { editing = !editing; if (editing) name.text = u.name; }), icon: Icon(editing ? Icons.close_rounded : Icons.edit_rounded), label: Text(editing ? 'Cancelar' : 'Editar'));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                compact
                    ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [identity, const SizedBox(height: 14), button])
                    : Row(children: [Expanded(child: identity), const SizedBox(width: 14), button]),
                if (editing) ...[
                  const SizedBox(height: 15),
                  TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Nome completo', prefixIcon: Icon(Icons.person_outline_rounded))),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: busy ? null : save,
                      icon: busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded),
                      label: Text(busy ? 'Salvando...' : 'Salvar alterações'),
                    ),
                  ),
                ],
              ],
            );
          }),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) {
          final cards = [
            _MetricCard(label: 'Medicamentos ativos', value: '${s.meds.where((m) => m.active).length}', icon: Icons.medication_rounded, color: kBlue),
            _MetricCard(label: 'Adesão 7 dias', value: '${s.adherence7}%', icon: Icons.insights_rounded, color: const Color(0xFF16A34A)),
            _MetricCard(label: 'Adesão 30 dias', value: '${s.adherence30}%', icon: Icons.calendar_month_rounded, color: const Color(0xFF7C3AED)),
          ];
          if (box.maxWidth < 620) return Column(children: [for (int i = 0; i < cards.length; i++) Padding(padding: EdgeInsets.only(bottom: i == cards.length - 1 ? 0 : 10), child: cards[i])]);
          return Row(children: [for (int i = 0; i < cards.length; i++) Expanded(child: Padding(padding: EdgeInsets.only(right: i == cards.length - 1 ? 0 : 12), child: cards[i]))]);
        }),
        const SizedBox(height: 16),
        SectionCard(title: 'Preferências', subtitle: 'Controle a aparência e a acessibilidade.', icon: Icons.tune_rounded, child: Column(children: [
          _PreferenceTile(icon: Icons.dark_mode_outlined, title: 'Tema escuro', subtitle: 'Reduz o brilho em ambientes com pouca luz.', trailing: Switch(value: s.dark, onChanged: s.setDark)),
          const SizedBox(height: 10),
          _PreferenceTile(icon: Icons.accessibility_new_rounded, title: 'Acessibilidade', subtitle: 'Aumenta a escala dos textos para facilitar a leitura.', trailing: Switch(value: s.accessible, onChanged: s.setAccessible)),
        ])),
        const SizedBox(height: 16),
        SectionCard(title: 'Conta e dados', subtitle: 'Ferramentas para manter suas informações sob controle.', icon: Icons.shield_outlined, child: Column(children: [
          _ActionTile(icon: Icons.ios_share_rounded, title: 'Exportar meus dados', subtitle: 'Compartilhe medicamentos e registros em formato estruturado.', onTap: () => exportData(u, s)),
          const SizedBox(height: 10),
          _ActionTile(icon: Icons.logout_rounded, title: 'Sair da conta', subtitle: 'Encerrar a sessão neste dispositivo.', danger: true, onTap: logout),
        ])),
      ]),
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget trailing;
  const _PreferenceTile({required this.icon, required this.title, required this.subtitle, required this.trailing});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .30), borderRadius: BorderRadius.circular(17), border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .65))),
    child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: kBlue.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: kBlue, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11.5, height: 1.35))])),
      const SizedBox(width: 10), trailing,
    ]),
  );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool danger;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, this.danger = false, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final accent = danger ? const Color(0xFFEF4444) : kBlue;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(17), onTap: onTap, child: Ink(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: danger ? .20 : .30), borderRadius: BorderRadius.circular(17), border: Border.all(color: danger ? accent.withValues(alpha: .16) : Theme.of(context).dividerColor.withValues(alpha: .65))), child: Row(children: [
      Container(width: 42, height: 42, decoration: BoxDecoration(color: accent.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: accent, size: 20)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: danger ? accent : null)), const SizedBox(height: 3), Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11.5, height: 1.35))])),
      const SizedBox(width: 8), Icon(Icons.chevron_right_rounded, color: danger ? accent : Theme.of(context).colorScheme.onSurfaceVariant),
    ]))));
  }
}

class MedicationForm extends StatefulWidget { final Medication? med; const MedicationForm({super.key,this.med}); @override State<MedicationForm> createState()=>_MedicationFormState(); }
class _MedicationFormState extends State<MedicationForm>{final name=TextEditingController(),dose=TextEditingController(),stock=TextEditingController(),maxStock=TextEditingController(),instructions=TextEditingController(),doctor=TextEditingController(),side=TextEditingController(),image=TextEditingController();String unit='mg',frequency='Diário',category='Outros',icon='💊',color='#2563EB',start='';bool reminder=true,busy=false,active=true;final List<String>times=['08:00'];@override void initState(){super.initState();final m=widget.med;name.text=m?.name??'';dose.text=m?.dosage??'';stock.text='${m?.stock??30}';maxStock.text='${m?.stockMax??30}';instructions.text=m?.instructions??'';doctor.text=m?.prescribedBy??'';side.text=m?.sideEffects??'';image.text=m?.imageUrl??'';unit=m?.unit??'mg';frequency=m?.frequency??'Diário';category=m?.category??'Outros';icon=m?.icon??'💊';color=m?.color??'#2563EB';start=m?.startDate??DateFormat('yyyy-MM-dd').format(DateTime.now());reminder=m?.reminder??true;active=m?.active??true;times..clear()..addAll(m?.times??const ['08:00']);}@override void dispose(){for(final c in[name,dose,stock,maxStock,instructions,doctor,side,image])c.dispose();super.dispose();}Future<void>addTime()async{final p=await showTimePicker(context:context,initialTime:const TimeOfDay(hour:12,minute:0));if(p==null){return;}final v='${p.hour.toString().padLeft(2,'0')}:${p.minute.toString().padLeft(2,'0')}';if(!times.contains(v))setState(()=>times.add(v));}Future<void>save()async{if(name.text.trim().isEmpty||dose.text.trim().isEmpty||times.isEmpty||times.any((x)=>!RegExp(r'^\d{2}:\d{2}$').hasMatch(x))){snack(context,'Preencha nome, dosagem e pelo menos um horário válido.');return;}final sv=int.tryParse(stock.text)??0,mv=int.tryParse(maxStock.text)??30;if(sv<0||mv<1||sv>mv){snack(context,'O estoque atual deve ser entre 0 e o estoque máximo.');return;}setState(()=>busy=true);final med=Medication(id:widget.med?.id??'',name:name.text.trim(),dosage:dose.text.trim(),unit:unit,frequency:frequency,times:[...times]..sort(),stock:sv,stockMax:mv,active:active,reminder:reminder,color:color,category:category,icon:icon,startDate:start,endDate:widget.med?.endDate,instructions:instructions.text.trim().isEmpty?null:instructions.text.trim(),imageUrl:image.text.trim().isEmpty?null:image.text.trim(),prescribedBy:doctor.text.trim().isEmpty?null:doctor.text.trim(),sideEffects:side.text.trim().isEmpty?null:side.text.trim());try{final s=AppScope.of(context);if(widget.med==null){await s.addMedication(med.toApi());}else{await s.editMedication(med.id,med.toApi());}if(mounted)Navigator.pop(context);}catch(e){if(mounted)snack(context,e.toString());}finally{if(mounted)setState(()=>busy=false);}}@override Widget build(BuildContext context)=>AlertDialog(title:Row(children:[const LogoMark(size:36),const SizedBox(width:10),Expanded(child:Text(widget.med==null?'Novo medicamento':'Editar medicamento',style:const TextStyle(fontWeight:FontWeight.w900)))]),content:SizedBox(width:680,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[TextField(controller:name,autofocus:widget.med==null,decoration:const InputDecoration(labelText:'Nome do medicamento *',prefixIcon:Icon(Icons.medication_outlined))),const SizedBox(height:12),Row(children:[Expanded(child:TextField(controller:dose,decoration:const InputDecoration(labelText:'Dosagem *'))),const SizedBox(width:10),Expanded(child:DropdownButtonFormField<String>(initialValue:unit,items:['mg','g','mL','mcg','UI','comprimido'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>unit=v??unit),decoration:const InputDecoration(labelText:'Unidade')))]),const SizedBox(height:12),Row(children:[Expanded(child:DropdownButtonFormField<String>(initialValue:frequency,items:['Diário','2x ao dia','3x ao dia','Semanal','Conforme necessidade'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>frequency=v??frequency),decoration:const InputDecoration(labelText:'Frequência'))),const SizedBox(width:10),Expanded(child:DropdownButtonFormField<String>(initialValue:category,items:['Outros','Pressão','Diabetes','Dor','Vitaminas','Antibiótico'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>category=v??category),decoration:const InputDecoration(labelText:'Categoria')))]),const SizedBox(height:18),Row(children:[const Icon(Icons.schedule_rounded,color:kBlue,size:20),const SizedBox(width:8),const Text('Horários',style:TextStyle(fontWeight:FontWeight.w900)),const Spacer(),Text('${times.length} horário(s)',style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant,fontSize:12))]),const SizedBox(height:9),Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha:.32),borderRadius:BorderRadius.circular(16)),child:Wrap(spacing:8,runSpacing:8,children:[for(int i=0;i<times.length;i++)InputChip(label:Text(times[i]),onDeleted:times.length>1?()=>setState(()=>times.removeAt(i)):null),ActionChip(avatar:const Icon(Icons.add_rounded,size:18),label:const Text('Adicionar horário'),onPressed:addTime)])),const SizedBox(height:16),Row(children:[Expanded(child:TextField(controller:stock,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Estoque atual'))),const SizedBox(width:10),Expanded(child:TextField(controller:maxStock,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Estoque máximo')))]),const SizedBox(height:8),SwitchListTile(contentPadding:EdgeInsets.zero,value:reminder,onChanged:(v)=>setState(()=>reminder=v),title:const Text('Lembrete ativo',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('Mantenha os avisos da rotina ligados.')),SwitchListTile(contentPadding:EdgeInsets.zero,value:active,onChanged:(v)=>setState(()=>active=v),title:const Text('Medicamento ativo',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:const Text('Medicamentos pausados deixam de aparecer na rotina.')),ExpansionTile(tilePadding:EdgeInsets.zero,title:const Text('Mais detalhes',style:TextStyle(fontWeight:FontWeight.w800)),children:[TextField(controller:doctor,decoration:const InputDecoration(labelText:'Médico prescritor',prefixIcon:Icon(Icons.medical_services_outlined))),const SizedBox(height:10),TextField(controller:instructions,maxLines:2,decoration:const InputDecoration(labelText:'Instruções',prefixIcon:Icon(Icons.notes_rounded))),const SizedBox(height:10),TextField(controller:side,maxLines:2,decoration:const InputDecoration(labelText:'Efeitos colaterais',prefixIcon:Icon(Icons.warning_amber_rounded))),const SizedBox(height:10),TextField(controller:image,decoration:const InputDecoration(labelText:'URL da imagem (opcional)',prefixIcon:Icon(Icons.image_outlined))),const SizedBox(height:10)]),const SizedBox(height:18),FilledButton.icon(onPressed:busy?null:save,icon:busy?const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white)):const Icon(Icons.save_rounded),label:Text(busy?'Salvando...':'Salvar medicamento'))]))));}

String medicationName(List<Medication> meds,String id){for(final m in meds){if(m.id==id)return m.name;}return 'Medicamento';}

Color parseColor(String hex){final value=hex.replaceFirst('#','');if(value.length!=6)return kBlue;return Color(int.parse('FF$value',radix:16));}
Color statusColor(String status){switch(status.toLowerCase()){case 'tomada':case 'tomado':return const Color(0xFF16A34A);case 'perdida':case 'missed':return const Color(0xFFEF4444);case 'pulada':case 'skipped':return const Color(0xFFF59E0B);default:return const Color(0xFF64748B);}}
IconData statusIcon(String status){switch(status.toLowerCase()){case 'tomada':case 'tomado':return Icons.check_circle_rounded;case 'perdida':case 'missed':return Icons.cancel_rounded;case 'pulada':case 'skipped':return Icons.skip_next_rounded;default:return Icons.schedule_rounded;}}
String statusLabel(String status){switch(status.toLowerCase()){case 'tomada':case 'tomado':return 'Tomada';case 'perdida':case 'missed':return 'Perdida';case 'pulada':case 'skipped':return 'Pulada';default:return 'Pendente';}}
String formatDate(String date){try{return DateFormat('dd/MM/yyyy').format(DateTime.parse(date));}catch(_){return date;}}
Future<bool> confirmDelete(BuildContext context,String name)async{final result=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('Excluir medicamento?'),content:Text('Você deseja excluir "$name"? Essa ação não pode ser desfeita.'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Excluir'))]));return result??false;}
void snack(BuildContext context,String message){ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(behavior:SnackBarBehavior.floating,margin:const EdgeInsets.all(16),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14)),content:Text(message)));}
