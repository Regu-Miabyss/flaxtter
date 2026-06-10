import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/media_actions.dart';

bool isPollCard(Map<String, dynamic>? card) {
  final name = card?['name'];
  return name is String && name.startsWith('poll') && name.contains('choice');
}

class _PollChoice {
  final int index; // 1-based, as used by the vote API
  final String label;
  final int count;

  const _PollChoice(this.index, this.label, this.count);
}

/// Rendering of a Twitter poll card. Supports voting while the poll is open.
class TweetPoll extends StatefulWidget {
  final Map<String, dynamic> card;
  final String? tweetId;

  const TweetPoll({super.key, required this.card, this.tweetId});

  @override
  State<TweetPoll> createState() => _TweetPollState();
}

class _TweetPollState extends State<TweetPoll> {
  late Map<String, dynamic> _card = widget.card;
  bool _voting = false;

  @override
  void didUpdateWidget(covariant TweetPoll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.card, widget.card)) {
      _card = widget.card;
    }
  }

  Map<String, dynamic> get _bindingValues {
    final raw = _card['binding_values'];
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    // v1.1-style list of {key, value} pairs.
    if (raw is List) {
      final map = <String, dynamic>{};
      for (final entry in raw) {
        if (entry is Map && entry['key'] is String) {
          map[entry['key'] as String] = entry['value'];
        }
      }
      return map;
    }
    return const {};
  }

  String? _stringValue(Map<String, dynamic> values, String key) {
    final value = values[key];
    if (value is Map) {
      return value['string_value'] as String?;
    }
    return null;
  }

  bool _boolValue(Map<String, dynamic> values, String key) {
    final value = values[key];
    if (value is Map) {
      final b = value['boolean_value'];
      if (b is bool) {
        return b;
      }
      if (b is String) {
        return b.toLowerCase() == 'true';
      }
    }
    return false;
  }

  Future<void> _vote(_PollChoice choice) async {
    final cardUri = _card['url'] as String? ?? _stringValue(_bindingValues, 'card_url');
    final cardName = _card['name'] as String?;
    final tweetId = widget.tweetId;
    if (cardUri == null || cardName == null || tweetId == null || _voting) {
      return;
    }

    setState(() => _voting = true);
    try {
      final updatedCard = await Twitter.votePoll(
        cardUri: cardUri,
        tweetId: tweetId,
        cardName: cardName,
        selectedChoice: choice.index,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        if (updatedCard != null) {
          _card = updatedCard;
        }
      });
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        await showMediaActionSnackBar(context, l10n.actionFailed(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _voting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final values = _bindingValues;

    final choices = <_PollChoice>[];
    for (var i = 1; i <= 4; i++) {
      final label = _stringValue(values, 'choice${i}_label');
      if (label == null) {
        break;
      }
      final count = int.tryParse(_stringValue(values, 'choice${i}_count') ?? '0') ?? 0;
      choices.add(_PollChoice(i, label, count));
    }
    if (choices.isEmpty) {
      return const SizedBox.shrink();
    }

    final totalVotes = choices.fold<int>(0, (sum, c) => sum + c.count);
    final maxCount = choices.fold<int>(0, (max, c) => c.count > max ? c.count : max);

    final countsAreFinal = _boolValue(values, 'counts_are_final');
    final endStr = _stringValue(values, 'end_datetime_utc');
    final endTime = endStr != null ? DateTime.tryParse(endStr) : null;
    final ended = countsAreFinal ||
        (endTime != null && endTime.isBefore(DateTime.now().toUtc()));

    final selectedChoice = int.tryParse(_stringValue(values, 'selected_choice') ?? '');
    final hasVoted = selectedChoice != null;
    final canVote = !ended && !hasVoted && widget.tweetId != null && _card['url'] != null;
    // Hide counts until the user voted or the poll ended, like Twitter does.
    final showResults = hasVoted || ended;

    final footer = StringBuffer(l10n.pollVotes(totalVotes));
    if (ended) {
      footer.write(' · ${l10n.pollEnded}');
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final choice in choices) ...[
            _PollBar(
              label: choice.label,
              fraction: !showResults || totalVotes == 0 ? 0 : choice.count / totalVotes,
              showPercent: showResults,
              leading: showResults && ended && choice.count == maxCount && maxCount > 0,
              selected: selectedChoice == choice.index,
              outlined: canVote,
              onTap: canVote && !_voting ? () => _vote(choice) : null,
            ),
            const SizedBox(height: 6),
          ],
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  footer.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (_voting)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PollBar extends StatelessWidget {
  final String label;
  final double fraction;
  final bool showPercent;
  final bool leading;
  final bool selected;
  final bool outlined;
  final VoidCallback? onTap;

  const _PollBar({
    required this.label,
    required this.fraction,
    required this.showPercent,
    required this.leading,
    required this.selected,
    required this.outlined,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentText = '${(fraction * 100).toStringAsFixed(fraction >= 0.1 ? 0 : 1)}%';
    final emphasized = leading || selected;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: outlined ? null : theme.colorScheme.surfaceContainerHighest,
                    border: outlined
                        ? Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.6))
                        : null,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              if (showPercent)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: fraction.clamp(0.0, 1.0),
                    child: ColoredBox(
                      color: emphasized
                          ? theme.colorScheme.primary.withValues(alpha: 0.55)
                          : theme.colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selected) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.check_circle, size: 14, color: theme.colorScheme.primary),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (showPercent)
                      Text(
                        percentText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
