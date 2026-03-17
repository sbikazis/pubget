import '../constants/limits.dart';

class Validators {

  //  AUTH VALIDATORS

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'البريد الإلكتروني مطلوب';
    }

    final emailRegex =
        RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$');

    if (!emailRegex.hasMatch(value.trim())) {
      return 'صيغة البريد غير صحيحة';
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'كلمة المرور مطلوبة';
    }

    if (value.length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }

    return null;
  }


  //  USER VALIDATORS


  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'الإسم مطلوب';
    }

    if (value.length > Limits.maxUsernameLength) {
      return 'الإسم طويل جداً';
    }

    return null;
  }

  static String? validateNickname(String? value) {
    if (value == null || value.isEmpty) return null;

    if (value.length > Limits.maxNicknameLength) {
      return 'اللقب طويل جداً';
    }

    return null;
  }

  static String? validateBio(String? value) {
    if (value == null || value.isEmpty) return null;

    if (value.length > Limits.maxBioLength) {
      return 'النبذة طويلة جداً';
    }

    return null;
  }

  static String? validateAge(String? value) {
    if (value == null || value.isEmpty) return null;

    final age = int.tryParse(value);
    if (age == null) {
      return 'العمر يجب أن يكون رقماً';
    }

    if (age < 5 || age > 100) {
      return 'عمر غير منطقي';
    }

    return null;
  }


  //  GROUP VALIDATORS


  static String? validateGroupName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'اسم المجموعة مطلوب';
    }

    if (value.length > Limits.maxGroupNameLength) {
      return 'اسم المجموعة طويل جداً';
    }

    return null;
  }

  static String? validateGroupDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'وصف المجموعة مطلوب';
    }

    if (value.length > Limits.maxGroupDescriptionLength) {
      return 'الوصف طويل جداً';
    }

    return null;
  }

  static String? validateGroupSlogan(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'شعار المجموعة مطلوب';
    }

    final wordCount =
        value.trim().split(' ').where((w) => w.isNotEmpty).length;

    if (wordCount > Limits.maxGroupSloganLength) {
      return 'الشعار يجب ألا يتجاوز 4 كلمات';
    }

    return null;
  }


  //  ROLEPLAY VALIDATORS


  static String? validateCharacterName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'اسم الشخصية مطلوب';
    }

    if (value.length > Limits.maxCharacterNameLength) {
      return 'اسم الشخصية طويل جداً';
    }

    return null;
  }

  static String? validateCharacterReason(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'سبب اختيار الشخصية مطلوب';
    }

    if (value.length > Limits.maxCharacterReasonLength) {
      return 'السبب طويل جداً';
    }

    return null;
  }


  //  MESSAGE VALIDATORS


  static String? validateMessage(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'لا يمكن إرسال رسالة فارغة';
    }

    if (value.length > Limits.maxMessageLength) {
      return 'الرسالة طويلة جداً';
    }

    return null;
  }
}