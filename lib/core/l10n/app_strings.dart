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

  String get brandTagline =>
      pick('Premium Anime Community', 'مجتمع أنمي مميز');
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
  String get returnToSignIn => pick('Return to sign in', 'العودة لتسجيل الدخول');
  String get reconnectBeforeRegister => pick(
    'Reconnect before creating an account.',
    'أعد الاتصال قبل إنشاء الحساب.',
  );
  String get registrationFailed =>
      pick('Registration failed', 'فشل إنشاء الحساب');
  String get confirmPassword => pick('Confirm password', 'تأكيد كلمة المرور');
  String get passwordHint => pick('At least 6 characters.', '6 أحرف على الأقل.');
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
  String get reconnectToReset =>
      pick('Reconnect to send a reset link.', 'أعد الاتصال لإرسال رابط إعادة التعيين.');
  String get sendResetLink => pick('Send reset link', 'إرسال رابط إعادة التعيين');
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
  String get agreeToTheTerms => pick('Agree to the terms', 'الموافقة على الشروط');

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
  String get tabEdits => pick('Edits', 'المقاطع');

  String get drawerProfile => pick('My Profile', 'ملفي');
  String get drawerPrivate => pick('Private Chats', 'المحادثات الخاصة');
  String get drawerGroups => pick('My Groups', 'مجموعاتي');
  String get drawerJoined => pick('Joined Groups', 'المجموعات المنضم إليها');
  String get drawerSuggested => pick('Suggested Groups', 'مجموعات مقترحة');
  String get drawerStore => pick('Dragon Store', 'متجر التنين');
  String get drawerPremium => pick('Premium', 'بريميوم');
  String get drawerSettings => pick('Settings', 'الإعدادات');
  String get drawerGuide => pick('Guide', 'الدليل');
  String get drawerAnime => pick('Anime List', 'قائمة الأنمي');
  String get drawerAnimeRatings => pick('Ratings', 'التقييمات');
  String get drawerAnimeCharacters =>
      pick('Popular Characters', 'الشخصيات الشائعة');
  String get myAnime => pick('My Anime', 'أنميّاتي');
  String get notifications => pick('Notifications', 'الإشعارات');

  String drawerLabel(String id) => switch (id) {
    'profile' => drawerProfile,
    'private' => drawerPrivate,
    'groups' => drawerGroups,
    'joined' => drawerJoined,
    'suggested' => drawerSuggested,
    'anime' => drawerAnime,
    'anime-ratings' => drawerAnimeRatings,
    'anime-characters' => drawerAnimeCharacters,
    'store' => drawerStore,
    'premium' => drawerPremium,
    'settings' => drawerSettings,
    'guide' => drawerGuide,
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
  String get communityFallback => pick('A Pubget community', 'مجتمع على Pubget');
  String get pubgetUser => pick('Pubget user', 'مستخدم Pubget');

  String get homeGreeting => pick('Your anime world', 'عالمك في الأنمي');
  String welcomeUser(String name) =>
      pick('Welcome back, $name', 'مرحباً بعودتك يا $name');
  String get homeWhatNow => pick(
    'What should I do right now?',
    'ماذا أفعل الآن؟',
  );
  String get homeHeroSubtitle => pick(
    'Discover people, groups, edits, and games in one place.',
    'اكتشف الأشخاص والمجموعات والمقاطع والألعاب من مكان واحد.',
  );
  String get nowJoinGroup => pick('Join a group', 'انضم لمجموعة');
  String get nowWatchEdits => pick('Watch Edits', 'شاهد المقاطع');
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
  String get sectionRecommended =>
      pick('Recommended groups', 'مجموعات مقترحة');
  String get sectionCommunity =>
      pick('Recent community activity', 'نشاط المجتمع الأخير');
  String get sectionPeople => pick('People to discover', 'أشخاص لاكتشافهم');
  String get sectionEdits => pick('Trending Edits', 'مقاطع رائجة');
  String get sectionEvents => pick('Events', 'الفعاليات');
  String get sectionGames => pick('Games', 'الألعاب');
  String get sectionFanWorks => pick('Fan Works', 'أعمال المعجبين');
  String get sectionAnime => pick('Anime Hub', 'مركز الأنمي');

  String get reasonPromoted => pick('Promoted', 'مروّج');
  String get reasonRising => pick('Rising now', 'يصعد الآن');
  String get reasonForYou => pick('For you', 'لك');

  String get nothingHereYet => pick('Nothing here yet', 'لا شيء هنا بعد');
  String get findPeopleHint =>
      pick('Find people through search and Respect.', 'ابحث عن أشخاص عبر البحث والاحترام.');
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
  String get joinedGroupsTab =>
      pick('Joined groups', 'المجموعات المنضم إليها');
  String get createdGroupsTab =>
      pick('Groups I created', 'المجموعات التي أنشأتها');
  String get noCreatedGroups =>
      pick('No created groups', 'لا مجموعات أنشأتها');
  String get noCreatedMessage => pick(
    'Create a group from the + button.',
    'أنشئ مجموعة من زر +.',
  );
  String get shareInApp => pick('Share in the app', 'مشاركة داخل التطبيق');
  String get shareOutside => pick('Share outside the app', 'مشاركة خارج التطبيق');
  String get skip => pick('Skip', 'تخطي');
  String get selectAnime => pick('Choose anime', 'تحديد الأنمي');
  String get selectCharacter => pick('Choose your character', 'تحديد شخصيتك');
  String get characterReserved => pick(
    'This character is currently reserved by another member of this group',
    'هذه الشخصية محجوزة حالياً من طرف عضو آخر في هذه المجموعة',
  );
  String get invitedByOptional =>
      pick('Invited by (optional username)', 'مدعو من طرف (اختياري)');
  String get acceptGroupRules =>
      pick('I accept the group rules and terms', 'أوافق على شروط وأحكام المجموعة');
  String get characterReason =>
      pick('Why this character?', 'سبب اختيارك لهذه الشخصية');
  String get useDefaultCharacterImage => pick(
    'Use the imported default image',
    'استخدام الصورة الافتراضية المستوردة',
  );
  String get useCustomCharacterImage =>
      pick('Set another image', 'تعيين صورة أخرى');
  String get requestPending =>
      pick('Request pending', 'الطلب معلّق');
  String get bannedFromGroup => pick(
    'You cannot join this group',
    'لا يمكنك الانضمام إلى هذه المجموعة',
  );
  String get groupCapacityReached =>
      pick('This group is at capacity', 'المجموعة مكتملة العدد');
  String get joinPolicyClosed => pick(
    'Closed (request + founder approval)',
    'مغلقة (طلب + موافقة المؤسس)',
  );
  String get joinPolicyOpenEveryone =>
      pick('Open to everyone', 'مفتوحة للجميع');
  String get groupCreatedTitle =>
      pick('Group created', 'تم إنشاء المجموعة');
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
  String get noCharacterResults => pick('No characters found', 'لا توجد شخصيات');
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
  String get groupsFailed => pick('Groups could not load.', 'تعذّر تحميل المجموعات.');
  String get noJoinedGroups => pick('No joined groups', 'لا مجموعات منضم إليها');
  String get noJoinedMessage => pick(
    'Join a community from Groups or Discover.',
    'انضم لمجتمع من المجموعات أو الاستكشاف.',
  );
  String get findGroups => pick('Find groups', 'ابحث عن مجموعات');
  String get joinedFailed =>
      pick('Joined groups could not load.', 'تعذّر تحميل المجموعات المنضم إليها.');

  String groupTypeLabel(String type) => switch (type) {
    'public' => pick('Public', 'عامة'),
    'animeRoleplay' => pick('Anime Roleplay', 'تمثيل أنمي'),
    'openRoleplay' => pick('Open Roleplay', 'تمثيل مفتوح'),
    _ => type,
  };

  String membersCount(int count) =>
      pick('$count members', '$count أعضاء');

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
  String get pickHostGroup => pick('Choose a host group', 'اختر المجموعة المضيفة');
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
  String quizMeta(int questions, int minutes) =>
      pick('$questions questions · $minutes min', '$questions أسئلة · $minutes دقائق');
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
    'openDiscussion' => pick('Talk', 'نقاش'),
    'challenge' => pick('Challenge', 'تحدٍ'),
    _ => type,
  };

  String pagesCount(int count) => pick('$count pages', '$count صفحة');
  String readMinutes(int minutes) =>
      pick('$minutes min read', 'قراءة $minutes دقائق');
  String worldDepth(int characters, int locations) =>
      pick('$characters characters · $locations places', '$characters شخصية · $locations مواقع');

  String get myProfile => pick('My profile', 'ملفي');
  String get profile => pick('Profile', 'الملف');
  String get editProfile => pick('Edit profile', 'تعديل الملف');
  String get shareProfile => pick('Share profile', 'مشاركة الملف');
  String get copyLink => pick('Copy link', 'نسخ الرابط');
  String get respect => pick('Respect', 'احترام');
  String get fans => pick('Fans', 'المعجبون');
  String get friends => pick('Friends', 'الأصدقاء');
  String get friendRequests => pick('Friend requests', 'طلبات الصداقة');
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
  String get groupUnavailable => pick('Group unavailable', 'المجموعة غير متاحة');
  String get groupFailed => pick('Group could not load.', 'تعذّر تحميل المجموعة.');
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
  String get invitationRequired =>
      pick('Invitation required', 'الدعوة مطلوبة');
  String get invitationRequiredMessage => pick(
    'Use a valid group invitation to join.',
    'استخدم دعوة صالحة للانضمام.',
  );
  String get disbandGroup => pick('Disband group', 'تفكيك المجموعة');
  String disbandTitle(String name) =>
      pick('Disband $name?', 'تفكيك $name؟');
  String get disbandMessage => pick(
    'This removes the group and cannot be undone.',
    'سيُحذف المجتمع ولا يمكن التراجع.',
  );
  String get continueLabel => pick('Continue', 'متابعة');
  String get cancel => pick('Cancel', 'إلغاء');
  String get finalConfirmation =>
      pick('Final confirmation', 'تأكيد أخير');
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
    'founder' => pick('Founder', 'المؤسس'),
    'shogun' => pick('Shogun', 'شوغون'),
    'commander' => pick('Commander', 'قائد'),
    'captain' => pick('Captain', 'كابتن'),
    'sensei' => pick('Sensei', 'سينسي'),
    'senpai' => pick('Senpai', 'سينباي'),
    'member' => pick('Member', 'عضو'),
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
  String get messageForwarded => pick('Message forwarded', 'أُعيد توجيه الرسالة');
  String get forwardFailed => pick('Forward failed.', 'فشل إعادة التوجيه.');
  String get cannotReportOwn => pick(
    'You cannot report your own message.',
    'لا يمكنك الإبلاغ عن رسالتك.',
  );
  String get changeRole => pick('Change role', 'تغيير الرتبة');
  String get kick => pick('Kick', 'طرد');
  String get ban => pick('Ban', 'حظر');
  String get transferOwnership =>
      pick('Transfer ownership', 'نقل الملكية');
}
