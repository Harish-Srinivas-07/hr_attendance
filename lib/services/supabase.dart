import 'dart:io';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/snackbar.dart';
import '../main.dart';
import '../screens/home.dart';
import '../starters/login.dart';

part 'supabase.g.dart';

@Riverpod(keepAlive: true)
SupaBase sbi(_) => SupaBase(pubbase: Supabase.instance.client);

class SupaBase {
  SupabaseClient? pubbase;
  Session? session = Supabase.instance.client.auth.currentSession;

  SupaBase({this.pubbase, this.session});

  Future<void> login(String email, String password, BuildContext context,
      WidgetRef ref) async {
    if (email.isNotEmpty && password.isNotEmpty) {
      try {
        // Query to get user details from 'users' table
        final response = await pubbase!
            .from('users')
            .select('id, email, password_hash, role')
            .eq('email', email)
            .maybeSingle();

        // If no user is found, response will be null
        if (response == null) {
          info("Invalid email or password. Please try again.", Severity.error);
          return;
        }

        // Extract user details
        final userId = response['id'];
        final storedPasswordHash = response['password_hash'];
        final userRole = response['role'];
        debugPrint('--- here the user detail ud $userId & role $userRole');

        bool isPasswordValid = password == storedPasswordHash;

        if (!isPasswordValid) {
          info("Invalid email or password. Please try again.", Severity.error);
          return;
        }

        // Successful login
        await signIn(
          email,
          password,
          () async {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              info('Welcome Back!', Severity.success);
            });

            await navigatorKey.currentState?.pushAndRemoveUntil(
              PageTransition(
                type: PageTransitionType.rightToLeftWithFade,
                duration: const Duration(milliseconds: 100),
                reverseDuration: const Duration(milliseconds: 100),
                child: const Home(),
              ),
              (route) => false,
            );
          },
          () async {
            info('Oops! 505 Internal Login Error.', Severity.error);
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.clear();
          },
        );
      } on PostgrestException catch (e) {
        info("Database error: ${e.message}", Severity.error);
      } on SocketException {
        info('Check your internet connection.', Severity.error);
      } catch (e) {
        debugPrint(e.toString());
        info("An error occurred during login.", Severity.error);
      }
    } else {
      info("Please enter both email and password.", Severity.info);
    }
  }

  Future<void> signOut() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    try {
      await prefs.clear();

      await pubbase!.auth.signOut();
    } catch (e) {
      debugPrint('Sign out error: $e');

      await prefs.clear();

      await pubbase!.auth.signOut();
    } finally {
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/about', (route) => false);
    }
  }

  Future<void> signIn(String email, String password, VoidCallback onSuccess,
      VoidCallback onError) async {
    try {
      final supabase = Supabase.instance.client;
      final AuthResponse response = await supabase.auth
          .signInWithPassword(email: email, password: password);

      final Session? session = response.session;
      final User? user = response.user;

      if (session == null || user == null) {
        // ignore: use_build_context_synchronously
        info('User Credential error, reach Administrative', Severity.warning);

        onError();
      } else {
        onSuccess();
      }
    } catch (e) {
      String errorMessage = 'Check your internet connections';
      debugPrint('----------qwertyuiop : $e');
      if (e is SocketException) {
        info(errorMessage, Severity.error);
      }
      if (e is AuthException) {
        switch (e.statusCode) {
          case '400':
            errorMessage = 'Oops! Check your login details';
            break;
          case '403':
            errorMessage = '403: Access denied';
            break;
          case '500':
            errorMessage = '500: Internal Error\nTry again later.';
            break;
          default:
            errorMessage =
                'Authentication failed: code ${e.statusCode} and the message ${e.message}';
        }
      }
      if (e != 'Null check operator used on a null value') {
        info(
          errorMessage,
          Severity.error,
        );
      }

      onError();
    }
  }

  Future<void> signUp(String email, String password, String role,
      VoidCallback onSuccess, VoidCallback onError) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.signUp(email: email, password: password);
      onSuccess();
    } catch (e) {
      String errorMessage = 'Check your internet connections';
      debugPrint('----------qwertyuiop : $e');

      if (e is AuthException) {
        switch (e.statusCode) {
          case '400':
            errorMessage = 'Oops! Check your login details';
            break;
          case '403':
            errorMessage = '403: Access denied';
            break;
          case '500':
            errorMessage = '500: Internal Error\nTry again later.';
            break;
          case '429':
            errorMessage =
                'User already created, make confirm your email account to proceed!';
            Navigator.pushReplacementNamed(
                navigatorKey.currentContext!, Login.routeName);

          default:
            errorMessage =
                'Authentication failed: code ${e.statusCode} and the message ${e.message}';
        }
      } else if (e is SocketException) {
        info(errorMessage, Severity.error);
      }
      if (e != 'Null check operator used on a null value') {
        info(errorMessage, Severity.error);
      }

      onError();
    }
  }
}
