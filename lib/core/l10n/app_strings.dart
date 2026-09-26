import 'package:flutter/widgets.dart';

/// Product copy for the two official locales (spec §2.3).
///
/// Feature screens that are not yet translated still contain English literals.
/// Auth, settings, and shell chrome read this catalog so the login language
/// picker and Settings language radios change real UI, not only RTL chrome.
final class AppStrings {
  const AppStrings._(this.locale, this._ar);

  final Locale locale;
  final bool _ar;

  static const english = AppStrings._(Locale('en'), false);
  static const arabic = AppStrings._(Locale('ar'), true);

  static AppStrings of(BuildContext context) =>
      forLocale(Localizations.localeOf(context));

  static AppStrings forLocale(Locale? locale) =>
      locale?.languageCode == 'ar' ? arabic : english;

  static AppStrings forLanguageCode(String? code) =>
      code == 'ar' ? arabic : english;

  bool get isArabic => _ar;

  String pick(String en, String ar) => _ar ? ar : en;

  String get brandTagline => pick('Premium Anime Community', 'مجتمع أنمي مميز');
  String get preparingExperience =>
      pick('Preparing your experience…', 'نجهّز تجربتك…');
  String get pubgetCouldNotStart =>
      pick('Pubget could not start', 'تعذّر تشغيل Pubget');
  String get couldNotStartPubget =>
      pick('Could not start Pubget', 'تعذّر تشغيل Pubget');
  String get couldNotLoadProfile =>
      pick('Could not load your profile', 'تعذّر تحميل ملفك');
  String get tryOpeningAgain =>
      pick('Please try opening Pubget again.', 'حاول فتح Pubget مرة أخرى.');
  String get tryLoadingProfileAgain => pick(
    'Please try loading your profile again.',
    'حاول تحميل ملفك مرة أخرى.',
  );
  String get youAreOffline => pick('You are offline', 'أنت غير متصل');

  String get language => pick('Language', 'اللغة');
  String get chooseLanguage => pick('Choose your language', 'اختر لغتك');
  String get languageArabic => 'العربية';
  String get languageEnglish => 'English';
  String get languageSystem => pick('System', 'تلقائي');

  String get welcomeBack => pick('Welcome back', 'مرحباً بعودتك');
  String get loginSubtitle => pick(
    'Sign in to continue your story in the premium anime community.',
    'سجّل دخولك لمتابعة قصتك في مجتمع الأنمي المميز.',
  );
  String get createAccountCta =>
      pick('New to Pubget? Create an account', 'جديد في Pubget؟ أنشئ حساباً');
  String get createAccountSemantic =>
      pick('Create a new account', 'إنشاء حساب جديد');
  String get reconnectBeforeSignIn =>
      pick('Reconnect before signing in.', 'أعد الاتصال قبل تسجيل الدخول.');
  String get signInFailed => pick('Sign-in failed', 'فشل تسجيل الدخول');
  String get email => pick('Email', 'البريد الإلكتروني');
  String get password => pick('Password', 'كلمة المرور');
  String get forgotPassword => pick('Forgot password?', 'نسيت كلمة المرور؟');
  String get resetForgottenPassword =>
      pick('Reset forgotten password', 'إعادة تعيين كلمة المرور');
  String get signIn => pick('Sign in', 'تسجيل الدخول');
  String get signInWithEmail =>
      pick('Sign in with email', 'تسجيل الدخول بالبريد');
  String get continueWithGoogle =>
      pick('Continue with Google', 'المتابعة عبر Google');
  String get staySignedIn => pick(
    'You stay signed in on this device.',
    'ستبقى مسجّلاً على هذا الجهاز.',
  );
  String get orDivider => pick('or', 'أو');

  String get createYourAccount => pick('Create your account', 'أنشئ حسابك');
  String get registerSubtitle => pick(
    'Join Pubget. You can finish your profile after registration.',
    'انضم إلى Pubget. يمكنك إكمال ملفك بعد التسجيل.',
  );
  String get alreadyHaveAccount =>
      pick('Already have an account? Sign in', 'لديك حساب؟ سجّل الدخول');
  String get returnToSignIn =>
      pick('Return to sign in', 'العودة لتسجيل الدخول');
  String get reconnectBeforeRegister => pick(
    'Reconnect before creating an account.',
    'أعد الاتصال قبل إنشاء الحساب.',
  );
  String get registrationFailed =>
      pick('Registration failed', 'فشل إنشاء الحساب');
  String get confirmPassword => pick('Confirm password', 'تأكيد كلمة المرور');
  String get passwordHint =>
      pick('At least 6 characters.', '6 أحرف على الأقل.');
  String get agreeToTerms => pick('I agree to the terms', 'أوافق على الشروط');
  String get readTheTerms => pick('Read the terms', 'اقرأ الشروط');
  String get createAccount => pick('Create account', 'إنشاء حساب');
  String get createAccountWithEmail =>
      pick('Create account with email', 'إنشاء حساب بالبريد');
  String get createAccountWithGoogle =>
      pick('Create account with Google', 'إنشاء حساب عبر Google');
  String get acceptTermsToContinue =>
      pick('Accept the terms to continue.', 'وافق على الشروط للمتابعة.');

  String get resetPassword =>
      pick('Reset your password', 'إعادة تعيين كلمة المرور');
  String get resetPasswordSubtitle => pick(
    'Enter the email you use for Pubget. We will send a reset link.',
    'أدخل البريد الذي تستخدمه في Pubget. سنرسل رابط إعادة التعيين.',
  );
  String get checkYourEmail => pick('Check your email', 'تحقق من بريدك');
  String get resetLinkOnTheWay => pick(
    'If an account exists for that address, a reset link is on its way.',
    'إذا وُجد حساب لهذا العنوان، فرابط إعادة التعيين في الطريق.',
  );
  String get backToSignIn => pick('Back to sign in', 'العودة لتسجيل الدخول');
  String get back => pick('Back', 'رجوع');
  String get close => pick('Close', 'إغلاق');
  String get reconnectToReset => pick(
    'Reconnect to send a reset link.',
    'أعد الاتصال لإرسال رابط إعادة التعيين.',
  );
  String get sendResetLink =>
      pick('Send reset link', 'إرسال رابط إعادة التعيين');
  String get sendPasswordResetEmail =>
      pick('Send password reset email', 'إرسال رسالة إعادة تعيين كلمة المرور');

  String get termsOfUse => pick('Terms of use', 'شروط الاستخدام');
  String get termsSubtitle => pick(
    'A clear summary before you create your account.',
    'ملخص واضح قبل إنشاء حسابك.',
  );
  String get backToRegistration =>
      pick('Back to registration', 'العودة للتسجيل');
  String get termsIntro => pick(
    'These are draft community terms. Final legal copy and a privacy '
        'policy will replace this text before public launch.',
    'هذه مسودة شروط المجتمع. ستُستبدل بنص قانوني وسياسة خصوصية قبل الإطلاق.',
  );
  String get termsAccountTitle => pick('Your account', 'حسابك');
  String get termsAccountBody => pick(
    'Keep your sign-in details private. You are responsible for '
        'activity on your Pubget account. If you think someone else '
        'used it, reset your password and contact support.',
    'احتفظ ببيانات الدخول لنفسك. أنت مسؤول عن النشاط على حسابك في Pubget. '
        'إذا ظننت أن أحداً استخدمه، أعد تعيين كلمة المرور وتواصل مع الدعم.',
  );
  String get termsCommunityTitle => pick('The community', 'المجتمع');
  String get termsCommunityBody => pick(
    'Pubget is for respectful anime conversation, groups, and '
        'events. Do not harass others, share illegal content, or '
        'impersonate people or brands.',
    'Pubget للحوار المحترم حول الأنمي والمجموعات والفعاليات. '
        'لا تضايق الآخرين، ولا تنشر محتوى غير قانوني، ولا تنتحل شخصيات أو علامات.',
  );
  String get termsContentTitle => pick('Your content', 'محتواك');
  String get termsContentBody => pick(
    'You keep ownership of what you post. By posting, you let '
        'Pubget display that content inside the product so other '
        'members can see it according to your privacy settings.',
    'تحتفظ بملكية ما تنشره. بالنشر تسمح لـ Pubget بعرض هذا المحتوى '
        'داخل التطبيق بحسب إعدادات خصوصيتك.',
  );
  String get termsPrivacyTitle => pick('Privacy', 'الخصوصية');
  String get termsPrivacyBody => pick(
    'We store the profile details you choose to share, plus the '
        'minimum account data needed to sign you in. A complete '
        'privacy policy will be published before launch.',
    'نحتفظ بتفاصيل الملف التي تختار مشاركتها، بالإضافة للحد الأدنى '
        'من بيانات الحساب اللازمة لتسجيل الدخول. ستُنشر سياسة خصوصية كاملة قبل الإطلاق.',
  );
  String get iAgree => pick('I agree', 'أوافق');
  String get agreeToTheTerms =>
      pick('Agree to the terms', 'الموافقة على الشروط');

