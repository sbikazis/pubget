import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../l10n/edit_copy.dart';
import '../providers/edit_upload_manager.dart';

/// Single app-wide upload progress surface (YouTube-style).
class GlobalEditUploadBar extends StatelessWidget {
  const GlobalEditUploadBar({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<EditUploadManager>();
    if (!manager.hasVisibleJobs) return const SizedBox.shrink();
    final copy = EditCopy.of(context);
    final primary = manager.primaryJob!;
    final queue = manager.visibleJobs;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _PrimaryBar(
                job: primary,
                copy: copy,
                queueCount: queue.length,
                expanded: manager.expanded,
                onTap: manager.toggleExpanded,
              ),
              if (manager.expanded) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                _DetailsCard(
                  jobs: queue,
                  copy: copy,
                  onRetry: manager.retry,
                  onCancel: manager.cancel,
                  onDismiss: manager.dismiss,
                  onDeleteDraft: manager.deleteDraft,
                  onCollapse: () => manager.setExpanded(false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryBar extends StatelessWidget {
  const _PrimaryBar({
    required this.job,
    required this.copy,
    required this.queueCount,
    required this.expanded,
    required this.onTap,
  });

  final EditUploadJob job;
  final EditCopy copy;
  final int queueCount;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final failed = job.isFailed;
    final processing = job.phase == EditUploadJobPhase.processing;
    final published = job.phase == EditUploadJobPhase.published;
    final review = job.phase == EditUploadJobPhase.needsReview;
    final bg = failed
        ? scheme.errorContainer
        : review
        ? scheme.tertiaryContainer
        : published
        ? scheme.secondaryContainer
        : scheme.surfaceContainerHighest;
    final fg = failed
        ? scheme.onErrorContainer
        : review
        ? scheme.onTertiaryContainer
        : published
        ? scheme.onSecondaryContainer
        : scheme.onSurface;

    final label = switch (job.phase) {
      EditUploadJobPhase.uploading || EditUploadJobPhase.queued =>
        '${copy.uploading} ${(job.progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
      EditUploadJobPhase.processing => copy.processing,
      EditUploadJobPhase.published => copy.published,
      EditUploadJobPhase.needsReview => copy.needsReview,
      EditUploadJobPhase.failed =>
        job.errorMessage ?? copy.failedStatus,
      EditUploadJobPhase.canceled => copy.cancelUpload,
    };

    return InkWell(
      key: const Key('global-edit-upload-bar'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Ink(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: failed
                ? scheme.error.withValues(alpha: 0.45)
                : scheme.outlineVariant.withValues(alpha: 0.5),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    failed
                        ? Icons.error_outline
                        : processing
                        ? Icons.auto_awesome
                        : published
                        ? Icons.check_circle_outline
                        : Icons.cloud_upload_outlined,
                    size: 18,
                    color: fg,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (queueCount > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: Text(
                        copy.queueCount(queueCount),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: fg.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: fg,
                  ),
                ],
              ),
              if (job.phase == EditUploadJobPhase.uploading ||
                  job.phase == EditUploadJobPhase.queued) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: job.progress <= 0 ? null : job.progress,
                    minHeight: 3,
                    backgroundColor: fg.withValues(alpha: 0.15),
                    color: AppColors.royalPurple,
                  ),
                ),
              ],
              if (processing) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: fg.withValues(alpha: 0.15),
                    color: AppColors.royalPurple,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.jobs,
    required this.copy,
    required this.onRetry,
    required this.onCancel,
    required this.onDismiss,
    required this.onDeleteDraft,
    required this.onCollapse,
  });

  final List<EditUploadJob> jobs;
  final EditCopy copy;
  final Future<void> Function(String localId) onRetry;
  final Future<void> Function(String localId) onCancel;
  final Future<void> Function(String localId) onDismiss;
  final Future<void> Function(String localId) onDeleteDraft;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 280),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.all(AppSpacing.sm),
          itemCount: jobs.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final job = jobs[index];
            return ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
              ),
              title: Text(
                job.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                job.errorMessage ??
                    switch (job.phase) {
                      EditUploadJobPhase.uploading =>
                        '${copy.uploading} ${(job.progress * 100).toStringAsFixed(0)}%',
                      EditUploadJobPhase.processing => copy.processing,
                      EditUploadJobPhase.published => copy.published,
                      EditUploadJobPhase.needsReview => copy.needsReview,
                      EditUploadJobPhase.failed => copy.failedStatus,
                      EditUploadJobPhase.queued => copy.queued,
                      EditUploadJobPhase.canceled => copy.cancelUpload,
                    },
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Wrap(
                spacing: 4,
                children: <Widget>[
                  if (job.isFailed) ...<Widget>[
                    TextButton(
                      onPressed: () => onRetry(job.localId),
                      child: Text(copy.retry),
                    ),
                    TextButton(
                      onPressed: () => onDeleteDraft(job.localId),
                      child: Text(copy.deleteDraft),
                    ),
                  ],
                  if (job.isActive)
                    TextButton(
                      onPressed: () => onCancel(job.localId),
                      child: Text(copy.cancelUpload),
                    ),
                  if (job.phase == EditUploadJobPhase.published ||
                      job.phase == EditUploadJobPhase.needsReview)
                    IconButton(
                      tooltip: copy.dismiss,
                      onPressed: () => onDismiss(job.localId),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                ],
              ),
              onTap: onCollapse,
            );
          },
        ),
      ),
    );
  }
}

/// Stacks the global bar above [child] for every route.
class EditUploadOverlayHost extends StatelessWidget {
  const EditUploadOverlayHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: GlobalEditUploadBar(),
        ),
      ],
    );
  }
}
