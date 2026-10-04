import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/league.dart';
import '../models/team.dart';
import '../services/cloud_sync.dart';
import 'team_edit_screen.dart';

/// Lists the coach's teams; tap one to edit, or add a new one.
class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final sync = uid == null ? null : CloudSync(uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teams'),
        backgroundColor: scheme.primaryContainer,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TeamEditScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add team'),
      ),
      body: sync == null
          ? const Center(child: Text('Sign in to manage teams.'))
          : StreamBuilder<List<League>>(
              stream: sync.leaguesStream(),
              builder: (context, leagueSnap) {
                final leagues = {
                  for (final l in leagueSnap.data ?? <League>[]) l.id: l.name,
                };
                return StreamBuilder<List<Team>>(
                  stream: sync.teamsStream(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Center(child: Text("Couldn't load teams."));
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final teams = snap.data!;
                    if (teams.isEmpty) {
                      return Center(
                        child: Text('No teams yet. Add one to save a roster.',
                            style: TextStyle(color: scheme.outline)),
                      );
                    }
                    return ListView.separated(
                      itemCount: teams.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final t = teams[i];
                        final n = t.players.length;
                        final league = leagues[t.leagueId];
                        return ListTile(
                          title: Text(t.name),
                          subtitle: Text([
                            '$n player${n == 1 ? '' : 's'}',
                            ?league,
                          ].join(' · ')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => TeamEditScreen(team: t)),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
