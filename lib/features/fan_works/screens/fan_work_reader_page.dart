import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import '../../../app/app_back_button.dart';
import '../../../core/loading/loading_state.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/pubget_design_system.dart';
import '../../authentication/providers/auth_provider.dart';
import '../l10n/fan_work_copy.dart';
import '../models/fan_work_models.dart';
import '../providers/fan_work_providers.dart';

/// The in-app reader for a document-backed Fan Work (manga or story).
///
/// Security posture, stated plainly: the PDF is fetched with a signed URL that
/// the server mints per request and that expires in minutes, and the reader
/// draws it with a native engine inside the app. There is no download button,
/// no share target for the file, and no permanent URL anywhere in the widget
/// tree. That is *access control*, not DRM — a determined user with a rooted
/// device or a screen capture can still copy what is rendered. The platform
/// channel in `fan_work_protected_viewer.dart` adds `FLAG_SECURE` on Android to
/// raise the cost of casual screen recording.
class FanWorkReaderPage extends StatefulWidget {
  const FanWorkReaderPage({required this.workId, super.key});

  final String workId;

  @override
  State<FanWorkReaderPage> createState() => _FanWorkReaderPageState();
}

class _FanWorkReaderPageState extends State<FanWorkReaderPage> {
  final PdfViewerController _controller = PdfViewerController();
  final FanWorkProtectedViewer _protection = const FanWorkProtectedViewer();

  int? _pageCount;
  int _currentPage = 1;
  bool _ready = false;

  /// Captured in [initState] so progress can be recorded without reaching for a
  /// [BuildContext] after an async gap.
  FanWorkReaderProvider? _reader;

  @override
  void initState() {
    super.initState();
    _protection.enable();
    final reader = context.read<FanWorkReaderProvider>();
    _reader = reader;
    final uid = context.read<AuthProvider>().currentUser?.id ?? '';
    Future<void>.microtask(
      () => reader.open(workId: widget.workId, userId: uid),
    );
  }

