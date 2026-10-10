import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../app/app_router.dart';
import '../../../core/errors/failure.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../anime/models/anime_models.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../groups/providers/group_provider.dart';
import '../../groups/screens/group_anime_picker_page.dart';
import '../data/event_image_uploader.dart';
import '../models/event_lifecycle.dart';
import '../models/event_models.dart';
import '../models/event_type_registry.dart';
import '../providers/event_providers.dart';
import '../widgets/event_crosspost_sheet.dart';
import '../widgets/event_widgets.dart';

/// Step-by-step event creation flow (spec 14.2):
/// scope <- type <- content <- duration <- mandatory preview <- publish.
class EventBuilderPage extends StatefulWidget {
  const EventBuilderPage({
    this.groupId,
    this.groupIds = const <String>[],
    this.scope = EventScope.global,
    this.templateId,
    super.key,
  });

  final String? groupId;
  final List<String> groupIds;
  final EventScope scope;
  final String? templateId;

  @override
  State<EventBuilderPage> createState() => _EventBuilderPageState();
}

/// The audience choice the user sees. It resolves to the stored scope:
/// one selected group -> group, several -> multiGroup, none -> global.
enum _ScopeChoice { global, groups }

class _EventBuilderPageState extends State<EventBuilderPage> {
  final _title = TextEditingController();
  final _pollQuestion = TextEditingController();
  final _theoryBody = TextEditingController();
  final List<_PollOptionForm> _options = <_PollOptionForm>[
    _PollOptionForm(),
    _PollOptionForm(),
  ];
  final FirebaseEventImageUploader _uploader = FirebaseEventImageUploader();

  _ScopeChoice _scopeChoice = _ScopeChoice.global;
  final List<String> _selectedGroupIds = <String>[];
  EventAnimeLink? _anime;
  int _step = 0;
  int _maxStep = 0;
  bool _started = false;
  bool _previewRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final builder = context.read<EventBuilderProvider>();
    final auth = context.read<AuthProvider>();
    final uid = auth.currentUser?.id;

    if (widget.groupId != null && widget.groupId!.isNotEmpty) {
      _scopeChoice = _ScopeChoice.groups;
      _selectedGroupIds
        ..clear()
        ..add(widget.groupId!);
    } else if (widget.scope == EventScope.multiGroup ||
        widget.groupIds.length > 1) {
      _scopeChoice = _ScopeChoice.groups;
      _selectedGroupIds
        ..clear()
        ..addAll(widget.groupIds);
    } else {
      _scopeChoice = widget.scope == EventScope.global
          ? _ScopeChoice.global
          : _ScopeChoice.groups;
      _selectedGroupIds
        ..clear()
        ..addAll(widget.groupIds);
    }

