import 'package:expensetracker/commons/constants/app_colors.dart';
import 'package:expensetracker/data/auth.dart';
import 'package:expensetracker/data/ledger.dart';
import 'package:expensetracker/data/reminder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// What opens when the month-end alarm rings: full screen, over the lock screen, with one big button.
class AlarmRingPage extends ConsumerStatefulWidget {
  const AlarmRingPage({super.key});

  @override
  ConsumerState<AlarmRingPage> createState() => _AlarmRingPageState();
}

class _AlarmRingPageState extends ConsumerState<AlarmRingPage> with SingleTickerProviderStateMixin {
  // the bell pulses gently, so the screen feels like an alarm
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    stopRinging(); // being on this screen means it was seen: stop the sound
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _close() => context.canPop() ? context.pop() : context.go('/');

  @override
  Widget build(BuildContext context) {
    final r = ref.watch(reminderProvider);
    final signedIn = ref.watch(authProvider).valueOrNull == true;
    final now = DateTime.now();
    final month = statementMonthName(r, now);
    final clock = TimeOfDay.fromDateTime(now).format(context);

    return PopScope(
      canPop: true,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.violet80, AppColors.violet100],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  ScaleTransition(
                    scale: Tween(begin: 0.94, end: 1.06).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.notifications_active_rounded, size: 44, color: AppColors.violet100),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(clock,
                      style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w800)),
                  Text('${weekdayName(now)}, ${shortDate(now)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 15)),
                  const SizedBox(height: 30),
                  const Text('Statement time',
                      style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Upload your $month\nbank statement',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.25)),
                  const SizedBox(height: 12),
                  const Text('Download it from your bank app, then import it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4)),
                  const Spacer(flex: 3),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.violet100,
                        minimumSize: const Size.fromHeight(58),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      onPressed: () => signedIn ? context.pushReplacement('/import') : context.go('/login'),
                      icon: const Icon(Icons.upload_file),
                      label: Text(signedIn ? 'Import statement' : 'Open Kharcha'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.white, minimumSize: const Size.fromHeight(48)),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await snoozeOneHour();
                            messenger.showSnackBar(const SnackBar(content: Text('I will remind you in 1 hour')));
                            if (mounted) _close();
                          },
                          child: const Text('Remind in 1 hour'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(foregroundColor: Colors.white70, minimumSize: const Size.fromHeight(48)),
                          onPressed: _close,
                          child: const Text('Not now'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
