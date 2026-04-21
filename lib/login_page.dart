import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool rememberMe = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  String _friendlyAuthError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return "No account found for that email.";
        case 'wrong-password':
          return "Wrong password.";
        case 'invalid-email':
          return "That email is not valid.";
        case 'user-disabled':
          return "This user account is disabled.";
        case 'too-many-requests':
          return "Too many attempts. Try again later.";
        default:
          return e.message ?? "Login failed.";
      }
    }
    return "Login failed.";
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pass.text,
      );

      if (!mounted) return;

      // ✅ Navigate to HomePage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
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

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0A3323);
    const lightGreen = Color(0xFF839958);

    return Scaffold(
      backgroundColor: Color(0xFFFCFFF5),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // CURVED IMAGE HEADER
            ClipPath(
              clipper: CurveClipper(),
              child: Container(
                height: 260,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/login.jpg"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // TEXT
            Text(
              "Welcome Back",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: primaryGreen,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Login to your account",
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 24),

            // FORM
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // EMAIL
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFDBDAAF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextFormField(
                          controller: _email,
                          style: const TextStyle(
                            color: Color(0xFF48521C),  
                            fontWeight: FontWeight.bold, // optional
                          ),
                          decoration: const InputDecoration(
                            hintText: "Email",
                          prefixIcon: Icon(Icons.email),
                          border: InputBorder.none,
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 16),
                        ),
                        validator: (v) {
                          final val = (v ?? "").trim();
                          if (val.isEmpty) return "Email required";
                          if (!val.contains("@")) return "Enter a valid email";
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // PASSWORD
                    Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFDBDAAF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextFormField(
                        controller: _pass,
                        style: const TextStyle(
                            color: Color(0xFF48521C),  
                            fontWeight: FontWeight.bold, // optional
                          ),
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          hintText: "Password",
                          prefixIcon: const Icon(Icons.lock),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 16),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if ((v ?? "").isEmpty) return "Password required";
                          return null;
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // REMEMBER + FORGOT
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: rememberMe,
                              onChanged: (v) {
                                setState(() {
                                  rememberMe = v!;
                                });
                              },
                            ),
                            const Text("Remember Me"),
                          ],
                        ),
                        Text(
                          "Forgot Password?",
                          style: TextStyle(color: primaryGreen),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // LOGIN BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF48521c),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            :  const Text(
  "Log In",
  style: TextStyle(
    color: Color(0xFFFCFFF5),
    fontWeight: FontWeight.bold,
    fontSize: 16,
  ),
),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // SIGN UP
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account? "),
                        GestureDetector(
                          onTap: _loading
                              ? null
                              : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const SignUpPage()),
                                  );
                                },
                          child: Text(
                            "Sign up",
                            style: TextStyle(
                              color: primaryGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

// 🌊 CURVE CLIPPER
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