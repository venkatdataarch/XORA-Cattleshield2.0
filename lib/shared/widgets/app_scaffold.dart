import 'package:flutter/material.dart';
import 'package:cattleshield/core/constants/app_colors.dart';

class AppScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final FloatingActionButton? floatingActionButton;
  final bool showBackButton;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  const AppScaffold({
    super.key,
    this.title,
    required this.body,
    this.floatingActionButton,
    this.showBackButton = true,
    this.actions,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title != null
          ? AppBar(
              title: Text(title!),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              automaticallyImplyLeading: showBackButton,
              actions: actions,
              bottom: bottom,
            )
          : null,
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
    );
  }
}
