import 'package:flutter/material.dart';
import 'package:flaxtter/client/client_account.dart';
import 'package:flaxtter/client/accounts.dart';
import 'package:flaxtter/client/login/login_screen.dart';
import 'package:flaxtter/features/profile/profile_screen.dart';
import 'package:flaxtter/features/search/search_screen.dart';
import 'package:flaxtter/features/timeline/timeline_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  String? _screenName;

  @override
  void initState() {
    super.initState();
    _loadScreenName();
  }

  Future<void> _loadScreenName() async {
    final accounts = await getAccounts();
    if (mounted && accounts.isNotEmpty) {
      setState(() => _screenName = accounts.first.screenName);
    }
  }

  Future<void> _logout() async {
    await TwitterAccount.logoutAll();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/gate');
    }
  }

  void _openProfile(String screenName) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(screenName: screenName)),
    );
  }

  void _searchHashtag(String hashtag) {
    context.read<SearchRequestNotifier>().requestSearch('#$hashtag');
    setState(() => _index = 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      primary: false,
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          if (_screenName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Text('@$_screenName')),
            ),
          IconButton(
            tooltip: l10n.logout,
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        sizing: StackFit.expand,
        index: _index,
        children: [
          TimelineScreen(
            onMentionTap: _openProfile,
            onHashtagTap: _searchHashtag,
          ),
          const SearchScreen(),
          if (_screenName != null)
            ProfileBody(
              key: ValueKey(_screenName),
              screenName: _screenName!,
              onMentionTap: _openProfile,
              onHashtagTap: _searchHashtag,
            )
          else
            const Center(child: CircularProgressIndicator()),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home), label: l10n.home),
          NavigationDestination(icon: const Icon(Icons.search), label: l10n.search),
          NavigationDestination(icon: const Icon(Icons.person), label: l10n.me),
        ],
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _loggedIn = false;
  bool _loggingIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    context.read<AccountAddedNotifier>().addListener(_checkAuth);
  }

  @override
  void dispose() {
    context.read<AccountAddedNotifier>().removeListener(_checkAuth);
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final accounts = await TwitterAccount.initCheckXAccounts(forceInit: true);
    if (mounted) {
      setState(() {
        _checking = false;
        _loggedIn = accounts.isNotEmpty;
        if (_loggedIn) {
          _loggingIn = false;
        }
      });
    }
  }

  Future<void> _login() async {
    setState(() => _loggingIn = true);
    final success = await openLoginScreen(context);
    if (mounted) {
      setState(() => _loggingIn = false);
      if (success == true) {
        await _checkAuth();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loggedIn) {
      return const HomeScreen();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flutter_dash, size: 72),
              const SizedBox(height: 16),
              Text(
                l10n.loginPrompt,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loggingIn ? null : _login,
                icon: _loggingIn
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(l10n.login),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
