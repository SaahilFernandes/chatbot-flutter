import 'package:flutter/material.dart';
import 'pages/login_page.dart'; // Correct relative path


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Basic Auth/Chat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const LoginPage(), // Start with the Login Page
      debugShowCheckedModeBanner: false,
    );
  }
}