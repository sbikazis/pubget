// lib/core/logic/system_message_builder.dart

class SystemMessageBuilder {
  SystemMessageBuilder._();

  /// يبني نص رسالة النظام حسب نوع الحدث ونوع المجموعة
  static String buildText({
    required String eventType,
    required String memberName,
    String? characterName,
    String? roleName,
    required bool isRoleplay,
    required String groupType,
  }) {
    switch (eventType) {
      case 'join':
        return _buildJoinText(
          memberName: memberName,
          characterName: characterName,
          isRoleplay: isRoleplay,
          groupType: groupType,
        );
      case 'leave':
        return _buildLeaveText(
          memberName: memberName,
          characterName: characterName,
          isRoleplay: isRoleplay,
          groupType: groupType,
        );
      case 'kick':
        return _buildKickText(
          memberName: memberName,
          characterName: characterName,
          isRoleplay: isRoleplay,
          groupType: groupType,
        );
      case 'roleAssign':
        return _buildRoleAssignText(
          memberName: memberName,
          roleName: roleName,
          isRoleplay: isRoleplay,
          groupType: groupType,
        );
      default:
        return '⚙️ حدث تحديث في المجموعة';
    }
  }

  // ══════════════════════════════════════════════════════════
  // JOIN
  // ══════════════════════════════════════════════════════════
  static String _buildJoinText({
    required String memberName,
    String? characterName,
    required bool isRoleplay,
    required String groupType,
  }) {
    // مجموعة رولبلاي مع شخصية محددة
    if (isRoleplay && characterName != null && characterName.isNotEmpty) {
      return '🌸 أهلاً وسهلاً بـ $memberName بيننا! '
          'لقد اختار دور $characterName وانضم إلى عالمنا. '
          'نتمنى له رحلة ممتعة ومليئة بالمغامرات! ⚔️✨';
    }

    // مجموعة أنمي عامة
    if (groupType == 'anime') {
      return '🎌 مرحباً بالعضو الجديد $memberName في عائلتنا! '
          'يسعدنا انضمامك لمجتمع الأنمي. '
          'لا تتردد في المشاركة والتعبير عن شغفك! 🔥💫';
    }

    // مجموعة رولبلاي بدون شخصية (عام)
    if (isRoleplay) {
      return '🎭 انضم $memberName إلى مسرحنا! '
          'يسعدنا وجودك بيننا، اختر دورك وابدأ مغامرتك! ✨';
    }

    // مجموعة عامة
    return '👋 مرحباً بـ $memberName في المجموعة! '
        'يسعدنا انضمامك، نتمنى لك وقتاً ممتعاً معنا! 🎉';
  }

  // ══════════════════════════════════════════════════════════
  // LEAVE
  // ══════════════════════════════════════════════════════════
  static String _buildLeaveText({
    required String memberName,
    String? characterName,
    required bool isRoleplay,
    required String groupType,
  }) {
    // رولبلاي مع شخصية
    if (isRoleplay && characterName != null && characterName.isNotEmpty) {
      return '🍃 غادرنا $memberName وأخذ معه شخصية $characterName. '
          'شكراً على الذكريات الجميلة، نتمنى لك التوفيق! 🌙';
    }

    // مجموعة أنمي
    if (groupType == 'anime') {
      return '🌊 ودّعنا $memberName اليوم. '
          'شكراً لمشاركتك شغفك معنا، الباب مفتوح دائماً للعودة! 🎌';
    }

    // رولبلاي عام
    if (isRoleplay) {
      return '🎭 أسدل $memberName الستار وغادر المسرح. '
          'نتمنى أن نراه مجدداً! 🌟';
    }

    // عام
    return '👋 غادرنا $memberName المجموعة. '
        'نتمنى له التوفيق دائماً، وسيبقى دائماً مرحباً به للعودة! 💙';
  }

  // ══════════════════════════════════════════════════════════
  // KICK
  // ══════════════════════════════════════════════════════════
  static String _buildKickText({
    required String memberName,
    String? characterName,
    required bool isRoleplay,
    required String groupType,
  }) {
    // رولبلاي مع شخصية
    if (isRoleplay && characterName != null && characterName.isNotEmpty) {
      return '⚖️ تم إبعاد $memberName (${characterName}) '
          'من المجموعة بقرار من الإدارة. '
          'شخصية $characterName متاحة الآن لعضو آخر.';
    }

    // مجموعة أنمي
    if (groupType == 'anime') {
      return '🚫 تم إزالة $memberName من المجموعة بقرار إداري. '
          'نأمل أن تكون تجربة الجميع ممتعة وملتزمة بقواعد المجتمع. 🎌';
    }

    // رولبلاي عام
    if (isRoleplay) {
      return '🎭 أُسقط الستار على $memberName وتم إبعاده عن المسرح '
          'بقرار من الإدارة.';
    }

    // عام
    return '🚫 تم إزالة $memberName من المجموعة بقرار من الإدارة.';
  }

  // ══════════════════════════════════════════════════════════
  // ROLE ASSIGN
  // ══════════════════════════════════════════════════════════
  static String _buildRoleAssignText({
    required String memberName,
    String? roleName,
    required bool isRoleplay,
    required String groupType,
  }) {
    final String localizedRole = _localizeRole(roleName ?? 'member');

    // رولبلاي
    if (isRoleplay) {
      return '🏅 تهانينا لـ $memberName! '
          'تم ترقيته إلى رتبة "$localizedRole" في عالمنا. '
          'استحق هذا الشرف بجدارة! ⚔️✨';
    }

    // مجموعة أنمي
    if (groupType == 'anime') {
      return '🎖️ مبروك لـ $memberName على حصوله على رتبة "$localizedRole"! '
          'شكراً لتميزك ومساهمتك في مجتمعنا! 🎌🔥';
    }

    // عام
    return '⭐ تهانينا لـ $memberName! '
        'تم تعيينه بمنصب "$localizedRole" في المجموعة. '
        'نثق بك وبقيادتك! 💪';
  }

  // ══════════════════════════════════════════════════════════
  // مساعد: تعريب أسماء الرتب
  // ══════════════════════════════════════════════════════════
  static String _localizeRole(String role) {
    switch (role.toLowerCase()) {
      case 'founder':
        return 'المؤسس';
      case 'shogun':
        return 'الشوغن';
      case 'samurai':
        return 'الساموراي';
      case 'ronin':
        return 'الرونين';
      case 'member':
        return 'عضو';
      case 'moderator':
        return 'مشرف';
      case 'admin':
        return 'مدير';
      default:
        return role;
    }
  }
}