import 'package:flutter/material.dart';

import '../services/backend_api.dart';

class AccountSetupScreen extends StatefulWidget {
  const AccountSetupScreen({
    required this.api,
    required this.onComplete,
    super.key,
  });

  final BackendApi api;
  final VoidCallback onComplete;

  @override
  State<AccountSetupScreen> createState() => _AccountSetupScreenState();
}

class _AccountSetupScreenState extends State<AccountSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _allergies = TextEditingController();
  final _emergency = TextEditingController();
  var _login = false;
  var _busy = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _identifier,
      _password,
      _allergies,
      _emergency,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final account = _login
        ? await widget.api.loginAccount(
            identifier: _identifier.text,
            password: _password.text,
          )
        : await widget.api.registerAccount(
            name: _name.text,
            password: _password.text,
            email: _identifier.text.contains('@') ? _identifier.text : null,
            phone: _identifier.text.contains('@') ? null : _identifier.text,
            allergies: _allergies.text,
            emergencyContact: _emergency.text,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not complete account setup. Check your details and connection.',
          ),
        ),
      );
      return;
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
            children: [
              Text(
                _login ? 'Welcome back' : 'Create your UsizoAI account',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _login
                    ? 'Sign in with your email or phone number.'
                    : 'Your account keeps your profile, checks, contributions, and orders connected across sessions.',
              ),
              const SizedBox(height: 24),
              if (!_login)
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your name.'
                      : null,
                ),
              if (!_login) const SizedBox(height: 12),
              TextFormField(
                controller: _identifier,
                keyboardType: TextInputType.emailAddress,
                decoration:
                    const InputDecoration(labelText: 'Email or phone number'),
                validator: (value) => value == null || value.trim().length < 3
                    ? 'Enter an email or phone number.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) => value == null || value.length < 8
                    ? 'Use at least 8 characters.'
                    : null,
              ),
              if (!_login) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _allergies,
                  decoration:
                      const InputDecoration(labelText: 'Allergies (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emergency,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Emergency contact (optional)',
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(
                  _busy
                      ? 'Please wait...'
                      : (_login ? 'Sign in' : 'Create account'),
                ),
              ),
              TextButton(
                onPressed:
                    _busy ? null : () => setState(() => _login = !_login),
                child: Text(
                  _login ? 'Create a new account' : 'I already have an account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
