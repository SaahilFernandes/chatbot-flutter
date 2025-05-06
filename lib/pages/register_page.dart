import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // Keep http import for Response type

// Import your ApiCall class
import '../Network/apicall.dart'; // Adjust path if needed
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController(); // For username
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    // Client-side password match check remains useful
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      // Call the static method from ApiCall
      final http.Response response = await ApiCall.registerUser(
        username: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );

      // --- Handle the response here in the page ---
      if (response.statusCode == 201) { // Success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration Successful! Please Login.')),
        );
        if (mounted) {
          Navigator.of(context).pop(); // Go back to Login
        }
      } else { // Failure
        String errorMessage = 'Registration failed.';
        try { // Try to parse specific error from backend
          final responseBody = jsonDecode(response.body);
          if (responseBody is Map) {
            errorMessage = responseBody.entries
                .map((e) => '${e.key}: ${e.value is List ? e.value.join(', ') : e.value}')
                .join('\n');
          } else {
            errorMessage += '\nServer response: ${response.body}';
          }
        } catch (e) { // Error parsing JSON response
          errorMessage += '\nServer response: ${response.body} (Status code: ${response.statusCode})';
          print("Error decoding registration error response: $e");
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
        print('Registration failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      // --- Handle network/other exceptions here ---
      print('Error during registration API call: $e');
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    } finally {
      // --- Ensure loading state is reset ---
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
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
                  const Icon(Icons.person_add_alt_1, size: 80, color: Colors.blue),
                  const SizedBox(height: 20),
                  // Username Field
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                    validator: (value) => value == null || value.isEmpty ? 'Please enter a username' : null,
                  ),
                  const SizedBox(height: 15),
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value == null || !value.contains('@') ? 'Please enter a valid email' : null,
                  ),
                  const SizedBox(height: 15),
                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                    obscureText: true,
                    validator: (value) => value == null || value.length < 6 ? 'Password must be at least 6 characters' : null, // Example validation
                  ),
                  const SizedBox(height: 15),
                  // Confirm Password Field
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(labelText: 'Confirm Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please confirm your password';
                      if (value != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 30),
                  // Button / Loading Indicator
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: _register,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    child: const Text('Register', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 15),
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Already have an account? Login'),
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