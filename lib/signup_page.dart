import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  String _carrier = "Verizon";

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _pass.dispose();
    _phone.dispose();
    super.dispose();
  }

  String _friendlyAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return "That email is already registered.";
        case 'invalid-email':
          return "That email is not valid.";
        case 'weak-password':
          return "Password is too weak (min 6 chars).";
        default:
          return e.message ?? "Sign up failed.";
      }
    }
    return "Sign up failed.";
  }

  String getPhoneEmail(String number, String carrier) {
    switch (carrier) {
      case "Verizon":
        return "$number@vtext.com";
      case "AT&T":
        return "$number@txt.att.net";
      case "T-Mobile":
        return "$number@tmomail.net";
      default:
        return "$number@vtext.com";
    }
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final UserCredential cred =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );

      await cred.user?.updateDisplayName(_name.text.trim());
      await cred.user?.reload();

      final uid = cred.user!.uid;

      final phoneEmail =
          getPhoneEmail(_phone.text.trim(), _carrier);

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phoneEmail': phoneEmail,
      });

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyAuthError(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 🔧 reusable field
  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFDBDAAF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(
          color: Color(0xFF48521C),
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16),
        ),
        validator: (v) {
          if ((v ?? "").trim().isEmpty) return "$hint required";
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0A3323);

    return Scaffold(
      backgroundColor: const Color(0xFFFCFFF5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            

            const SizedBox(height: 20),

            Text(
              "Create Account",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Sign up to get started",
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildField(
                        controller: _name,
                        hint: "Username",
                        icon: Icons.person),

                    const SizedBox(height: 16),

                    _buildField(
                        controller: _email,
                        hint: "Email",
                        icon: Icons.email),

                    const SizedBox(height: 16),

                    // PASSWORD
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBDAAF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextFormField(
                        controller: _pass,
                        obscureText: _obscure,
                        style: const TextStyle(
                          color: Color(0xFF48521C),
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: "Password",
                          prefixIcon: const Icon(Icons.lock),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 16),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure
                                ? Icons.visibility_off
                                : Icons.visibility),
                          ),
                        ),
                        validator: (v) {
                          if ((v ?? "").isEmpty) return "Password required";
                          if (v!.length < 6) return "Min 6 characters";
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildField(
                        controller: _phone,
                        hint: "Phone Number",
                        icon: Icons.phone),

                    const SizedBox(height: 16),

                    // CARRIER
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBDAAF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _carrier,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                        ),
                        items: ["Verizon", "AT&T", "T-Mobile"]
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _carrier = val!),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF48521C),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "Create Account",
                                style: TextStyle(
                                  color: Color(0xFFFCFFF5),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        "Already have an account? Log in",
                        style: TextStyle(
                          color: primaryGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 🌊 SAME CLIPPER
class CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 60);

    path.quadraticBezierTo(
      size.width / 2,
      size.height,
      size.width,
      size.height - 60,
    );

    path.lineTo(size.width, 0);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}