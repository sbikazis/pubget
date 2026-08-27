import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/constants/group_type.dart';
import 'package:pubget/models/group_model.dart';
import 'package:pubget/providers/group_provider.dart';

void main() {
  group('GroupProvider user groups merge', () {
    test('keeps founded and joined groups without duplicates and sorts by latest activity', () {
      final founded = [
        GroupModel(
          id: 'g1',
          founderId: 'u1',
          name: 'My Group',
          description: '',
          slogan: '',
          type: GroupType.public,
          imageUrl: '',
          createdAt: DateTime(2024, 1, 1),
          lastMessageAt: DateTime(2024, 1, 1, 8),
          membersCount: 5,
          maxMembers: 20,
          isPromoted: false,
        ),
      ];

      final joined = [
        GroupModel(
          id: 'g1',
          founderId: 'u2',
          name: 'My Group',
          description: '',
          slogan: '',
          type: GroupType.public,
          imageUrl: '',
          createdAt: DateTime(2024, 1, 2),
          lastMessageAt: DateTime(2024, 1, 2, 10),
          membersCount: 8,
          maxMembers: 20,
          isPromoted: false,
        ),
        GroupModel(
          id: 'g2',
          founderId: 'u2',
          name: 'Joined Group',
          description: '',
          slogan: '',
          type: GroupType.public,
          imageUrl: '',
          createdAt: DateTime(2024, 1, 3),
          lastMessageAt: DateTime(2024, 1, 3, 9),
          membersCount: 4,
          maxMembers: 20,
          isPromoted: false,
        ),
      ];

      final merged = GroupProvider.mergeUserGroups(foundedGroups: founded, joinedGroups: joined);

      expect(merged.length, 2);
      expect(merged.map((g) => g.id).toList(), ['g2', 'g1']);
    });
  });
}
