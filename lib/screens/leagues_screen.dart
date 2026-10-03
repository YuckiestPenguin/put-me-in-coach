import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/league.dart';
import '../services/cloud_sync.dart';
import 'league_edit_screen.dart';

/// Lists the coach's leagues; tap one to edit, or add a new one.
class LeaguesScreen extends StatelessWidget {
  const LeaguesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leagues'),
        backgroundColor: scheme.primaryContainer,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LeagueEditScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add league'),
      ),
      body: uid == null
          ? const Center(child: Text('Sign in to manage leagues.'))
          : StreamBuilder<List<League>>(
              stream: CloudSync(uid).leaguesStream(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(child: Text("Couldn't load leagues."));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final leagues = snap.data!;
                if (leagues.isEmpty) {
                  return Center(
                    child: Text('No leagues yet. Add one to save its rules.',
                        style: TextStyle(color: scheme.outline)),
                  );
                }
                return ListView.separated(
                  itemCount: leagues.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final l = leagues[i];
                    return ListTile(
                      title: Text(l.name),
                      subtitle: Text(l.summary),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => LeagueEditScreen(league: l)),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
