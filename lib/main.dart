import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/momo_provider.dart';
import 'screens/transact_screen.dart';
import 'screens/commissions_screen.dart';
import 'screens/reconciliation_screen.dart';
import 'screens/tills_screen.dart';
import 'screens/ledger_screen.dart';
import 'screens/customer_test_screen.dart';
import 'screens/settings_screen.dart';
import 'services/security_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MoMoProvider()..init()),
      ],
      child: const MoMoApp(),
    ),
  );
}

class MoMoApp extends StatelessWidget {
  const MoMoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MomoBoss',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A73E8),
          brightness: Brightness.light,
          primary: const Color(0xFF1A73E8),
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          Theme.of(context).textTheme,
        ),
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
      ),
      home: const MainNavigationShell(),
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

  final List<Widget> _screens = const [
    TransactScreen(),
    ReconciliationScreen(),
    CommissionsScreen(),
    TillsAndLedgerScreen(),
  ];

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
      final pass = await SecurityService.authenticate(reason: 'Unlock MoMo Boss POS');
      setState(() => _isAuthenticated = pass);
    } else {
      setState(() => _isAuthenticated = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MoMoProvider>();

    if (provider.isAppLockEnabled && !_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 64, color: Color(0xFF1A73E8)),
              const SizedBox(height: 16),
              const Text('MoMo Boss is Locked', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.flash_on_rounded, color: Color(0xFF1A73E8), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MoMo Boss',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Drawer: ${provider.formatAmount(provider.currentCashInDrawer)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
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
      body: _screens[_currentIndex],
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
            color: Colors.white,
            child: const TabBar(
              labelColor: Color(0xFF1A73E8),
              unselectedLabelColor: Color(0xFF5F6368),
              indicatorColor: Color(0xFF1A73E8),
              tabs: [
                Tab(icon: Icon(Icons.sim_card_rounded, size: 18), text: 'SIM Till Floats'),
                Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Transaction Ledger'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                TillsScreen(),
                LedgerScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
