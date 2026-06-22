import 'package:flutter/material.dart';

/// Shared breakpoints for phone, tablet, and desktop (Windows / wide web).
abstract final class Responsive {
  static const compactBreakpoint = 600.0;
  static const wideBreakpoint = 1024.0;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isCompact(BuildContext context) =>
      widthOf(context) < compactBreakpoint;

  static bool isWide(BuildContext context) =>
      widthOf(context) >= wideBreakpoint;

  /// Max width for auth / onboarding forms.
  static double formMaxWidth(BuildContext context) =>
      isWide(context) ? 480 : 560;

  /// Max width for in-app page content on very wide screens.
  static double pageMaxWidth(BuildContext context) =>
      isWide(context) ? 1200 : double.infinity;

  static EdgeInsets pagePadding(BuildContext context) {
    if (isWide(context)) return const EdgeInsets.symmetric(horizontal: 32);
    if (widthOf(context) >= compactBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 24);
    }
    return EdgeInsets.zero;
  }
}

/// Centers public/auth page content with a readable max width on desktop.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.child,
    this.backgroundColor = Colors.white,
    this.maxWidth,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final Color backgroundColor;
  final double? maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final wide = Responsive.isWide(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Align(
          alignment: wide ? Alignment.center : Alignment.topCenter,
          child: SingleChildScrollView(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth ?? Responsive.formMaxWidth(context),
                minHeight: wide
                    ? MediaQuery.sizeOf(context).height -
                        MediaQuery.paddingOf(context).vertical -
                        padding.vertical
                    : 0,
              ),
              child: wide
                  ? Center(child: child)
                  : child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Keeps in-shell screens readable on ultra-wide desktop windows.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final resolvedPadding = padding ?? Responsive.pagePadding(context);
    final resolvedMaxWidth = maxWidth ?? Responsive.pageMaxWidth(context);

    if (resolvedMaxWidth == double.infinity &&
        resolvedPadding == EdgeInsets.zero) {
      return child;
    }

    return Align(
      alignment: alignment,
      child: Padding(
        padding: resolvedPadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: resolvedMaxWidth),
          child: child,
        ),
      ),
    );
  }
}
