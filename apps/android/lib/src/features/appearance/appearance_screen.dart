import 'package:flutter/material.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({
    required this.initialSettings,
    required this.saving,
    required this.onContinue,
    this.error,
    super.key,
  });

  final AppearanceSettings initialSettings;
  final bool saving;
  final String? error;
  final Future<void> Function(AppearanceSettings) onContinue;

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late AppearanceSettings _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialSettings;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 48 : 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.soup_kitchen,
                        color: Theme.of(context).colorScheme.primary,
                        size: 34,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Make Soup yours',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Choose how Soup will look after you sign in. You can change this later in Settings.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  Text('Layout', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _FruityCard(selected: _draft.preset == UiPreset.fruity),
                  const SizedBox(height: 28),
                  Text(
                    'Colour palette',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final palette in PaletteFamily.values)
                        _PaletteChoice(
                          palette: palette,
                          selected: _draft.palette == palette,
                          onSelected: () => setState(
                            () => _draft = _draft.copyWith(palette: palette),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Brightness',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<AppearanceBrightness>(
                    key: const ValueKey('appearance-brightness'),
                    segments: const [
                      ButtonSegment(
                        value: AppearanceBrightness.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: AppearanceBrightness.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {_draft.brightness},
                    onSelectionChanged: widget.saving
                        ? null
                        : (selection) => setState(
                            () => _draft = _draft.copyWith(
                              brightness: selection.single,
                            ),
                          ),
                  ),
                  if (widget.error case final error?) ...[
                    const SizedBox(height: 20),
                    Text(
                      error,
                      key: const ValueKey('appearance-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      key: const ValueKey('appearance-continue'),
                      autofocus: true,
                      onPressed: widget.saving
                          ? null
                          : () async => widget.onContinue(_draft),
                      icon: widget.saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward),
                      label: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FruityCard extends StatelessWidget {
  const _FruityCard({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      label: 'Fruity layout',
      child: Container(
        key: const ValueKey('fruity-layout-choice'),
        width: 360,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.primary, width: 3),
        ),
        child: const Row(
          children: [
            Icon(Icons.auto_awesome, size: 34),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fruity', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Spacious, cinematic and focused on your artwork.'),
                ],
              ),
            ),
            Icon(Icons.check_circle),
          ],
        ),
      ),
    );
  }
}

class _PaletteChoice extends StatelessWidget {
  const _PaletteChoice({
    required this.palette,
    required this.selected,
    required this.onSelected,
  });

  final PaletteFamily palette;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (palette) {
      PaletteFamily.soup => ('Soup', const Color(0xFFFC7814)),
      PaletteFamily.ocean => ('Ocean', const Color(0xFF1E88E5)),
      PaletteFamily.grove => ('Grove', const Color(0xFF2E7D32)),
      PaletteFamily.mono => ('Mono', const Color(0xFF6B7280)),
    };
    return ChoiceChip(
      key: ValueKey('palette-${palette.name}'),
      selected: selected,
      onSelected: (_) => onSelected(),
      avatar: CircleAvatar(backgroundColor: color),
      label: Text(label),
    );
  }
}
