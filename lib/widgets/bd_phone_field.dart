import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BdPhoneField extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final String? errorText;

  const BdPhoneField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.errorText,
  });

  static bool isValidBdMobileLocalPart(String s) {
    return RegExp(r'^1[3-9]\d{8}$').hasMatch(s.trim());
  }

  static String toE164(String localPart) => '+880${localPart.trim()}';

  @override
  State<BdPhoneField> createState() => _BdPhoneFieldState();
}

class _BdPhoneFieldState extends State<BdPhoneField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _showPrefix =>
      _focusNode.hasFocus || widget.controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(
        prefixText: _showPrefix ? '+880 ' : null,
        hintText: _showPrefix ? '1XXXXXXXXX' : '+880 ',
        errorText: widget.errorText,
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
