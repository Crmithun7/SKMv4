import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:skmcam/utils/error_utils.dart';

void main() {
  group('friendlyError', () {
    test('strips the Exception: prefix from a plain, friendly Exception', () {
      expect(friendlyError(Exception('Please enter your login code.')),
          'Please enter your login code.');
    });

    test('leaves a message with no Exception: prefix untouched', () {
      expect(friendlyError('plain string error'), 'plain string error');
    });

    test('falls back to the generic message when "Exception" still appears '
        'after the prefix is stripped', () {
      final e = Exception('failed: Exception: nested detail');
      expect(friendlyError(e), genericErrorMessage);
    });

    test('falls back to the generic message for snake_case/db-style text', () {
      expect(
        friendlyError(Exception('null value in column employee_id violates')),
        genericErrorMessage,
      );
    });

    test('honors a custom fallback for technical-looking text', () {
      final e = Exception('NoSuchMethodError: foo');
      expect(friendlyError(e, fallback: 'custom fallback'), 'custom fallback');
    });

    test('falls back to the generic message for very long text', () {
      final e = Exception('a' * 221);
      expect(friendlyError(e), genericErrorMessage);
    });

    test('maps SocketException to the no-internet message', () {
      expect(friendlyError(const SocketException('Failed host lookup')),
          noInternetMessage);
    });

    test('maps http.ClientException to the no-internet message', () {
      expect(friendlyError(http.ClientException('Connection closed')),
          noInternetMessage);
    });

    test('maps TimeoutException to the slow-network message', () {
      expect(friendlyError(TimeoutException('timed out')), slowNetworkMessage);
    });

    test('maps HandshakeException to a secure-connection message', () {
      final message = friendlyError(
        const HandshakeException(
            'Handshake error (OS Error: CERTIFICATE_VERIFY_FAILED)'),
      );
      expect(message, contains('connect securely'));
      expect(message, isNot(contains('CERTIFICATE_VERIFY_FAILED')));
    });

    test('maps TlsException the same way as HandshakeException', () {
      expect(
        friendlyError(const TlsException('tls error')),
        friendlyError(const HandshakeException('')),
      );
    });

    test('maps FormatException to the bad-reply message', () {
      expect(
        friendlyError(const FormatException('Unexpected character at line 1')),
        badReplyMessage,
      );
    });

    test('delegates CameraException to friendlyCameraError', () {
      final e = CameraException('CameraAccessDenied', 'denied');
      expect(friendlyError(e), friendlyCameraError(e));
      expect(friendlyError(e), contains('Camera access is turned off'));
    });
  });

  group('isConnectivityError', () {
    test('is true for every type friendlyError treats as a network problem',
        () {
      expect(isConnectivityError(const SocketException('x')), isTrue);
      expect(isConnectivityError(http.ClientException('x')), isTrue);
      expect(isConnectivityError(TimeoutException('x')), isTrue);
      expect(isConnectivityError(const HandshakeException('x')), isTrue);
      expect(isConnectivityError(const TlsException('x')), isTrue);
    });

    test('is false for a server rejection or any other error', () {
      expect(isConnectivityError(Exception(sessionExpiredMessage)), isFalse);
      expect(isConnectivityError(const FormatException('x')), isFalse);
      expect(
        isConnectivityError(CameraException('permission', 'denied')),
        isFalse,
      );
    });
  });

  group('friendlyCameraError', () {
    test('explains a permission-denied error', () {
      expect(
        friendlyCameraError(CameraException('permission', 'denied')),
        contains('Camera access is turned off'),
      );
    });

    test('explains a restricted-camera error', () {
      expect(
        friendlyCameraError(CameraException('restricted', 'restricted')),
        contains('restricted'),
      );
    });

    test('explains a missing-camera error', () {
      expect(
        friendlyCameraError(CameraException('no_camera', 'none')),
        'No camera was found on this phone.',
      );
    });

    test('falls back to a generic camera message for unknown codes', () {
      expect(
        friendlyCameraError(CameraException('cameraNotRunning', 'busy')),
        contains('camera could not be started'),
      );
    });
  });

  group('serverErrorMessage', () {
    http.Response response(int status, Map<String, dynamic>? body) {
      return http.Response(body == null ? '' : jsonEncode(body), status);
    }

    test('maps a known detail string to a plain-language message', () {
      final r = response(401, {'detail': 'Invalid credentials'});
      expect(serverErrorMessage(r),
          'Incorrect login code or password. Please check and try again.');
    });

    test('uses the session-expired message for a 401 with no usable detail',
        () {
      expect(serverErrorMessage(response(401, null)), sessionExpiredMessage);
    });

    test('uses the no-access message for a 403 with no usable detail', () {
      expect(serverErrorMessage(response(403, null)), noAccessMessage);
    });

    test('uses the server-down message for any 5xx', () {
      final r = response(500, {'detail': 'relation "users" does not exist'});
      expect(serverErrorMessage(r), serverDownMessage);
    });

    test(
        'shows the 503 maintenance detail verbatim when it reads as plain '
        'text', () {
      final r = response(503, {
        'detail': 'We are doing scheduled maintenance. Please check back in '
            'an hour.'
      });
      expect(serverErrorMessage(r),
          'We are doing scheduled maintenance. Please check back in an hour.');
    });

    test('uses the slow-network message for a 408', () {
      expect(serverErrorMessage(response(408, null)), slowNetworkMessage);
    });

    test('uses a rate-limit message for a 429', () {
      expect(serverErrorMessage(response(429, null)),
          'Too many attempts. Please wait a minute and try again.');
    });

    test('maps a FastAPI validation error list to a plain-language message',
        () {
      final r = http.Response(
        '{"detail": [{"loc": ["body", "login_code"], "msg": "field '
        'required", "type": "value_error.missing"}]}',
        422,
      );
      expect(serverErrorMessage(r),
          'Some information is missing or not valid. Please check and try again.');
    });

    test('passes through a server detail that already reads as plain text',
        () {
      final r =
          response(400, {'detail': 'Your account is blocked. Contact admin.'});
      expect(
          serverErrorMessage(r), 'Your account is blocked. Contact admin.');
    });

    test(
        'falls back to the given fallback for an unmapped status with '
        'technical detail', () {
      final r = response(
          400, {'detail': 'IntegrityError: duplicate key value'});
      expect(serverErrorMessage(r, fallback: 'custom fallback'),
          'custom fallback');
    });
  });
}
