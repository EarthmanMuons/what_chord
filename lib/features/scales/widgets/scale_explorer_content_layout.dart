import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/core/core.dart';

class ScaleExplorerContentLayout extends StatelessWidget {
  const ScaleExplorerContentLayout({
    super.key,
    required this.isLandscape,
    required this.showScalePicker,
    required this.header,
    required this.toneRow,
    required this.tonicWheel,
    required this.viewControl,
    required this.chordsList,
    required this.scalePicker,
  });

  final bool isLandscape;
  final bool showScalePicker;
  final Widget header;
  final Widget toneRow;
  final Widget tonicWheel;
  final Widget viewControl;
  final Widget chordsList;
  final Widget Function({required bool scrollable}) scalePicker;

  @override
  Widget build(BuildContext context) {
    if (isLandscape) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 6,
            child: FadedScrollView(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [header, const SizedBox(height: 16), toneRow],
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: _LowerSection(
              scrollsAsOne: true,
              showScalePicker: showScalePicker,
              tonicWheel: tonicWheel,
              viewControl: viewControl,
              chordsList: chordsList,
              scalePicker: scalePicker,
              padding: const EdgeInsets.only(left: 12, top: 8),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 16),
        toneRow,
        const SizedBox(height: 16),
        Expanded(
          child: _LowerSection(
            scrollsAsOne: false,
            showScalePicker: showScalePicker,
            tonicWheel: tonicWheel,
            viewControl: viewControl,
            chordsList: chordsList,
            scalePicker: scalePicker,
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}

class _LowerSection extends StatelessWidget {
  const _LowerSection({
    required this.scrollsAsOne,
    required this.showScalePicker,
    required this.tonicWheel,
    required this.viewControl,
    required this.chordsList,
    required this.scalePicker,
    required this.padding,
  });

  final bool scrollsAsOne;
  final bool showScalePicker;
  final Widget tonicWheel;
  final Widget viewControl;
  final Widget chordsList;
  final Widget Function({required bool scrollable}) scalePicker;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final controls = <Widget>[
      tonicWheel,
      const SizedBox(height: 16),
      viewControl,
      const SizedBox(height: 8),
    ];

    if (scrollsAsOne) {
      return FadedScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...controls,
            _list(wrapChordsList: false, scrollableScalePicker: false),
          ],
        ),
      );
    }

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...controls,
          Expanded(
            child: _list(wrapChordsList: true, scrollableScalePicker: true),
          ),
        ],
      ),
    );
  }

  Widget _list({
    required bool wrapChordsList,
    required bool scrollableScalePicker,
  }) {
    if (showScalePicker) return scalePicker(scrollable: scrollableScalePicker);
    if (!wrapChordsList) return chordsList;
    return FadedScrollView(
      maintainVisualPositionOnResize: true,
      child: chordsList,
    );
  }
}
