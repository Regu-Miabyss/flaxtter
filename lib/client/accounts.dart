import 'package:flaxtter/database/repository.dart';
import 'package:flaxtter/database/entities.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _keyActiveAccountId = 'active_account_id';

Future<List<Account>> getAccounts() async {
  var database = await Repository.readOnly();
  List<Map<String, Object?>> lst = await database.query(tableAccounts);
  return lst.map((map) => Account.fromMap(map)).toList();
}

/// Returns the user-selected account, or the first stored account.
Future<Account?> getActiveAccount() async {
  final accounts = await getAccounts();
  if (accounts.isEmpty) {
    return null;
  }
  final prefs = await SharedPreferences.getInstance();
  final activeId = prefs.getString(_keyActiveAccountId);
  if (activeId != null) {
    for (final account in accounts) {
      if (account.id == activeId) {
        return account;
      }
    }
  }
  return accounts.first;
}

Future<void> setActiveAccount(String accountId) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_keyActiveAccountId, accountId);
}
