import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../models/event_lifecycle.dart';
import '../models/event_models.dart';
import '../models/event_type_registry.dart';
import '../providers/event_providers.dart';
import '../widgets/event_widgets.dart';

class EventBuilderPage extends StatefulWidget {
  const EventBuilderPage({this.groupId, this.templateId, super.key});

  final String? groupId;
  final String? templateId;

  @override
  State<EventBuilderPage> createState() => _EventBuilderPageState();
}

class _EventBuilderPageState extends State<EventBuilderPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _question = TextEditingController();
  final _completionRule = TextEditingController();
  final _targetEventId = TextEditingController();
  String _challengeKind = 'finish_game';
  final List<TextEditingController> _options = <TextEditingController>[
    TextEditingController(text: 'Option A'),
    TextEditingController(text: 'Option B'),
  ];
  final List<_ImageCandidateForm> _images = <_ImageCandidateForm>[
    _ImageCandidateForm(),
    _ImageCandidateForm(),
  ];
  final List<_QuizQuestionForm> _quizQuestions = <_QuizQuestionForm>[
    _QuizQuestionForm(id: 'q-1'),
  ];
  int _quizSeq = 1;
  int _step = 0;
  bool _started = false;
  bool _allowMultiple = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final builder = context.read<EventBuilderProvider>();
    final uid = context.read<AuthProvider>().currentUser?.id;
    Future<void>.microtask(() async {
      builder.start(groupId: widget.groupId, templateId: widget.templateId);
      if (!mounted) return;
      if (uid != null && widget.templateId == null) {
        await builder.restoreDraft(userId: uid, groupId: widget.groupId);
        if (!mounted) return;
        _hydrate(builder.draft);
      }
    });
  }

  void _hydrate(EventDraft draft) {
    _title.text = draft.title;
    _description.text = draft.description;
    _question.text = draft.configuration.question.isNotEmpty
        ? draft.configuration.question
        : draft.configuration.prompt;
    _completionRule.text = draft.configuration.completionRule;
    _challengeKind = draft.configuration.challengeKind.isEmpty
        ? 'finish_game'
        : draft.configuration.challengeKind;
    _targetEventId.text = draft.configuration.targetEventId;
    if (draft.configuration.criterion.isNotEmpty) {
      _question.text = draft.configuration.criterion;
    }
    _allowMultiple = draft.configuration.allowMultiple;
    if (draft.configuration.options.isNotEmpty) {
      for (final controller in _options) {
        controller.dispose();
      }
      _options
        ..clear()
        ..addAll(
          draft.configuration.options.map(
            (option) => TextEditingController(text: option.label),
          ),
        );
    }
    if (draft.configuration.questions.isNotEmpty) {
      for (final form in _quizQuestions) {
        form.dispose();
      }
      _quizQuestions
        ..clear()
        ..addAll(
          draft.configuration.questions.map(_QuizQuestionForm.fromQuestion),
        );
      _quizSeq = _quizQuestions.length;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _question.dispose();
    _completionRule.dispose();
    _targetEventId.dispose();
    for (final controller in _options) {
      controller.dispose();
    }
    for (final form in _images) {
      form.dispose();
    }
    for (final form in _quizQuestions) {
      form.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final builder = context.watch<EventBuilderProvider>();
    final spec = EventTypeRegistry.of(builder.draft.type);
    return Scaffold(
      appBar: AppBar(title: const Text(EventStrings.create)),
      body: Stepper(
        currentStep: _step,
        onStepTapped: (value) => setState(() => _step = value),
        onStepContinue: _step == 4 ? () => _publish(builder) : _next,
        onStepCancel: _step == 0
            ? () => builder.abandon()
            : () => setState(() => _step--),
        controlsBuilder: (context, details) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.lg),
          child: Row(
            children: <Widget>[
              PubgetPrimaryButton(
                onPressed: details.onStepContinue,
                semanticLabel: _step == 4 ? EventStrings.publish : 'Continue',
                loading: builder.saving,
                child: Text(_step == 4 ? EventStrings.publish : 'Continue'),
              ),
              const SizedBox(width: AppSpacing.sm),
              PubgetTextButton(
                onPressed: details.onStepCancel,
                semanticLabel: 'Back',
                child: Text(_step == 0 ? 'Discard draft' : 'Back'),
              ),
            ],
          ),
        ),
        steps: <Step>[
          Step(
            title: const Text('Type'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DropdownButtonFormField<EventType>(
                  key: ValueKey<EventType>(builder.draft.type),
                  value: builder.draft.type,
                  decoration: const InputDecoration(labelText: 'Event type'),
                  items: EventType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(EventTypeRegistry.of(type).label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value == null) return;
                    builder.update(
                      builder.draft.copyWith(type: value, clearTemplate: true),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: EventTypeRegistry.templates.entries
                      .map(
                        (entry) => PubgetSelectionChip(
                          label:
                              EventTypeRegistry.templateLabels[entry.key] ??
                              entry.key,
                          selected: builder.draft.templateId == entry.key,
                          onSelected: (_) => builder.update(
                            builder.draft.copyWith(
                              templateId: entry.key,
                              type: entry.value,
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Basics'),
            content: Column(
              children: <Widget>[
                PubgetTextField(controller: _title, label: 'Title'),
                const SizedBox(height: AppSpacing.sm),
                PubgetTextArea(controller: _description, label: 'Description'),
              ],
            ),
          ),
          Step(
            title: const Text('Configure'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(spec.hint),
                const SizedBox(height: AppSpacing.sm),
                if (spec.usesOptions || spec.usesTextResponse)
                  PubgetTextField(
                    controller: _question,
                    label: spec.type == EventType.characterComparison ||
                            spec.type == EventType.animeComparison ||
                            spec.type == EventType.imageComparison
                        ? 'Criterion'
                        : (spec.usesTextResponse ? 'Prompt' : 'Question'),
                  ),
                if (spec.usesOptions && spec.type != EventType.imageComparison) ...[
                  const SizedBox(height: AppSpacing.sm),
                  for (var i = 0; i < _options.length; i++) ...[
                    PubgetTextField(
                      controller: _options[i],
                      label: spec.type == EventType.characterComparison
                          ? 'Character ID ${i + 1}'
                          : spec.type == EventType.animeComparison
                          ? 'Anime ID ${i + 1}'
                          : spec.type == EventType.versus
                          ? 'Candidate ${i + 1}'
                          : 'Option ${i + 1}',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (_options.length < 10)
                    PubgetTextButton(
                      onPressed: () =>
                          setState(() => _options.add(TextEditingController())),
                      semanticLabel: 'Add option',
                      child: const Text('Add option'),
                    ),
                  if (spec.type == EventType.poll ||
                      spec.type == EventType.multipleChoice)
                    SwitchListTile(
                      title: const Text('Allow multiple selections'),
                      value: _allowMultiple,
                      onChanged: (value) =>
                          setState(() => _allowMultiple = value),
                    ),
                ],
                if (spec.type == EventType.imageComparison) ...[
                  const SizedBox(height: AppSpacing.sm),
                  for (var i = 0; i < _images.length; i++) ...[
                    Text('Image ${i + 1}', style: Theme.of(context).textTheme.titleSmall),
                    PubgetTextField(
                      controller: _images[i].url,
                      label: 'HTTPS image URL',
                    ),
                    PubgetTextField(
                      controller: _images[i].mimeType,
                      label: 'MIME type (image/jpeg)',
                    ),
                    PubgetTextField(
                      controller: _images[i].license,
                      label: 'License',
                    ),
                    PubgetTextField(
                      controller: _images[i].attribution,
                      label: 'Attribution',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (_images.length < 10)
                    PubgetTextButton(
                      onPressed: () =>
                          setState(() => _images.add(_ImageCandidateForm())),
                      semanticLabel: 'Add image candidate',
                      child: const Text('Add image candidate'),
                    ),
                ],
                if (spec.usesTextResponse && spec.type == EventType.challenge) ...[
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    value: _challengeKind,
                    decoration: const InputDecoration(labelText: 'Challenge type'),
                    items: const [
                      DropdownMenuItem(
                        value: 'finish_game',
                        child: Text('Finish a game'),
                      ),
                      DropdownMenuItem(
                        value: 'publish_edit',
                        child: Text('Publish an edit'),
                      ),
                      DropdownMenuItem(
                        value: 'create_group',
                        child: Text('Create a group'),
                      ),
                      DropdownMenuItem(
                        value: 'participate_event',
                        child: Text('Participate in another event'),
                      ),
                      DropdownMenuItem(
                        value: 'self_report',
                        child: Text('Self-reported (not server-verified)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _challengeKind = value);
                    },
                  ),
                  if (_challengeKind == 'participate_event')
                    PubgetTextField(
                      controller: _targetEventId,
                      label: 'Target event ID',
                    ),
                  PubgetTextField(
                    controller: _completionRule,
                    label: 'Display rule (not used as authority)',
                  ),
                ],
                if (spec.usesQuiz) _quizEditor(),
              ],
            ),
          ),
          Step(
            title: const Text('Duration'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    _DurationChip(
                      label: '1 hour',
                      selected: _isDuration(builder, const Duration(hours: 1)),
                      onSelected: () =>
                          _setDuration(builder, const Duration(hours: 1)),
                    ),
                    _DurationChip(
                      label: '24 hours',
                      selected: _isDuration(builder, const Duration(hours: 24)),
                      onSelected: () =>
                          _setDuration(builder, const Duration(hours: 24)),
                    ),
                    _DurationChip(
                      label: '3 days',
                      selected: _isDuration(builder, const Duration(days: 3)),
                      onSelected: () =>
                          _setDuration(builder, const Duration(days: 3)),
                    ),
                    _DurationChip(
                      label: '7 days',
                      selected: _isDuration(builder, const Duration(days: 7)),
                      onSelected: () =>
                          _setDuration(builder, const Duration(days: 7)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                PubgetSecondaryButton(
                  onPressed: () => _pickStart(context, builder),
                  semanticLabel: 'Choose start time',
                  child: Text(
                    builder.draft.startAt == null
                        ? 'Start now'
                        : builder.draft.startAt!.toLocal().toString(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                PubgetSecondaryButton(
                  onPressed: () => _pickEnd(context, builder),
                  semanticLabel: 'Choose end time',
                  child: Text(
                    builder.draft.endAt == null
                        ? 'Lasts 24 hours (max 7 days)'
                        : builder.draft.endAt!.toLocal().toString(),
                  ),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Review'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(spec.label),
                Text(_title.text),
                Text(_description.text),
                if (spec.usesQuiz)
                  Text('${_quizQuestions.length} quiz question(s)'),
                if (builder.draft.startAt != null &&
                    builder.draft.endAt != null)
                  Text(
                    EventLifecycle.validateWindow(
                          builder.draft.startAt!,
                          builder.draft.endAt!,
                        ) ??
                        'Duration is valid.',
                  ),
                const SizedBox(height: AppSpacing.md),
                PubgetSecondaryButton(
                  onPressed: builder.saving ? null : () => _saveDraft(builder),
                  semanticLabel: EventStrings.saveDraft,
                  child: const Text(EventStrings.saveDraft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quizEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < _quizQuestions.length; i++) ...[
          _QuizQuestionCard(
            index: i,
            form: _quizQuestions[i],
            canRemove: _quizQuestions.length > 1,
            canMoveUp: i > 0,
            canMoveDown: i < _quizQuestions.length - 1,
            onChanged: () => setState(() {}),
            onRemove: () => setState(() {
              _quizQuestions.removeAt(i).dispose();
            }),
            onMoveUp: () => setState(() {
              final form = _quizQuestions.removeAt(i);
              _quizQuestions.insert(i - 1, form);
            }),
            onMoveDown: () => setState(() {
              final form = _quizQuestions.removeAt(i);
              _quizQuestions.insert(i + 1, form);
            }),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        if (_quizQuestions.length < 20)
          PubgetTextButton(
            onPressed: () => setState(() {
              _quizSeq += 1;
              _quizQuestions.add(_QuizQuestionForm(id: 'q-$_quizSeq'));
            }),
            semanticLabel: EventStrings.addQuestion,
            child: const Text(EventStrings.addQuestion),
          ),
      ],
    );
  }

  Future<void> _saveDraft(EventBuilderProvider builder) async {
    _syncDraft(builder);
    final result = await builder.saveDraft();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? 'Draft saved'
              : (result.failureOrNull?.message ?? 'Could not save draft.'),
        ),
      ),
    );
  }

  bool _isDuration(EventBuilderProvider builder, Duration duration) {
    final start = builder.draft.startAt;
    final end = builder.draft.endAt;
    if (start == null || end == null) return false;
    return (end.difference(start) - duration).abs() <
        const Duration(minutes: 2);
  }

  void _setDuration(EventBuilderProvider builder, Duration duration) {
    final start = builder.draft.startAt ?? DateTime.now();
    builder.update(
      builder.draft.copyWith(startAt: start, endAt: start.add(duration)),
    );
  }

  void _next() {
    _syncDraft(context.read<EventBuilderProvider>());
    setState(() => _step += 1);
  }

  void _syncDraft(EventBuilderProvider builder) {
    final spec = EventTypeRegistry.of(builder.draft.type);
    var configuration = builder.draft.configuration;
    if (spec.type == EventType.imageComparison) {
      configuration = EventConfiguration(
        question: _question.text,
        criterion: _question.text,
        options: [
          for (var i = 0; i < _images.length; i++)
            EventOption(
              id: 'img-${i + 1}',
              label: 'Image ${i + 1}',
              imageUrl: _images[i].url.text.trim(),
              mimeType: _images[i].mimeType.text.trim(),
              license: _images[i].license.text.trim(),
              attribution: _images[i].attribution.text.trim(),
            ),
        ],
      );
    } else if (spec.type == EventType.characterComparison ||
        spec.type == EventType.animeComparison) {
      configuration = EventConfiguration(
        question: _question.text,
        criterion: _question.text,
        options: [
          for (var i = 0; i < _options.length; i++)
            EventOption(
              id: _options[i].text.trim().isEmpty ? 'opt-${i + 1}' : _options[i].text.trim(),
              label: _options[i].text.trim(),
              characterId: spec.type == EventType.characterComparison
                  ? _options[i].text.trim()
                  : '',
              animeId: spec.type == EventType.animeComparison
                  ? _options[i].text.trim()
                  : '',
            ),
        ],
      );
    } else if (spec.usesOptions) {
      configuration = EventConfiguration(
        question: _question.text,
        allowMultiple: _allowMultiple,
        maxSelections: _allowMultiple ? _options.length : 1,
        options: [
          for (var i = 0; i < _options.length; i++)
            EventOption(id: 'opt-${i + 1}', label: _options[i].text),
        ],
      );
    } else if (spec.usesTextResponse) {
      configuration = EventConfiguration(
        prompt: _question.text,
        completionRule: _completionRule.text,
        challengeKind: spec.type == EventType.challenge ? _challengeKind : '',
        targetEventId: _targetEventId.text.trim(),
      );
    } else if (spec.usesQuiz) {
      configuration = EventConfiguration(
        questions: [
          for (var i = 0; i < _quizQuestions.length; i++)
            _quizQuestions[i].toQuestion(index: i),
        ],
      );
    }
    builder.update(
      builder.draft.copyWith(
        groupId: widget.groupId,
        title: _title.text,
        description: _description.text,
        configuration: configuration,
        startAt: builder.draft.startAt ?? DateTime.now(),
        endAt:
            builder.draft.endAt ??
            DateTime.now().add(const Duration(hours: 24)),
      ),
    );
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context, {
    required DateTime initial,
    required DateTime first,
    required DateTime last,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return DateTime(date.year, date.month, date.day);
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickStart(
    BuildContext context,
    EventBuilderProvider builder,
  ) async {
    final now = DateTime.now();
    final picked = await _pickDateTime(
      context,
      initial: builder.draft.startAt ?? now,
      first: now,
      last: now.add(EventLifecycle.maxDuration),
    );
    if (picked == null) return;
    builder.update(builder.draft.copyWith(startAt: picked));
  }

  Future<void> _pickEnd(
    BuildContext context,
    EventBuilderProvider builder,
  ) async {
    final start = builder.draft.startAt ?? DateTime.now();
    final picked = await _pickDateTime(
      context,
      initial: builder.draft.endAt ?? start.add(const Duration(hours: 24)),
      first: start.add(const Duration(minutes: 1)),
      last: start.add(EventLifecycle.maxDuration),
    );
    if (picked == null) return;
    builder.update(builder.draft.copyWith(endAt: picked));
  }

  Future<void> _publish(EventBuilderProvider builder) async {
    _syncDraft(builder);
    final result = await builder.publish();
    if (!mounted) return;
    final event = result.valueOrNull;
    if (event != null) {
      EventLinks.open(context, event.id);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.failureOrNull?.message ?? 'Could not publish.'),
      ),
    );
  }
}

class _QuizQuestionForm {
  _QuizQuestionForm({
    required this.id,
    String prompt = '',
    List<String>? optionLabels,
    this.correctOptionId = 'opt-1',
  }) : prompt = TextEditingController(text: prompt),
       options = [
         for (var i = 0; i < (optionLabels?.length ?? 2); i++)
           TextEditingController(
             text: optionLabels?[i] ?? (i == 0 ? 'A' : 'B'),
           ),
       ];

  factory _QuizQuestionForm.fromQuestion(EventQuizQuestion question) {
    return _QuizQuestionForm(
      id: question.id,
      prompt: question.prompt,
      optionLabels: question.options.map((option) => option.label).toList(),
      correctOptionId: question.correctOptionId,
    );
  }

  final String id;
  final TextEditingController prompt;
  final List<TextEditingController> options;
  String correctOptionId;

  EventQuizQuestion toQuestion({required int index}) {
    final resolvedOptions = [
      for (var i = 0; i < options.length; i++)
        EventOption(id: 'opt-${i + 1}', label: options[i].text),
    ];
    final correct = resolvedOptions.any((option) => option.id == correctOptionId)
        ? correctOptionId
        : (resolvedOptions.isEmpty ? '' : resolvedOptions.first.id);
    return EventQuizQuestion(
      id: id.isEmpty ? 'q-${index + 1}' : id,
      prompt: prompt.text,
      options: resolvedOptions,
      correctOptionId: correct,
    );
  }

  void dispose() {
    prompt.dispose();
    for (final controller in options) {
      controller.dispose();
    }
  }
}

class _QuizQuestionCard extends StatelessWidget {
  const _QuizQuestionCard({
    required this.index,
    required this.form,
    required this.canRemove,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onChanged,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final int index;
  final _QuizQuestionForm form;
  final bool canRemove;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return PubgetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Question ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Move up',
                onPressed: canMoveUp ? onMoveUp : null,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Move down',
                onPressed: canMoveDown ? onMoveDown : null,
                icon: const Icon(Icons.arrow_downward),
              ),
              IconButton(
                tooltip: EventStrings.removeQuestion,
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          PubgetTextField(controller: form.prompt, label: 'Question'),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < form.options.length; i++) ...[
            PubgetTextField(
              controller: form.options[i],
              label: 'Answer ${i + 1}',
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          DropdownButtonFormField<String>(
            key: ValueKey<String>('${form.id}-${form.correctOptionId}'),
            value: form.options.asMap().keys
                    .map((i) => 'opt-${i + 1}')
                    .contains(form.correctOptionId)
                ? form.correctOptionId
                : 'opt-1',
            decoration: const InputDecoration(
              labelText: EventStrings.correctAnswer,
            ),
            items: [
              for (var i = 0; i < form.options.length; i++)
                DropdownMenuItem(
                  value: 'opt-${i + 1}',
                  child: Text(
                    form.options[i].text.trim().isEmpty
                        ? 'Answer ${i + 1}'
                        : form.options[i].text,
                  ),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              form.correctOptionId = value;
              onChanged();
            },
          ),
          Row(
            children: <Widget>[
              if (form.options.length < 6)
                PubgetTextButton(
                  onPressed: () {
                    form.options.add(TextEditingController());
                    onChanged();
                  },
                  semanticLabel: EventStrings.addAnswer,
                  child: const Text(EventStrings.addAnswer),
                ),
              if (form.options.length > 2)
                PubgetTextButton(
                  onPressed: () {
                    form.options.removeLast().dispose();
                    if (!form.options.asMap().keys
                        .map((i) => 'opt-${i + 1}')
                        .contains(form.correctOptionId)) {
                      form.correctOptionId = 'opt-1';
                    }
                    onChanged();
                  },
                  semanticLabel: 'Remove answer',
                  child: const Text('Remove answer'),
                ),
            ],
          ),
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

class _ImageCandidateForm {
  _ImageCandidateForm()
    : url = TextEditingController(),
      mimeType = TextEditingController(text: 'image/jpeg'),
      license = TextEditingController(),
      attribution = TextEditingController();

  final TextEditingController url;
  final TextEditingController mimeType;
  final TextEditingController license;
  final TextEditingController attribution;

  void dispose() {
    url.dispose();
    mimeType.dispose();
    license.dispose();
    attribution.dispose();
  }
}
