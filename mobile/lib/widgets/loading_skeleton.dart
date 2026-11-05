import 'package:flutter/material.dart';

bool reducedMotion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ||
    MediaQuery.accessibleNavigationOf(context);

class MotionReveal extends StatefulWidget {
  const MotionReveal({super.key, required this.child, this.replayKey});
  final Widget child;
  final Object? replayKey;
  @override
  State<MotionReveal> createState() => _MotionRevealState();
}

class _MotionRevealState extends State<MotionReveal>
    with SingleTickerProviderStateMixin {
  late final controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final curve = CurvedAnimation(
    parent: controller,
    curve: Curves.easeOutCubic,
  );
  bool reduce = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduce = reducedMotion(context);
    if (reduce) {
      controller.value = 1;
    } else if (!controller.isCompleted && !controller.isAnimating) {
      controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant MotionReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replayKey != widget.replayKey) {
      if (reduce) {
        controller.value = 1;
      } else {
        controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    curve.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: .65, end: 1).animate(curve),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, .015),
        end: Offset.zero,
      ).animate(curve),
      child: widget.child,
    ),
  );
}

class KitchenSkeleton extends StatefulWidget {
  const KitchenSkeleton({super.key});
  @override
  State<KitchenSkeleton> createState() => _KitchenSkeletonState();
}

class _KitchenSkeletonState extends State<KitchenSkeleton>
    with SingleTickerProviderStateMixin {
  late final pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  bool reduce = true;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reduce = reducedMotion(context);
    if (reduce) {
      pulse.stop();
    } else if (!pulse.isAnimating) {
      pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    Widget block(double height, {double? width, double radius = 16}) =>
        Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
        );
    final content = ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: block(12, width: 110, radius: 6),
        ),
        const SizedBox(height: 20),
        block(32),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerLeft, child: block(32, width: 210)),
        const SizedBox(height: 16),
        block(14),
        const SizedBox(height: 28),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i != 0) const SizedBox(width: 12),
              Expanded(child: block(94, radius: 22)),
            ],
          ],
        ),
        const SizedBox(height: 28),
        block(22),
        const SizedBox(height: 16),
        block(88, radius: 22),
        const SizedBox(height: 20),
        block(52),
        const SizedBox(height: 24),
        block(132, radius: 22),
        const SizedBox(height: 16),
        block(132, radius: 22),
      ],
    );
    return Semantics(
      label: 'Mutfağın hazırlanıyor',
      liveRegion: true,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: reduce
                ? content
                : FadeTransition(
                    opacity: Tween<double>(begin: .45, end: .9).animate(pulse),
                    child: content,
                  ),
          ),
        ),
      ),
    );
  }
}

class StartupSkeleton extends StatelessWidget {
  const StartupSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('taze kal')),
    body: const SafeArea(top: false, child: KitchenSkeleton()),
  );
}
