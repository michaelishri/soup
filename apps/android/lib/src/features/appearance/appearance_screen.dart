import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:soup/src/data/appearance/appearance_settings.dart';
import 'package:soup/src/features/shared/soup_mark.dart';
import 'package:soup/src/features/connectivity/onboarding_backdrop.dart';

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
      body: OnboardingBackdrop(
        child: SafeArea(
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
                        const SoupMark(size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Make Soup yours',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Choose how Soup will look after you sign in. You can change this later in Settings.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Layout',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _LayoutCard(
                          key: const ValueKey('fruity-layout-choice'),
                          title: 'Fruity',
                          description:
                              'Spacious, cinematic and focused on your artwork.',
                          icon: PhosphorIconsRegular.sparkle,
                          selected: _draft.preset == UiPreset.fruity,
                          onSelected: () => setState(
                            () => _draft = _draft.copyWith(
                              preset: UiPreset.fruity,
                            ),
                          ),
                        ),
                        _LayoutCard(
                          key: const ValueKey('blockbuster-layout-choice'),
                          title: 'Blockbuster',
                          description:
                              'Bold billboards, dense shelves and quick browsing.',
                          icon: PhosphorIconsRegular.filmStrip,
                          selected: _draft.preset == UiPreset.blockbuster,
                          onSelected: () => setState(
                            () => _draft = _draft.copyWith(
                              preset: UiPreset.blockbuster,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                          icon: Icon(PhosphorIconsRegular.sun),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: AppearanceBrightness.dark,
                          icon: Icon(PhosphorIconsRegular.moon),
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
                        onPressed: widget.saving
                            ? null
                            : () async => widget.onContinue(_draft),
                        icon: widget.saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(PhosphorIconsRegular.arrowRight),
                        label: const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LayoutCard extends StatelessWidget {
  const _LayoutCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      label: '$title layout',
      child: InkWell(
        autofocus: selected,
        borderRadius: BorderRadius.circular(4),
        onTap: onSelected,
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: selected ? colors.secondaryContainer : colors.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(description),
                  ],
                ),
              ),
              if (selected) const Icon(PhosphorIconsFill.checkCircle),
            ],
          ),
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
