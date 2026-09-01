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
  final _quizPrompt = TextEditingController();
  final List<TextEditingController> _options = <TextEditingController>[
    TextEditingController(text: 'Option A'),
    TextEditingController(text: 'Option B'),
  ];
  final _quizA = TextEditingController(text: 'A');
  final _quizB = TextEditingController(text: 'B');
  String _correctOptionId = 'opt-1';
  int _step = 0;
  bool _started = false;
  bool _allowMultiple = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final builder = context.read<EventBuilderProvider>();
    builder.start(groupId: widget.groupId, templateId: widget.templateId);
    final uid = context.read<AuthProvider>().currentUser?.id;
    if (uid != null && widget.templateId == null) {
      Future<void>.microtask(() async {
        await builder.restoreDraft(userId: uid, groupId: widget.groupId);
        if (!mounted) return;
        _hydrate(builder.draft);
      });
    }
  }

  void _hydrate(EventDraft draft) {
    _title.text = draft.title;
    _description.text = draft.description;
    _question.text = draft.configuration.question.isNotEmpty
        ? draft.configuration.question
        : draft.configuration.prompt;
    _completionRule.text = draft.configuration.completionRule;
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
      final question = draft.configuration.questions.first;
      _quizPrompt.text = question.prompt;
      if (question.options.length >= 2) {
        _quizA.text = question.options[0].label;
        _quizB.text = question.options[1].label;
        _correctOptionId = question.correctOptionId;
      }
    }
    setState(() {});
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _question.dispose();
    _completionRule.dispose();
    _quizPrompt.dispose();
    _quizA.dispose();
    _quizB.dispose();
    for (final controller in _options) {
      controller.dispose();
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
                    label: spec.usesTextResponse ? 'Prompt' : 'Question',
                  ),
                if (spec.usesOptions) ...[
                  const SizedBox(height: AppSpacing.sm),
                  for (var i = 0; i < _options.length; i++) ...[
                    PubgetTextField(
                      controller: _options[i],
                      label: spec.type == EventType.versus
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
                if (spec.usesTextResponse && spec.type == EventType.challenge)
                  PubgetTextField(
                    controller: _completionRule,
                    label: 'Completion rule',
                  ),
                if (spec.usesQuiz) ...[
                  PubgetTextField(controller: _quizPrompt, label: 'Question'),
                  const SizedBox(height: AppSpacing.sm),
                  PubgetTextField(controller: _quizA, label: 'Answer A'),
                  const SizedBox(height: AppSpacing.sm),
                  PubgetTextField(controller: _quizB, label: 'Answer B'),
                  DropdownButtonFormField<String>(
                    value: _correctOptionId,
                    decoration: const InputDecoration(
                      labelText: 'Correct answer',
                    ),
                    items: const <DropdownMenuItem<String>>[
                      DropdownMenuItem(value: 'opt-1', child: Text('A')),
                      DropdownMenuItem(value: 'opt-2', child: Text('B')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _correctOptionId = value);
                    },
                  ),
                ],
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
                if (builder.draft.startAt != null &&
                    builder.draft.endAt != null)
                  Text(
                    EventLifecycle.validateWindow(
                          builder.draft.startAt!,
                          builder.draft.endAt!,
                        ) ??
                        'Duration is valid.',
                  ),
              ],
            ),
          ),
        ],
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
    if (spec.usesOptions) {
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
      );
    } else if (spec.usesQuiz) {
      configuration = EventConfiguration(
        questions: <EventQuizQuestion>[
          EventQuizQuestion(
            id: 'q-1',
            prompt: _quizPrompt.text.isEmpty ? _title.text : _quizPrompt.text,
            options: <EventOption>[
              EventOption(id: 'opt-1', label: _quizA.text),
              EventOption(id: 'opt-2', label: _quizB.text),
            ],
            correctOptionId: _correctOptionId,
          ),
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
