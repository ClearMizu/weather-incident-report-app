import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  final bool isFirebaseReady;

  const LoginPage({super.key, required this.isFirebaseReady});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  String _statusMessage = '';
  bool _isLoading = false;
  
  // Local state for demo login when Firebase is not configured yet
  bool _isDemoLoggedIn = false;
  String _demoEmail = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithFirebase() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter both email and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      setState(() {
        _statusMessage = 'Logged in successfully!';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _statusMessage = 'Login failed: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _registerWithFirebase() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _statusMessage = 'Please enter both email and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      setState(() {
        _statusMessage = 'Registered and logged in successfully!';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _statusMessage = 'Registration failed: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _logoutFirebase() async {
    try {
      await FirebaseAuth.instance.signOut();
      setState(() {
        _statusMessage = 'Signed out successfully.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Sign out error: $e';
      });
    }
  }

  void _demoLogin() {
    final email = _emailController.text.trim();
    setState(() {
      _isDemoLoggedIn = true;
      _demoEmail = email.isNotEmpty ? email : 'demo@example.com';
      _statusMessage = 'Logged in as Demo User ($_demoEmail)';
    });
  }

  void _demoLogout() {
    setState(() {
      _isDemoLoggedIn = false;
      _demoEmail = '';
      _statusMessage = 'Demo user logged out.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isFirebaseReady) {
      return _buildDemoLoginView();
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = snapshot.data;
        if (user != null) {
          return _buildLoggedInView(user.email ?? user.uid);
        }

        return _buildLoginForm(isFirebase: true);
      },
    );
  }

  Widget _buildLoggedInView(String userIdentifier) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.account_circle, size: 80, color: Colors.blue),
          const SizedBox(height: 16),
          const Text(
            'User Status',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Logged in as:\n$userIdentifier',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: widget.isFirebaseReady ? _logoutFirebase : _demoLogout,
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoLoginView() {
    if (_isDemoLoggedIn) {
      return _buildLoggedInView(_demoEmail);
    }
    return _buildLoginForm(isFirebase: false);
  }

  Widget _buildLoginForm({required bool isFirebase}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Text(
            'User Login',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (!isFirebase) ...[
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.amber.shade100,
              child: const Text(
                'Note: Firebase is not configured yet. You can use Demo Login below or set up Firebase by following the steps provided.',
                style: TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (isFirebase) ...[
            ElevatedButton(
              onPressed: _loginWithFirebase,
              child: const Text('Log In (Firebase)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _registerWithFirebase,
              child: const Text('Register (Firebase)'),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: _demoLogin,
              child: const Text('Demo Login'),
            ),
          ],
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}
