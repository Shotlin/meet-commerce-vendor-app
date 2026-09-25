/// API endpoints and base URL for the FreshCuts Vendor App.
///
/// The base URL points at the local Fastify backend during development.
/// Override at build time, e.g.:
///   flutter run --dart-define=BASE_URL=http://192.168.1.10:4500/api/v1
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:4500/api/v1',
  );

  // Auth (existing OTP backend)
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String refreshToken = '/auth/refresh-token';

  // Vendor procurement (vendor surface)
  static const String vendorBase = '/vendor-procurement/vendor';
  static const String vendorRequests = '$vendorBase/requests';
  static const String vendorQuotes = '$vendorBase/quotes';
  static const String vendorSupplies = '$vendorBase/supplies';
  static const String vendorServiceProfile = '$vendorBase/service-profile';
  static const String vendorPerformance = '$vendorBase/performance';
  static const String vendorReviews = '$vendorBase/reviews';

  static String requestDetail(String requestId) => '$vendorRequests/$requestId';
  static String acceptOffer(String requestId) => '$vendorRequests/$requestId/accept';
  static String declineRequest(String requestId) => '$vendorRequests/$requestId/decline';
  static String submitQuote(String requestId) => '$vendorRequests/$requestId/quote';
  static String quoteDetail(String quoteId) => '$vendorQuotes/$quoteId';
  static String withdrawQuote(String quoteId) => '$vendorQuotes/$quoteId/withdraw';
  static String supplyDetail(String supplyId) => '$vendorSupplies/$supplyId';

  // Vendor business profile (older `vendors` module — self-service via
  // vendor-scoped JWT; the server resolves the real target from the JWT,
  // this vendorId is only needed to satisfy the URL's :vendorId segment).
  static String vendorDetail(String vendorId) => '/vendors/$vendorId';
  static String vendorProfile(String vendorId) => '/vendors/$vendorId/profile';
  static String vendorSettings(String vendorId) => '/vendors/$vendorId/settings';
  static String vendorKycStatus(String vendorId) => '/vendor-kyc/$vendorId/kyc/status';
  static String vendorKycSubmit(String vendorId) => '/vendor-kyc/$vendorId/kyc';
}
