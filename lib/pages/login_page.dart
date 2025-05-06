import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Import your ApiCall class
import '../Network/apicall.dart'; // Adjust path if needed
import 'register_page.dart';
import 'chat_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController(text: "Shaheed"); // Optional: Pre-fill UI
  final _passwordController = TextEditingController(text: "admin@123"); // Optional: Pre-fill UI
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final _storage = const FlutterSecureStorage();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // Call the static method from ApiCall
      final http.Response response = await ApiCall.loginUser(
        username: _usernameController.text,
        password: _passwordController.text,
      );

      // --- Handle the response here in the page ---
      if (response.statusCode == 200) { // Success
        final responseBody = jsonDecode(response.body);
        final String? accessToken = responseBody['access'];
        final String? refreshToken = responseBody['refresh'];

        if (accessToken != null) {
          await _storage.write(key: 'access_token', value: accessToken);
          if (refreshToken != null) {
            await _storage.write(key: 'refresh_token', value: refreshToken);
          }
          print('Login successful. Token stored.');
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const ChatPage()),
            );
          }
        } else {
          // Should not happen if status is 200, but good to check
          if(mounted) _showErrorSnackbar('Login successful, but token missing in response.');
        }
      } else { // Failure
        String errorMessage = 'Login failed.';
        try {
          final responseBody = jsonDecode(response.body);
          errorMessage = responseBody['error'] ?? responseBody['detail'] ?? 'Invalid credentials or server error.';
        } catch(e) {
          errorMessage += '\nServer response: ${response.body} (Status code: ${response.statusCode})';
          print("Error decoding login error response: $e");
        }
        if(mounted) _showErrorSnackbar(errorMessage);
        print('Login failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      // --- Handle network/other exceptions here ---
      print('Error during login API call: $e');
      if(mounted) _showErrorSnackbar('An network error occurred: $e');
    } finally {
      // --- Ensure loading state is reset ---
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _goToRegister() {
    if (!_isLoading) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const RegisterPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Your Icon
                  const Icon(Icons.lock_person, size: 80, color: Colors.blue),
                  const SizedBox(height: 20),
                  // Username Field
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter your username' : null,
                  ),
                  const SizedBox(height: 15),
                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                    obscureText: true,
                    validator: (value) => value == null || value.isEmpty ? 'Please enter your password' : null,
                  ),
                  const SizedBox(height: 30),
                  // Button / Loading Indicator
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: const Text('Login', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 15),
                  TextButton(
                    onPressed: _isLoading ? null : _goToRegister,
                    child: const Text('Don\'t have an account? Register'),
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