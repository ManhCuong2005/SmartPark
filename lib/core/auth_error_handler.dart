import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models.dart';

enum AuthOperation {
  unknown,
  signUp,
  signIn,
  passwordReset,
  resendConfirmation,
  passwordUpdate,
}

abstract final class AuthErrorHandler {
  static String message(
    Object error, {
    AuthOperation operation = AuthOperation.unknown,
  }) {
    if (error is ParkFailure) return error.message;

    final code = error is AuthException ? (error.code ?? '').toLowerCase() : '';
    final status = error is AuthException ? error.statusCode ?? '' : '';
    final text =
        error is AuthException
            ? error.message.toLowerCase()
            : error.toString().toLowerCase();
    final sendsEmail =
        operation == AuthOperation.signUp ||
        operation == AuthOperation.passwordReset ||
        operation == AuthOperation.resendConfirmation;

    if (code == 'over_email_send_rate_limit' ||
        (sendsEmail && status == '429') ||
        RegExp(
          r'(email|mail).*(rate limit|too many)|rate limit.*(email|mail)',
        ).hasMatch('$code $text')) {
      return 'Bạn đã yêu cầu gửi email quá nhiều lần. Vui lòng chờ một khoảng thời gian trước khi thử lại. Hãy kiểm tra cả hộp thư rác trước khi yêu cầu gửi lại.';
    }
    if (code == 'invalid_credentials' ||
        text.contains('invalid login credentials')) {
      return 'Email hoặc mật khẩu chưa chính xác. Hãy kiểm tra lại thông tin và thử lại.';
    }
    if (code == 'email_not_confirmed' || text.contains('email not confirmed')) {
      return 'Email của bạn chưa được xác nhận. Hãy kiểm tra hộp thư hoặc chọn “Gửi lại email xác nhận”.';
    }
    if (code == 'email_exists' ||
        code == 'user_already_exists' ||
        RegExp(
          r'already (registered|exists)|user already registered',
        ).hasMatch(text)) {
      return 'Email này đã được đăng ký. Hãy đăng nhập hoặc dùng chức năng quên mật khẩu.';
    }
    if (code == 'invalid_email' ||
        code == 'email_address_invalid' ||
        text.contains('invalid email')) {
      return 'Địa chỉ email chưa đúng định dạng. Hãy kiểm tra và nhập lại.';
    }
    if (code == 'weak_password' ||
        text.contains('password should be') ||
        text.contains('password is too')) {
      return 'Mật khẩu chưa đáp ứng yêu cầu. Hãy dùng mật khẩu dài và khó đoán hơn.';
    }
    if (status == '429' ||
        code == 'too_many_requests' ||
        text.contains('too many requests') ||
        text.contains('rate limit')) {
      return 'Bạn thao tác quá nhanh. Vui lòng đợi một lát rồi thử lại.';
    }
    final type = error.runtimeType.toString().toLowerCase();
    if (error is TimeoutException ||
        type.contains('socketexception') ||
        type.contains('httpexception') ||
        type.contains('clientexception') ||
        type.contains('handshakeexception') ||
        text.contains('failed to fetch') ||
        text.contains('network') ||
        text.contains('socketexception') ||
        text.contains('connection refused')) {
      return 'Không thể kết nối đến dịch vụ. Hãy kiểm tra kết nối mạng rồi thử lại.';
    }
    if (status.startsWith('5') ||
        code == 'unexpected_failure' ||
        text.contains('internal server error')) {
      return 'Dịch vụ đang gặp sự cố tạm thời. Vui lòng thử lại sau ít phút.';
    }

    return switch (operation) {
      AuthOperation.unknown => 'Đã xảy ra sự cố. Vui lòng thử lại sau ít phút.',
      AuthOperation.signUp =>
        'Chưa thể tạo tài khoản lúc này. Hãy kiểm tra thông tin và thử lại sau.',
      AuthOperation.signIn =>
        'Chưa thể đăng nhập lúc này. Hãy kiểm tra thông tin hoặc thử lại sau.',
      AuthOperation.passwordReset =>
        'Chưa thể gửi hướng dẫn khôi phục lúc này. Hãy thử lại sau ít phút.',
      AuthOperation.resendConfirmation =>
        'Chưa thể gửi email xác nhận lúc này. Hãy thử lại sau ít phút.',
      AuthOperation.passwordUpdate =>
        'Chưa thể cập nhật mật khẩu lúc này. Hãy thử lại sau ít phút.',
    };
  }
}
