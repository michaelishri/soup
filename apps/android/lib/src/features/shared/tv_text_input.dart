import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvTextEdit {
  const TvTextEdit({required this.text, required this.submitted});
  final String text;
  final bool submitted;
}

/// Android TV's IME must edit a native field to own remote navigation.
/// Phones continue to use the normal Flutter text fields.
class TvTextInput {
  const TvTextInput();
  static const _channel = MethodChannel('dev.michaelishri.soup/tv_text_input');

  Future<bool> isTelevision() async {
    try {
      return await _channel.invokeMethod<bool>('isTelevision') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<TvTextEdit?> edit({
    required String label,
    required String text,
    required bool obscureText,
    required bool isUrl,
    required bool next,
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>('edit', {
      'label': label,
      'text': text,
      'obscureText': obscureText,
      'isUrl': isUrl,
      'next': next,
    });
    if (result == null) return null;
    return TvTextEdit(
      text: result['text'] as String,
      submitted: result['submitted'] as bool,
    );
  }

  Future<void> dismiss() => _channel.invokeMethod<void>('dismiss');
}

/// A remote focus stop, separate from the native editing session. Merely
/// traversing the form never opens an IME or traps arrows in a text cursor.
class TvTextField extends StatefulWidget {
  const TvTextField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.onEdit,
    this.hint,
    this.enabled = true,
    this.obscureText = false,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String? hint;
  final bool enabled;
  final bool obscureText;
  final VoidCallback onEdit;

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final text = widget.obscureText
          ? '•' * widget.controller.text.length
          : widget.controller.text;
      return FocusableActionDetector(
        focusNode: widget.focusNode,
        enabled: widget.enabled,
        onFocusChange: (value) => setState(() => _focused = value),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              if (widget.enabled) widget.onEdit();
              return null;
            },
          ),
        },
        child: Semantics(
          label: widget.label,
          value: text,
          button: true,
          enabled: widget.enabled,
          onTap: widget.enabled ? widget.onEdit : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: widget.enabled ? widget.onEdit : null,
            child: ExcludeSemantics(
              child: InputDecorator(
                isFocused: _focused,
                isEmpty: text.isEmpty,
                decoration: InputDecoration(
                  labelText: widget.label,
                  enabled: widget.enabled,
                ),
                child: Text(
                  text.isEmpty ? widget.hint ?? '' : text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: text.isEmpty ? Theme.of(context).hintColor : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
