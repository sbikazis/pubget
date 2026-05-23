import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/group_model.dart';
import '../../models/user_model.dart';
import '../../models/member_model.dart';
import '../../models/invite_model.dart';

import '../../providers/group_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/home_provider.dart';

import '../../services/firebase/firestore_service.dart';
import '../../services/firebase/storage_service.dart';
import '../../services/api/anime_api_service.dart';

import '../../core/logic/group_join_validator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/roles.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/constants/group_type.dart';

import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_textfield.dart';
import '../../widgets/empty_state_widget.dart';

class RoleplayJoinScreen extends StatefulWidget {
  final GroupModel group;
  final InviteModel? invite;

  const RoleplayJoinScreen({
    super.key,
    required this.group,
    this.invite,
  });

  @override
  State<RoleplayJoinScreen> createState() => _RoleplayJoinScreenState();
}

class _RoleplayJoinScreenState extends State<RoleplayJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _inviterController = TextEditingController();

  // ── الشخصية المختارة
  int? _selectedCharId;
  String? _selectedCharName;
  String? _selectedCharImageUrl;

  File? _pickedImage;
  bool _isProcessing = false;
  bool _isLoadingCharacters = false;
  bool _hasInviter = false;

  // ── الشخصيات المحجوزة داخل المجموعة
  Set<String> _reservedCharacterNames = {};

  final ImagePicker _picker = ImagePicker();

  // ─────────────────────────────────────────────
  // INIT - جلب الشخصيات المحجوزة
  // ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadReservedCharacters();
  }

  Future<void> _loadReservedCharacters() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestorePaths.groupCharacters(widget.group.id))
          .get();
      final reserved = <String>{};
      for (final doc in snapshot.docs) {
        reserved.add(doc.id); // الـ key هو _normalizeCharacterKey
      }
      if (mounted) setState(() => _reservedCharacterNames = reserved);
    } catch (e) {
      debugPrint("⚠️ Failed to load reserved characters: $e");
    }
  }

  // ─────────────────────────────────────────────
  // NORMALIZE KEY (نفس منطق group_join_validator)
  // ─────────────────────────────────────────────

  String _normalizeKey(String name) {
    final words = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .split(RegExp(r'\s+'))
      ..sort();
    return words.join('');
  }

  bool _isReserved(String characterName) {
    return _reservedCharacterNames.contains(_normalizeKey(characterName));
  }

  // ─────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────

  @override
  void dispose() {
    _reasonController.dispose();
    _inviterController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // PICK IMAGE
  // ─────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
      });
    }
  }

  // ─────────────────────────────────────────────
  // SHOW AVAILABLE CHARACTERS
  // ─────────────────────────────────────────────

  Future<void> _showAvailableCharacters() async {
    setState(() => _isLoadingCharacters = true);

    try {
      final List<int> idsToFetch =
          (widget.group.franchiseIds?.cast<int>() ?? []).toList();
      if (widget.group.animeId != null) {
        final int mainId = int.tryParse(widget.group.animeId.toString()) ?? 0;
        if (mainId != 0 && !idsToFetch.contains(mainId)) {
          idsToFetch.add(mainId);
        }
      }

      final characters =
          await AnimeApiService.getAnimeCharacters(animeIds: idsToFetch);

      if (mounted) setState(() => _isLoadingCharacters = false);

      if (characters.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('لم نجد شخصيات لهذا الأنمي، حاول لاحقاً')),
          );
        }
        return;
      }

      if (mounted) _showCharacterSheet(characters);
    } catch (e) {
      debugPrint("Error loading characters: $e");
      if (mounted) setState(() => _isLoadingCharacters = false);
    }
  }

  // ─────────────────────────────────────────────
  // CHARACTER SHEET مع إظهار المحجوز
  // ─────────────────────────────────────────────

  void _showCharacterSheet(List<Map<String, dynamic>> characters) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  const Icon(Icons.people_alt_outlined,
                      color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'شخصيات ${widget.group.animeName ?? "الأنمي"}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ]),
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'الشخصيات الرمادية محجوزة بالفعل',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const Divider(height: 24),
              Flexible(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: characters.length,
                  itemBuilder: (context, index) {
                    final char = characters[index];
                    final String charName = char['name'] ?? '';
                    final bool reserved = _isReserved(charName);

                    return GestureDetector(
                      onTap: () {
                        if (reserved) {
                          // ── محجوزة: أظهر رسالة فقط
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  '"$charName" محجوزة بالفعل داخل هذه المجموعة'),
                              backgroundColor: Colors.red.shade400,
                            ),
                          );
                          return;
                        }
                        // ── متاحة: اختر
                        Navigator.pop(context);
                        setState(() {
                          _selectedCharId = char['id'];
                          _selectedCharName = charName;
                          _selectedCharImageUrl = char['imageUrl'];
                          _pickedImage = null;
                        });
                      },
                      child: Opacity(
                        opacity: reserved ? 0.35 : 1.0,
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: char['imageUrl'] != null &&
                                            char['imageUrl']!.isNotEmpty
                                        ? Image.network(
                                            char['imageUrl']!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              color: Colors.grey.shade300,
                                              child: const Icon(Icons.person,
                                                  size: 30),
                                            ),
                                          )
                                        : Container(
                                            color: Colors.grey.shade300,
                                            child: const Icon(Icons.person,
                                                size: 30),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  charName,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            // ── أيقونة القفل على المحجوزة
                            if (reserved)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.lock,
                                      size: 12, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // SUBMIT JOIN REQUEST
  // ─────────────────────────────────────────────

  Future<void> _submitJoinRequest(UserModel currentUser) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCharName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('الرجاء اختيار شخصيتك من قائمة الشخصيات أولاً')),
      );
      return;
    }

    final hasImage = _pickedImage != null ||
        (_selectedCharImageUrl != null &&
            _selectedCharImageUrl!.isNotEmpty);

    try {
      setState(() => _isProcessing = true);

      final groupProvider = context.read<GroupProvider>();
      final homeProvider = context.read<HomeProvider>();
      final firestore = context.read<FirestoreService>();
      final storage = context.read<StorageService>();

      final inviterName =
          _hasInviter ? _inviterController.text.trim() : null;
      final reason = _reasonController.text.trim();

      final validator = GroupJoinValidator(firestoreService: firestore);

      final validation = await validator.validateJoin(
        user: currentUser,
        currentJoinedGroupsCount: homeProvider.joinedGroups.length,
        groupId: widget.group.id,
        groupType: widget.group.type,
        characterName: _selectedCharName,
        characterImageUrl: hasImage ? 'valid' : null,
        animeName: widget.group.animeName,
        animeId: widget.group.animeId,
        franchiseIds: widget.group.franchiseIds?.cast<int>(),
        inviterName: inviterName,
      );

      if (!validation.isValid) {
        if (mounted) setState(() => _isProcessing = false);
        if (!mounted) return;
        await AppDialog.show(
          context,
          title: validation.shouldShowUpgrade ? 'ترقية الحساب' : 'تنبيه',
          content: validation.errorMessage ?? 'فشل التحقق من البيانات.',
          confirmText:
              validation.shouldShowUpgrade ? 'ترقية الآن' : 'حسناً',
          onConfirm: () =>
              Navigator.of(context, rootNavigator: true).pop(),
        );
        return;
      }

      String? finalImageUrl = _selectedCharImageUrl;
      if (_pickedImage != null) {
        finalImageUrl = await storage.uploadRoleplayCharacterImage(
          groupId: widget.group.id,
          userId: currentUser.id,
          file: _pickedImage!,
        );
      }

      final String finalRealName = currentUser.username.isNotEmpty
          ? currentUser.username
          : 'مستخدم جديد';

      String? finalInviterId = validation.foundInviterId;
      if (finalInviterId == currentUser.id) finalInviterId = null;

      final memberRequest = MemberModel(
        userId: currentUser.id,
        groupId: widget.group.id,
        role: Roles.member,
        joinedAt: DateTime.now(),
        displayName: _selectedCharName,
        characterName: _selectedCharName,
        characterImageUrl: finalImageUrl,
        characterReason: reason.isNotEmpty ? reason : null,
        realUserName: finalRealName,
        realUserImageUrl: currentUser.avatarUrl,
        invitedByUserId: finalInviterId,
        isPremium: currentUser.isPremium,
      );

      await groupProvider.sendJoinRequest(
        groupId: widget.group.id,
        groupName: widget.group.name,
        founderId: widget.group.founderId,
        memberRequest: memberRequest,
      );

      if (widget.invite != null) {
        await firestore.deleteDocument(
          path: FirestorePaths.groupInvites(widget.group.id),
          docId: widget.invite!.inviteId,
        );
      }

      if (mounted) setState(() => _isProcessing = false);
      if (!mounted) return;

      await AppDialog.show(
        context,
        title: 'تم إرسال الطلب',
        content:
            'لقد تم إرسال طلبك بنجاح. سيقوم الشوغو بمراجعته وقبوله قريباً!',
        confirmText: 'حسناً',
        onConfirm: () {
          Navigator.of(context, rootNavigator: true).pop();
          Navigator.of(context).pop(true);
        },
      );
    } catch (e) {
      debugPrint("❌ Error in _submitJoinRequest: $e");
      if (mounted) setState(() => _isProcessing = false);
      if (!mounted) return;
      await AppDialog.show(
        context,
        title: 'فشل العملية',
        content:
            'حدث خطأ: ${e.toString().contains('Timeout') ? 'انتهت مهلة الاتصال، حاول مجدداً' : e.toString()}',
        confirmText: 'حسناً',
        onConfirm: () =>
            Navigator.of(context, rootNavigator: true).pop(),
      );
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final currentUser = userProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الانضمام كتقمص دور'),
        centerTitle: true,
        elevation: 0,
      ),
      body: currentUser == null
          ? const Center(
              child: EmptyStateWidget(
                title: 'يجب تسجيل الدخول',
                subtitle: 'سجل الدخول للانضمام كممثل.',
                icon: Icons.lock_outline,
              ),
            )
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [

                        // ── بانر اسم الأنمي
                        if (widget.group.type == GroupType.roleplay &&
                            widget.group.animeName != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.2)),
                              ),
                              child: Row(children: [
                                const Icon(Icons.movie_filter,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'هذه المجموعة تتبع أنمي: ${widget.group.animeName}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ),
                              ]),
                            ),
                          ),

                        // ── زر عرض الشخصيات المتاحة
                        SizedBox(
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _isLoadingCharacters || _isProcessing
                                ? null
                                : _showAvailableCharacters,
                            icon: _isLoadingCharacters
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Icon(Icons.people_alt_outlined),
                            label: Text(
                              _selectedCharName != null
                                  ? 'تغيير الشخصية'
                                  : 'عرض الشخصيات المتاحة',
                              style: const TextStyle(fontSize: 14),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ── بطاقة الشخصية المختارة
                        if (_selectedCharName != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(children: [
                              GestureDetector(
                                onTap: _isProcessing ? null : _pickImage,
                                child: Stack(children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _pickedImage != null
                                        ? Image.file(_pickedImage!,
                                            width: 55,
                                            height: 65,
                                            fit: BoxFit.cover)
                                        : (_selectedCharImageUrl != null &&
                                                _selectedCharImageUrl!
                                                    .isNotEmpty
                                            ? Image.network(
                                                _selectedCharImageUrl!,
                                                width: 55,
                                                height: 65,
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (_, __, ___) => Container(
                                                  width: 55,
                                                  height: 65,
                                                  color: Colors.grey.shade300,
                                                  child: const Icon(
                                                      Icons.person),
                                                ),
                                              )
                                            : Container(
                                                width: 55,
                                                height: 65,
                                                color: Colors.grey.shade300,
                                                child: const Icon(
                                                    Icons.person),
                                              )),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.edit,
                                          size: 10, color: Colors.white),
                                    ),
                                  ),
                                ]),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(_selectedCharName!,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14)),
                                    const SizedBox(height: 2),
                                    const Text(
                                        'اضغط على الصورة لتغييرها اختيارياً',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey)),
                                  ])),
                              const Icon(Icons.check_circle,
                                  color: Colors.green, size: 20),
                            ]),
                          ),

                        const SizedBox(height: 16),

                        // ── هل تمت دعوتك؟
                        SwitchListTile(
                          title: const Text(
                            'هل تمت دعوتك من قبل عضو؟',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                          value: _hasInviter,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: _isProcessing
                              ? null
                              : (val) =>
                                  setState(() => _hasInviter = val),
                        ),
                        if (_hasInviter) ...[
                          AppTextField(
                            label: 'اسم العضو الداعي',
                            placeholder: 'اكتب اسم العضو أو اسم شخصيته',
                            controller: _inviterController,
                            validator: (v) {
                              if (_hasInviter &&
                                  (v == null || v.trim().isEmpty)) {
                                return 'الرجاء إدخال اسم الداعي';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                        ],

                        // ── سبب الاختيار
                        AppTextField(
                          label: 'لماذا اخترت هذه الشخصية؟',
                          placeholder: 'اكتب سبب اختيارك (اختياري)',
                          controller: _reasonController,
                          isMultiline: true,
                        ),
                        const SizedBox(height: 24),

                        // ── أزرار
                        AppButton(
                          text: 'تقديم طلب الانضمام',
                          isLoading: _isProcessing,
                          onPressed: _isProcessing
                              ? null
                              : () => _submitJoinRequest(currentUser),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _isProcessing
                              ? null
                              : () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('إلغاء'),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),

                if (_isProcessing)
                  Positioned.fill(
                    child: Container(
                        color: Colors.black12,
                        child: const AbsorbPointer()),
                  ),
              ],
            ),
    );
  }
}
