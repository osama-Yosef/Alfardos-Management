import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../features/settings/application/settings_providers.dart';
import '../utils/dates.dart';
import '../utils/validators.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.hint,
    this.prefixIcon,
    this.suffix,
    this.maxLines = 1,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.inputFormatters,
    this.helper,
    this.readOnly = false,
    this.onTap,
    this.textDirection,
  });

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffix;
  final int maxLines;
  final bool obscure;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final String? helper;
  final bool readOnly;
  final VoidCallback? onTap;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      validator: validator,
      onChanged: onChanged,
      keyboardType: keyboardType,
      maxLines: obscure ? 1 : maxLines,
      obscureText: obscure,
      enabled: enabled,
      autofocus: autofocus,
      readOnly: readOnly,
      onTap: onTap,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      textDirection: textDirection,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
        suffixIcon: suffix,
      ),
    );
  }
}

/// Money input: numeric keyboard, currency suffix, amount validation.
class AmountField extends ConsumerWidget {
  const AmountField({
    super.key,
    required this.label,
    required this.controller,
    this.required = true,
    this.allowZero = false,
    this.allowNegative = false,
    this.max,
    this.maxMessage,
    this.onChanged,
    this.helper,
    this.autofocus = false,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final bool required;
  final bool allowZero;
  final bool allowNegative;
  final int? max;
  final String? maxMessage;
  final ValueChanged<String>? onChanged;
  final String? helper;
  final bool autofocus;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final symbol = ref.watch(companySettingsProvider).currencySymbol;
    return AppTextField(
      label: label,
      controller: controller,
      autofocus: autofocus,
      enabled: enabled,
      helper: helper,
      keyboardType: TextInputType.numberWithOptions(decimal: true, signed: allowNegative),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹.,٫\-]')),
      ],
      textDirection: TextDirection.ltr,
      validator: (v) => Validators.amount(
        v,
        required: required,
        allowZero: allowZero,
        allowNegative: allowNegative,
        max: max,
        maxMessage: maxMessage,
      ),
      onChanged: onChanged,
      suffix: symbol.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Align(
                widthFactor: 1,
                alignment: Alignment.center,
                child: Text(symbol, style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
    );
  }
}

/// Debounced search box.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.onChanged,
    this.hint = 'بحث...',
    this.autofocus = false,
    this.initial = '',
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final bool autofocus;
  final String initial;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final _controller = TextEditingController(text: widget.initial);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _changed(String v) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => widget.onChanged(v.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: widget.autofocus,
      onChanged: _changed,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Symbols.search, size: 20),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'مسح',
                icon: const Icon(Symbols.close, size: 18),
                onPressed: () {
                  _controller.clear();
                  _changed('');
                },
              ),
      ),
    );
  }
}

/// Read-only field that opens a date picker.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: firstDate ?? DateTime(2015),
          lastDate: lastDate ?? DateTime.now().add(const Duration(days: 1)),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Symbols.calendar_today, size: 20),
        ),
        child: Text(Dates.format(value)),
      ),
    );
  }
}

/// Dropdown bound to a list of items.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.itemLabel,
    required this.onChanged,
    this.validator,
    this.prefixIcon,
  });

  final String label;
  final List<T> items;
  final T? value;
  final String Function(T) itemLabel;
  final ValueChanged<T?>? onChanged;
  final FormFieldValidator<T>? validator;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item, child: Text(itemLabel(item), overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged,
    );
  }
}
