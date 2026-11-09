
import 'package:flutter/material.dart';

import 'app_router.dart';
import '../core/theme/app_theme.dart';

class VendraOneApp extends StatelessWidget {
  const VendraOneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'VendraOne',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
