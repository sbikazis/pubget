// lib/core/logic/system_message_builder.dart

class SystemMessageBuilder {
  SystemMessageBuilder._();

  /// يبني نص رسالة النظام حسب نوع الحدث ونوع المجموعة
  static String buildText({
    required String eventType,
    required String memberName,
    String? characterName,
    String? roleName,
    int? oldRoleLevel,
    int? newRoleLevel,
    String? country,
    String? editorName,
    String? fieldName,
    String? oldValue,
    String? newValue,
    required bool isRoleplay,
    required String groupType,
  }) {
    switch (eventType) {
      case 'join':
        return _buildJoinText(
          memberName: memberName,
          characterName: characterName,
          country: country,
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
          oldRoleLevel: oldRoleLevel,
          newRoleLevel: newRoleLevel,
          isRoleplay: isRoleplay,
          groupType: groupType,
        );
      case 'edit':
        return _buildEditText(
          editorName: editorName ?? 'المؤسس',
          fieldName: fieldName ?? '',
          oldValue: oldValue,
          newValue: newValue,
        );
      case 'background':
        return _buildBackgroundText(
          editorName: editorName ?? 'المؤسس',
        );
      default:
        return '⚙️ حدث تحديث في المجموعة';
    }
  }

  // ══════════════════════════════════════════════════════════
  // JOIN — بطاقة ترحيب فاخرة
  // ══════════════════════════════════════════════════════════
  static String _buildJoinText({
    required String memberName,
    String? characterName,
    String? country,
    required bool isRoleplay,
    required String groupType,
  }) {
    final String countryLine =
        (country != null && country.trim().isNotEmpty)
            ? '\n🌍 ينضم إلينا من: $country'
            : '';

    // مجموعة رولبلاي مع شخصية محددة — بطاقة تعريفية كاملة
    if (isRoleplay && characterName != null && characterName.isNotEmpty) {
      return '🌸✨ ━━━ عضو جديد في عالمنا ━━━ ✨🌸\n\n'
          '🎭 الاسم: $memberName\n'
          '⚔️ يتقمص شخصية: $characterName'
          '$countryLine\n\n'
          'أهلاً وسهلاً بك بيننا! لقد اختار $memberName دور $characterName '
          'وانضم رسمياً إلى عالمنا.\n'
          'نتمنى له رحلة ممتعة ومليئة بالمغامرات والذكريات الجميلة! ⚔️🔥\n\n'
          '━━━━━━━━━━━━━━━━━━━━━';
    }

    // مجموعة أنمي عامة
    if (groupType == 'anime') {
      return '🎌✨ ━━━ مرحباً بالعضو الجديد ━━━ ✨🎌\n\n'
          '👤 $memberName$countryLine\n\n'
          'يسعدنا انضمامك لمجتمع الأنمي لدينا.\n'
          'لا تتردد في المشاركة والتعبير عن شغفك! 🔥💫\n\n'
          '━━━━━━━━━━━━━━━━━━━━━';
    }

    // مجموعة رولبلاي بدون شخصية (عام)
    if (isRoleplay) {
      return '🎭✨ ━━━ وافد جديد إلى المسرح ━━━ ✨🎭\n\n'
          '👤 $memberName$countryLine\n\n'
          'يسعدنا وجودك بيننا، اختر دورك وابدأ مغامرتك! ✨\n\n'
          '━━━━━━━━━━━━━━━━━━━━━';
    }

    // مجموعة عامة
    return '👋✨ ━━━ عضو جديد ━━━ ✨👋\n\n'
        '👤 $memberName$countryLine\n\n'
        'مرحباً بك في المجموعة! يسعدنا انضمامك، '
        'نتمنى لك وقتاً ممتعاً معنا! 🎉\n\n'
        '━━━━━━━━━━━━━━━━━━━━━';
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
  // ROLE ASSIGN — ذكي: يميز بين ترقية وتخفيض وتعديل بلا تغيير
  // ══════════════════════════════════════════════════════════
  static String _buildRoleAssignText({
    required String memberName,
    String? roleName,
    int? oldRoleLevel,
    int? newRoleLevel,
    required bool isRoleplay,
    required String groupType,
  }) {
    final String localizedRole = _localizeRole(roleName ?? 'member');

    // إذا لم تُمرَّر المستويات (حالة قديمة/احتياطية) نفترض ترقية كما كان سابقاً
    final int oldLevel = oldRoleLevel ?? 0;
    final int newLevel = newRoleLevel ?? (oldLevel + 1);

    if (newLevel > oldLevel) {
      return _buildPromotionText(
        memberName: memberName,
        localizedRole: localizedRole,
        isRoleplay: isRoleplay,
        groupType: groupType,
      );
    } else if (newLevel < oldLevel) {
      return _buildDemotionText(
        memberName: memberName,
        localizedRole: localizedRole,
        isRoleplay: isRoleplay,
        groupType: groupType,
      );
    } else {
      return _buildNeutralRoleChangeText(
        memberName: memberName,
        localizedRole: localizedRole,
      );
    }
  }

  // ── ترقية ─────────────────────────────────────────────────
  static String _buildPromotionText({
    required String memberName,
    required String localizedRole,
    required bool isRoleplay,
    required String groupType,
  }) {
    if (isRoleplay) {
      return '🏅 تهانينا لـ $memberName! '
          'تم ترقيته إلى رتبة "$localizedRole" في عالمنا. '
          'استحق هذا الشرف بجدارة! ⚔️✨';
    }

    if (groupType == 'anime') {
      return '🎖️ مبروك لـ $memberName على حصوله على رتبة "$localizedRole"! '
          'شكراً لتميزك ومساهمتك في مجتمعنا! 🎌🔥';
    }

    return '⭐ تهانينا لـ $memberName! '
        'تم ترقيته إلى منصب "$localizedRole" في المجموعة. '
        'نثق بك وبقيادتك! 💪';
  }

  // ── تخفيض ─────────────────────────────────────────────────
  static String _buildDemotionText({
    required String memberName,
    required String localizedRole,
    required bool isRoleplay,
    required String groupType,
  }) {
    if (isRoleplay) {
      return '📉 تم تخفيض رتبة $memberName إلى "$localizedRole" '
          'بقرار من الإدارة.';
    }

    if (groupType == 'anime') {
      return '📉 تم تعديل رتبة $memberName إلى "$localizedRole" '
          'بقرار إداري.';
    }

    return '📉 تم تخفيض رتبة $memberName إلى "$localizedRole" '
        'بقرار من إدارة المجموعة.';
  }

  // ── تعديل بدون تغيير مستوى (نادر) ───────────────────────────
  static String _buildNeutralRoleChangeText({
    required String memberName,
    required String localizedRole,
  }) {
    return 'ℹ️ تم تعديل صلاحيات $memberName إلى "$localizedRole".';
  }

  // ══════════════════════════════════════════════════════════
  // EDIT — تعديل بيانات المجموعة (الاسم/الوصف/الصورة)
  // ══════════════════════════════════════════════════════════
  static String _buildEditText({
    required String editorName,
    required String fieldName,
    String? oldValue,
    String? newValue,
  }) {
    switch (fieldName) {
      case 'name':
        return '✏️ قام $editorName بتغيير اسم المجموعة إلى "$newValue".';
      case 'description':
        return '📝 قام $editorName بتحديث وصف المجموعة.';
      case 'imageUrl':
        return '🖼️ قام $editorName بتغيير صورة المجموعة.';
      case 'slogan':
        return '🪶 قام $editorName بتحديث شعار المجموعة.';
      default:
        return '⚙️ قام $editorName بتعديل بيانات المجموعة.';
    }
  }

  // ══════════════════════════════════════════════════════════
  // BACKGROUND — تغيير خلفية الدردشة
  // ══════════════════════════════════════════════════════════
  static String _buildBackgroundText({
    required String editorName,
  }) {
    return '🖼️ قام $editorName بتغيير خلفية الدردشة.';
  }

  // ══════════════════════════════════════════════════════════
  // مساعد: تعريب أسماء الرتب
  // ══════════════════════════════════════════════════════════
  static String _localizeRole(String role) {
    switch (role.toLowerCase()) {
      case 'founder':
        return 'الشوغن';
      case 'sensei':
        return 'سينسي';
      case 'hakusho':
        return 'هاكوشو';
      case 'senpai':
        return 'سينباي';
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
