import '../../edits/repositories/firebase_edits_repository.dart';
import '../../edits/repositories/edits_repository.dart';

abstract interface class ReelsRepository implements EditsRepository {}

final class FirebaseReelsRepository extends FirebaseEditsRepository
    implements ReelsRepository {
  FirebaseReelsRepository({
    super.firestore,
    super.storage,
    super.functions,
  }) : super(reels: true);
}