import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasaran/data/repositories/auth_repository.dart';
import 'package:kasaran/ui/providers/auth_provider.dart';
import 'package:kasaran/ui/router/app_router.dart';

/// Authentication only: plan creation and invite acceptance are separate flows.
class Scr01SignIn extends ConsumerStatefulWidget {
  const Scr01SignIn({super.key});
  @override
  ConsumerState<Scr01SignIn> createState() => _Scr01SignInState();
}

class _Scr01SignInState extends ConsumerState<Scr01SignIn> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _signUp = false;
  bool _adult = false;
  bool _busy = false;
  String? _message;
  bool _unverified = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_signUp && !_adult) {
      setState(
        () => _message =
            'Confirm that you are 18 or older before creating an account.',
      );
      return;
    }
    final repository = ref.read(authRepositoryProvider);
    if (repository == null) {
      setState(
        () => _message =
            'Authentication is unavailable. Check the local service and try again.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final status = _signUp
          ? await repository.signUp(
              email: _email.text,
              password: _password.text,
              displayName: _name.text,
              isAdult: _adult,
            )
          : await repository.signIn(
              email: _email.text,
              password: _password.text,
            );
      if (!mounted) return;
      setState(() {
        _unverified = status == AuthSessionStatus.emailUnverified;
        _message = status == AuthSessionStatus.signedOut
            ? 'Unable to sign in. Check your email and password.'
            : null;
      });
    } catch (_) {
      // Never display SDK exception text: it may contain email, URLs or tokens.
      if (mounted) {
        setState(
          () => _message =
              'Authentication failed. Check your details and connection, then try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _notice() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Privacy notice'),
      content: const Text(
        'This is a placeholder notice for synthetic local development only. Do not enter real personal data. Legal basis and privacy wording require counsel review before a real-data beta.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(authStateProvider);
    if (status == AuthState.authenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kasaran')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('How would you like to begin?'),
                FilledButton(
                  onPressed: () => context.go(Routes.onboardingBudgetDate),
                  child: const Text('Start our plan'),
                ),
                OutlinedButton(
                  onPressed: () => context.go(Routes.invitePaste),
                  child: const Text("Join my partner's plan"),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('SCR-01 · Kasaran')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _signUp ? 'Create account' : 'Sign in',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('auth-email'),
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (value) => value == null || !value.contains('@')
                        ? 'Enter your email address.'
                        : null,
                  ),
                  TextFormField(
                    key: const Key('auth-password'),
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your password.'
                        : null,
                  ),
                  if (_signUp) ...[
                    TextFormField(
                      key: const Key('auth-display-name'),
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Enter a display name.'
                          : null,
                    ),
                    CheckboxListTile(
                      value: _adult,
                      title: const Text('I am 18 or older'),
                      onChanged: _busy
                          ? null
                          : (value) => setState(() {
                              _adult = value ?? false;
                              _message = null;
                            }),
                    ),
                    TextButton(
                      onPressed: _notice,
                      child: const Text('Privacy notice'),
                    ),
                  ],
                  if (_message != null)
                    Text(
                      _message!,
                      key: const Key('auth-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (_unverified || status == AuthState.unverified)
                    const Text(
                      'Verify your email before starting or joining a plan.',
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: Text(_signUp ? 'Sign up' : 'Sign in'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _signUp = !_signUp;
                            _adult = false;
                            _message = null;
                            _unverified = false;
                          }),
                    child: Text(
                      _signUp ? 'Have an account? Sign in' : 'Create account',
                    ),
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
