import '../../../core/constants/limits.dart';
import '../../../core/errors/failure.dart';

final class EditValidation {
  const EditValidation._();

  static const allowedTypes = <String>{'video/mp4'};

  static Failure? reject({
    required String fileName,
    required String contentType,
    required int sizeBytes,
    Duration? duration,
    int minDurationSeconds = Limits.editMinDurationSeconds,
    int maxDurationSeconds = Limits.editMaxDurationSeconds,
  }) {
    final type = contentType.trim().toLowerCase();
    final name = fileName.trim().toLowerCase();
    final looksMp4 = name.endsWith('.mp4');
    if (!looksMp4 && !allowedTypes.contains(type)) {
      return const ValidationError(
        'Choose an MP4 video. Other formats are not supported.',
      );
    }
    if (sizeBytes <= 0) {
      return const ValidationError('This video file could not be read.');
    }
    if (sizeBytes > Limits.editMaxBytes) {
      return const ValidationError(
        'This video is too large. Choose a file under 100 MB.',
      );
    }
    if (duration != null) {
      // §15.2 is 3–60s. The lower bound used to be missing here as well as on
      // the server, so a 1-second clip was accepted everywhere.
      final seconds = duration.inSeconds;
      if (seconds < minDurationSeconds) {
        return ValidationError(
          'Reels must be at least $minDurationSeconds seconds long.',
        );
      }
      if (seconds > maxDurationSeconds) {
        return const ValidationError(
          'Reels can be up to 60 seconds long.',
        );
      }
    }
    return null;
  }

  static Failure? rejectCaption(String caption) {
    if (caption.trim().length > Limits.editCaptionMax) {
      return const ValidationError('Caption is too long.');
    }
    return null;
  }

  static List<String> mentionsIn(String text) {
    return RegExp(r'@([A-Za-z0-9_]{2,32})')
        .allMatches(text)
        .map((match) => match.group(1)!)
        .toSet()
        .take(Limits.editMentionMax)
        .toList(growable: false);
  }
}
