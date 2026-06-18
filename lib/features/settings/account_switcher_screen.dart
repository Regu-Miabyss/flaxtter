import 'package:flutter/material.dart';
import 'package:flaxtter/client/accounts.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/database/entities.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:provider/provider.dart';

class AccountSwitcherScreen extends StatefulWidget {
  const AccountSwitcherScreen({super.key});

  @override
  State<AccountSwitcherScreen> createState() => _AccountSwitcherScreenState();
}

class _AccountSwitcherScreenState extends State<AccountSwitcherScreen> {
  List<Account> _accounts = const [];
  String? _activeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final accounts = await getAccounts();
    final active = await getActiveAccount();
    if (!mounted) {
      return;
    }
    setState(() {
      _accounts = accounts;
      _activeId = active?.id;
      _loading = false;
    });
  }

  Future<void> _select(Account account) async {
    if (account.id == _activeId) {
      return;
    }
    await setActiveAccount(account.id);
    if (!mounted) {
      return;
    }
    setState(() => _activeId = account.id);
    context.read<AccountAddedNotifier>().publish();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      primary: false,
      appBar: AppBar(title: Text(l10n.switchAccount)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
              ? Center(child: Text(l10n.loginRequired))
              : ListView.builder(
                  itemCount: _accounts.length,
                  itemBuilder: (context, index) {
                    final account = _accounts[index];
                    final selected = account.id == _activeId;
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          account.screenName.isNotEmpty ? account.screenName[0].toUpperCase() : '?',
                        ),
                      ),
                      title: Text('@${account.screenName}'),
                      trailing: selected ? const Icon(Icons.check_circle) : null,
                      onTap: () => _select(account),
                    );
                  },
                ),
    );
  }
}
