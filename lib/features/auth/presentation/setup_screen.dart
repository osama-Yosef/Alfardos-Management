import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/fields.dart';
import '../application/auth_providers.dart';
import 'auth_layout.dart';

/// First-run wizard: company name, currency and the administrator account.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _form = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _currency = TextEditingController(text: 'ج.م');
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_company, _currency, _name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    await runWithFeedback(
      context,
      () => ref.read(authRepositoryProvider).setupFirstAdmin(
            companyName: _company.text,
            currencySymbol: _currency.text,
            name: _name.text,
            email: _email.text,
            password: _password.text,
          ),
      success: 'تم إعداد النظام بنجاح. مرحباً بك!',
    );
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'إعداد النظام لأول مرة',
      subtitle: 'أدخل بيانات الشركة وحساب المدير. يمكن تعديل الإعدادات لاحقاً.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'اسم الشركة / النشاط',
              controller: _company,
              prefixIcon: Symbols.storefront,
              validator: (v) => Validators.required(v, 'اسم الشركة'),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'رمز العملة',
              controller: _currency,
              prefixIcon: Symbols.payments,
              hint: 'مثال: ج.م ، ر.س ، \$',
              validator: (v) => Validators.required(v, 'رمز العملة'),
            ),
            const SizedBox(height: 22),
            AppTextField(
              label: 'اسم المدير',
              controller: _name,
              prefixIcon: Symbols.person,
              validator: (v) => Validators.required(v, 'الاسم'),
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'البريد الإلكتروني',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Symbols.mail,
              validator: Validators.email,
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'كلمة المرور',
              controller: _password,
              obscure: true,
              prefixIcon: Symbols.lock,
              validator: Validators.password,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'تأكيد كلمة المرور',
              controller: _confirm,
              obscure: true,
              prefixIcon: Symbols.lock,
              validator: (v) => v != _password.text ? 'كلمتا المرور غير متطابقتين.' : null,
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'إنشاء النظام', onPressed: _submit, loading: _loading, expand: true),
            TextButton(onPressed: () => context.go('/login'), child: const Text('لدي حساب بالفعل')),
          ],
        ),
      ),
    );
  }
}
