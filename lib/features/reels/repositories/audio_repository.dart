import '../../../core/errors/result.dart' as result_lib;
import '../models/audio_models.dart';

abstract class AudioRepository {
  Future<result_lib.Result<String>> extractAudio({
    required String reelId,
    String? audioName,
    int startMs = 0,
    int durationMs = 15000,
  });

  Future<result_lib.Result<ReelAudioPage>> listAudios({
    int limit = 20,
    String? afterId,
    String type = 'trending',
  });

  Future<result_lib.Result<ReelAudio>> getAudio(String audioId);

  Future<result_lib.Result<void>> useAudio({
    required String audioId,
    required String reelId,
  });

  Future<result_lib.Result<void>> removeAudio(String reelId);

  Future<result_lib.Result<List<ReelAudio>>> searchAudios({
    required String query,
    int limit = 15,
  });
}
