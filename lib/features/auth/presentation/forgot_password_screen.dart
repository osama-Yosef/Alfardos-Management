import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/fields.dart';
import '../application/auth_providers.dart';
import 'auth_layout.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final ok = await runWithFeedback(
      context,
      () async {
        await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
        return true;
      },
    );
    if (mounted) {
      setState(() {
        _loading = false;
        _sent = ok ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'استعادة كلمة المرور',
      subtitle: 'أدخل بريدك الإلكتروني وسنرسل لك رابطاً لتعيين كلمة مرور جديدة',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_sent)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'إذا كان البريد مسجلاً لدينا فستصلك رسالة خلال دقائق. تحقق من صندوق البريد والرسائل غير المرغوب فيها.',
                  style: TextStyle(color: AppColors.success),
                ),
              ),
            AppTextField(
              label: 'البريد الإلكتروني',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Symbols.mail,
              validator: Validators.email,
              textDirection: TextDirection.ltr,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            PrimaryButton(label: 'إرسال رابط الاستعادة', onPressed: _submit, loading: _loading, expand: true),
            const SizedBox(height: 8),
            TextButton(onPressed: () => context.go('/login'), child: const Text('العودة لتسجيل الدخول')),
          ],
        ),
      ),
    );
  }
}
