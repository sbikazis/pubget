import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/widgets/pubget_bottom_sheet.dart';
import '../../kirari/data/kirari_repository.dart';

/// A licensed track chosen in [AudioPickerSheet].
///
/// The composer stores [audioId] on the Edit and renders [displayName] in the
/// form. The previous picker exposed a `ReelAudio` Firestore model from an
/// audio domain that was deleted while the Kirari pipeline took over; keeping
/// this small value object means the composer no longer depends on a backend
/// shape that no longer exists, and no fake track list has to be invented.
final class PickedAudio {
  const PickedAudio({
    required this.audioId,
    required this.name,
    required this.displayName,
  });

  final String audioId;
  final String name;
  final String displayName;
}

/// Bottom sheet that lists the server's licensed audio library.
///
/// Data comes from `KirariRepository.getAudioLibrary()` (the
/// `getKirariAudioLibrary` callable). Loading, failure and empty are all real
/// states: when Firebase is degraded the sheet says the library could not be
/// loaded instead of silently offering a dead list.
class AudioPickerSheet extends StatefulWidget {
  const AudioPickerSheet({super.key});

  static Future<PickedAudio?> show(BuildContext context) {
    return PubgetBottomSheet.present<PickedAudio>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AudioPickerSheet(),
    );
  }

  @override
  State<AudioPickerSheet> createState() => _AudioPickerSheetState();
}

class _AudioPickerSheetState extends State<AudioPickerSheet> {
  Future<List<KirariAudioTrack>>? _tracks;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolve once. A rebuild while the sheet is open must not re-query the
    // callable or restart the loading state.
    _tracks ??= context.read<KirariRepository>().getAudioLibrary();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return SafeArea(
      child: SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                strings.pick('Pick audio', 'اختيار صوت'),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: FutureBuilder<List<KirariAudioTrack>>(
                future: _tracks,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          strings.pick(
                            'Could not load the audio library. Please retry.',
                            'تعذر تحميل مكتبة الأصوات. أعد المحاولة.',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final tracks = snapshot.data ?? const <KirariAudioTrack>[];
                  if (tracks.isEmpty) {
                    return Center(
                      child: Text(
                        strings.pick(
                          'No audio is available yet.',
                          'لا توجد أصوات متاحة حاليًا.',
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: tracks.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final track = tracks[index];
                      if (track.id.isEmpty) return const SizedBox.shrink();
                      final artist = track.artist.trim();
                      return ListTile(
                        leading: const Icon(Icons.audiotrack_outlined),
                        title: Text(track.title),
                        subtitle: artist.isEmpty ? null : Text(artist),
                        onTap: () => Navigator.of(context).pop(
                          PickedAudio(
                            audioId: track.id,
                            name: track.title,
                            displayName: artist.isEmpty
                                ? track.title
                                : '${track.title} — $artist',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
