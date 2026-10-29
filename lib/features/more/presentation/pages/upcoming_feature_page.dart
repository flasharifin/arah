import 'package:arah/core/widgets/widgets.dart';
import 'package:flutter/material.dart';

/// Placeholder jujur untuk fitur yang belum dibangun; ganti dengan halaman fitur aslinya.
class UpcomingFeaturePage extends StatelessWidget {
  const UpcomingFeaturePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const EmptyView(
        icon: Icons.construction_outlined,
        title: 'Belum tersedia di aplikasi mobile',
        message: 'Fitur ini masih bisa dipakai di versi web.',
      ),
    );
  }
}
