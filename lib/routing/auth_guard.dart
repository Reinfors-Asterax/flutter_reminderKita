import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../login_page.dart';

abstract final class AuthGuard {
  static Route<dynamic> protect({
    required RouteSettings settings,
    required WidgetBuilder builder,
  }) {
    if (Supabase.instance.client.auth.currentUser == null) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const LoginPage(),
      );
    }
    return MaterialPageRoute(settings: settings, builder: builder);
  }
}
