import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/notifications_page.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    Future<void> goToNotifications() async {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const NotificationsPage()));

      // Force rebuild of the bell right after coming back
      if (context.mounted) {
        (context as Element).markNeedsBuild();
      }
    }

    Widget bellWithBadge({required int unread}) {
      return SizedBox(
        width: kMinInteractiveDimension,
        height: kMinInteractiveDimension,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: goToNotifications,
              alignment: Alignment.center,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: kMinInteractiveDimension,
                minHeight: kMinInteractiveDimension,
              ),
            ),
            if (unread > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : unread.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    if (user == null) {
      return bellWithBadge(unread: 0);
    }

    final stream = supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const [];
        final unread = rows.where((r) => r['read_at'] == null).length;

        return bellWithBadge(unread: unread);
      },
    );
  }
}
