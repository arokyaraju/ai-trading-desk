import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/panel_rect.dart';
import '../providers/panel_layout_provider.dart';

class CustomizableDashboard extends StatelessWidget {
  final Map<String, Widget> panels;

  const CustomizableDashboard({super.key, required this.panels});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PanelLayoutProvider>();

    if (!provider.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          children: [
            for (final entry in panels.entries)
              _PositionedPanel(
                id: entry.key,
                content: entry.value,
                rect: provider.layout[entry.key] ??
                    const PanelRect(x: 0, y: 0, w: 0.3, h: 0.3),
                editMode: provider.editMode,
                width: width,
                height: height,
                onRectChanged: (rect) => provider.updateRect(entry.key, rect),
              ),
          ],
        );
      },
    );
  }
}

class _PositionedPanel extends StatelessWidget {
  final String id;
  final Widget content;
  final PanelRect rect;
  final bool editMode;
  final double width;
  final double height;
  final ValueChanged<PanelRect> onRectChanged;

  const _PositionedPanel({
    required this.id,
    required this.content,
    required this.rect,
    required this.editMode,
    required this.width,
    required this.height,
    required this.onRectChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: rect.x * width,
      top: rect.y * height,
      width: rect.w * width,
      height: rect.h * height,
      child: Stack(
        children: [
          Positioned.fill(child: content),
          if (editMode) ...[
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanUpdate: (details) {
                  final newX =
                      ((rect.x * width + details.delta.dx) / width).clamp(0.0, 1.0 - rect.w);
                  final newY =
                      ((rect.y * height + details.delta.dy) / height).clamp(0.0, 1.0 - rect.h);
                  onRectChanged(rect.copyWith(x: newX, y: newY));
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blueAccent, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onPanUpdate: (details) {
                  final newW = ((rect.w * width + details.delta.dx) / width)
                      .clamp(PanelLayoutProvider.minSize, 1.0 - rect.x);
                  final newH = ((rect.h * height + details.delta.dy) / height)
                      .clamp(PanelLayoutProvider.minSize, 1.0 - rect.y);
                  onRectChanged(rect.copyWith(w: newW, h: newH));
                },
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(6)),
                  ),
                  child: const Icon(Icons.open_in_full, size: 13, color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}