  String get emailInvalid =>
      pick('Enter a valid email.', 'أدخل بريداً إلكترونياً صالحاً.');
  String get passwordTooShort => pick(
    'Password must be at least 6 characters.',
    'يجب أن تكون كلمة المرور 6 أحرف على الأقل.',
  );
  String get passwordsDoNotMatch =>
      pick('Passwords do not match.', 'كلمتا المرور غير متطابقتين.');
  String get usernameTooShort =>
      pick('Use at least 3 characters.', 'استخدم 3 أحرف على الأقل.');
  String get showPassword => pick('Show password', 'إظهار كلمة المرور');
  String get hidePassword => pick('Hide password', 'إخفاء كلمة المرور');
  String get passwordShort => pick('Too short', 'قصيرة جداً');
  String get passwordFair => pick('Good', 'جيدة');
  String get passwordStrong => pick('Strong', 'قوية');

  String get settings => pick('Settings', 'الإعدادات');
  String get account => pick('Account', 'الحساب');
  String get signedInAs => pick('Signed in as', 'مسجّل الدخول باسم');
  String get privacyAndProfile =>
      pick('Privacy and profile', 'الخصوصية والملف');
  String get openPrivacyAndProfile =>
      pick('Open privacy and profile settings', 'فتح إعدادات الخصوصية والملف');
  String get sendPasswordReset =>
      pick('Send password reset', 'إرسال إعادة تعيين كلمة المرور');
  String get passwordResetSent => pick(
    'Password reset email sent, if the account exists.',
    'تم إرسال رسالة إعادة التعيين إن وُجد الحساب.',
  );
  String get signOut => pick('Sign out', 'تسجيل الخروج');
  String get appearance => pick('Appearance', 'المظهر');
  String get themeSystem => pick('System', 'تلقائي');
  String get themeLight => pick('Light', 'فاتح');
  String get themeDark => pick('Dark', 'داكن');
  String get help => pick('Help', 'مساعدة');
  String get guide => pick('Guide', 'الدليل');
  String get openGuide => pick('Open the Pubget guide', 'فتح دليل Pubget');
  String get terms => pick('Terms', 'الشروط');
  String get openTerms => pick('Open community terms', 'فتح شروط المجتمع');
  String get about => pick('About', 'حول التطبيق');
  String get version => pick('Version', 'الإصدار');

  String get tabDiscover => pick('Discover', 'استكشف');
  String get tabGroups => pick('Groups', 'المجموعات');
  String get tabJoined => pick('Joined', 'المنضم إليها');
  String get tabPrivate => pick('Private', 'الخاص');
  String get tabEdits => pick('Reels', 'ريلز');

  String get drawerProfile => pick('My Profile', 'ملفي');
  String get drawerPrivate => pick('Private Chats', 'المحادثات الخاصة');
  String get drawerGroups => pick('My Groups', 'مجموعاتي');
  String get drawerJoined => pick('Joined Groups', 'المجموعات المنضم إليها');
  String get drawerSuggested => pick('Suggested Groups', 'مجموعات مقترحة');
  String get drawerStore => pick('Dragon Store', 'متجر التنين');
  String get drawerPremium => pick('Premium', 'بريميوم');
  String get drawerSettings => pick('Settings', 'الإعدادات');
  String get drawerGuide => pick('Guide', 'الدليل');
  String get drawerEvents => pick('Events', 'الفعاليات');
  String get drawerGames => pick('Games', 'الألعاب');
  String get drawerAnime => pick('Anime List', 'قائمة الأنمي');
  String get drawerAnimeUpdated => pick('Latest Updates', 'آخر التحديثات');
  String get drawerAnimeMalRanking => pick('MAL Ranking', 'ترتيب MAL');
  String get drawerAnimePubgetRating => pick('Pubget Rating', 'تقييم Pubget');
  String get drawerAnimeLibrary => pick('My Anime Lists', 'قوائمي');
  String get drawerAnimeCharacters =>
      pick('Most Popular Characters', 'الشخصيات الأكثر شعبية');
  String get drawerAnimeCharacterFavorites =>
      pick('My Favorite Characters', 'شخصياتي المفضلة');
  String get myAnime => pick('My Anime', 'أنميّاتي');
  String get notifications => pick('Notifications', 'الإشعارات');

  String drawerLabel(String id) => switch (id) {
    'profile' => drawerProfile,
    'private' => drawerPrivate,
    'groups' => drawerGroups,
    'joined' => drawerJoined,
    'suggested' => drawerSuggested,
    'anime' => drawerAnime,
    'anime-updated' => drawerAnimeUpdated,
    'anime-ratings' => drawerAnimeMalRanking,
    'anime-ratings-mal' => drawerAnimeMalRanking,
    'anime-ratings-pubget' => drawerAnimePubgetRating,
    'anime-library' => drawerAnimeLibrary,
    'anime-characters' => drawerAnimeCharacters,
    'anime-characters-favorites' => drawerAnimeCharacterFavorites,
    'store' => drawerStore,
    'premium' => drawerPremium,
    'achievements' => achievements,
    'settings' => drawerSettings,
    'guide' => drawerGuide,
    'events' => drawerEvents,
    'games' => drawerGames,
    'notifications' => notifications,
    _ => id,
  };

  String tabLabel(String id) => switch (id) {
    'discover' => tabDiscover,
    'groups' => tabGroups,
    'joined' => tabJoined,
    'private' => tabPrivate,
    'edits' => tabEdits,
    _ => id,
  };

  String get seeAll => pick('See all', 'عرض الكل');
  String get loadMore => pick('Load more', 'تحميل المزيد');
  String get searchHint => pick('Search Pubget', 'ابحث في Pubget');
  String get communityFallback =>
      pick('A Pubget community', 'مجتمع على Pubget');
  String get pubgetUser => pick('Pubget user', 'مستخدم Pubget');

  String get homeGreeting => pick('Your anime world', 'عالمك في الأنمي');
  String welcomeUser(String name) =>
      pick('Welcome back, $name', 'مرحباً بعودتك يا $name');
  String get homeWhatNow =>
      pick('What should I do right now?', 'ماذا أفعل الآن؟');
  String get homeHeroSubtitle => pick(
    'Discover people, groups, edits, and games in one place.',
    'اكتشف الأشخاص والمجموعات والمقاطع والألعاب من مكان واحد.',
  );
  String get nowJoinGroup => pick('Join a group', 'انضم لمجموعة');
  String get nowWatchEdits => pick('Watch Reels', 'شاهد الريلز');
  String get nowPlay => pick('Play', 'العب');
  String get nowEvents => pick('Events', 'الفعاليات');
  String get nowPeople => pick('People', 'أشخاص');
  String get nowAnime => pick('Anime', 'أنمي');

  String get coldStartBanner => pick(
    'Fresh start: we mix quality, trending, and rising groups until your taste is clearer.',
    'بداية جديدة: نمزج الجودة والشائع والمجموعات الصاعدة حتى تتضح ذائقتك.',
  );

