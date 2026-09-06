import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A numeric PIN field that displays one dedicated slot per configured digit.
class VaultPinInput extends StatefulWidget {
  const VaultPinInput({
    super.key,
    required this.controller,
    required this.label,
    required this.pinLength,
    this.autofocus = false,
    this.obscureText = true,
    this.errorText,
    this.onSubmitted,
  }) : assert(pinLength == 4 || pinLength == 6);

  final TextEditingController controller;
  final String label;
  final int pinLength;
  final bool autofocus;
  final bool obscureText;
  final String? errorText;
  final VoidCallback? onSubmitted;

  @override
  State<VaultPinInput> createState() => _VaultPinInputState();
}

class _VaultPinInputState extends State<VaultPinInput> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    _focusNode.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant VaultPinInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
    if (oldWidget.pinLength != widget.pinLength &&
        widget.controller.text.length > widget.pinLength) {
      widget.controller.clear();
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _focusNode
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final value = widget.controller.text;
    return Semantics(
      textField: true,
      label: widget.label,
      value: '${value.length} of ${widget.pinLength} digits entered',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 9),
          SizedBox(
            height: 58,
            child: Stack(
              children: [
                ExcludeSemantics(
                  child: Row(
                    children: List.generate(widget.pinLength, (index) {
                      final hasValue = index < value.length;
                      final active =
                          _focusNode.hasFocus &&
                          (index == value.length ||
                              (value.length == widget.pinLength &&
                                  index == widget.pinLength - 1));
                      return Expanded(
                        child: Container(
                          key: ValueKey('${widget.label}-pin-box-$index'),
                          margin: EdgeInsets.only(
                            right: index == widget.pinLength - 1 ? 0 : 7,
                          ),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: widget.errorText != null
                                  ? colorScheme.error
                                  : active
                                  ? colorScheme.primary
                                  : colorScheme.outlineVariant,
                              width: active ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            hasValue
                                ? (widget.obscureText ? '●' : value[index])
                                : '',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0,
                    child: TextField(
                      key: ValueKey('${widget.label}-pin-input'),
                      controller: widget.controller,
                      focusNode: _focusNode,
                      autofocus: widget.autofocus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: widget.pinLength,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(widget.pinLength),
                      ],
                      enableSuggestions: false,
                      autocorrect: false,
                      obscureText: widget.obscureText,
                      decoration: const InputDecoration(counterText: ''),
                      onSubmitted: (_) => widget.onSubmitted?.call(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.errorText != null) ...[
            const SizedBox(height: 6),
            Text(
              widget.errorText!,
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}
