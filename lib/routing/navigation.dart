import 'package:flutter/material.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

bool _navigationScheduled = false;

void navigateAndRemoveAll(String routeName) {
  if (_navigationScheduled) return;
  _navigationScheduled = true;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
    );
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      _navigationScheduled = false;
    });
  });
}
