import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameController   = TextEditingController();
  final _lastNameController    = TextEditingController();
  final _businessNameController = TextEditingController();
  final _emailController       = TextEditingController();
  final _passwordController    = TextEditingController();
  final _confirmController     = TextEditingController();
  final _formKey               = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  // Password strength requirements
  static final _hasUppercase   = RegExp(r'[A-Z]');
  static final _hasLowercase   = RegExp(r'[a-z]');
  static final _hasDigit       = RegExp(r'[0-9]');
  static final _hasSpecial     = RegExp(r'[!@#\$&*~%^()_\-+=\[\]{};:,.<>?/\\|`]');

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 10) return 'At least 10 characters required';
    if (!_hasUppercase.hasMatch(v)) return 'Must contain an uppercase letter';
    if (!_hasLowercase.hasMatch(v)) return 'Must contain a lowercase letter';
    if (!_hasDigit.hasMatch(v)) return 'Must contain a number';
    if (!_hasSpecial.hasMatch(v)) return 'Must contain a special character (!@#\$&*~ etc)';
    return null;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _businessNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      await AuthService.instance.register(
        email:        _emailController.text.trim(),
        password:     _passwordController.text,
        businessName: _businessNameController.text.trim().isEmpty
                        ? null
                        : _businessNameController.text.trim(),
        firstName:    _firstNameController.text.trim().isEmpty
                        ? null
                        : _firstNameController.text.trim(),
        lastName:     _lastNameController.text.trim().isEmpty
                        ? null
                        : _lastNameController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not connect to server. Check your network.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create Account',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Start managing your inventory today',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 32),

                // ── Error ──────────────────────────────────────────────────
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Name row ───────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: AuthField(
                        controller: _firstNameController,
                        label: 'First Name',
                        icon: Icons.person_outline,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AuthField(
                        controller: _lastNameController,
                        label: 'Last Name',
                        icon: Icons.person_outline,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Business name ──────────────────────────────────────────
                AuthField(
                  controller: _businessNameController,
                  label: 'Business Name (optional)',
                  icon: Icons.storefront_outlined,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'e.g. Triple Play Sports Cards — shown as your greeting',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 16),

                AuthField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // ── Password — allow OS autofill/suggestions ───────────────
                AuthField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outlined,
                  obscureText: _obscure,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.newPassword],
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Min 10 chars · uppercase · lowercase · number · special character',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
                const SizedBox(height: 16),

                AuthField(
                  controller: _confirmController,
                  label: 'Confirm Password',
                  icon: Icons.lock_outlined,
                  obscureText: _obscure,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) {
                    if (v != _passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: _loading ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Already have an account? Sign in',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