  String get sectionPromoted => pick('Promoted groups', 'مجموعات مروّجة');
  String get sectionRising => pick('Rising groups', 'مجموعات صاعدة');
  String get sectionRecommended => pick('Recommended groups', 'مجموعات مقترحة');
  String get sectionCommunity =>
      pick('Recent community activity', 'نشاط المجتمع الأخير');
  String get sectionPeople => pick('People to discover', 'أشخاص لاكتشافهم');
  String get sectionEdits => pick('Trending Reels', 'ريلز رائجة');
  String get sectionEvents => pick('Events', 'الفعاليات');
  String get sectionGames => pick('Games', 'الألعاب');
  String get sectionFanWorks => pick('Fan Works', 'أعمال المعجبين');
  String get sectionAnime => pick('Anime Hub', 'مركز الأنمي');

  String get reasonPromoted => pick('Promoted', 'مروّج');
  String get reasonRising => pick('Rising now', 'يصعد الآن');
  String get reasonForYou => pick('For you', 'لك');

  String get nothingHereYet => pick('Nothing here yet', 'لا شيء هنا بعد');
  String get findPeopleHint => pick(
    'Find people through search and Respect.',
    'ابحث عن أشخاص عبر البحث والاحترام.',
  );
  String get discoverGroupsHint => pick(
    'Discover groups or start one of your own.',
    'اكتشف مجموعات أو أنشئ مجموعتك.',
  );
  String get searchPeople => pick('Search people', 'ابحث عن أشخاص');
  String get exploreGroups => pick('Explore groups', 'استكشف المجموعات');
  String get sectionFailed =>
      pick('This section could not load.', 'تعذّر تحميل هذا القسم.');
  String get tryAgainShort => pick('Please try again.', 'حاول مرة أخرى.');
  String get couldNotLoad => pick("Couldn't load this", 'تعذّر التحميل');

  String get groupsTitle => pick('My Groups', 'مجموعاتي');
  String get joinedTitle => pick('Joined', 'المنضم إليها');
  String get joinedGroupsTab => pick('Joined groups', 'المجموعات المنضم إليها');
  String get createdGroupsTab =>
      pick('Groups I created', 'المجموعات التي أنشأتها');
  String get noCreatedGroups => pick('No created groups', 'لا مجموعات أنشأتها');
  String get noCreatedMessage =>
      pick('Create a group from the + button.', 'أنشئ مجموعة من زر +.');
  String get shareInApp => pick('Share in the app', 'مشاركة داخل التطبيق');
  String get shareOutside =>
      pick('Share outside the app', 'مشاركة خارج التطبيق');
  String get skip => pick('Skip', 'تخطي');
  String get selectAnime => pick('Choose anime', 'تحديد الأنمي');
  String get selectCharacter => pick('Choose your character', 'تحديد شخصيتك');
  String get characterReserved => pick(
    'This character is currently reserved by another member of this group',
    'هذه الشخصية محجوزة حالياً من طرف عضو آخر في هذه المجموعة',
  );
  String get invitedByOptional =>
      pick('Invited by (optional username)', 'مدعو من طرف (اختياري)');
  String get acceptGroupRules => pick(
    'I accept the group rules and terms',
    'أوافق على شروط وأحكام المجموعة',
  );
  String get characterReason =>
      pick('Why this character?', 'سبب اختيارك لهذه الشخصية');
  String get useDefaultCharacterImage => pick(
    'Use the imported default image',
    'استخدام الصورة الافتراضية المستوردة',
  );
  String get useCustomCharacterImage =>
      pick('Set another image', 'تعيين صورة أخرى');
  String get requestPending => pick('Request pending', 'الطلب معلّق');
  String get bannedFromGroup =>
      pick('You cannot join this group', 'لا يمكنك الانضمام إلى هذه المجموعة');
  String get groupCapacityReached =>
      pick('This group is at capacity', 'المجموعة مكتملة العدد');
  String get joinPolicyClosed => pick(
    'Closed (request + founder approval)',
    'مغلقة (طلب + موافقة المؤسس)',
  );
  String get joinPolicyOpenEveryone =>
      pick('Open to everyone', 'مفتوحة للجميع');
  String get groupCreatedTitle => pick('Group created', 'تم إنشاء المجموعة');
  String get controlPanelTitle =>
      pick('Group control panel', 'لوحة تحكم المجموعة');
  String get growthOverview => pick('Growth', 'النمو');
  String get dangerZone => pick('Danger zone', 'منطقة الإجراءات الخطرة');
  String get memberPreview => pick('Members preview', 'معاينة الأعضاء');
  String get noAnimeResults => pick('No anime found', 'لا يوجد أنمي');
  String get noAnimeResultsHint => pick(
    'Try a different spelling or adjust the filters.',
    'جرّب صياغة أخرى أو عدّل عوامل التصفية.',
  );
  String get noCharacterResults =>
      pick('No characters found', 'لا توجد شخصيات');
  String get noCharacterResultsHint => pick(
    'Try another name or clear the filters.',
    'جرّب اسماً آخر أو امسح عوامل التصفية.',
  );
  String get searchGroups => pick('Search groups', 'ابحث عن مجموعات');
  String get createGroup => pick('Create', 'إنشاء');
  String get createAGroup => pick('Create a group', 'أنشئ مجموعة');
  String get noGroupsFound => pick('No groups found', 'لا توجد مجموعات');
  String get noGroupsMessage => pick(
    'Discover a community or create the first group on Pubget.',
    'اكتشف مجتمعاً أو أنشئ أول مجموعة على Pubget.',
  );
  String get groupsFailed =>
      pick('Groups could not load.', 'تعذّر تحميل المجموعات.');
  String get noJoinedGroups =>
      pick('No joined groups', 'لا مجموعات منضم إليها');
  String get noJoinedMessage => pick(
    'Join a community from Groups or Discover.',
    'انضم لمجتمع من المجموعات أو الاستكشاف.',
  );
  String get findGroups => pick('Find groups', 'ابحث عن مجموعات');
  String get joinedFailed => pick(
    'Joined groups could not load.',
    'تعذّر تحميل المجموعات المنضم إليها.',
  );

  String groupTypeLabel(String type) => switch (type) {
    'public' => pick('Public', 'عامة'),
    'animeRoleplay' => pick('Anime Roleplay', 'تمثيل أنمي'),
    'openRoleplay' => pick('Open Roleplay', 'تمثيل مفتوح'),
    _ => type,
  };

  String membersCount(int count) => pick('$count members', '$count أعضاء');

  String membersCapacity(int count, int max) =>
      pick('$count/$max members', '$count/$max أعضاء');

