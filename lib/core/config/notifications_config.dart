abstract final class NotificationsConfig {
  // Public project identifier only. Android app IDs/API configuration are
  // supplied separately by each flavor's google-services.json.
  static const firebaseProjectId = String.fromEnvironment(
    'FCM_PROJECT_ID',
    defaultValue: 'smartpark-606ea',
  );
}
