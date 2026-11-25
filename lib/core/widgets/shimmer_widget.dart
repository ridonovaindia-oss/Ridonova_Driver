import 'package:flutter/material.dart';

/// Custom high-performance Shimmer Widget with zero external dependencies.
class ShimmerWidget extends StatefulWidget {
  final double width;
  final double height;
  final ShapeBorder shapeBorder;

  const ShimmerWidget.rectangular({
    super.key,
    required this.width,
    required this.height,
    this.shapeBorder = const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
  });

  const ShimmerWidget.circular({
    super.key,
    required this.width,
    required this.height,
    this.shapeBorder = const CircleBorder(),
  });

  @override
  State<ShimmerWidget> createState() => _ShimmerWidgetState();
}

class _ShimmerWidgetState extends State<ShimmerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: ShapeDecoration(
            shape: widget.shapeBorder,
            gradient: LinearGradient(
              begin: Alignment(-1.0 + (_controller.value * 3.0), -0.3),
              end: Alignment(1.0 + (_controller.value * 3.0), 0.3),
              colors: const [
                Color(0xFFE0E0E0),
                Color(0xFFF5F5F5),
                Color(0xFFE0E0E0),
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}

/// Shimmer Skeleton screen for Driver Home Map Tab while location is being fetched.
class HomeScreenShimmer extends StatelessWidget {
  final String? statusText;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const HomeScreenShimmer({
    super.key,
    this.statusText,
    this.actionLabel,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final hasAction = actionLabel != null && onActionPressed != null;

    return Stack(
      children: [
        // 1. Shimmer Map Background Replacement
        Container(
          color: const Color(0xFFF0F2F5),
          width: double.infinity,
          height: double.infinity,
          child: const Center(
            child: ShimmerWidget.rectangular(
              width: double.infinity,
              height: double.infinity,
              shapeBorder: RoundedRectangleBorder(),
            ),
          ),
        ),

        // 2. Top Bar Shimmer (Menu, Duty Badge, Location Button)
        Positioned(
          top: topPadding + 12,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Menu Button Shimmer
              const ShimmerWidget.circular(width: 46, height: 46),

              // Duty Badge Shimmer
              const ShimmerWidget.rectangular(
                width: 120,
                height: 42,
                shapeBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(24)),
                ),
              ),

              // My Location Button Shimmer
              const ShimmerWidget.circular(width: 46, height: 46),
            ],
          ),
        ),

        // 3. Location Fetching Status Floating Pill
        Positioned(
          top: topPadding + 70,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                if (hasAction)
                  const Icon(
                    Icons.location_off_rounded,
                    size: 18,
                    color: Color(0xFFEA580C),
                  )
                else
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFF0A2550),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    statusText ?? 'Fetching your current location...',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                if (hasAction) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onActionPressed,
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFFFF7ED),
                      foregroundColor: const Color(0xFFEA580C),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      actionLabel!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // 4. Bottom Sheet Duty / Status Card Shimmer
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Driver Avatar + Info Shimmer
                const Row(
                  children: [
                    ShimmerWidget.circular(width: 50, height: 50),
                    SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerWidget.rectangular(width: 140, height: 16),
                        SizedBox(height: 8),
                        ShimmerWidget.rectangular(width: 90, height: 12),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Stats Cards Row Shimmer
                const Row(
                  children: [
                    Expanded(
                      child: ShimmerWidget.rectangular(
                        width: double.infinity,
                        height: 70,
                        shapeBorder: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ShimmerWidget.rectangular(
                        width: double.infinity,
                        height: 70,
                        shapeBorder: RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(16)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Duty Toggle Big Button Shimmer
                const ShimmerWidget.rectangular(
                  width: double.infinity,
                  height: 54,
                  shapeBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(28)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