  String fansCount(int count) => pick('$count fans', '$count معجب');
  String get seeMore => pick('See more', 'مشاهدة المزيد');
  String get createNew => pick('Create', 'إنشاء');
  String get createGroupAction => pick('Create a group', 'إنشاء مجموعة');
  String get createVideoClip => pick('Create video clip', 'إنشاء مقطع فيديو');
  String get uploadClip => pick('Upload a clip', 'رفع مقطع');
  String get createFanWork => pick('Create a fan work', 'إنشاء عمل معجبين');
  String get browseEvents => pick('Browse events', 'تصفح الفعاليات');
  String get pickHostGroup =>
      pick('Choose a host group', 'اختر المجموعة المضيفة');
  String get joinGroupToCreateEvent => pick(
    'Join a group to create an event.',
    'انضم إلى مجموعة لإنشاء فعالية.',
  );
  String get hostGroup => pick('Host group', 'المجموعة المضيفة');
  String get eventEnded => pick('Ended', 'انتهت');
  String get justStarted => pick('Just started', 'بدأت للتو');
  String get eventActive => pick('Active', 'نشطة');
  String endsInHours(int hours) =>
      pick('Ends in $hours hours', 'تنتهي خلال $hours ساعات');
  String get vote => pick('Vote', 'صوّت');
  String get seeResult => pick('See result', 'شاهد النتيجة');
  String get rankChoices => pick('Rank your picks', 'رتّب اختياراتك');
  String get seeFullRanking => pick('See full ranking', 'شاهد الترتيب الكامل');
  String get addTheory => pick('Add your theory', 'اطرح نظريتك');
  String get browseTheories => pick('Browse theories', 'تصفح كل النظريات');
  String moreTheories(int count) =>
      pick('+$count more theories', '+$count نظرية أخرى');
  String get predictNow => pick('Predict now', 'توقّع الآن');
  String get seeActualResult =>
      pick('See the actual result', 'شاهد النتيجة الفعلية');
  String get startQuiz => pick('Start quiz', 'ابدأ الاختبار');
  String get seeYourScore => pick('See your score', 'شاهد نتيجتك');
  String quizMeta(int questions, int minutes) => pick(
    '$questions questions · $minutes min',
    '$questions أسئلة · $minutes دقائق',
  );
  String yourScore(int score, int total) =>
      pick('Your score: $score/$total', 'نتيجتك: $score/$total');
  String get shareOpinion => pick('Share your take', 'شارك برأيك');
  String get joinChallenge => pick('Join the challenge', 'شارك في التحدي');
  String get sendProof => pick('Send your proof', 'أرسل إثباتك');
  String get challengeDone => pick('Completed ✓', 'أنجزت ✓');
  String get verifiedAuto => pick('Auto-verified', 'تحقق تلقائي');
  String get selfReport => pick('Self-report', 'تحقق ذاتي');
  String get yes => pick('Yes', 'نعم');
  String get no => pick('No', 'لا');

  String eventTypeLabel(String type) => switch (type) {
    'poll' || 'multipleChoice' => pick('Poll', 'تصويت'),
    'ranking' => pick('Ranking', 'ترتيب'),
    'versus' => pick('Versus', 'مواجهة'),
    'theory' => pick('Theory', 'نظرية'),
    'prediction' => pick('Prediction', 'توقّع'),
    'quiz' => pick('Quiz', 'اختبار'),
    'imageComparison' => pick('Images', 'صور'),
    'characterComparison' => pick('Characters', 'شخصيات'),
    'animeComparison' => pick('Anime', 'أنمي'),
    'comparison' => pick('Comparison', 'مقارنة'),
    'question' => pick('Question', 'سؤال'),
    'openDiscussion' => pick('Talk', 'نقاش'),
    'challenge' => pick('Challenge', 'تحدٍ'),
    _ => type,
  };

  String get eventRankOptionsHint => pick(
    'Drag options into your preferred order.',
    'اسحب الخيارات إلى الترتيب الذي تفضّله.',
  );
  String get eventResetRanking => pick('Reset ranking', 'إعادة ضبط الترتيب');
  String get eventQuestionTimer =>
      pick('Time limit per question', 'المدة الزمنية لكل سؤال');
  String get eventNoTimeLimit => pick('No time limit', 'بدون وقت');
  String eventQuestionSeconds(int seconds) =>
      pick('$seconds seconds', '$seconds ثانية');
  String eventQuestionMinutes(int minutes) =>
      pick('$minutes minutes', '$minutes دقيقة');
  String get eventTimeUp => pick('Time up', 'انتهى الوقت');
  String get eventQuestionLocked => pick(
    'This question was locked and counts as 0 points.',
    'تم قفل هذا السؤال ويُحتسب بـ 0 نقاط.',
  );
  String get eventLeaderboard => pick('Leaderboard', 'لوحة المتصدرين');
  String get eventPoints => pick('pts', 'نقطة');
  String get eventResultTitle => pick('Final result', 'النتيجة النهائية');
  String get eventSubmissions => pick('Submissions', 'الإجابات');
  String get eventWinner => pick('Winner', 'الفائز');

  String pagesCount(int count) => pick('$count pages', '$count صفحة');
  String readMinutes(int minutes) =>
      pick('$minutes min read', 'قراءة $minutes دقائق');
  String worldDepth(int characters, int locations) => pick(
    '$characters characters · $locations places',
    '$characters شخصية · $locations مواقع',
  );

  String get myProfile => pick('My profile', 'ملفي');
  String get profile => pick('Profile', 'الملف');
  String get manageProfile => pick('Manage profile', 'إدارة الملف');
  String get editProfile => pick('Edit profile', 'تعديل الملف');
  String get shareProfile => pick('Share profile', 'مشاركة الملف');
  String get copyLink => pick('Copy link', 'نسخ الرابط');
  String get respect => pick('Respect', 'احترام');
  String get fans => pick('Fans', 'المعجبون');
  String get friends => pick('Friends', 'الأصدقاء');
  String get friendRequests => pick('Friend requests', 'طلبات الصداقة');
  String get friendRequest => pick('Friend request', 'طلب صداقة');
  String get couldNotLoadFriendRequests =>
      pick('Friend requests could not load.', 'تعذّر تحميل طلبات الصداقة.');
  String get achievements => pick('Achievements', 'الإنجازات');
  String get store => pick('Store', 'المتجر');
  String get profileUnavailable =>
      pick('Profile not available', 'الملف غير متاح');
  String get profilePrivate => pick(
    'This user may have made their profile private.',
    'قد يكون هذا المستخدم جعل ملفه خاصاً.',
  );
  String get profileFailed =>
      pick('The profile could not load.', 'تعذّر تحميل الملف.');

  String get groupDetails => pick('Group details', 'تفاصيل المجموعة');
  String get shareGroup => pick('Share group', 'مشاركة المجموعة');
  String get groupUnavailable =>
      pick('Group unavailable', 'المجموعة غير متاحة');
  String get groupFailed =>
      pick('Group could not load.', 'تعذّر تحميل المجموعة.');
  String get rules => pick('Rules', 'القوانين');
  String get openChat => pick('Open chat', 'فتح الدردشة');
  String get groupEvents => pick('Group events', 'فعاليات المجموعة');
  String get createEvent => pick('Create event', 'إنشاء فعالية');
  String get groupGames => pick('Group games', 'ألعاب المجموعة');
  String get createGame => pick('Create game', 'إنشاء لعبة');
  String get groupSettings => pick('Group settings', 'إعدادات المجموعة');
  String get bannedUsers => pick('Banned users', 'المحظورون');
  String get manageMembers => pick('Manage members', 'إدارة الأعضاء');
  String get joinRequests => pick('Join requests', 'طلبات الانضمام');
  String get roleplayCharacters =>
      pick('Roleplay characters', 'شخصيات التمثيل');
  String get joinGroup => pick('Join group', 'الانضمام للمجموعة');
  String get requestToJoin => pick('Request to join', 'طلب الانضمام');
  String get groupIsFull => pick('Group is full', 'المجموعة ممتلئة');
  String get groupFullMessage => pick(
    'Try again when a place becomes available.',
    'حاول لاحقاً عندما تتوفر مكان.',
  );
  String get invitationRequired => pick('Invitation required', 'الدعوة مطلوبة');
  String get invitationRequiredMessage => pick(
    'Use a valid group invitation to join.',
    'استخدم دعوة صالحة للانضمام.',
  );
  String get disbandGroup => pick('Disband group', 'تفكيك المجموعة');
  String disbandTitle(String name) => pick('Disband $name?', 'تفكيك $name؟');
  String get disbandMessage => pick(
    'This removes the group and cannot be undone.',
    'سيُحذف المجتمع ولا يمكن التراجع.',
  );
  String get continueLabel => pick('Continue', 'متابعة');
  String get cancel => pick('Cancel', 'إلغاء');
  String get finalConfirmation => pick('Final confirmation', 'تأكيد أخير');
  String get disbandFinalMessage => pick(
    'All members will be notified. Disband this group now?',
    'سيُبلَّغ كل الأعضاء. هل تفكك المجموعة الآن؟',
  );
  String get disband => pick('Disband', 'تفكيك');
  String get keepGroup => pick('Keep group', 'الإبقاء على المجموعة');
  String get leaveGroup => pick('Leave group', 'مغادرة المجموعة');
  String get leaveGroupMessage => pick(
    'You will leave this community and its chat.',
    'ستغادر هذا المجتمع ودردشته.',
  );
  String get leave => pick('Leave', 'مغادرة');

