import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// A sleek Uber/Rapido style "Swipe to Accept" slider button
/// providing smooth dragging, haptic feedback, animated chevrons,
/// and responsive loading state.
class SwipeToAcceptSlider extends StatefulWidget {
  final Future<void> Function() onSwipeComplete;
  final bool isLoading;
  final String text;
  final Color? trackColor;
  final Color? activeTrackColor;
  final Color? thumbColor;
  final Color? iconColor;
  final double height;

  const SwipeToAcceptSlider({
    super.key,
    required this.onSwipeComplete,
    this.isLoading = false,
    this.text = 'SWIPE TO ACCEPT',
    this.trackColor,
    this.activeTrackColor,
    this.thumbColor,
    this.iconColor,
    this.height = 56.0,
  });

  @override
  State<SwipeToAcceptSlider> createState() => _SwipeToAcceptSliderState();
}

class _SwipeToAcceptSliderState extends State<SwipeToAcceptSlider> with TickerProviderStateMixin {
  double _dragOffset = 0.0;
  bool _isCompleted = false;
  bool _hasHapticTriggeredMid = false;

  late AnimationController _resetController;
  Animation<double>? _resetAnimation;

  late AnimationController _chevronController;
  late Animation<double> _chevronAnimation;

  @override
  void initState() {
    super.initState();

    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _resetController.addListener(() {
      if (_resetAnimation != null) {
        setState(() {
          _dragOffset = _resetAnimation!.value;
        });
      }
    });

    _chevronController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _chevronAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _chevronController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant SwipeToAcceptSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If loading was finished and was not successful, reset slider
    if (oldWidget.isLoading && !widget.isLoading && _isCompleted) {
      _resetSlider();
    }
  }

  @override
  void dispose() {
    _resetController.dispose();
    _chevronController.dispose();
    super.dispose();
  }

  void _resetSlider() {
    _resetAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutCubic),
    );
    _resetController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _isCompleted = false;
          _hasHapticTriggeredMid = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const double padding = 4.0;
    final double thumbSize = widget.height - (padding * 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxTrackWidth = constraints.maxWidth;
        final double maxDrag = (maxTrackWidth - thumbSize - (padding * 2)).clamp(0.0, double.infinity);

        // Ensure drag offset doesn't exceed bounds if layout resized
        if (_dragOffset > maxDrag && !_isCompleted) {
          _dragOffset = maxDrag;
        }

        final double progress = maxDrag > 0 ? (_dragOffset / maxDrag).clamp(0.0, 1.0) : 0.0;

        return Container(
          height: widget.height,
          width: maxTrackWidth,
          decoration: BoxDecoration(
            color: widget.trackColor ?? const Color(0xFF0F172A), // Dark slate
            borderRadius: BorderRadius.circular(widget.height / 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.height / 2),
            child: Stack(
              children: [
                // 🟢 1. Active Progress Gradient Track
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _dragOffset + thumbSize + (padding * 2),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          widget.activeTrackColor ?? const Color(0xFF059669),
                          widget.activeTrackColor ?? AppColors.success,
                        ],
                      ),
                    ),
                  ),
                ),

                // 🟢 2. Center Text + Animated Chevrons
                Positioned.fill(
                  child: Center(
                    child: Opacity(
                      opacity: (1.0 - (progress * 1.6)).clamp(0.0, 1.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 38), // Offset to balance thumb presence
                          Flexible(
                            child: Text(
                              widget.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                letterSpacing: 0.8,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedBuilder(
                            animation: _chevronAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_chevronAnimation.value, 0),
                                child: Icon(
                                  Icons.keyboard_double_arrow_right_rounded,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 20,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 🟢 3. Draggable Knob / Thumb
                Positioned(
                  left: padding + _dragOffset,
                  top: padding,
                  bottom: padding,
                  child: GestureDetector(
                    onHorizontalDragStart: widget.isLoading || _isCompleted
                        ? null
                        : (_) {
                            _resetController.stop();
                            _hasHapticTriggeredMid = false;
                          },
                    onHorizontalDragUpdate: widget.isLoading || _isCompleted
                        ? null
                        : (details) {
                            setState(() {
                              _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, maxDrag);
                            });

                            // Soft haptic when reaching 50%
                            if (progress >= 0.5 && !_hasHapticTriggeredMid) {
                              _hasHapticTriggeredMid = true;
                              HapticFeedback.selectionClick();
                            } else if (progress < 0.5 && _hasHapticTriggeredMid) {
                              _hasHapticTriggeredMid = false;
                            }
                          },
                    onHorizontalDragEnd: widget.isLoading || _isCompleted
                        ? null
                        : (details) async {
                            if (_dragOffset >= maxDrag * 0.75) {
                              // Reached threshold -> Snap to end & trigger accept
                              setState(() {
                                _dragOffset = maxDrag;
                                _isCompleted = true;
                              });
                              HapticFeedback.heavyImpact();
                              await widget.onSwipeComplete();
                              if (mounted && !widget.isLoading) {
                                _resetSlider();
                              }
                            } else {
                              // Snap back
                              HapticFeedback.lightImpact();
                              _resetSlider();
                            }
                          },
                    onHorizontalDragCancel: widget.isLoading || _isCompleted
                        ? null
                        : () {
                            _resetSlider();
                          },
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.thumbColor ?? Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: widget.isLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    widget.iconColor ?? const Color(0xFF059669),
                                  ),
                                ),
                              )
                            : Icon(
                                _isCompleted ? Icons.check_rounded : Icons.arrow_forward_rounded,
                                color: widget.iconColor ?? const Color(0xFF059669),
                                size: 24,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
