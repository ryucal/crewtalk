import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';

class AuthLineField extends StatelessWidget {
  final String label;
  final String placeholder;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  const AuthLineField({
    super.key,
    required this.label,
    required this.placeholder,
    this.focusNode,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    required this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textHint,
            letterSpacing: 1.5,
          ),
        ),
        TextField(
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 16, color: Colors.black),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 16),
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            counterText: '',
          ),
        ),
      ],
    );
  }
}

class AuthLineDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const AuthLineDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textHint,
            letterSpacing: 1.5,
          ),
        ),
        // 드롭다운 선택값을 부모 state와 동기화하려면 value 사용 (initialValue는 초기 1회만)
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: value,
          hint: const Text(
            '소속 선택',
            style: TextStyle(color: AppColors.textLight, fontSize: 16),
          ),
          items: items
              .map(
                (name) => DropdownMenuItem(
                  value: name,
                  child: Text(name, style: const TextStyle(fontSize: 16)),
                ),
              )
              .toList(),
          onChanged: onChanged,
          style: const TextStyle(fontSize: 16, color: Colors.black),
          decoration: const InputDecoration(
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 1.5),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textHint),
        ),
      ],
    );
  }
}

class AuthBlackButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const AuthBlackButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0xFFCCCCCC) : Colors.black,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class PhoneHyphenFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    String formatted;
    if (digits.length <= 3) {
      formatted = digits;
    } else if (digits.length <= 7) {
      formatted = '${digits.substring(0, 3)}-${digits.substring(3)}';
    } else {
      final end = digits.length.clamp(0, 11);
      formatted =
          '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, end)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
