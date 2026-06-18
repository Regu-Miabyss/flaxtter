import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flaxtter/client/client_account.dart';
import 'package:flaxtter/features/settings/user_list_screen.dart';
import 'package:flaxtter/features/settings/account_switcher_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/app_rebirth.dart';
import 'package:flaxtter/utils/app_settings.dart';
import 'package:flaxtter/utils/json_cache.dart';
import 'package:flaxtter/utils/media_actions.dart';
import 'package:flaxtter/utils/search_history.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

/// Android-settings-style main page: grouped categories navigating to subpages.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.confirmLogout),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    await TwitterAccount.logoutAll();
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/gate', (route) => false);
    }
  }

  void _push(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      primary: false,
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SettingsNavTile(
            icon: Icons.switch_account,
            iconColor: Colors.cyan,
            title: l10n.switchAccount,
            subtitle: l10n.switchAccountHint,
            onTap: () => _push(context, const AccountSwitcherScreen()),
          ),
          _SettingsNavTile(
            icon: Icons.palette_outlined,
            iconColor: Colors.deepPurple,
            title: l10n.settingsAppearance,
            subtitle: l10n.settingsAppearanceSubtitle,
            onTap: () => _push(context, const AppearanceSettingsScreen()),
          ),
          _SettingsNavTile(
            icon: Icons.tune,
            iconColor: Colors.blue,
            title: l10n.settingsGeneral,
            subtitle: l10n.settingsGeneralSubtitle,
            onTap: () => _push(context, const GeneralSettingsScreen()),
          ),
          _SettingsNavTile(
            icon: Icons.image_outlined,
            iconColor: Colors.indigo,
            title: l10n.settingsMedia,
            subtitle: l10n.settingsMediaSubtitle,
            onTap: () => _push(context, const MediaSettingsScreen()),
          ),
          _SettingsNavTile(
            icon: Icons.notifications_outlined,
            iconColor: Colors.orange,
            title: l10n.notifications,
            subtitle: l10n.settingsNotificationsSubtitle,
            onTap: () => _push(context, const NotificationSettingsScreen()),
          ),
          _SettingsNavTile(
            icon: Icons.shield_outlined,
            iconColor: Colors.teal,
            title: l10n.settingsPrivacy,
            subtitle: l10n.settingsPrivacySubtitle,
            onTap: () => _push(context, const PrivacySettingsScreen()),
          ),
          _SettingsNavTile(
            icon: Icons.storage_outlined,
            iconColor: Colors.green,
            title: l10n.settingsData,
            subtitle: l10n.settingsDataSubtitle,
            onTap: () => _push(context, const DataSettingsScreen()),
          ),
          const Divider(indent: 16, endIndent: 16),
          _SettingsNavTile(
            icon: Icons.logout,
            iconColor: theme.colorScheme.error,
            title: l10n.logout,
            titleColor: theme.colorScheme.error,
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback onTap;

  const _SettingsNavTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: iconColor.withValues(alpha: 0.15),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: titleColor),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onTap: onTap,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class AppearanceSettingsScreen extends StatelessWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<AppSettings>();

    return Scaffold(
      primary: false,
      appBar: AppBar(title: Text(l10n.settingsAppearance)),
      body: ListView(
        children: [
          _SectionHeader(title: l10n.themeMode),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: Text(l10n.themeMode),
            trailing: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l10n.themeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_outlined, size: 18),
                  tooltip: l10n.themeLight,
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_outlined, size: 18),
                  tooltip: l10n.themeDark,
                ),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (selection) => settings.themeMode = selection.first,
            ),
          ),
          _SectionHeader(title: l10n.themeColor),
          SwitchListTile(
            secondary: const Icon(Icons.wallpaper_outlined),
            title: Text(l10n.dynamicColor),
            subtitle: Text(l10n.dynamicColorHint),
            value: settings.useDynamicColor,
            onChanged: (value) => settings.useDynamicColor = value,
          ),
          if (!settings.useDynamicColor)
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.themeColor),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    for (final color in seedColorChoices)
                      _ColorDot(
                        color: Color(color),
                        selected: settings.seedColor == color,
                        onTap: () => settings.seedColor = color,
                      ),
                  ],
                ),
              ),
            ),
          _SectionHeader(title: l10n.customFont),
          ListTile(
            leading: const Icon(Icons.font_download_outlined),
            title: Text(l10n.customFont),
            subtitle: Text(
              settings.customFontPath != null
                  ? p.basename(settings.customFontPath!)
                  : l10n.customFontDefault,
            ),
            trailing: settings.customFontPath != null
                ? IconButton(
                    tooltip: l10n.restoreDefaultFont,
                    icon: const Icon(Icons.restart_alt),
                    onPressed: () => settings.clearCustomFont(),
                  )
                : null,
            onTap: () => _pickFont(context, settings),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFont(BuildContext context, AppSettings settings) async {
    final l10n = AppLocalizations.of(context);
    const typeGroup = XTypeGroup(
      label: 'Fonts',
      extensions: ['ttf', 'otf', 'ttc'],
    );
    final file = await openFile(acceptedTypeGroups: const [typeGroup]);
    if (file == null) {
      return;
    }

    final bytes = await file.readAsBytes();
    if (!context.mounted) {
      return;
    }

    final valid = await AppSettings.validateFontBytes(bytes);
    if (!context.mounted) {
      return;
    }

    if (!valid) {
      final retry = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l10n.invalidFontFile),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.reselectFont),
            ),
          ],
        ),
      );
      if (retry == true && context.mounted) {
        await _pickFont(context, settings);
      }
      return;
    }

    try {
      await settings.setCustomFontBytes(bytes, file.name);
    } catch (e) {
      if (context.mounted) {
        await showMediaActionSnackBar(context, l10n.actionFailed(e.toString()));
      }
      return;
    }

    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.customFontRestartRequired),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.restartLater),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              AppRebirth.restartApp(context);
            },
            child: Text(l10n.restartNow),
          ),
        ],
      ),
    );
  }
}

