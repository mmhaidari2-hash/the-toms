import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/data/providers.dart';
import '../../core/i18n/helper_text.dart';

/// Deep link `/#/owner?code=...` activates owner mode once per device (code never logged).
class OwnerScreen extends ConsumerStatefulWidget {
  const OwnerScreen({super.key, this.code});
  final String? code;
  @override
  ConsumerState<OwnerScreen> createState() => _OwnerScreenState();
}

class _OwnerScreenState extends ConsumerState<OwnerScreen> {
  String? _msg;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _try(widget.code));
  }

  Future<void> _try(String? code) async {
    if (code == null || code.isEmpty) {
      setState(() => _msg = 'Missing code');
      return;
    }
    if (ref.read(progressProvider).ownerMode) {
      if (mounted) context.go('/');
      return;
    }
    if (_busy) return;
    setState(() { _busy = true; _msg = null; });
    await Future<void>.delayed(Duration.zero);
    final err = ref.read(progressProvider.notifier).tryActivateOwner(code);
    if (!mounted) return;
    setState(() { _busy = false; _msg = err; });
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hl('Owner mode on — everything unlocked on this device.'))));
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(progressProvider);
    return Scaffold(
      backgroundColor: BL.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(hl('Owner unlock'), style: BL.display(24)),
              const SizedBox(height: 12),
              if (p.ownerMode) Text(hl('Already active on this device.'), style: const TextStyle(fontWeight: FontWeight.w700)),
              if (_busy) const Padding(padding: EdgeInsets.only(top: 24), child: Center(child: CircularProgressIndicator())),
              if (_msg != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(hl(_msg!), style: const TextStyle(color: BL.red))),
              const Spacer(),
              OutlinedButton(onPressed: () => context.go('/'), child: Text(hl('Back to map'))),
            ],
          ),
        ),
      ),
    );
  }
}
