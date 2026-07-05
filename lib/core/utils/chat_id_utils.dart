String buildPrivateChatId(String userIdA, String userIdB) {
  final sortedIds = [userIdA, userIdB]..sort();
  return '${sortedIds[0]}_${sortedIds[1]}';
}
