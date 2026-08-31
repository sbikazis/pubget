import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_theme.dart';

import '../../widgets/app_button.dart';
import '../../widgets/info_tooltipe.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    

    return Scaffold(
      appBar: AppBar(
        title: const Text("دليل Pubget"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [

                  _sectionTitle(context, "ما هو Pubget؟"),

                  _sectionText(
                    context,
                    "Pubget هو تطبيق مجتمع لمحبي الأنمي حيث يمكنك الانضمام إلى المجموعات "
                    "والدردشة مع المعجبين الآخرين ولعب لعبة تخمين الشخصيات وبناء سمعتك "
                    "داخل المجتمع عبر نقاط الإحترام.",
                  ),
                  const SizedBox(height: 10),

                  const InfoTooltip(
                    message:
                        "ملاحظة : هذه هي النسخة الأولى من التطبيق نعدكم أن نضيف مزايا أخرى ستنال إعجابكم",
                  ),

                  const SizedBox(height: 24),
                  

                  _sectionTitle(context, "الصفحة الرئيسية"),

                  _sectionText(
                    context,
                    "الصفحة الرئيسية هي المكان الذي يمكنك من خلاله اكتشاف المجموعات "
                    "المقترحة والوصول إلى مجموعاتك والتحقق من الإشعارات وبدء الدردشات الخاصة.",
                  ),

                  const SizedBox(height: 10),

                  const InfoTooltip(
                    message:
                        "المجموعات المروّجة تظهر أولاً حتى تتمكن المجتمعات الجديدة من النمو بشكل أسرع.",
                  ),

                  const SizedBox(height: 24),

                  _sectionTitle(context, "المجموعات"),

                  _sectionText(
                    context,
                    "المجموعات هي قلب التطبيق. يمكنك إنشاء مجموعتك الخاصة أو الانضمام قد تنال إعجابك "
                    "هناك ثلاث أنواع من المجموعات , أولا المجموعات العامة وهي مجموعات عادية تدخلها بهويتك الخاصة"
                    "ثانية مجموعات تقمص الدور المخصصة و التي تدخلها بإسم شخصية محددة من الأنمي المرتبط بالمجموعة"
                    "ثالث مجموعات تقمص الدور المفتوحة نفس المجموعات المخصصة ولاكن غير مرتبطة بأنمي محدد",
                  ),

                  const SizedBox(height: 24),

                  _sectionTitle(context, "مجموعات تقمص الأدوار"),

                  _sectionText(
                    context,
                    "في مجموعات تقمص الأدوار يجب على كل عضو اختيار شخصية من الأنمي. "
                    "لا يمكن تكرار الشخصيات، لذلك عندما يتم اختيار شخصية فإنها تصبح "
                    "محجوزة لبقية الأعضاء.",
                  ),

                  const SizedBox(height: 10),

                  const InfoTooltip(
                    message:
                        "تأكد من أن اسم الشخصية موجود فعلاً في الأنمي ومن الأفضل إنسخها كما هي من MAL قبل إرسال طلب الانضمام.",
                  ),

                  const SizedBox(height: 24),

                  _sectionTitle(context, "نظام الرتب"),

                  _sectionText(
                    context,
                    "كل مجموعة تحتوي على نظام رتب ينظم الأعضاء والمسؤوليات داخل المجموعة.",
                  ),

                  const SizedBox(height: 10),

                  _rankItem("الشوغو", "مؤسس المجموعة."),
                  _rankItem("السينسي", "مشرفون بمستوى عالٍ."),
                  _rankItem("الهاكوشو", "مساعدون في إدارة المجموعة."),
                  _rankItem("السينباي", "أعضاء محترمون داخل المجتمع."),
                  _rankItem("عضو", "أعضاء المجتمع العاديون."),

                  const SizedBox(height: 24),

                  _sectionTitle(context, "نقاط الإحترام"),

                  _sectionText(
                    context,
                    "يمكن للأعضاء تقييم بعضهم البعض بنقاط إحترام من 0 إلى 7. "
                    "إذا تجاوز شخص ما 5 نقاط فإنه يحصل على حالة معجب "
                    "وتُفتح إمكانية الدردشة الخاصة معه.",
                  ),

                  const SizedBox(height: 24),

                  _sectionTitle(context, "نظام الدردشة"),

                  _sectionText(
                    context,
                    "دردشات المجموعات تعمل بطريقة مشابهة لتطبيقات المراسلة الحديثة. "
                    "يمكنك إرسال الرسائل والصور وحتى .",
                  ),

                  const SizedBox(height: 10),

                  const InfoTooltip(
                    message:
                        "تظهر رتب الأعضاء بجانب أسمائهم مع شارات مميزة حتى تتمكن من معرفة القيادات بسهولة.",
                  ),

                  const SizedBox(height: 24),

                  _sectionTitle(context, "لعبة تخمين الشخصية"),

                  _sectionText(
                    context,
                    "داخل المجموعات يمكنك بدء فعالية تخمين شخصية الأنمي. "
                    "يقوم اللاعبون بطرح أسئلة بنعم أو لا حتى يتمكن أحدهم من تخمين الشخصية الصحيحة.",
                  ),

                  const SizedBox(height: 24),

                  _sectionTitle(context, "نصائح"),

                  _sectionText(
                    context,
                    "• كن محترماً مع بقية الأعضاء\n"
                    "• قم بدعوة أصدقائك لترتقي في رتب المجموعة\n"
                    "• شارك في الفعاليات لجعل المجتمع أكثر نشاطاً\n"
                    "• تجنب الإزعاج أو مخالفة القواعد",
                  ),

                  const SizedBox(height: 40),

                  AppButton(
                    text: "فهمت",
                    icon: Icons.check,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: AppTextTheme.lightTextTheme.headlineMedium?.copyWith(
        color: AppColors.primary,
      ),
    );
  }

  Widget _sectionText(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: AppTextTheme.lightTextTheme.bodyMedium,
      ),
    );
  }

  Widget _rankItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Icon(
            Icons.star,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              "$title — $description",
              style: AppTextTheme.lightTextTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}