  String joinPolicyLabel(String policy) => switch (policy) {
    'open' => pick('Open', 'مفتوحة'),
    'approval' => pick('Request', 'بطلب'),
    'inviteOnly' => pick('Invite', 'بدعوة'),
    _ => policy,
  };

  String roleLabel(String role) => switch (role) {
    'mikado' || 'founder' => pick('MIKADO', 'ميكادو'),
    'shogun' => pick('SHŌGUN', 'شوغون'),
    'daimyo' || 'commander' => pick('DAIMYŌ', 'دايميو'),
    'hatamoto' || 'captain' => pick('HATAMOTO', 'هاتاموتو'),
    'samurai' || 'sensei' => pick('SAMURAI', 'ساموراي'),
    'gokenin' || 'senpai' => pick('GOKENIN', 'غوكينين'),
    'ronin' || 'member' => pick('RŌNIN', 'رونين'),
    _ => role,
  };

  String get members => pick('Members', 'الأعضاء');
  String get searchMembers => pick('Search members', 'ابحث في الأعضاء');
  String get noMembers => pick('No members', 'لا أعضاء');
  String get membersFailed =>
      pick('Members could not load.', 'تعذّر تحميل الأعضاء.');
  String get addMembers => pick('Add members', 'إضافة أعضاء');
  String get copyGroupLink => pick('Copy group link', 'نسخ رابط المجموعة');
  String get groupInformation => pick('Group information', 'معلومات المجموعة');
  String get groupMedia => pick('Group media', 'وسائط المجموعة');
  String get editGroup => pick('Edit group', 'تعديل المجموعة');
  String get chatBackground => pick('Chat background', 'خلفية الدردشة');
  String get groupMenu => pick('Group menu', 'قائمة المجموعة');
  String get groupChat => pick('Group chat', 'دردشة المجموعة');
  String get sendMessage => pick('Send message', 'إرسال رسالة');
  String get messageHint => pick('Message the group', 'اكتب للمجموعة');
  String get attachments => pick('Attachments', 'مرفقات');
  String get copy => pick('Copy', 'نسخ');
  String get reply => pick('Reply', 'رد');
  String get react => pick('React', 'تفاعل');
  String get pin => pick('Pin', 'تثبيت');
  String get unpin => pick('Unpin', 'إلغاء التثبيت');
  String get delete => pick('Delete', 'حذف');
  String get forwardShare => pick('Forward / share', 'إعادة توجيه / مشاركة');
  String get report => pick('Report', 'إبلاغ');
  String get reportMessage => pick('Report message', 'الإبلاغ عن الرسالة');
  String get reportSubmitted => pick('Report submitted', 'تم الإبلاغ');
  String get reportFailed => pick('Report failed.', 'فشل الإبلاغ.');
  String get confirmReport => pick('Confirm report', 'تأكيد الإبلاغ');
  String confirmReportContent(String reason) => pick(
    'Submit this message report for “$reason”?',
    'إرسال بلاغ عن هذه الرسالة بسبب «$reason»؟',
  );
  String get submitReport => pick('Submit report', 'إرسال البلاغ');
  String reportReasonLabel(String key) => switch (key) {
    'inappropriate' => pick('Inappropriate content', 'محتوى غير مناسب'),
    'spam' => pick('Spam', 'سبام'),
    'copyright' => pick('Copyright', 'حقوق الطبع'),
    'harassment' => pick('Harassment', 'تحرّش أو إزعاج'),
    'other' => pick('Other', 'أخرى'),
    _ => key,
  };
  String get editMessage => pick('Edit message', 'تعديل الرسالة');
  String get updateYourMessage => pick('Update your message', 'حدّث رسالتك');
  String get save => pick('Save', 'حفظ');
  String get messageEditFailed =>
      pick('Unable to edit message.', 'تعذّر تعديل الرسالة.');
  String get copyFailed => pick('Could not copy message', 'تعذّر نسخ الرسالة');
  String get forwardTo => pick('Forward to', 'إعادة توجيه إلى');
  String get noForwardTargets => pick(
    'No other groups or chats available',
    'لا توجد مجموعات أو محادثات أخرى متاحة',
  );
  String replyingToLabel(String name) =>
      pick('Replying to $name', 'الرد على $name');
  String get cancelReply => pick('Cancel reply', 'إلغاء الرد');
  String get messageForwarded =>
      pick('Message forwarded', 'أُعيد توجيه الرسالة');
  String get forwardFailed => pick('Forward failed.', 'فشل إعادة التوجيه.');
  String get cannotReportOwn => pick(
    'You cannot report your own message.',
    'لا يمكنك الإبلاغ عن رسالتك.',
  );
  String get changeRole => pick('Change role', 'تغيير الرتبة');
  String get kick => pick('Kick', 'طرد');
  String get ban => pick('Ban', 'حظر');
  String get transferOwnership => pick('Transfer ownership', 'نقل الملكية');

  // —— Group chat chrome (Arabic-first messaging UI) ——
  String get messageDeleted =>
      pick('This message was deleted', 'تم حذف هذه الرسالة');
  String get loadOlderMessages =>
      pick('Load older messages', 'تحميل رسائل أقدم');
  String get forwarded => pick('Forwarded', 'معاد توجيهها');
  String get edited => pick('edited', 'معدّلة');
  String get voiceMessage => pick('Voice message', 'رسالة صوتية');
  String get groupUpdate => pick('Group update', 'تحديث المجموعة');
  String get eventCard => pick('Event', 'فعالية');
  String get gameCard => pick('Game', 'لعبة');
  String get open => pick('Open', 'فتح');
  String get messageFrom => pick('Message from', 'رسالة من');
  String get now => pick('now', 'الآن');
  String get startConversation =>
      pick('Start the conversation', 'ابدأ المحادثة');
  String get messagesWillAppear => pick(
    'Messages from group members will appear here.',
    'ستظهر هنا رسائل أعضاء المجموعة.',
  );
  String get messagesCouldNotLoad =>
      pick('Messages could not load.', 'تعذّر تحميل الرسائل.');
  String get cachedMessagesUnavailable =>
      pick('Cached messages are unavailable.', 'الرسائل المحفوظة غير متاحة.');
  String get offlineCachedBanner => pick(
    'No internet connection — some saved data is available.',
    'لا يوجد اتصال بالإنترنت — بعض البيانات المحفوظة متاحة حاليًا',
  );
  String get mediaMessage => pick('Media message', 'رسالة وسائط');
  String get messageNotSent =>
      pick('Message was not sent.', 'لم تُرسل الرسالة.');
  String get messageWaitingConnection =>
      pick('Waiting for connection…', 'بانتظار الاتصال…');
  String get messageRetryingAutomatically =>
      pick('Retrying automatically…', 'جارٍ إعادة المحاولة تلقائياً…');
  String get messageSendPermissionDenied => pick(
    'You do not have permission to send in this chat.',
    'ليست لديك صلاحية الإرسال في هذه المحادثة.',
  );
  String get messageSendNotFound => pick(
    'This chat or message is no longer available.',
    'هذه المحادثة أو الرسالة لم تعد متاحة.',
  );
  String get messageSendInvalid =>
      pick('This message could not be sent.', 'تعذّر إرسال هذه الرسالة.');
  String get chatSecurityNote => pick(
    'Messages are stored securely with Firebase and protected during transit. '
        'Pubget and community moderators can access content for safety, moderation, '
        'and abuse reporting.',
    'تُخزَّن الرسائل بأمان عبر Firebase وتُحمى أثناء النقل. يمكن لبُبجت ومشرفي '
        'المجتمع الاطلاع على المحتوى لأغراض السلامة والرقابة والإبلاغ عن الإساءة.',
  );
  String chatSendFailureLabel(String? code) {
    switch (code) {
      case 'chat_network':
        return messageWaitingConnection;
      case 'chat_permission':
        return messageSendPermissionDenied;
      case 'chat_not_found':
        return messageSendNotFound;
      case 'chat_validation':
        return messageSendInvalid;
      default:
        return messageNotSent;
    }
  }