class GeneralSettingsScreen extends StatelessWidget {
  const GeneralSettingsScreen({super.key});

  String _languageLabel(AppLocalizations l10n, AppLanguage language) {
    return switch (language) {
      AppLanguage.system => l10n.languageSystem,
      AppLanguage.zhHans => '简体中文',
      AppLanguage.zhHant => '繁體中文',
      AppLanguage.en => 'English',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<AppSettings>();

    return Scaffold(
      primary: false,
      appBar: AppBar(title: Text(l10n.settingsGeneral)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            trailing: DropdownButton<AppLanguage>(
              value: settings.language,
              underline: const SizedBox.shrink(),
              items: [
                for (final language in AppLanguage.values)
                  DropdownMenuItem(
                    value: language,
                    child: Text(_languageLabel(l10n, language)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  settings.language = value;
                }
              },
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.schedule),
            title: Text(l10n.absoluteTime),
            subtitle: Text(l10n.absoluteTimeHint),
            value: settings.useAbsoluteTime,
            onChanged: (value) => settings.useAbsoluteTime = value,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.refresh),
            title: Text(l10n.refreshOnLaunch),
            subtitle: Text(l10n.refreshOnLaunchHint),
            value: settings.refreshOnLaunch,
            onChanged: (value) => settings.refreshOnLaunch = value,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.repeat),
            title: Text(l10n.hideRetweets),
            subtitle: Text(l10n.hideRetweetsHint),
            value: settings.hideRetweets,
            onChanged: (value) => settings.hideRetweets = value,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.history),
            title: Text(l10n.saveSearchHistorySetting),
            value: settings.saveSearchHistory,
            onChanged: (value) => settings.saveSearchHistory = value,
          ),
          ListTile(
            leading: const Icon(Icons.format_size),
            title: Text(l10n.textSize),
            subtitle: Text(l10n.textSizeHint),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('A'),
                Expanded(
                  child: Slider(
                    min: 0.85,
                    max: 1.35,
                    divisions: 10,
                    value: settings.textScale,
                    label: '${(settings.textScale * 100).round()}%',
                    onChanged: (value) => settings.textScale = value,
                  ),
                ),
                const Text('A', style: TextStyle(fontSize: 20)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MediaSettingsScreen extends StatelessWidget {
  const MediaSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<AppSettings>();

    return Scaffold(
      primary: false,
      appBar: AppBar(title: Text(l10n.settingsMedia)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.high_quality_outlined),
            title: Text(l10n.mediaQualityTitle),
            trailing: SegmentedButton<MediaQuality>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: MediaQuality.small, label: Text(l10n.mediaQualitySmall)),
                ButtonSegment(value: MediaQuality.medium, label: Text(l10n.mediaQualityMedium)),
                ButtonSegment(value: MediaQuality.large, label: Text(l10n.mediaQualityLarge)),
              ],
              selected: {settings.mediaQuality},
              onSelectionChanged: (selection) => settings.mediaQuality = selection.first,
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.data_saver_on_outlined),
            title: Text(l10n.dataSaver),
            subtitle: Text(l10n.dataSaverHint),
            value: settings.dataSaver,
            onChanged: (value) => settings.dataSaver = value,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined),
            title: Text(l10n.blurSensitive),
            subtitle: Text(l10n.blurSensitiveHint),
            value: settings.blurSensitiveMedia,
            onChanged: (value) => settings.blurSensitiveMedia = value,
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.warning_amber_outlined),
            title: Text(l10n.markMediaSensitive),
            subtitle: Text(l10n.markMediaSensitiveHint),
            value: settings.markMediaSensitive,
            onChanged: (value) => settings.markMediaSensitive = value,
          ),
        ],
      ),
    );
  }
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<AppSettings>();

    String labelOf(NotificationType type) => switch (type) {
          NotificationType.likes => l10n.notifLikes,
          NotificationType.retweets => l10n.notifRetweets,
          NotificationType.follows => l10n.notifFollows,
          NotificationType.mentions => l10n.notifMentions,
          NotificationType.other => l10n.notifOther,
        };

    IconData iconOf(NotificationType type) => switch (type) {
          NotificationType.likes => Icons.favorite_border,
          NotificationType.retweets => Icons.repeat,
          NotificationType.follows => Icons.person_add_alt,
          NotificationType.mentions => Icons.alternate_email,
          NotificationType.other => Icons.notifications_none,
        };

    return Scaffold(
      primary: false,
      appBar: AppBar(title: Text(l10n.notifications)),
      body: ListView(
        children: [
          _SectionHeader(title: l10n.settingsNotificationsSubtitle),
          for (final type in NotificationType.values)
            SwitchListTile(
              secondary: Icon(iconOf(type)),
              title: Text(labelOf(type)),
              value: settings.notificationTypeEnabled(type),
              onChanged: (value) => settings.setNotificationTypeEnabled(type, value),
            ),
        ],
      ),
    );
  }
}

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      primary: false,
      appBar: AppBar(title: Text(l10n.settingsPrivacy)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.volume_off_outlined),
            title: Text(l10n.mutedUsers),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const UserListScreen(mode: UserListMode.muted),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: Text(l10n.blockedUsers),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const UserListScreen(mode: UserListMode.blocked),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DataSettingsScreen extends StatelessWidget {
  const DataSettingsScreen({super.key});

  Future<void> _clearSearchHistory(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await clearSearchHistory();
    if (context.mounted) {
      await showMediaActionSnackBar(context, l10n.searchHistoryCleared);
    }
  }

  Future<void> _clearCache(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await clearJsonCache();
    if (context.mounted) {
      await showMediaActionSnackBar(context, l10n.cacheCleared);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      primary: false,
      appBar: AppBar(title: Text(l10n.settingsData)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.history),
            title: Text(l10n.clearSearchHistory),
            onTap: () => _clearSearchHistory(context),
          ),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: Text(l10n.clearCache),
            subtitle: Text(l10n.clearCacheHint),
            onTap: () => _clearCache(context),
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected
              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
              : null,
        ),
        child: selected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
      ),
    );
  }
}