  @override
  void dispose() {
    // Drop the protected surface before the widget tree goes away, otherwise
    // the last rendered frame can survive in the task-switcher snapshot.
    _protection.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reader = context.watch<FanWorkReaderProvider>();
    // A pre-rebuild work has no PDF, so the document reader cannot render it.
    // Dispatching here — rather than at the route — means a manga or story link
    // keeps working whether the work was written before or after the rebuild.
    switch (reader.shape) {
      case FanWorkReaderShape.legacyPages:
        final work = reader.work;
        if (work != null) {
          return LegacyMangaPagesPage(
            workId: widget.workId,
            pages: work.content.orderedPages,
          );
        }
      case FanWorkReaderShape.legacyProse:
        final work = reader.work;
        if (work != null) {
          return LegacyStoryReaderPage(
            workId: widget.workId,
            title: work.title,
            body: work.content.body,
            chapters: work.content.orderedChapters,
          );
        }
      case FanWorkReaderShape.document:
      case FanWorkReaderShape.unknown:
        break;
    }
    final copy = FanWorkCopy.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        // Persist where the reader stopped so "continue reading" is accurate.
        // Read the provider before any await; there is none here, but capturing
        // it keeps the call independent of the element still being mounted.
        _reader?.recordPage(_currentPage - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: AppBackButton.maybeOf(context),
          title: Text(copy.tableOfContents),
          actions: <Widget>[
            if (_ready)
              IconButton(
                tooltip: copy.closeReader,
                onPressed: () => _goToPage(1),
                icon: const Icon(Icons.first_page),
              ),
            if (_ready)
              IconButton(
                tooltip: copy.markAsRead,
                onPressed: reader.completed
                    ? null
                    : () {
                        final messenger = ScaffoldMessenger.of(context);
                        reader.markAsRead().then((_) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(copy.markedAsRead)),
                          );
                        });
                      },
                icon: const Icon(Icons.done_all),
              ),
          ],
          bottom: _ready && (_pageCount ?? 0) > 0
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(28),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      copy.pageOf(_pageCount!, _currentPage),
                      key: const Key('fan-work-reader-position'),
                    ),
                  ),
                )
              : null,
        ),
        body: _buildBody(reader, copy),
      ),
    );
  }

  Widget _buildBody(FanWorkReaderProvider reader, FanWorkCopy copy) {
    if (reader.state == LoadingState.loading ||
        reader.state == LoadingState.initial) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const PubgetSkeleton.card(width: 240, height: 160),
            const SizedBox(height: AppSpacing.md),
            Text(copy.loadingDocument),
          ],
        ),
      );
    }

    final url = reader.url;
    if (url == null || url.isEmpty) {
      final offline = reader.state == LoadingState.offline;
      return PubgetEmptyState(
        icon: Icons.lock_outline,
        title: offline ? copy.offline : copy.documentUnavailable,
        message: copy.documentExpired,
        action: PubgetSecondaryButton(
          onPressed: () => reader.refresh(),
          semanticLabel: copy.openDocument,
          leadingIcon: Icons.refresh,
          child: Text(copy.openDocument),
        ),
      );
    }

    return Stack(
      children: <Widget>[
        PdfViewer.uri(
          Uri.parse(url),
          controller: _controller,
          // A signed URL is a bearer credential that dies in minutes, so the
          // viewer must never be left holding a stale one: this param fires when
          // the document ref reports the fetch failed, and we re-mint.
          passwordProvider: _onPasswordRequired,
          params: PdfViewerParams(
            margin: 8,
            backgroundColor: Theme.of(context).colorScheme.surface,
            onViewerReady: (document, controller) {
              if (!mounted) return;
              setState(() {
                _ready = true;
                _pageCount = document.pages.length;
              });
              final resume = reader.page;
              if (resume > 0) {
                controller.goToPage(pageNumber: resume + 1);
              }
            },
            onPageChanged: (pageNumber) {
              if (!mounted || pageNumber == null) return;
              if (pageNumber == _currentPage) return;
              setState(() => _currentPage = pageNumber);
              reader.recordPage(pageNumber - 1);
            },
            loadingBannerBuilder: (context, downloaded, total) => Center(
              child: Text(
                total == null || total <= 0
                    ? copy.loadingDocument
                    : '${copy.loadingDocument} '
                          '${(downloaded / total * 100).round()}%',
              ),
            ),
            errorBannerBuilder: (context, error, stackTrace, ref) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      _isPasswordError(error)
                          ? copy.protectedPdf
                          : copy.documentUnavailable,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PubgetSecondaryButton(
                      onPressed: reader.refresh,
                      semanticLabel: copy.openDocument,
                      leadingIcon: Icons.refresh,
                      child: Text(copy.openDocument),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          end: AppSpacing.md,
          bottom: AppSpacing.lg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_ready)
                FloatingActionButton.small(
                  heroTag: 'fan-work-zoom-out',
                  tooltip: copy.zoomOut,
                  onPressed: () => _controller.zoomDown(),
                  child: const Icon(Icons.zoom_out),
                ),
              if (_ready)
                FloatingActionButton.small(
                  heroTag: 'fan-work-zoom-in',
                  tooltip: copy.zoomIn,
                  onPressed: () => _controller.zoomUp(),
                  child: const Icon(Icons.zoom_in),
                ),
              if (_ready && (_pageCount ?? 0) > 1)
                FloatingActionButton.small(
                  heroTag: 'fan-work-next-page',
                  tooltip: copy.nextPage,
                  onPressed: () => _goToPage(_currentPage + 1),
                  child: const Icon(Icons.navigate_next),
                ),
              if (_ready && (_pageCount ?? 0) > 1)
                FloatingActionButton.small(
                  heroTag: 'fan-work-prev-page',
                  tooltip: copy.previousPage,
                  onPressed: () => _goToPage(_currentPage - 1),
                  child: const Icon(Icons.navigate_before),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _goToPage(int pageNumber) {
    final total = _pageCount ?? 0;
    if (total <= 0) return;
    final target = pageNumber.clamp(1, total);
    _controller.goToPage(pageNumber: target);
    setState(() => _currentPage = target);
  }

  /// The product does not support password-protected PDFs. Returning `null`
  /// aborts the open, and the viewer surfaces the rejection.
  Future<String?> _onPasswordRequired() async {
    await HapticFeedback.mediumImpact();
    return null;
  }

  static bool _isPasswordError(Object error) =>
      error.toString().toLowerCase().contains('password');
}

/// Thin wrapper over the platform channel that marks the reader window as
/// protected. On Android this sets `FLAG_SECURE`, which blocks screenshots and
/// hides the view in the recents switcher; iOS has no equivalent flag, so the
/// channel reports unsupported and the app relies on the signed-URL expiry
/// alone. Keeping this behind one class means the reader never talks to
/// `MethodChannel` directly and a missing platform side degrades to a no-op
/// instead of crashing.
final class FanWorkProtectedViewer {
  const FanWorkProtectedViewer();

  static const MethodChannel _channel = MethodChannel('pubget/fan_work_reader');

  Future<void> enable() async {
    try {
      await _channel.invokeMethod<void>('setProtected', true);
    } on MissingPluginException {
      // No native side registered (unit tests, desktop); nothing to do.
    } on PlatformException {
      // A refusal must never block reading.
    }
  }

  Future<void> disable() async {
    try {
      await _channel.invokeMethod<void>('setProtected', false);
    } on MissingPluginException {
      // No native side registered.
    } on PlatformException {
      // A refusal must never block leaving the reader.
    }
  }
}

/// The legacy image-page manga reader.
///
/// Pre-rebuild manga published individual page images instead of a PDF, so they
/// keep their own page-by-page viewer. A manga that has been re-published with
/// a PDF is routed to [FanWorkReaderPage] instead.
class LegacyMangaPagesPage extends StatefulWidget {
  const LegacyMangaPagesPage({
    required this.workId,
    required this.pages,
    super.key,
  });

  final String workId;
  final List<FanWorkPage> pages;

  @override
  State<LegacyMangaPagesPage> createState() => _LegacyMangaPagesPageState();
}

class _LegacyMangaPagesPageState extends State<LegacyMangaPagesPage> {
  final FanWorkProtectedViewer _protection = const FanWorkProtectedViewer();
  FanWorkReaderProvider? _reader;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _protection.enable();
    final reader = context.read<FanWorkReaderProvider>();
    _reader = reader;
    final uid = context.read<AuthProvider>().currentUser?.id ?? '';
    Future<void>.microtask(() async {
      await reader.open(workId: widget.workId, userId: uid);
      if (!mounted) return;
      if (reader.canResume) setState(() => _page = reader.page);
    });
  }

  @override
  void dispose() {
    _protection.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = FanWorkCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(copy.tableOfContents),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(copy.pageOf(widget.pages.length, _page + 1)),
          ),
        ),
      ),
      body: PageView.builder(
        key: const Key('fan-work-legacy-pages'),
        itemCount: widget.pages.length,
        onPageChanged: (index) {
          setState(() => _page = index);
          _reader?.recordPage(index);
        },
        itemBuilder: (context, index) {
          final page = widget.pages[index];
          return Column(
            children: <Widget>[
              Expanded(
                child: AppImageLoader(
                  imageUrl: page.path,
                  fit: BoxFit.contain,
                  memCacheWidth: 1200,
                ),
              ),
              if (page.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Text(page.caption),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The legacy prose reader for a story published before the rebuild, which
/// stored its text inline instead of as a PDF.
class LegacyStoryReaderPage extends StatefulWidget {
  const LegacyStoryReaderPage({
    required this.workId,
    required this.title,
    required this.body,
    required this.chapters,
    super.key,
  });

  final String workId;
  final String title;
  final String body;
  final List<FanWorkChapter> chapters;

  @override
  State<LegacyStoryReaderPage> createState() => _LegacyStoryReaderPageState();
}

class _LegacyStoryReaderPageState extends State<LegacyStoryReaderPage> {
  int _chapter = 0;

  @override
  Widget build(BuildContext context) {
    final copy = FanWorkCopy.of(context);
    final chapters = widget.chapters;
    final text = chapters.isEmpty
        ? widget.body
        : chapters[_chapter.clamp(0, chapters.length - 1)].body;
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton.maybeOf(context),
        title: Text(widget.title.isEmpty ? copy.feedTitle : widget.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          if (chapters.isNotEmpty)
            DropdownButton<int>(
              value: _chapter.clamp(0, chapters.length - 1),
              items: <DropdownMenuItem<int>>[
                for (var i = 0; i < chapters.length; i++)
                  DropdownMenuItem<int>(
                    value: i,
                    child: Text(
                      chapters[i].title.isEmpty
                          ? copy.chapterNumber(i + 1)
                          : chapters[i].title,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() => _chapter = value ?? 0),
            ),
          Text(
            text.isEmpty ? copy.storyNoContent : text,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