  String get retry => pick('Retry', 'إعادة المحاولة');
  String get deleteFailedMessage =>
      pick('Delete failed message', 'حذف الرسالة الفاشلة');
  String get sending => pick('Sending', 'جارٍ الإرسال');
  String get notDelivered => pick('Not delivered', 'لم تصل');
  String get delivered => pick('Delivered', 'وصلت');
  String get read => pick('Read', 'قُرئت');
  String get attachImage => pick('Image', 'صورة');
  String get attachVideo => pick('Video', 'فيديو');
  String get attachGif => pick('GIF', 'GIF');
  String get attachSticker => pick('Sticker', 'ملصق');
  String get emoji => pick('Emoji', 'إيموجي');
  String get eventCenter => pick('Event Center', 'مركز الفعاليات');
  String get voiceNoteLimits => pick(
    'Voice notes are limited to 60 seconds and 10 MB.',
    'الرسائل الصوتية محدودة بـ 60 ثانية و10 ميجابايت.',
  );
  String get voicePlayFailed => pick(
    'Voice message could not be played.',
    'تعذّر تشغيل الرسالة الصوتية.',
  );
  String get voiceMicPermissionDenied => pick(
    'Microphone access is required to record a voice message.',
    'يلزم السماح بالوصول إلى الميكروفون لتسجيل رسالة صوتية.',
  );
  String get voicePreviewUnavailable => pick(
    'Preview is not available on this device.',
    'المعاينة غير متاحة على هذا الجهاز.',
  );
  String get voiceSlideToCancel => pick('Slide to cancel', 'اسحب للإلغاء');
  String get resume => pick('Resume', 'استئناف');
  String get pause => pick('Pause', 'إيقاف مؤقت');
  String get preview => pick('Preview', 'معاينة');

  // ---- Phase 02: username + availability (spec §3.2) ----
  String get username => pick('Username', 'اسم المستخدم');
  String get usernameHint => pick('pubget_fan', 'pubget_fan');
  String get usernameRequired =>
      pick('Username is required.', 'اسم المستخدم مطلوب.');
  String get usernameHelp => pick(
    'Letters, numbers, dots, underscores and hyphens. 3–20 characters, not starting with a digit.',
    'حروف وأرقام ونقاط وشرطات سفلية وواصلات. 3–20 حروف، ولا يبدأ برقم.',
  );
  String get usernameTooLong =>
      pick('Use at most 20 characters.', '20 حروف كحد أقصى.');
  String get usernameInvalidStart =>
      pick('Must start with a letter.', 'يجب أن يبدأ بحرف.');
  String get usernameInvalidCharacters => pick(
    'Use letters, numbers, and middle dots only.',
    'استخدم الحروف والأرقام والنقاط المتوسطة فقط.',
  );
  String get usernameChecking =>
      pick('Checking availability…', 'نفحص توفر الاسم…');
  String get usernameAvailable =>
      pick('Username is available.', 'اسم المستخدم متاح.');
  String get usernameTaken =>
      pick('Username is already taken.', 'اسم المستخدم محجوز بالفعل.');
  String get usernameCheckFailed =>
      pick('We could not check this username.', 'تعذّر فحص هذا الاسم.');

  // ---- Phase 02: onboarding (spec §3.2/§3.3) ----
  String get onboardingTitleIdentity => pick('Your face & name', 'صورتك واسمك');
  String get onboardingTitleAbout => pick('A little about you', 'القليل عنك');
  String get onboardingTitleInterests => pick('What do you love?', 'ماذا تحب؟');
  String get onboardingSubtitleIdentity => pick(
    'Username and photo are required. Everything else can wait.',
    'اسم المستخدم والصور مطلوبان. كل شيء آخر يمكن تأجيله.',
  );
  String get onboardingSubtitleAbout => pick(
    'Optional details. Skip any field you want to fill later.',
    'تفاصيل اختيارية. تخطَّ أي حقل تريد تعبئته لاحقاً.',
  );
  String get onboardingSubtitleInterests => pick(
    'Pick anime moods to feed recommendations. Skip anytime.',
    'اختر مزاجك الأنمي لتغذية التوصيات. يمكنك التخطي في أي وقت.',
  );
  String get onboardingContinue => pick('Continue', 'متابعة');
  String get onboardingContinueSemantic =>
      pick('Continue profile setup', 'متابعة إعداد الملف');
  String get onboardingSaveAndEnter =>
      pick('Save profile and continue', 'حفظ الملف والمتابعة');
  String get onboardingEnterPubget => pick('Enter Pubget', 'ادخل إلى Pubget');
  String get onboardingBack => pick('Back', 'رجوع');
  String get onboardingBackSemantic =>
      pick('Back to previous step', 'العودة إلى الخطوة السابقة');
  String get onboardingSkipStep => pick('Skip this step', 'تخطي هذه الخطوة');
  String get onboardingSkipForNow => pick('Skip for now', 'تخطٍّ الآن');
  String get onboardingStepOfLabel => pick('Step', 'الخطوة');
  String get onboardingOfLabel => pick('of', 'من');
  String get onboardingDisplayName => pick('Display name', 'الاسم الظاهر');
  String get onboardingDisplayNameOptional =>
      pick('Display name (optional)', 'الاسم الظاهر (اختياري)');
  String get onboardingDisplayNameHint =>
      pick('How you appear to other members.', 'كيف تظهر لأعضاء آخرين.');
  String get onboardingDisplayNameRequired =>
      pick('Display name is required.', 'الاسم الظاهر مطلوب.');
  String get onboardingPhotoRequired =>
      pick('Profile photo is required.', 'صورة البروفايل مطلوبة.');
  String get onboardingChoosePhoto =>
      pick('Choose profile picture', 'اختر صورة البروفايل');
  String get onboardingChoosePhotoSemantic =>
      pick('Choose a profile picture', 'اختر صورة للبروفايل');
  String get onboardingPhotoReady => pick('Photo ready', 'الصورة جاهزة');
  String get onboardingBio => pick('Bio', 'نبذة');
  String get onboardingBioHint =>
      pick('A short vibe check for your page.', 'سطر قصير يعبّر عن صفحتك.');
  String get onboardingSkipBio => pick('Skip bio', 'تخطي النبذة');
  String get onboardingSkipBioSemantic => pick('Skip bio', 'تخطي النبذة');
  String get onboardingCountry => pick('Country', 'البلد');
  String get onboardingSkipCountry => pick('Skip country', 'تخطي البلد');
  String get onboardingSkipCountrySemantic =>
      pick('Skip country', 'تخطي البلد');
  String get onboardingAge => pick('Age', 'العمر');
  String get onboardingSkipAge => pick('Skip age', 'تخطي العمر');
  String get onboardingSkipAgeSemantic => pick('Skip age', 'تخطي العمر');
  String get onboardingInterestsTitle =>
      pick('Anime interests', 'اهتماماتك الأنمي');
  String get onboardingSkipInterests =>
      pick('Skip interests', 'تخطي الاهتمامات');
  String get onboardingSkipInterestsSemantic =>
      pick('Skip anime interests', 'تخطي اهتمامات الأنمي');
  String get onboardingOfflineSave =>
      pick('Save on this device for now', 'احفظ على هذا الجهاز الآن');
  String get onboardingOfflineSaveSemantic => pick(
    'Save your onboarding details on this device for now.',
    'احفظ بياناتك على هذا الجهاز الآن.',
  );
  String get onboardingInterestAction => pick('Action', 'أكشن');
  String get onboardingInterestAdventure => pick('Adventure', 'مغامرة');
  String get onboardingInterestComedy => pick('Comedy', 'كوميديا');
  String get onboardingInterestFantasy => pick('Fantasy', 'فانتازيا');
  String get onboardingInterestMystery => pick('Mystery', 'غموض');
  String get onboardingInterestRomance => pick('Romance', 'رومانسية');
  String get onboardingOfflineTitle => pick('You are offline', 'أنت غير متصل');
  String get onboardingOfflineMessage => pick(
    'Skip for now, or reconnect to save your profile.',
    'تخطَّ الآن، أو أعد الاتصال لحفظ ملفك.',
  );
  String get onboardingSaveFailedTitle =>
      pick('Profile not saved', 'لم يتم حفظ الملف');

