import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// An entry in a [PickerList]: either a selectable item or a
/// non-selectable section subheading.
sealed class PickerListEntry<T> {
  const PickerListEntry();
}

final class PickerListItem<T> extends PickerListEntry<T> {
  const PickerListItem(this.value);
  final T value;
}

final class PickerListHeader<T> extends PickerListEntry<T> {
  const PickerListHeader(this.title, {this.extent});
  final String title;

  /// Optional override for this header's height. Falls back to the list's
  /// [PickerList.headerExtent] when null. Lets a leading header sit tight to the
  /// top while later headers keep the taller extent that separates sections.
  final double? extent;
}

/// A flat, freely scrolling list where one row is selected (highlighted).
/// Tapping a row selects it, scrolling browses without snapping, and the
/// selected row is centered when the selection changes. Section subheadings can
/// be interspersed. Each edge fades only once there is more content to scroll to
/// in that direction, so a list resting at its top stays flush with no padding.
///
/// When [scrollable] is false the list renders as a plain, full-height column
/// with no internal scrolling, edge fades, or auto-centering, so it can be
/// dropped into an outer scroll view that owns those behaviors.
class PickerList<T> extends StatefulWidget {
  const PickerList({
    super.key,
    required this.entries,
    required this.selected,
    required this.itemExtent,
    required this.itemBuilder,
    required this.onChanged,
    this.headerExtent = 36,
    this.headerBuilder,
    this.fadeExtent = 24,
    this.scrollable = true,
  });

  final List<PickerListEntry<T>> entries;
  final T selected;
  final double itemExtent;
  final double headerExtent;
  final Widget Function(BuildContext context, T value, bool selected)
  itemBuilder;
  final Widget Function(BuildContext context, String title)? headerBuilder;
  final ValueChanged<T> onChanged;
  final double fadeExtent;
  final bool scrollable;

  @override
  State<PickerList<T>> createState() => _PickerListState<T>();
}

class _PickerListState<T> extends State<PickerList<T>> {
  final ScrollController _controller = ScrollController();
  late List<double> _itemTopOffsets;
  late List<T> _itemValues;
  bool _showTopFade = false;
  bool _showBottomFade = false;

  @override
  void initState() {
    super.initState();
    _recompute();
    _controller.addListener(_updateFades);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _centerSelected();
      _updateFades();
    });
  }

  @override
  void didUpdateWidget(covariant PickerList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _recompute();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (oldWidget.selected != widget.selected) _centerSelected();
      _updateFades();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updateFades);
    _controller.dispose();
    super.dispose();
  }

  void _updateFades() {
    if (!_controller.hasClients) return;

    final position = _controller.position;
    if (!position.hasContentDimensions) return;

    const epsilon = 0.5;
    final maxExtent = position.maxScrollExtent;
    final pixels = position.pixels;
    final nextTop = maxExtent > epsilon && pixels > epsilon;
    final nextBottom = maxExtent > epsilon && pixels < maxExtent - epsilon;

    if (nextTop == _showTopFade && nextBottom == _showBottomFade) return;

    setState(() {
      _showTopFade = nextTop;
      _showBottomFade = nextBottom;
    });
  }

  void _recompute() {
    _itemTopOffsets = [];
    _itemValues = [];
    var offset = 0.0;
    for (final entry in widget.entries) {
      if (entry is PickerListItem<T>) {
        _itemTopOffsets.add(offset);
        _itemValues.add(entry.value);
        offset += widget.itemExtent;
      } else if (entry is PickerListHeader<T>) {
        offset += entry.extent ?? widget.headerExtent;
      }
    }
  }

  void _centerSelected() {
    if (!_controller.hasClients) return;
    final index = _itemValues.indexOf(widget.selected);
    if (index < 0) return;

    final position = _controller.position;
    final itemCenter = _itemTopOffsets[index] + widget.itemExtent / 2;
    final target = (itemCenter - position.viewportDimension / 2).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 0.5) return;

    unawaited(
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  Widget _buildEntry(BuildContext context, PickerListEntry<T> entry) {
    return switch (entry) {
      PickerListItem<T>(:final value) => SizedBox(
        height: widget.itemExtent,
        child: Semantics(
          button: true,
          selected: value == widget.selected,
          onTap: () => widget.onChanged(value),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onChanged(value),
            child: widget.itemBuilder(context, value, value == widget.selected),
          ),
        ),
      ),
      PickerListHeader<T>(:final title, :final extent) => SizedBox(
        height: extent ?? widget.headerExtent,
        child: (widget.headerBuilder ?? _defaultHeader)(context, title),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.scrollable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in widget.entries) _buildEntry(context, entry),
        ],
      );
    }

    final surface = Theme.of(context).colorScheme.surface;

    return Stack(
      children: [
        Positioned.fill(
          child: ListView.builder(
            controller: _controller,
            padding: EdgeInsets.zero,
            itemCount: widget.entries.length,
            itemBuilder: (context, index) =>
                _buildEntry(context, widget.entries[index]),
          ),
        ),
        if (_showTopFade)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: widget.fadeExtent,
            child: _EdgeFade(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              surface: surface,
            ),
          ),
        if (_showBottomFade)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: widget.fadeExtent,
            child: _EdgeFade(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              surface: surface,
            ),
          ),
      ],
    );
  }

  Widget _defaultHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EdgeFade extends StatelessWidget {
  const _EdgeFade({
    required this.begin,
    required this.end,
    required this.surface,
  });

  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            stops: const [0.0, 0.6, 1.0],
            colors: [
              surface,
              surface.withValues(alpha: 0.7),
              surface.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
