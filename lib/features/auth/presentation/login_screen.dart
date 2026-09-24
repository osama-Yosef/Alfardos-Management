import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/fields.dart';
import '../application/auth_providers.dart';
import 'auth_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signIn(_email.text, _password.text);
    } catch (e, s) {
      if (mounted) setState(() => _error = ErrorMapper.message(e, s));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialized = ref.watch(systemInitializedProvider);
    return AuthLayout(
      title: 'تسجيل الدخول',
      subtitle: 'مرحباً بك، سجّل الدخول لمتابعة أعمالك',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'البريد الإلكتروني',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Symbols.mail,
              validator: Validators.email,
              textInputAction: TextInputAction.next,
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'كلمة المرور',
              controller: _password,
              obscure: _obscure,
              prefixIcon: Symbols.lock,
              validator: (v) => (v == null || v.isEmpty) ? 'كلمة المرور مطلوبة.' : null,
              onSubmitted: (_) => _submit(),
              suffix: IconButton(
                tooltip: _obscure ? 'إظهار' : 'إخفاء',
                icon: Icon(_obscure ? Symbols.visibility : Symbols.visibility_off, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: () => context.go('/forgot-password'),
                child: const Text('نسيت كلمة المرور؟'),
              ),
            ),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger)),
              ),
              const SizedBox(height: 12),
            ],
            PrimaryButton(label: 'دخول', onPressed: _submit, loading: _loading, expand: true),
            if (initialized.value == false) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              const Text('لم يتم إعداد النظام بعد.', textAlign: TextAlign.center),
              TextButton(
                onPressed: () => context.go('/setup'),
                child: const Text('إعداد النظام لأول مرة وإنشاء حساب المدير'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
