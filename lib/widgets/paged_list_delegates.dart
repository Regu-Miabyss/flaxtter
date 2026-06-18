import 'package:flutter/material.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/widgets/tweet_loading_skeleton.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

/// Footer shown when loading the next page fails — scroll or tap to retry.
class PagedLoadMoreErrorFooter extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const PagedLoadMoreErrorFooter({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onRetry(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).hintColor,
                ),
          ),
        ),
      ),
    );
  }
}

class PagedEndFooter extends StatelessWidget {
  final String message;

  const PagedEndFooter({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).hintColor,
              ),
        ),
      ),
    );
  }
}

class PagedFirstPageErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  const PagedFirstPageErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}

PagedChildBuilderDelegate<ItemType> flaxtterPagedDelegate<ItemType>({
  required AppLocalizations l10n,
  required Future<void> Function() fetchNextPage,
  required ItemWidgetBuilder<ItemType> itemBuilder,
  required VoidCallback resetAndRetry,
  required Object? firstPageError,
  String? noItemsMessage,
  String Function(Object? error)? firstPageErrorMessage,
}) {
  return PagedChildBuilderDelegate<ItemType>(
    itemBuilder: itemBuilder,
    firstPageErrorIndicatorBuilder: (_) => PagedFirstPageErrorView(
      message: firstPageErrorMessage?.call(firstPageError) ??
          l10n.loadFailed(firstPageError?.toString() ?? ''),
      onRetry: resetAndRetry,
      retryLabel: l10n.retry,
    ),
    newPageErrorIndicatorBuilder: (_) => PagedLoadMoreErrorFooter(
      message: l10n.scrollToRetryLoading,
      onRetry: fetchNextPage,
    ),
    firstPageProgressIndicatorBuilder: (_) => const TweetLoadingSkeleton(),
    newPageProgressIndicatorBuilder: (_) => const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: TweetLoadingSkeleton(itemCount: 2),
    ),
    noItemsFoundIndicatorBuilder: (_) => Center(child: Text(noItemsMessage ?? l10n.noResults)),
    noMoreItemsIndicatorBuilder: (_) => PagedEndFooter(message: l10n.reachedEnd),
  );
}
