import 'package:flutter/material.dart';

/// Shown when an existing progress file cannot be decrypted.
/// The file and the stored key are left as they were.
class ProgressLockedScreen extends StatelessWidget {
  const ProgressLockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Saved progress is still on this device, but its encryption key could not be read. Nothing was deleted.',
                style: TextStyle(fontSize: 18, height: 1.4),
              ),
              SizedBox(height: 16),
              Text(
                'پیشرفت ذخیره‌شده هنوز روی این دستگاه است، اما کلید رمز آن خوانده نشد. هیچ چیز پاک نشده است.',
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 18, height: 1.6),
              ),
              SizedBox(height: 16),
              Text(
                'Close the app and open it again. If this continues, the key store on this device may have been reset. The saved file is not erased.',
              ),
              SizedBox(height: 12),
              Text(
                'برنامه را ببندید و دوباره باز کنید. اگر ادامه داشت، ممکن است مخزن کلید این دستگاه بازنشانی شده باشد. فایل ذخیره‌شده پاک نمی‌شود.',
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
