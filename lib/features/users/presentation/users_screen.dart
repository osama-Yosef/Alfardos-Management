import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/firebase/firebase_providers.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/app_user.dart';
import '../data/users_repository.dart';

final usersRepositoryProvider = Provider((ref) => UsersRepository(ref.watch(firestoreProvider)));
final usersProvider = StreamProvider.autoDispose((ref) => ref.watch(usersRepositoryProvider).watchUsers());
final rolesProvider = StreamProvider.autoDispose((ref) => ref.watch(usersRepositoryProvider).watchRoles());

class UsersScreen extends ConsumerStatefulWidget {
  const UsersScreen({super.key});

  @override
  ConsumerState<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends ConsumerState<UsersScreen> {
  bool _roles = false;

  @override
  Widget build(BuildContext context) {
    return PageScaffold(
      title: 'المستخدمون والصلاحيات',
      actions: [
        FilledButton.icon(
          onPressed: () => _roles
              ? AppDialog.show(context, title: 'دور جديد', maxWidth: 720, child: const _RoleForm())
              : AppDialog.show(context, title: 'إضافة مستخدم', child: const _NewUserForm()),
          icon: const Icon(Symbols.add),
          label: Text(_roles ? 'دور جديد' : 'مستخدم جديد'),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('المستخدمون'), icon: Icon(Symbols.group)),
              ButtonSegment(value: true, label: Text('الأدوار والصلاحيات'), icon: Icon(Symbols.admin_panel_settings)),
            ],
            selected: {_roles},
            onSelectionChanged: (s) => setState(() => _roles = s.first),
          ),
          const SizedBox(height: 14),
          _roles ? const _RolesList() : const _UsersList(),
        ],
      ),
    );
  }
}

