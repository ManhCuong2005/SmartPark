export type AuthOperation =
  | "unknown"
  | "signIn"
  | "signUp"
  | "passwordReset"
  | "resendConfirmation"
  | "passwordUpdate"
  | "signOut";

function fields(error: unknown) {
  const value = error && typeof error === "object" ? error : {};
  const item = value as Record<string, unknown>;
  return {
    name: String(item.name ?? "").toLowerCase(),
    code: String(item.code ?? "").toLowerCase(),
    status: String(item.statusCode ?? item.status ?? ""),
    text: String(item.message ?? error ?? "").toLowerCase(),
  };
}

export function isAuthError(error: unknown) {
  const { name, code, text } = fields(error);
  return (
    name.includes("auth") ||
    [
      "over_email_send_rate_limit",
      "invalid_credentials",
      "email_not_confirmed",
      "email_exists",
      "user_already_exists",
      "invalid_email",
      "email_address_invalid",
      "weak_password",
    ].includes(code) ||
    /authapiexception|authapierror|email rate limit exceeded/i.test(text)
  );
}

export function authErrorMessage(
  error: unknown,
  operation: AuthOperation = "unknown",
) {
  const { code, status, text } = fields(error);
  const sendsEmail = ["signUp", "passwordReset", "resendConfirmation"].includes(
    operation,
  );

  if (
    code === "over_email_send_rate_limit" ||
    (sendsEmail && status === "429") ||
    /(?:email|mail).*(?:rate limit|too many)|rate limit.*(?:email|mail)/.test(
      `${code} ${text}`,
    )
  )
    return "Bạn đã yêu cầu gửi email quá nhiều lần. Vui lòng chờ một khoảng thời gian trước khi thử lại. Hãy kiểm tra cả hộp thư rác trước khi yêu cầu gửi lại.";
  if (code === "invalid_credentials" || /invalid login credentials/i.test(text))
    return "Email hoặc mật khẩu chưa chính xác. Hãy kiểm tra lại thông tin và thử lại.";
  if (code === "email_not_confirmed" || /email not confirmed/i.test(text))
    return "Email của bạn chưa được xác nhận. Hãy kiểm tra hộp thư hoặc chọn “Gửi lại email xác nhận”.";
  if (
    ["email_exists", "user_already_exists"].includes(code) ||
    /already (registered|exists)|user already registered/i.test(text)
  )
    return "Email này đã được đăng ký. Hãy đăng nhập hoặc dùng chức năng quên mật khẩu.";
  if (
    ["invalid_email", "email_address_invalid"].includes(code) ||
    /invalid email/i.test(text)
  )
    return "Địa chỉ email chưa đúng định dạng. Hãy kiểm tra và nhập lại.";
  if (
    code === "weak_password" ||
    /password should be|password is too/i.test(text)
  )
    return "Mật khẩu chưa đáp ứng yêu cầu. Hãy dùng mật khẩu dài và khó đoán hơn.";
  if (
    status === "429" ||
    code === "too_many_requests" ||
    /too many requests|rate limit/i.test(text)
  )
    return "Bạn thao tác quá nhanh. Vui lòng đợi một lát rồi thử lại.";
  if (/failed to fetch|network|fetch failed|networkerror|load failed/i.test(text))
    return "Không thể kết nối đến dịch vụ. Hãy kiểm tra kết nối mạng rồi thử lại.";
  if (status.startsWith("5") || /internal server error/i.test(text))
    return "Dịch vụ đang gặp sự cố tạm thời. Vui lòng thử lại sau ít phút.";

  switch (operation) {
    case "unknown":
      return "Đã xảy ra sự cố. Vui lòng thử lại sau ít phút.";
    case "signUp":
      return "Chưa thể tạo tài khoản lúc này. Hãy kiểm tra thông tin và thử lại sau.";
    case "signIn":
      return "Chưa thể đăng nhập lúc này. Hãy kiểm tra thông tin hoặc thử lại sau.";
    case "passwordReset":
      return "Chưa thể gửi hướng dẫn khôi phục lúc này. Hãy thử lại sau ít phút.";
    case "resendConfirmation":
      return "Chưa thể gửi email xác nhận lúc này. Hãy thử lại sau ít phút.";
    case "passwordUpdate":
      return "Chưa thể cập nhật mật khẩu lúc này. Hãy thử lại sau ít phút.";
    case "signOut":
      return "Chưa thể đăng xuất lúc này. Hãy kiểm tra kết nối rồi thử lại.";
  }
}
