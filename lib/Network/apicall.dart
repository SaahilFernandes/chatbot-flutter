import 'dart:convert'; // Needed for jsonEncode
import 'package:http/http.dart' as http;

class ApiCall {
  // Use static for BASE_URL if it's constant for all calls from this class
  static const String BASE_URL = "https://acea-182-75-134-114.ngrok-free.app/"; // Your ngrok URL

  // Static method for user registration
  static Future<http.Response> registerUser({required String username, required String email, required String password,}) {
    final url = Uri.parse(BASE_URL + 'users/api/users/register/');
    return http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        // Add ngrok skip header if needed when testing locally
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode(<String, String>{
        'username': username,
        'email': email,
        'password': password,
        // Add 'password2' if your Django serializer requires it
      }),
    );
  }

  // Static method for user login
  static Future<http.Response> loginUser({required String username,required String password,}) {
    final url = Uri.parse(BASE_URL + 'users/api/users/login/');
    return http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
        // Add ngrok skip header if needed when testing locally
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode(<String, String>{
        'username': username,
        'password': password,
      }),
    );
  }

  // Static method to fetch user details (requires token)
  static Future<http.Response> fetchUserDetails({required String token}) {
    final url = Uri.parse(BASE_URL + 'users/api/users/userDetails/');
    return http.get(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token', // Pass the token here
        'Content-Type': 'application/json; charset=UTF-8',
        // Add ngrok skip header if needed when testing locally
        'ngrok-skip-browser-warning': 'true',
      },
    );
  }

  // Example: Static method to send a chat message (requires token)
  static Future<http.Response> sendChatMessage({
    required String token,
    required String message,
    // Add other relevant parameters like recipientId if needed
  }) {
    final url = Uri.parse(BASE_URL + 'chat/get-response/'); // Replace with your actual chat send endpoint
    return http.post(
      url,
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json; charset=UTF-8',
        // Add ngrok skip header if needed when testing locally
        'ngrok-skip-browser-warning': 'true',
      },
      body: jsonEncode(<String, String>{
        'query': message, // Or whatever your backend expects
        // Add other relevant fields
      }),
    );
  }

}