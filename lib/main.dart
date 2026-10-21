import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/mobiboss_provider.dart';
import 'screens/transact_screen.dart';
import 'screens/commissions_screen.dart';
import 'screens/reconciliation_screen.dart';
import 'screens/paywall_screen.dart';
import 'screens/tills_screen.dart';
import 'screens/ledger_screen.dart';
import 'screens/customer_test_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/security_service.dart';
import 'widgets/top_toast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Replace with your Supabase project credentials
  await Supabase.initialize(
    url: 'https://pyomprjluyjkwnllpprn.supabase.co',
    // ignore: deprecated_member_use
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB5b21wcmpsdXlqa3dubGxwcHJuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIzOTc2MDgsImV4cCI6MjEwNzk3MzYwOH0._5SW2DaGWqMDUzNDyU7GdsNMgflgAsxaWeJe_kmLA48',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MobiBossProvider()..init()),
      ],
      child: const MobiBossApp(),
    ),
  );
}

class MobiBossApp extends StatelessWidget {
  const MobiBossApp({super.key});

  static final _lightTextTheme = GoogleFonts.plusJakartaSansTextTheme(
    ThemeData.light().textTheme,
  );
  static final _darkTextTheme = GoogleFonts.plusJakartaSansTextTheme(
    ThemeData.dark().textTheme,
  );

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<MoMoProvider, ThemeMode>((p) => p.themeMode);
    final hasCompletedOnboarding = context.select<MoMoProvider, bool>((p) => p.hasCompletedOnboarding);