  // ---- Phase 02: place holder home shell chrome ----
  String get homeWelcomeToPubget =>
      pick('Welcome to Pubget', 'مرحباً بك في Pubget');
  String get homeAccountReady => pick(
    'Your account is ready. The full home experience arrives in a later prompt.',
    'حسابك جاهز. تجربة الرئيسية الكاملة ستصل في تحديث لاحق.',
  );
  String get homeMyProfile => pick('My profile', 'ملفي');
  String get homeMyProfileSemantic => pick('Open my profile', 'فتح ملفي');
  String get homeGroups => pick('Groups', 'المجموعات');
  String get homeGroupsSemantic => pick('Open groups', 'فتح المجموعات');
  String get homeEditOnboarding =>
      pick('Edit onboarding details', 'تعديل بيانات التعارف');
  String get homeEditOnboardingSemantic =>
      pick('Edit onboarding details', 'تعديل بيانات التعارف');

  // ---- Phase 02: profile (spec §18) ----
  String get displayName => pick('Display name', 'الاسم الظاهر');
  String get bio => pick('Bio', 'نبذة');
  String get bioHint =>
      pick('Tell your community who you are.', 'أخبر مجتمعك من أنت.');
  String get bioEmptyCta =>
      pick('Add a bio so people can meet you', 'أضف نبذة ليتعارف الناس عليك');
  String get age => pick('Age', 'العمر');
  String get country => pick('Country', 'البلد');
  String get favoriteQuote => pick('Favorite quote', 'اقتباسك المفضل');
  String get animeTwin => pick('Anime twin', 'توأمك الأنمي');
  String get giveRespect => pick('Give Respect', 'منح الاحترام');
  String get saveRespect => pick('Save Respect', 'حفظ الاحترام');
  String get startChat => pick('Start chat', 'ابدأ المحادثة');
  String get blockUser => pick('Block user', 'حظر المستخدم');
  String get unblockUser => pick('Unblock user', 'إلغاء الحظر');
  String get blockUserConfirmTitle =>
      pick('Block this user?', 'حظر هذا المستخدم؟');
  String get blockUserConfirmBody => pick(
    'Blocked users cannot message you or appear in your feed.',
    'لا يمكن للمحظورين مراسلتك أو الظهور في خلاصتك.',
  );
  String get addFriend => pick('Add friend', 'إضافة صديق');
  String get removeFriend => pick('Remove friend', 'إزالة الصديق');
  String get couldNotLoadEdits =>
      pick('Could not load edits.', 'تعذّر تحميل الإيديتات.');
  String get edits => pick('Edits', 'الإيديتات');
  String get noEditsYet =>
      pick('No edits published yet', 'لا توجد إيديتات منشورة بعد');
  String get noEditsToShow => pick('No edits to show', 'لا توجد إيديتات للعرض');
  String get cutSceneCta => pick(
    'Cut a scene and publish your first edit.',
    'قصّ مشهداً وانشر أول إيديت لك.',
  );
  String get creatorNoEdits => pick(
    'This creator has not shared edits yet.',
    'لم يشارك هذا المبدع إيديتات بعد.',
  );
  String get openEdits => pick('Open edits', 'فتح الإيديتات');
  String get createAnEdit => pick('Create an edit', 'أنشئ إيديتاً');
  String get favoriteAnime => pick('Favorite anime', 'الأنمي المفضل');
  String get giveRespectSemantic =>
      pick('Give selected Respect', 'منح الاحترام المختار');
  String get startChatSemantic =>
      pick('Start a private chat', 'ابدأ محادثة خاصة');
  String get couldNotStartChat => pick(
    'Could not start this private chat.',
    'تعذّر بدء هذه المحادثة الخاصة.',
  );
  String get block => pick('Block', 'حظر');
  String get sendFriendRequest =>
      pick('Send friend request', 'إرسال طلب صداقة');
  String get cancelFriendRequest =>
      pick('Cancel friend request', 'إلغاء طلب الصداقة');
  String get acceptFriendRequest =>
      pick('Accept friend request', 'قبول طلب الصداقة');
  String get cancelRequest => pick('Cancel request', 'إلغاء الطلب');
  String get acceptRequest => pick('Accept request', 'قبول الطلب');
  String get unblock => pick('Unblock', 'إلغاء الحظر');
  String get incomingRequests => pick('Incoming requests', 'الطلبات الواردة');
  String get outgoingRequests => pick('Outgoing requests', 'الطلبات المرسلة');
  String get requestSent => pick('Request sent', 'تم إرسال الطلب');
  String get rejectRequest => pick('Reject request', 'رفض الطلب');
  String get noFriendRequests =>
      pick('No friend requests', 'لا توجد طلبات صداقة');
  String get newRequestsAppearHere =>
      pick('New friend requests will appear here.', 'ستظهر طلبات الصداقة هنا.');
  String get myEvents => pick('My Events', 'فعالياتي');

  // ---- Phase 02: edit profile (spec §18.2) ----
  String get cover => pick('Cover', 'الغلاف');
  String get coverChange => pick('Change cover', 'تغيير الغلاف');
  String get coverSelected => pick('New cover selected', 'تم اختيار غلاف جديد');
  String get avatarChange => pick('Change photo', 'تغيير الصورة');
  String get avatarSelected =>
      pick('New photo selected', 'تم اختيار صورة جديدة');
  String get editBioHint =>
      pick('Tell the community about you.', 'أخبر المجتمع عن نفسك.');
  String get ageOptional => pick('Age (optional)', 'العمر (اختياري)');
  String get countryOptional => pick('Country (optional)', 'البلد (اختياري)');
  String get favoriteQuoteOptional =>
      pick('Favorite quote (optional)', 'اقتباسك المفضل (اختياري)');
  String get animeTwinOptional =>
      pick('Anime twin (optional)', 'توأمك الأنمي (اختياري)');
  String get animeTwinHint =>
      pick('A character you vibe with', 'شخصية تنسجم معها');
  String get favoriteAnimeIds =>
      pick('Favorite anime IDs', 'معرّفات الأنمي المفضل');
  String get socialLinks => pick('Social links', 'روابط التواصل');
  String get addLinkUrl => pick('Add link URL', 'أضف رابطاً');
  String get linkLabelOptional => pick('Label (optional)', 'التسمية (اختياري)');
  String get addLink => pick('Add link', 'إضافة الرابط');
  String get addSocialLinkSemantic =>
      pick('Add social link', 'إضافة رابط تواصل');
  String get privacy => pick('Privacy', 'الخصوصية');
  String get profileVisibility => pick('Profile visibility', 'ظهور الملف');
  String get activityVisibility => pick('Activity visibility', 'ظهور النشاط');
  String get whoCanMessageMe => pick('Who can message me', 'من يمكنه مراسلتي');
  String get whoCanMessageRelated =>
      pick('Fans and Friends', 'المعجبون والأصدقاء');
  String get whoCanMessageFriends => pick('Friends only', 'الأصدقاء فقط');
  String get showFavorites => pick('Show favorites', 'إظهار المفضلة');
  String get showActivity => pick('Show activity', 'إظهار النشاط');
  String get showFriends => pick('Show friends', 'إظهار الأصدقاء');
  String get showFans => pick('Show fans', 'إظهار المعجبين');
  String get showWorks => pick(
    'Show works (Edits / Fan Works)',
    'إظهار الأعمال (الإيديتات / أعمال المعجبين)',
  );
  String get showGroups => pick('Show groups', 'إظهار المجموعات');
  String get showRatings => pick('Show ratings', 'إظهار التقييمات');
  String get showAchievements => pick('Show achievements', 'إظهار الإنجازات');
  String get public => pick('Public', 'عام');
  String get private => pick('Private', 'خاص');
  String get saveChanges => pick('Save changes', 'حفظ التغييرات');
  String get saveProfileChangesSemantic =>
      pick('Save profile changes', 'حفظ تغييرات الملف');
  String get chooseCoverSemantic =>
      pick('Choose a cover photo', 'اختر صورة غلاف');
  String get chooseAvatarSemantic =>
      pick('Choose a new profile photo', 'اختر صورة ملف جديدة');