class _UsersList extends ConsumerWidget {
  const _UsersList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)!;
    return AsyncView<List<AppUser>>(
      value: ref.watch(usersProvider),
      data: (users) => Card(
        child: Column(
          children: [
            for (var i = 0; i < users.length; i++) ...[
              if (i > 0) const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primarySoft,
                  child: Text(users[i].name.isEmpty ? '?' : users[i].name.characters.first,
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
                title: Row(children: [
                  Flexible(child: Text(users[i].name + (users[i].uid == me.uid ? ' (أنت)' : ''))),
                  const SizedBox(width: 8),
                  StatusBadge.active(users[i].active),
                ]),
                subtitle: Text('${users[i].email} • ${users[i].roleName}'),
                trailing: const Icon(Symbols.edit, size: 20),
                onTap: () => AppDialog.show(
                  context,
                  title: 'تعديل ${users[i].name}',
                  child: _EditUserForm(user: users[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NewUserForm extends ConsumerStatefulWidget {
  const _NewUserForm();

  @override
  ConsumerState<_NewUserForm> createState() => _NewUserFormState();
}

class _NewUserFormState extends ConsumerState<_NewUserForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  Role? _role;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runWithFeedback(context, () async {
      await ref.read(usersRepositoryProvider).createUser(
            name: _name.text,
            email: _email.text,
            password: _password.text,
            role: _role!,
            admin: ref.read(currentUserProvider)!,
          );
      return true;
    }, success: 'تم إنشاء المستخدم. أرسل له البريد وكلمة المرور ليسجل الدخول.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(rolesProvider).value ?? const [];
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(label: 'الاسم', controller: _name, validator: (v) => Validators.required(v, 'الاسم')),
          const SizedBox(height: 14),
          AppTextField(label: 'البريد الإلكتروني', controller: _email, validator: Validators.email,
              keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr),
          const SizedBox(height: 14),
          AppTextField(label: 'كلمة المرور المؤقتة', controller: _password, validator: Validators.password),
          const SizedBox(height: 14),
          AppDropdown<Role>(
            label: 'الدور',
            items: roles,
            value: _role,
            itemLabel: (r) => r.name,
            validator: (v) => v == null ? 'اختر الدور.' : null,
            onChanged: (r) => setState(() => _role = r),
          ),
          const SizedBox(height: 20),
          PrimaryButton(label: 'إنشاء المستخدم', onPressed: _save, loading: _saving, expand: true),
        ],
      ),
    );
  }
}

class _EditUserForm extends ConsumerStatefulWidget {
  const _EditUserForm({required this.user});
  final AppUser user;

  @override
  ConsumerState<_EditUserForm> createState() => _EditUserFormState();
}

class _EditUserFormState extends ConsumerState<_EditUserForm> {
  Role? _role;
  late bool _active = widget.user.active;
  bool _saving = false;

  Future<void> _save() async {
    if (_role == null) return;
    setState(() => _saving = true);
    final ok = await runWithFeedback(context, () async {
      await ref.read(usersRepositoryProvider).updateUser(
            widget.user,
            role: _role!,
            active: _active,
            admin: ref.read(currentUserProvider)!,
          );
      return true;
    }, success: 'تم الحفظ');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final roles = ref.watch(rolesProvider).value ?? const [];
    _role ??= roles.where((r) => r.id == widget.user.roleId).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.user.email),
        const SizedBox(height: 14),
        AppDropdown<Role>(
          label: 'الدور',
          items: roles,
          value: _role,
          itemLabel: (r) => r.name,
          onChanged: (r) => setState(() => _role = r),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('الحساب مفعل'),
          subtitle: const Text('إيقاف الحساب يمنع صاحبه من الدخول وتنفيذ أي عملية فوراً.'),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
        const SizedBox(height: 16),
        PrimaryButton(label: 'حفظ', onPressed: _save, loading: _saving, expand: true),
      ],
    );
  }
}

class _RolesList extends ConsumerWidget {
  const _RolesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView<List<Role>>(
      value: ref.watch(rolesProvider),
      data: (roles) => Card(
        child: Column(
          children: [
            for (var i = 0; i < roles.length; i++) ...[
              if (i > 0) const Divider(),
              ListTile(
                leading: const Icon(Symbols.admin_panel_settings, color: AppColors.primary),
                title: Text(roles[i].name),
                subtitle: Text(roles[i].permissions.contains(Permission.admin.id)
                    ? 'كل الصلاحيات'
                    : '${roles[i].permissions.length} صلاحية'),
                trailing: const Icon(Symbols.edit, size: 20),
                onTap: () => AppDialog.show(
                  context,
                  title: 'تعديل دور ${roles[i].name}',
                  maxWidth: 720,
                  child: _RoleForm(role: roles[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleForm extends ConsumerStatefulWidget {
  const _RoleForm({this.role});
  final Role? role;

  @override
  ConsumerState<_RoleForm> createState() => _RoleFormState();
}

class _RoleFormState extends ConsumerState<_RoleForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.role?.name);
  late final Set<String> _perms = {...?widget.role?.permissions};
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final ok = await runWithFeedback(context, () async {
      await ref.read(usersRepositoryProvider).saveRole(
            existing: widget.role,
            name: _name.text,
            permissions: _perms,
            admin: ref.read(currentUserProvider)!,
          );
      return true;
    }, success: 'تم حفظ الدور وتحديث صلاحيات مستخدميه');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok == true) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = _perms.contains(Permission.admin.id);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(label: 'اسم الدور', controller: _name, validator: (v) => Validators.required(v, 'اسم الدور')),
          const SizedBox(height: 8),
          for (final group in PermissionGroup.values) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(group.label, style: Theme.of(context).textTheme.titleSmall),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in Permission.values.where((p) => p.group == group))
                  FilterChip(
                    label: Text(p.label),
                    selected: isAdmin || _perms.contains(p.id),
                    onSelected: isAdmin && p != Permission.admin
                        ? null
                        : (v) => setState(() => v ? _perms.add(p.id) : _perms.remove(p.id)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          PrimaryButton(label: 'حفظ الدور', onPressed: _save, loading: _saving, expand: true),
        ],
      ),
    );
  }
}
