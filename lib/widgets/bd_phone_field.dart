import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BdPhoneField extends StatelessWidget {
  final TextEditingController controller; // user types only: 1XXXXXXXXX
  final bool enabled;
  final String? errorText;

  const BdPhoneField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.errorText,
  });

  static bool isValidBdMobileLocalPart(String s) {
    // After +880, BD mobile numbers are typically: 1[3-9]XXXXXXXX
    return RegExp(r'^1[3-9]\d{8}$').hasMatch(s.trim());
  }

  static String toE164(String localPart) => '+880${localPart.trim()}';

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(
        // ✅ NO labelText here (prevents the duplicated "Phone number" text)
        prefixText: '+880 ',
        hintText: '1XXXXXXXXX',
        errorText: errorText,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
