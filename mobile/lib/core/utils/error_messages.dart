import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// User-facing API exception that carries a short, plain-English message
/// without exposing HTTP status codes or raw server payloads.
class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  factory ApiException.fromStatus(int statusCode, {String? fallback}) {
    switch (statusCode) {
      case 400:
        return ApiException(fallback ?? 'Please check your details and try again.');
      case 401:
        return const ApiException('Your session expired. Please sign in again.');
      case 403:
        return const ApiException("You don't have permission to do that.");
      case 404:
        return const ApiException("We couldn't find that item.");
      case 413:
        return const ApiException('That photo is too large. Try a smaller image.');
      case 415:
        return const ApiException("That image format isn't supported. Try JPG or PNG.");
      case 422:
        return const ApiException('Some details look invalid. Please review and try again.');
      case 429:
        return const ApiException('Too many requests right now. Please wait a moment.');
      default:
        if (statusCode >= 500) {
          return const ApiException('Server is busy right now. Please try again shortly.');
        }
        return ApiException(fallback ?? 'Something went wrong. Please try again.');
    }
  }

  @override
  String toString() => message;
}

/// Converts any thrown error into a short, friendly plain-English message
/// with no technical jargon, exception prefixes, or numeric error codes.
class ErrorMessages {
  static String friendly(Object error, {String? fallback}) {
    if (error is ApiException) {
      return error.message;
    }

    if (error is TimeoutException) {
      return 'Connection timed out. Please try again.';
    }

    if (error is SocketException || error is http.ClientException) {
      return "Can't reach the server. Check your connection and try again.";
    }

    if (error is AuthException) {
      return _friendlyAuthMessage(error.message);
    }

    if (error is FileSystemException) {
      return "Couldn't read that file on your device.";
    }

    if (error is FormatException) {
      return "Something didn't look right. Please try again.";
    }

    final raw = error.toString().toLowerCase();

    if (raw.contains('socketexception') ||
        raw.contains('connection refused') ||
        raw.contains('failed host lookup') ||
        raw.contains('network is unreachable') ||
        raw.contains('connection reset') ||
        raw.contains('handshakeexception')) {
      return "Can't reach the server. Check your connection and try again.";
    }

    if (raw.contains('timeout') || raw.contains('timed out')) {
      return 'Connection timed out. Please try again.';
    }

    if (raw.contains('permission') || raw.contains('camera_access_denied') || raw.contains('photo_access_denied')) {
      return 'Please allow camera and photo access in your phone settings.';
    }

    if (raw.contains('database') || raw.contains('sqlite')) {
      return "Couldn't save data on your device. Please try again.";
    }

    return fallback ?? 'Something went wrong. Please try again.';
  }

  static String _friendlyAuthMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid credentials') ||
        lower.contains('invalid email or password')) {
      return 'Incorrect email or password.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email address before signing in.';
    }
    if (lower.contains('already registered') || lower.contains('already exists')) {
      return 'An account with this email already exists.';
    }
    if (lower.contains('password') && (lower.contains('weak') || lower.contains('short') || lower.contains('least'))) {
      return 'Please choose a stronger password.';
    }
    if (lower.contains('invalid email') || lower.contains('validate email')) {
      return 'Please enter a valid email address.';
    }
    if (lower.contains('unsupported provider') ||
        lower.contains('provider is not enabled') ||
        lower.contains('not enabled')) {
      return "This sign-in option isn't turned on yet. Try email or guest mode.";
    }
    if (lower.contains('sms') ||
        lower.contains('phone provider') ||
        lower.contains('phone logins are disabled')) {
      return "Phone sign-in isn't enabled yet. Try email or guest mode.";
    }
    if (lower.contains('otp') ||
        lower.contains('token has expired') ||
        lower.contains('invalid token')) {
      return 'That verification code is invalid or expired. Please request a new code.';
    }
    if (lower.contains('invalid phone') || lower.contains('phone number')) {
      return 'Please enter a valid phone number including country code (e.g. +92...).';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (lower.contains('network') || lower.contains('socket') || lower.contains('host lookup')) {
      return 'No internet connection. Please check your network.';
    }
    return "Couldn't sign you in right now. Please try again.";
  }
}
