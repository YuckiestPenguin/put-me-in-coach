import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Shown until the coach signs in with Google.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
    } on FirebaseAuthException catch (e) {
      // The coach closing the popup isn't worth an error message.
      if (e.code != 'popup-closed-by-user' &&
          e.code != 'cancelled-popup-request') {
        _error = e.message ?? e.code;
      }
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⚽', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 12),
                Text('Put Me In, Coach',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Sign in to keep your roster and game history safe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.outline),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _busy ? null : _signIn,
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in with Google'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