    final groups = context.read<GroupProvider>();
    Future<void>.microtask(() async {
      builder.start(
        groupId: widget.groupId,
        groupIds: widget.groupIds,
        scope: widget.scope,
        templateId: widget.templateId,
      );
      if (uid != null) {
        await groups.openJoined(uid);
      }
      if (!mounted) return;
      if (uid != null && widget.templateId == null) {
        // A group entry only adopts that group's draft; a global entry
        // adopts whatever draft is newest (the scope step shows it).
        final restoreGroup = (widget.groupId != null &&
                widget.groupId!.isNotEmpty)
            ? widget.groupId
            : (widget.groupIds.length == 1 ? widget.groupIds.first : null);
        await builder.restoreDraft(
          userId: uid,
          groupId: restoreGroup,
          scope: widget.groupIds.length > 1
              ? EventScope.multiGroup
              : (restoreGroup != null ? EventScope.group : null),
        );
        if (!mounted) return;
        _hydrate(builder.draft);
      }
    });
  }

  void _hydrate(EventDraft draft) {
    _title.text = draft.title;
    if (widget.groupId == null || widget.groupId!.isEmpty) {
      switch (draft.scope) {
        case EventScope.global:
          _scopeChoice = _ScopeChoice.global;
          _selectedGroupIds.clear();
        case EventScope.group:
          _scopeChoice = _ScopeChoice.groups;
          _selectedGroupIds
            ..clear()
            ..addAll(draft.groupId == null
                ? draft.groupIds
                : <String>[draft.groupId!]);
        case EventScope.multiGroup:
          _scopeChoice = _ScopeChoice.groups;
          _selectedGroupIds
            ..clear()
            ..addAll(draft.groupIds);
      }
    }
    if (draft.type == EventType.theory) {
      _theoryBody.text = draft.description;
      _anime = draft.configuration.anime;
    } else {
      _pollQuestion.text = draft.configuration.question;
      if (draft.configuration.options.isNotEmpty) {
        for (final form in _options) {
          form.dispose();
        }
        _options
          ..clear()
          ..addAll(draft.configuration.options.map(
            (option) => _PollOptionForm(
              label: option.label,
              imageUrl: option.imageUrl,
            ),
          ));
        while (_options.length < EventLifecycle.pollOptionMin) {
          _options.add(_PollOptionForm());
        }
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _title.dispose();
    _pollQuestion.dispose();
    _theoryBody.dispose();
    for (final form in _options) {
      form.dispose();
    }
    super.dispose();
  }

  bool get _scopeLocked =>
      widget.groupId != null && widget.groupId!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final copy = AppStrings.of(context);
    final builder = context.watch<EventBuilderProvider>();
    final quota = builder.quota;
    final remaining = builder.remainingAllowance;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.eventCreate),
      ),
      body: Stepper(
        currentStep: _step,
        onStepTapped: (value) {
          if (value > _maxStep || value == _step) return;
          setState(() {
            _step = value;
            _previewRequested = false;
          });
        },
        onStepContinue: _step >= _previewStep
            ? () => _publish(builder)
            : () => _next(builder),
        onStepCancel: () => _back(builder),
        controlsBuilder: (context, details) {
          final isLast = _step >= _previewStep;
          final disabled = isLast &&
              quota != null &&
              quota.exhausted &&
              remaining != EventLifecycle.unknownQuotaRemaining;
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (builder.failure != null) ...[
                  Text(
                    _failureText(copy, builder.failure!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                Row(
                  children: <Widget>[
                    Expanded(
                      child: PubgetPrimaryButton(
                        key: Key(isLast ? 'create-publish' : 'create-continue'),
                        onPressed: disabled
                            ? null
                            : (isLast
                                ? () => _publish(builder)
                                : details.onStepContinue),
                        semanticLabel:
                            isLast ? copy.eventPublish : copy.eventContinue,
                        loading: builder.saving || builder.previewing,
                        child: Text(
                          isLast ? copy.eventPublish : copy.eventContinue,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PubgetTextButton(
                      onPressed: builder.saving
                          ? null
                          : () => _back(builder),
                      semanticLabel: _step == 0
                          ? copy.eventDiscardDraft
                          : copy.eventBack,
                      child: Text(
                        _step == 0 ? copy.eventDiscardDraft : copy.eventBack,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        steps: <Step>[
          Step(
            title: Text(copy.eventStepScope),
            isActive: _step >= 0,
            content: _scopeStep(copy, builder),
          ),
          Step(
            title: Text(copy.eventStepType),
            isActive: _step >= 1,
            content: _typeStep(copy, builder),
          ),
          Step(
            title: Text(copy.eventStepContent),
            isActive: _step >= 2,
            content: _contentStep(copy, builder),
          ),
          Step(
            title: Text(copy.eventStepDuration),
            isActive: _step >= 3,
            content: _durationStep(copy, builder),
          ),
          Step(
            title: Text(copy.eventStepPreview),
            isActive: _step >= _previewStep,
            content: _previewStepWidget(copy, builder),
          ),
        ],
      ),
    );
  }

  int get _previewStep => 4;

  // ---------------------------------------------------------------- steps --

  Widget _scopeStep(AppStrings copy, EventBuilderProvider builder) {
    if (_scopeLocked) {
      final groups = context.watch<GroupProvider>().joinedGroups;
      final name = groups
          .where((group) => group.id == widget.groupId)
          .map((group) => group.name)
          .followedBy(<String>[copy.groupEvents])
          .first;
      return PubgetCard(
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.groups_outlined),
          title: Text(name),
          subtitle: Text(copy.eventToGroupsHint),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _ScopeCard(
          key: const Key('create-scope-global'),
          icon: Icons.public_outlined,
          title: copy.eventGlobal,
          hint: copy.eventGlobalHint,
          selected: _scopeChoice == _ScopeChoice.global,
          onTap: () => setState(() => _scopeChoice = _ScopeChoice.global),
        ),
        const SizedBox(height: AppSpacing.sm),
        _ScopeCard(
          key: const Key('create-scope-groups'),
          icon: Icons.groups_outlined,
          title: copy.eventToGroups,
          hint: copy.eventToGroupsHint,
          selected: _scopeChoice == _ScopeChoice.groups,
          onTap: () => setState(() => _scopeChoice = _ScopeChoice.groups),
        ),
        if (_scopeChoice == _ScopeChoice.groups) ...[
          const SizedBox(height: AppSpacing.sm),
          PubgetSecondaryButton(
            key: const Key('create-pick-groups'),
            onPressed: _pickGroups,
            semanticLabel: copy.eventChooseGroups,
            leadingIcon: Icons.checklist_outlined,
            child: Text(
              _selectedGroupIds.isEmpty
                  ? copy.eventChooseGroups
                  : copy.eventSelectedGroups(_selectedGroupIds.length),
            ),
          ),
        ],
      ],
    );
  }

  Widget _typeStep(AppStrings copy, EventBuilderProvider builder) {
    final type = builder.draft.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _TypeCard(
          key: const Key('create-type-poll'),
          icon: Icons.poll_outlined,
          title: copy.eventPollChoice,
          hint: copy.eventPollChoiceHint,
          selected: type == EventType.poll,
          onTap: () => _setType(builder, EventType.poll),
        ),
        const SizedBox(height: AppSpacing.sm),
        _TypeCard(
          key: const Key('create-type-theory'),
          icon: Icons.auto_stories_outlined,
          title: copy.eventTheoryChoice,
          hint: copy.eventTheoryChoiceHint,
          selected: type == EventType.theory,
          onTap: () => _setType(builder, EventType.theory),
        ),
      ],
    );
  }

  Widget _contentStep(AppStrings copy, EventBuilderProvider builder) {
    final isTheory = builder.draft.type == EventType.theory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PubgetTextField(
          key: const Key('create-title'),
          controller: _title,
          label: copy.eventTitleLabel,
          hint: copy.eventTitleHint,
          maxLength: EventLifecycle.titleMax,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (isTheory) ...[
          PubgetTextArea(
            key: const Key('create-theory-body'),
            controller: _theoryBody,
            label: copy.eventTheoryBodyLabel,
            hint: copy.eventTheoryBodyHint,
            maxLength: EventLifecycle.descriptionMax,
            minLines: 4,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          _animeCard(copy),
        ] else ...[
          PubgetTextField(
            key: const Key('create-poll-question'),
            controller: _pollQuestion,
            label: copy.eventQuestionLabel,
            hint: copy.eventQuestionHint,
            maxLength: 200,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            copy.eventPollOptionsHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < _options.length; i++) ...[
            _optionCard(copy, i),
            const SizedBox(height: AppSpacing.sm),
          ],
          if (_options.length < EventLifecycle.pollOptionMax)
            PubgetTextButton(
              key: const Key('create-add-option'),
              onPressed: () =>
                  setState(() => _options.add(_PollOptionForm())),
              semanticLabel: copy.eventAddOption,
              child: Text(copy.eventAddOption),
            ),
        ],
      ],
    );
  }

  Widget _optionCard(AppStrings copy, int index) {
    final form = _options[index];
    return PubgetCard(
      key: Key('create-option-$index'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InkWell(
            key: Key('create-option-image-$index'),
            borderRadius: BorderRadius.circular(12),
            onTap: form.uploading ? null : () => _pickOptionImage(form),
            child: Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: form.uploading
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : form.imageUrl.isEmpty
                      ? const Icon(Icons.add_photo_alternate_outlined)
                      : Image.network(
                          form.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const Icon(Icons.broken_image_outlined),
                        ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PubgetTextField(
                  controller: form.label,
                  label: copy.eventOptionLabel(index),
                  maxLength: 80,
                  onChanged: (_) => setState(() {}),
                ),
                if (form.error != null)
                  Text(
                    form.error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
              ],
            ),
          ),
          if (_options.length > EventLifecycle.pollOptionMin)
            IconButton(
              key: Key('create-remove-option-$index'),
              tooltip: copy.eventRemoveOption,
              onPressed: () => setState(() => _options.removeAt(index).dispose()),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
    );
  }

  Widget _animeCard(AppStrings copy) {
    final anime = _anime;
    if (anime == null) {
      return PubgetSecondaryButton(
        key: const Key('create-attach-anime'),
        onPressed: _pickAnime,
        semanticLabel: copy.eventAnimeAttach,
        leadingIcon: Icons.movie_outlined,
        child: Text(copy.eventAnimeAttach),
      );
    }
    return PubgetCard(
      key: const Key('create-anime-attached'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 40,
              height: 56,
              child: anime.imageUrl.isEmpty
                  ? ColoredBox(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: const Icon(Icons.movie_outlined),
                    )
                  : Image.network(
                      anime.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined),
                    ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              anime.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            tooltip: copy.eventAnimeRemove,
            onPressed: () => setState(() => _anime = null),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _durationStep(AppStrings copy, EventBuilderProvider builder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            _DurationChip(
              label: copy.eventDurationQuick1h,
              selected: _isDuration(builder, const Duration(hours: 1)),
              onSelected: () =>
                  _setDuration(builder, const Duration(hours: 1)),
            ),
            _DurationChip(
              label: copy.eventDurationQuick24h,
              selected: _isDuration(builder, const Duration(hours: 24)),
              onSelected: () =>
                  _setDuration(builder, const Duration(hours: 24)),
            ),
            _DurationChip(
              label: copy.eventDurationQuick3d,
              selected: _isDuration(builder, const Duration(days: 3)),
              onSelected: () => _setDuration(builder, const Duration(days: 3)),
            ),
            _DurationChip(
              label: copy.eventDurationQuick7d,
              selected: _isDuration(builder, const Duration(days: 7)),
              onSelected: () => _setDuration(builder, const Duration(days: 7)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        PubgetSecondaryButton(
          onPressed: () => _pickStart(builder),
          semanticLabel: copy.eventPickStart,
          child: Text(
            builder.draft.startAt == null
                ? copy.eventStartNow
                : '${copy.eventStartsAt} ${_format(builder.draft.startAt!)}',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        PubgetSecondaryButton(
          onPressed: () => _pickEnd(builder),
          semanticLabel: copy.eventPickEnd,
          child: Text(
            builder.draft.endAt == null
                ? copy.eventEndDefault
                : '${copy.eventEndsAt} ${_format(builder.draft.endAt!)}',
          ),
        ),
        Builder(
          builder: (context) {
            final start = builder.draft.startAt;
            final end = builder.draft.endAt;
            if (start == null || end == null) return const SizedBox.shrink();
            final error = EventLifecycle.validateWindow(start, end);
            if (error == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                copy.eventValidationMessage(error),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _previewStepWidget(AppStrings copy, EventBuilderProvider builder) {
    if (!_previewRequested && builder.previewData == null) {
      _previewRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final current = context.read<EventBuilderProvider>();
        if (current.previewData == null && !current.previewing) {
          current.preview();
        }
      });
    }
    final preview = builder.previewData;
    final quota = builder.quota;
    final remaining = builder.remainingAllowance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(copy.eventPreviewCheck, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        if (quota != null && remaining != EventLifecycle.unknownQuotaRemaining)
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: quota.exhausted
                  ? Theme.of(context).colorScheme.errorContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              quota.exhausted
                  ? copy.eventCreateLimit
                  : copy.eventCreateLimitRemaining(remaining),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        if (builder.previewing)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: CircularProgressIndicator(),
            ),
          )
        else if (preview == null && builder.failure != null)
          PubgetSecondaryButton(
            onPressed: () => context.read<EventBuilderProvider>().preview(),
            semanticLabel: copy.eventRetry,
            child: Text(copy.eventRetry),
          )
        else
          _previewCard(copy, builder, preview),
        const SizedBox(height: AppSpacing.sm),
        PubgetSecondaryButton(
          key: const Key('create-save-draft'),
          onPressed: builder.saving ? null : () => _saveDraft(builder),
          semanticLabel: copy.eventSaveDraft,
          child: Text(copy.eventSaveDraft),
        ),
      ],
    );
  }

  Widget _previewCard(
    AppStrings copy,
    EventBuilderProvider builder,
    EventPreview? preview,
  ) {
    final isTheory = builder.draft.type == EventType.theory;
    final title = (preview?.title.isNotEmpty ?? false)
        ? preview!.title
        : builder.draft.title;
    final description = (preview?.description.isNotEmpty ?? false)
        ? preview!.description
        : builder.draft.description;
    final configuration = preview?.configuration ?? builder.draft.configuration;
    final start = builder.draft.startAt;
    final end = builder.draft.endAt;
    return PubgetCard(
      key: const Key('create-preview-card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _PreviewChip(
                icon: Icons.public_outlined,
                label: _scopeLabel(copy),
              ),
              _PreviewChip(
                icon: isTheory
                    ? Icons.auto_stories_outlined
                    : Icons.poll_outlined,
                label: copy.eventTypeLabel(builder.draft.type.name),
              ),
              if (start != null && end != null)
                _PreviewChip(
                  icon: Icons.schedule_outlined,
                  label: '${_format(start)} → ${_format(end)}',
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (description.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (isTheory && configuration.anime != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${copy.eventAnimeAttach}: ${configuration.anime!.title}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (!isTheory && configuration.options.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final option in configuration.options)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: option.imageUrl.isEmpty
                            ? ColoredBox(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                child: const Icon(
                                  Icons.image_outlined,
                                  size: 16,
                                ),
                              )
                            : Image.network(
                                option.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image_outlined, size: 16),
                              ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        option.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            copy.eventPreviewOk,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _scopeLabel(AppStrings copy) {
    if (_scopeLocked || _scopeChoice == _ScopeChoice.groups) {
      if (_selectedGroupIds.length <= 1) return copy.eventToGroups;
      return copy.eventSelectedGroups(_selectedGroupIds.length);
    }
    return copy.eventGlobal;
  }

  // -------------------------------------------------------------- actions --

  void _setType(EventBuilderProvider builder, EventType type) {
    if (builder.draft.type == type) return;
    builder.update(builder.draft.copyWith(type: type, clearTemplate: true));
    setState(() {});
  }

  void _next(EventBuilderProvider builder) {
    _syncDraft(builder);
    final error = _validateStep(builder);
    if (error != null) {
      _showMessage(AppStrings.of(context).eventValidationMessage(error));
      return;
    }
    setState(() {
      _step = math.min(_step + 1, _previewStep);
      _maxStep = math.max(_maxStep, _step);
      if (_step == _previewStep) _previewRequested = false;
    });
  }

  void _back(EventBuilderProvider builder) {
    if (_step == 0) {
      _confirmDiscard(builder);
      return;
    }
    setState(() {
      _step -= 1;
      _previewRequested = false;
    });
  }

  Future<void> _confirmDiscard(EventBuilderProvider builder) async {
    final copy = AppStrings.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy.eventDiscardDraft),
        content: Text(copy.eventDiscardDraftConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(copy.eventBack),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(copy.eventDiscardDraft),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    await builder.abandon();
    if (!mounted) return;
    await AppNavigation.popLayer(context);
  }

  /// Validates the step the user is on. Returns a stable `ev.*` key.
  String? _validateStep(EventBuilderProvider builder) {
    final draft = builder.draft;
    switch (_step) {
      case 0:
        if (_scopeLocked) return null;
        if (_scopeChoice == _ScopeChoice.groups &&
            _selectedGroupIds.isEmpty) {
          return 'ev.chooseGroup';
        }
        return null;
      case 1:
        if (!EventTypeRegistry.creatableTypes.contains(draft.type)) {
          return 'ev.typeNotAllowed';
        }
        return null;
      case 2:
        if (draft.type == EventType.theory) {
          if (_title.text.trim().isEmpty) return 'ev.titleRequired';
          if (_title.text.trim().length > EventLifecycle.titleMax) {
            return 'ev.titleTooLong';
          }
          if (_theoryBody.text.length > EventLifecycle.descriptionMax) {
            return 'ev.descriptionTooLong';
          }
          return null;
        }
        return EventValidation.draft(draft);
      case 3:
        final start = draft.startAt;
        final end = draft.endAt;
        if (start == null || end == null) return 'ev.windowEndAfterStart';
        return EventLifecycle.validateWindow(start, end);
      default:
        return EventValidation.publish(draft);
    }
  }

  void _syncDraft(EventBuilderProvider builder) {
    final type = builder.draft.type;
    final EventConfiguration configuration;
    if (type == EventType.theory) {
      configuration = EventConfiguration(anime: _anime);
    } else {
      configuration = EventConfiguration(
        question: _pollQuestion.text.trim(),
        options: <EventOption>[
          for (var i = 0; i < _options.length; i++)
            EventOption(
              id: 'opt-${i + 1}',
              label: _options[i].label.text.trim(),
              imageUrl: _options[i].imageUrl,
            ),
        ],
      );
    }

    var scope = EventScope.global;
    String? groupId;
    var groupIds = const <String>[];
    if (_scopeLocked) {
      scope = EventScope.group;
      groupId = widget.groupId;
      groupIds = const <String>[];
    } else if (_scopeChoice == _ScopeChoice.groups) {
      if (_selectedGroupIds.length == 1) {
        scope = EventScope.group;
        groupId = _selectedGroupIds.first;
        groupIds = const <String>[];
      } else if (_selectedGroupIds.length > 1) {
        scope = EventScope.multiGroup;
        groupId = null;
        groupIds = List<String>.unmodifiable(_selectedGroupIds);
      }
    }

    final now = DateTime.now();
    final current = builder.draft;
    // Built directly (not via copyWith) so switching from a group scope back
    // to global can clear groupId — copyWith cannot unset a nullable field.
    builder.update(
      EventDraft(
        eventId: current.eventId,
        groupId: groupId,
        scope: scope,
        groupIds: groupIds,
        type: type,
        title: _title.text,
        description: type == EventType.theory ? _theoryBody.text : '',
        templateId: current.templateId,
        startAt: current.startAt ?? now,
        endAt: current.endAt ?? now.add(const Duration(hours: 24)),
        configuration: configuration,
      ),
    );
  }

  Future<void> _saveDraft(EventBuilderProvider builder) async {
    _syncDraft(builder);
    final result = await builder.saveDraft();
    if (!mounted) return;
    final copy = AppStrings.of(context);
    _showMessage(result.isSuccess
        ? copy.eventDraftSaved
        : _failureText(copy, result.failureOrNull));
  }

  Future<void> _publish(EventBuilderProvider builder) async {
    _syncDraft(builder);
    final copy = AppStrings.of(context);
    final validation = EventValidation.publish(builder.draft);
    if (validation != null) {
      _showMessage(copy.eventValidationMessage(validation));
      return;
    }
    if (builder.quota != null && builder.quota!.exhausted) {
      _showMessage(copy.eventCreateLimit);
      return;
    }
    final result = await builder.publish();
    if (!mounted) return;
    final event = result.valueOrNull;
    if (event == null) {
      _showMessage(_failureText(copy, result.failureOrNull));
      return;
    }
    await _offerCrosspost(event);
    if (!mounted) return;
    EventLinks.open(context, event.id);
  }

  /// Spec 14.4: one event, extended audiences. Offered right after publish.
  Future<void> _offerCrosspost(PubgetEvent event) async {
    await offerEventCrosspost(context, event, onMessage: _showMessage);
  }

  // ------------------------------------------------------------ form pickers --

  Future<void> _pickGroups() async {
    final copy = AppStrings.of(context);
    final uid = context.read<AuthProvider>().currentUser?.id;
    final provider = context.read<GroupProvider>();
    if (uid != null && provider.joinedGroups.isEmpty) {
      await provider.openJoined(uid);
    }
    if (!mounted) return;
    final joined = provider.joinedGroups;
    if (joined.isEmpty) {
      _showMessage(copy.eventNoGroupsJoined);
      return;
    }
    final picked = List<String>.of(_selectedGroupIds);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final sheetCopy = AppStrings.of(sheetContext);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    sheetCopy.eventChooseGroups,
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: <Widget>[
                        for (final group in joined)
                          CheckboxListTile(
                            key: Key('pick-group-${group.id}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(group.name),
                            subtitle: Text(
                              sheetCopy.membersCount(group.membersCount),
                            ),
                            value: picked.contains(group.id),
                            onChanged: (value) => setSheetState(() {
                              if (value == true) {
                                picked.add(group.id);
                              } else {
                                picked.remove(group.id);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PubgetPrimaryButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    semanticLabel: sheetCopy.eventContinue,
                    child: Text(
                      picked.isEmpty
                          ? sheetCopy.eventContinue
                          : sheetCopy.eventSelectedGroups(picked.length),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _selectedGroupIds
      ..clear()
      ..addAll(picked));
  }

  Future<void> _pickOptionImage(_PollOptionForm form) async {
    final copy = AppStrings.of(context);
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid == null || uid.isEmpty) return;
    final cropped = await pickAndCropImage(
      context,
      aspect: ImageCropAspect.square,
    );
    if (cropped == null || !mounted) return;
    setState(() {
      form.uploading = true;
      form.error = null;
    });
    try {
      final url = await _uploader.uploadOptionImage(
        uid: uid,
        bytes: cropped.bytes,
      );
      if (!mounted) return;
      setState(() {
        form.imageUrl = url;
        form.uploading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        form.uploading = false;
        form.error = copy.eventImageUploadFailed;
      });
    }
  }

  Future<void> _pickAnime() async {
    final anime = await Navigator.of(context).push<Anime>(
      MaterialPageRoute(builder: (_) => const GroupAnimePickerPage()),
    );
    if (anime == null || !mounted) return;
    setState(() {
      _anime = EventAnimeLink(
        animeId: anime.id,
        title: anime.title,
        imageUrl: anime.images.displayUrl ?? '',
      );
    });
  }

  // ---------------------------------------------------------------- duration --

  bool _isDuration(EventBuilderProvider builder, Duration duration) {
    final start = builder.draft.startAt;
    final end = builder.draft.endAt;
    if (start == null || end == null) return false;
    return (end.difference(start) - duration).abs() < const Duration(minutes: 2);
  }

  void _setDuration(EventBuilderProvider builder, Duration duration) {
    final start = builder.draft.startAt ?? DateTime.now();
    builder.update(
      builder.draft.copyWith(startAt: start, endAt: start.add(duration)),
    );
  }

  Future<void> _pickStart(EventBuilderProvider builder) async {
    final now = DateTime.now();
    final picked = await _pickDateTime(
      initial: builder.draft.startAt ?? now,
      first: now,
      last: now.add(EventLifecycle.maxDuration),
    );
    if (picked == null || !mounted) return;
    builder.update(builder.draft.copyWith(startAt: picked));
  }

  Future<void> _pickEnd(EventBuilderProvider builder) async {
    final start = builder.draft.startAt ?? DateTime.now();
    final picked = await _pickDateTime(
      initial: builder.draft.endAt ?? start.add(const Duration(hours: 24)),
      first: start.add(EventLifecycle.minDuration),
      last: start.add(EventLifecycle.maxDuration),
    );
    if (picked == null || !mounted) return;
    builder.update(builder.draft.copyWith(endAt: picked));
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initial,
    required DateTime first,
    required DateTime last,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: last,
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return DateTime(date.year, date.month, date.day);
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  // ------------------------------------------------------------------ utils --

  String _format(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }

  String _failureText(AppStrings copy, Failure? failure) {
    if (failure == null) return '';
    if (failure is ValidationError) {
      return copy.eventValidationMessage(failure.message);
    }
    return failure.message;
  }

  void _showMessage(String message) {
    if (message.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

// ---------------------------------------------------------------- widgets --

class _ScopeCard extends StatelessWidget {
  const _ScopeCard({
    required this.icon,
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: selected ? theme.colorScheme.primary : null),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(hint, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
        color: selected
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: selected ? theme.colorScheme.primary : null),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(hint, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return PubgetSelectionChip(
      label: label,
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _PollOptionForm {
  _PollOptionForm({String label = '', this.imageUrl = ''})
      : label = TextEditingController(text: label);

  final TextEditingController label;
  String imageUrl;
  bool uploading = false;
  String? error;

  void dispose() => label.dispose();
}
