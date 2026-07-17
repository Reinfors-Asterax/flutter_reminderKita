import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({
    super.key,
    this.message = 'Anda tidak memiliki akses ke halaman ini.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                size: 72,
                color: Color(0xFF2563EB),
              ),
              const SizedBox(height: 20),
              const Text(
                'Akses Ditolak',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AuthService.instance.dashboardRoute(),
                  (_) => false,
                ),
                child: const Text('Kembali ke Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