    return MaterialApp(
      title: 'MobiBoss',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.light,
          primary: const Color(0xFF1A73E8),
          surface: Colors.white,
        ),
        textTheme: _lightTextTheme,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF202124),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE8EAED), width: 1),
          ),
          color: Colors.white,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFD2E3FC),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? const Color(0xFF1A73E8) : const Color(0xFF5F6368),
            ),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.dark,
          primary: const Color(0xFF8AB4F8),
          surface: const Color(0xFF1E1E1E),
        ),
        textTheme: _darkTextTheme,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Color(0xFFE8EAED),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2D2F31), width: 1),
          ),
          color: const Color(0xFF1E1E1E),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1E1E1E),
          indicatorColor: const Color(0xFF0D47A1),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected) ? FontWeight.bold : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? const Color(0xFF8AB4F8) : const Color(0xFF9AA0A6),
            ),
          ),
        ),
      ),
      home: hasCompletedOnboarding
          ? const MainNavigationShell()
          : const OnboardingScreen(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isAuthenticated = false;

  /// Reconciliation tab (index 1) shows PaywallScreen when subscription is
  /// expired — all other tabs are always accessible.
  List<Widget> _buildScreens(bool hasReconciliationAccess) {
    return [
      const TransactScreen(),
      hasReconciliationAccess ? const ReconciliationScreen() : const PaywallScreen(),
      const CommissionsScreen(),
      const TillsAndLedgerScreen(),
    ];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAppLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      final provider = context.read<MoMoProvider>();
      if (provider.isAppLockEnabled) {
        setState(() => _isAuthenticated = false);
      }
    } else if (state == AppLifecycleState.resumed) {
      final provider = context.read<MoMoProvider>();
      if (provider.isAppLockEnabled && !_isAuthenticated) {
        _checkAppLock();
      }
    }
  }

  Future<void> _checkAppLock() async {
    final provider = context.read<MoMoProvider>();
    if (provider.isAppLockEnabled) {
      final pass = await SecurityService.authenticate(reason: 'Unlock MobiBoss POS');
      setState(() => _isAuthenticated = pass);
    } else {
      setState(() => _isAuthenticated = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MoMoProvider>();
    final auth = context.watch<AuthProvider>();
    final screens = _buildScreens(auth.hasReconciliationAccess);

    if (provider.isAppLockEnabled && !_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 64, color: Color(0xFF1A73E8)),
              const SizedBox(height: 16),
              const Text('MobiBoss is Locked', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              const Text('Authenticate with fingerprint or PIN to continue.', style: TextStyle(color: Color(0xFF5F6368))),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Unlock with Biometrics'),
                onPressed: _checkAppLock,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/app_logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => _showAdjustDrawerModal(context, provider),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MobiBoss',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Drawer: ${provider.formatAmount(provider.currentCashInDrawer)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? const Color(0xFF81C995)
                                  : const Color(0xFF1E8E3E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.edit_outlined, size: 12, color: Color(0xFF1E8E3E)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded, size: 20),
            tooltip: 'Sync Telco SMS',
            onPressed: () async {
              final count = await provider.syncRecentSms();
              if (context.mounted) {
                TopToast.show(
                  context,
                  title: count > 0 ? 'SMS Sync Complete' : 'Up to Date',
                  message: count > 0
                      ? 'Reconciled $count incoming telecom messages.'
                      : 'No new MoMo confirmation SMS found.',
                  icon: count > 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                  backgroundColor: count > 0 ? const Color(0xFF1E8E3E) : const Color(0xFF5F6368),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(
              provider.isBalancePrivacyEnabled ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 20,
              color: provider.isBalancePrivacyEnabled ? const Color(0xFF1A73E8) : const Color(0xFF5F6368),
            ),
            tooltip: 'Toggle Balance Privacy',
            onPressed: () => provider.toggleBalancePrivacy(),
          ),
          IconButton(
            icon: const Icon(Icons.science_outlined, size: 20),
            tooltip: 'Customer Test Lab (*170#)',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomerTestScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: 'Settings & Tills',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        indicatorColor: const Color(0xFFD2E3FC),
        height: 68,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.send_outlined),
            selectedIcon: Icon(Icons.send_rounded, color: Color(0xFF1A73E8)),
            label: 'Transact',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check_rounded, color: Color(0xFF1A73E8)),
            label: 'Reconcile',
          ),
          NavigationDestination(
            icon: Icon(Icons.monetization_on_outlined),
            selectedIcon: Icon(Icons.monetization_on_rounded, color: Color(0xFF1A73E8)),
            label: 'Earnings',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: Color(0xFF1A73E8)),
            label: 'Ledger',
          ),
        ],
      ),
    );
  }

  void _showAdjustDrawerModal(BuildContext context, MoMoProvider provider) {
    final cashCtrl = TextEditingController(text: provider.currentCashInDrawer.toStringAsFixed(2));
    final noteCtrl = TextEditingController(text: 'Shift Opening Cash Float');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.point_of_sale_rounded, color: Color(0xFF1E8E3E), size: 22),
            SizedBox(width: 8),
            Text('Adjust Cash in Drawer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set your opening physical cash in the drawer or update following a physical cash count.',
              style: TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: cashCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cash in Drawer (GHS)',
                prefixText: 'GHS ',
                prefixIcon: Icon(Icons.payments_rounded, size: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason / Note',
                hintText: 'e.g. Opening Float, Cash Drop',
                prefixIcon: Icon(Icons.notes_rounded, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final val = double.tryParse(cashCtrl.text) ?? provider.currentCashInDrawer;
              await provider.adjustDrawerCash(newAmount: val, reason: noteCtrl.text.trim());
              if (context.mounted) {
                Navigator.pop(ctx);
                TopToast.show(
                  context,
                  title: 'Drawer Cash Updated',
                  message: 'Physical drawer balance set to GHS ${provider.formatAmount(val)}',
                  icon: Icons.check_circle_rounded,
                  backgroundColor: const Color(0xFF1E8E3E),
                );
              }
            },
            child: const Text('Update Balance'),
          ),
        ],
      ),
    );
  }
}

class TillsAndLedgerScreen extends StatelessWidget {
  const TillsAndLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).cardColor,
            child: TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF9AA0A6)
                  : const Color(0xFF5F6368),
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Transaction Ledger'),
                Tab(icon: Icon(Icons.sim_card_rounded, size: 18), text: 'SIM Till Floats'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                LedgerScreen(),
                TillsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
