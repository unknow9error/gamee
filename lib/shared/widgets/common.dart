import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';
import 'trail_icon.dart';

TrailIconKind trailActivityKind(ActivityKind kind) => switch (kind) {
  ActivityKind.numberColor => TrailIconKind.brush,
  ActivityKind.freeColor => TrailIconKind.palette,
  ActivityKind.maze => TrailIconKind.maze,
  ActivityKind.guidedDraw => TrailIconKind.draw,
  ActivityKind.hiddenAnimals => TrailIconKind.search,
  ActivityKind.oddFragment => TrailIconKind.search,
  ActivityKind.connectDots => TrailIconKind.dots,
  ActivityKind.matchPairs => TrailIconKind.pairs,
  ActivityKind.patternSequence => TrailIconKind.pattern,
  ActivityKind.missingPuzzle => TrailIconKind.puzzle,
  ActivityKind.ropeTrace => TrailIconKind.rope,
};

IconData activityIcon(ActivityKind kind) => switch (kind) {
  ActivityKind.numberColor => Icons.format_paint_rounded,
  ActivityKind.freeColor => Icons.palette_outlined,
  ActivityKind.maze => Icons.route_rounded,
  ActivityKind.guidedDraw => Icons.gesture_rounded,
  ActivityKind.hiddenAnimals => Icons.travel_explore_rounded,
  ActivityKind.oddFragment => Icons.manage_search_rounded,
  ActivityKind.connectDots => Icons.linear_scale_rounded,
  ActivityKind.matchPairs => Icons.extension_rounded,
  ActivityKind.patternSequence => Icons.widgets_rounded,
  ActivityKind.missingPuzzle => Icons.grid_view_rounded,
  ActivityKind.ropeTrace => Icons.timeline_rounded,
};

Color activityColor(ActivityKind kind) => switch (kind) {
  ActivityKind.numberColor => AppColors.blue,
  ActivityKind.freeColor => AppColors.peach,
  ActivityKind.maze => AppColors.lime,
  ActivityKind.guidedDraw => AppColors.lavender,
  ActivityKind.hiddenAnimals => AppColors.yellow,
  ActivityKind.oddFragment => AppColors.peach,
  ActivityKind.connectDots => AppColors.blue,
  ActivityKind.matchPairs => AppColors.lavender,
  ActivityKind.patternSequence => AppColors.yellow,
  ActivityKind.missingPuzzle => AppColors.lime,
  ActivityKind.ropeTrace => AppColors.blue,
};

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.border = false,
  });
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool border;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(26),
      side: border ? const BorderSide(color: AppColors.line) : BorderSide.none,
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: padding, child: child),
    ),
  );
}

class StarCount extends StatelessWidget {
  const StarCount({super.key, required this.count});
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0C0),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TrailIcon(TrailIconKind.star, size: 23, selected: true),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
        ),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 26, bottom: 15),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    ),
  );
}

class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.child, this.disabled = false});
  final Widget child;
  final bool disabled;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(
      begin: disabled || MediaQuery.disableAnimationsOf(context) ? 1 : 0,
      end: 1,
    ),
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 15 * (1 - value)),
        child: child,
      ),
    ),
    child: child,
  );
}