  // ── Group Games and Mafia (spec §12-13) ────────────────────────────────
  String get mafiaTitle => pick('Mafia', 'مافيا');
  String get mafiaCouldNotLoad =>
      pick('Could not load Mafia', 'تعذّر تحميل المافيا');
  String get mafiaLog => pick('Game log', 'سجل اللعبة');
  String get mafiaDiscussionLabel => pick('Discussion', 'النقاش');
  String get mafiaSecretChannel =>
      pick('Mafia secret channel', 'القناة السرية للمافيا');
  String get mafiaSecretMessage => pick('Secret message', 'رسالة سرية');
  String get mafiaSendSecretSemantic =>
      pick('Send a secret message', 'إرسال رسالة سرية');
  String get mafiaLeave => pick('Leave', 'مغادرة');
  String get mafiaJoin => pick('Join', 'انضمام');
  String get mafiaStart => pick('Start game', 'بدء اللعبة');
  String get mafiaStartSemantic => pick('Start', 'بدء');
  String mafiaNeedMorePlayers(int minimum, int joined) => pick(
    'You need $minimum players to start. Joined now: $joined.',
    'تحتاج اللعبة إلى $minimum لاعبين. المنضم الآن: $joined.',
  );
  String mafiaRosterCount(int joined, int maximum, int minimum) => pick(
    '$joined/$maximum players · minimum $minimum',
    '$joined/$maximum لاعبين · الحد الأدنى $minimum',
  );
  String get mafiaYouAreSpectator =>
      pick('You are watching this game.', 'أنت تشاهد اللعبة كمشاهد.');
  String get mafiaYourTurn =>
      pick('It is your turn to speak.', 'حان دورك للكلام.');
  String get mafiaWaitingForSpeaker =>
      pick('Waiting for the current player.', 'بانتظار دور اللاعب الحالي.');
  String get mafiaEndTurn => pick('End my turn', 'إنهاء دوري');
  String get mafiaEndTurnSemantic => pick('End turn', 'إنهاء الدور');
  String mafiaNightAbility(String role) =>
      pick('$role night ability', 'قدرة $role الليلية');
  String get mafiaSecretVoteRevote => pick(
    'Secret re-vote: only the tied players.',
    'إعادة تصويت سرية بين المتعادلين فقط.',
  );
  String get mafiaSecretVote => pick(
    'Secret vote. You cannot vote for yourself.',
    'تصويت سري. لا يمكنك التصويت لنفسك.',
  );
  String get mafiaLastWordsIntro => pick(
    'You are out. You may write last words once.',
    'أنت الآن خارج اللعبة. يمكنك كتابة كلماتك الأخيرة مرة واحدة.',
  );
  String get mafiaLastWordsLabel => pick('Last words', 'كلمات أخيرة');
  String get mafiaLastWordsSend => pick('Send', 'إرسال');
  String get mafiaLastWordsSendSemantic =>
      pick('Send last words', 'إرسال الكلمات الأخيرة');
  String get mafiaLastWordsSpoken => pick('Last words: ', 'الكلمات الأخيرة: ');
  String mafiaYourRole(String role) => pick('Your role: $role', 'دورك: $role');
  String mafiaYourTeam(String team) => pick('Team: $team', 'الفريق: $team');
  String get mafiaTeamMafia => pick('Mafia', 'المافيا');
  String get mafiaTeamTown => pick('Town', 'المدينة');
  String mafiaTeammates(String names) =>
      pick('Your Mafia allies: $names', 'زملاؤك في المافيا: $names');
  String mafiaInvestigationResult(String result) =>
      pick('Investigation result: $result', 'نتيجة التحقيق: $result');
  String mafiaDonResult(String result) =>
      pick('Don check: $result', 'نتيجة تحقق الدون: $result');
  String get mafiaEliminated => pick('eliminated', 'مقصى');
  String get mafiaDisconnected => pick('disconnected', 'غير متصل');
  String get mafiaYou => pick('you', 'أنت');
  String get mafiaMafiaWon => pick('The Mafia won', 'فازت المافيا');
  String get mafiaTownWon => pick('The town won', 'فازت المدينة');
  String get mafiaGameEnded => pick('The game ended', 'انتهت اللعبة');
  String get mafiaPlayAgain => pick('Play again', 'العب مجددًا');
  String get mafiaProtectedLastNight =>
      pick('Saved last night', 'تم إنقاذه الليلة الماضية');
  String get mafiaDead => pick('dead', 'ميت');
  String get mafiaDoctorSameTarget => pick(
    'You already protected this player last night.',
    'لقد حمت هذا اللاعب الليلة الماضية.',
  );
  String get mafiaRoleUnknown => pick('Unknown', 'غير معروف');

  String mafiaPhaseLabel(String phase) =>
      pick(_mafiaPhasesEn[phase] ?? phase, _mafiaPhasesAr[phase] ?? phase);
  String mafiaRoleLabel(String role) => pick(
    _mafiaRolesEn[role] ?? (role.isEmpty ? 'Unknown' : role),
    _mafiaRolesAr[role] ?? (role.isEmpty ? 'غير معروف' : role),
  );

  String userNameWelcome(String name) =>
      pick('Welcome, $name', 'مرحباً، $name');
  String stepOf(int step, int total) =>
      pick('Step $step of $total', 'الخطوة $step من $total');
  String memberSince(String month) => pick('Since $month', 'منذ $month');
}

const Map<String, String> _mafiaPhasesEn = <String, String>{
  'WAITING': 'Waiting room',
  'STARTING': 'Starting',
  'ROLE_REVEAL': 'Role reveal',
  'NIGHT': 'Night',
  'DAY': 'Day',
  'DISCUSSION': 'Discussion',
  'VOTING': 'Voting',
  'VOTE_RESULT': 'Vote result',
  'RESOLUTION': 'Resolving',
  'GAME_OVER': 'The game is over',
  'CANCELLED': 'The game was cancelled',
};

const Map<String, String> _mafiaPhasesAr = <String, String>{
  'WAITING': 'غرفة الانتظار',
  'STARTING': 'جاري بدء اللعبة',
  'ROLE_REVEAL': 'كشف دورك',
  'NIGHT': 'الليل',
  'DAY': 'النهار',
  'DISCUSSION': 'النقاش',
  'VOTING': 'التصويت',
  'VOTE_RESULT': 'نتيجة التصويت',
  'RESOLUTION': 'معالجة النتيجة',
  'GAME_OVER': 'انتهت اللعبة',
  'CANCELLED': 'أُلغيت اللعبة',
};

const Map<String, String> _mafiaRolesEn = <String, String>{
  'mafia': 'Mafia',
  'don': 'Don',
  'detective': 'Detective',
  'doctor': 'Doctor',
  'citizen': 'Citizen',
};

const Map<String, String> _mafiaRolesAr = <String, String>{
  'mafia': 'مافيا',
  'don': 'الدون',
  'detective': 'المحقق',
  'doctor': 'الطبيب',
  'citizen': 'مواطن',
};
