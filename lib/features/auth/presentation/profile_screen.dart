import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/responsive.dart';
import '../application/auth_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _profileForm = GlobalKey<FormState>();
  final _passwordForm = GlobalKey<FormState>();
  late final _name = TextEditingController(text: ref.read(currentUserProvider)?.name);
  late final _phone = TextEditingController(text: ref.read(currentUserProvider)?.phone);
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _saving = false;
  bool _changing = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _current, _next]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_profileForm.currentState!.validate()) return;
    setState(() => _saving = true);
    await runWithFeedback(
      context,
      () => ref.read(authRepositoryProvider).updateOwnProfile(name: _name.text, phone: _phone.text),
      success: 'تم حفظ البيانات',
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _changePassword() async {
    if (!_passwordForm.currentState!.validate()) return;
    setState(() => _changing = true);
    final ok = await runWithFeedback(
      context,
      () async {
        await ref.read(authRepositoryProvider).changePassword(_current.text, _next.text);
        return true;
      },
      success: 'تم تغيير كلمة المرور',
    );
    if (ok == true) {
      _current.clear();
      _next.clear();
    }
    if (mounted) setState(() => _changing = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider)!;
    final profile = Form(
      key: _profileForm,
      child: FormSection(
        title: 'البيانات الشخصية',
        children: [
          InfoRow(label: 'البريد الإلكتروني', value: Text(user.email)),
          InfoRow(label: 'الدور', value: Text(user.roleName)),
          AppTextField(label: 'الاسم', controller: _name, validator: (v) => Validators.required(v, 'الاسم')),
          AppTextField(label: 'الهاتف', controller: _phone, validator: Validators.phone, keyboardType: TextInputType.phone),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: PrimaryButton(label: 'حفظ', icon: Symbols.save, onPressed: _saveProfile, loading: _saving),
          ),
        ],
      ),
    );
    final password = Form(
      key: _passwordForm,
      child: FormSection(
        title: 'تغيير كلمة المرور',
        children: [
          AppTextField(label: 'كلمة المرور الحالية', controller: _current, obscure: true,
              validator: (v) => (v == null || v.isEmpty) ? 'مطلوبة.' : null),
          AppTextField(label: 'كلمة المرور الجديدة', controller: _next, obscure: true, validator: Validators.password),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: PrimaryButton(label: 'تغيير', icon: Symbols.key, onPressed: _changePassword, loading: _changing),
          ),
        ],
      ),
    );
    return PageScaffold(
      title: 'الملف الشخصي',
      maxWidth: 1000,
      body: context.isMobile
          ? Column(children: [profile, const SizedBox(height: 16), password])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: profile),
                const SizedBox(width: 16),
                Expanded(child: password),
              ],
            ),
    );
  }
}
