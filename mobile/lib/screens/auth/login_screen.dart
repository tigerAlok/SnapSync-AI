import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_logo.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/divider_text.dart';
import '../../widgets/google_button.dart';
import '../../widgets/primary_button.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - 48,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const Spacer(),

                  const AppLogo(),

                  const SizedBox(height: 40),

                  const CustomTextField(
                    label: "Email Address",
                    icon: Icons.email_outlined,
                  ),

                  const SizedBox(height: 20),

                  const CustomTextField(
                    label: "Password",
                    icon: Icons.lock_outline,
                    obscureText: true,
                  ),

                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        context.go('/forgot-password');
                      },
                      child: const Text("Forgot Password?"),
                    ),
                  ),

                  const SizedBox(height: 16),

                  PrimaryButton(
                    text: "Continue",
                    onPressed: () {
                      context.go('/home');
                    },
                  ),

                  const SizedBox(height: 24),

                  const DividerText(text: "OR"),

                  const SizedBox(height: 24),

                  GoogleButton(
                    onPressed: () {
                      // Firebase Google Sign-In will be added later
                    },
                  ),

                  const Spacer(),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      TextButton(
                        onPressed: () {
                          context.go('/register');
                        },
                        child: const Text("Create Account"),
                      ),
                    ],
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