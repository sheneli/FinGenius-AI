import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Consent-gated analytics with a fixed event taxonomy (docs/analytics_events.md).
/// Events carry NO monetary values, merchant names, or free text — counts and
/// categories only (privacy by design).
class AnalyticsService {
  AnalyticsService(this._analytics);
  final FirebaseAnalytics? _analytics;

  bool _consented = false;

  Future<void> setConsent({required bool granted}) async {
    _consented = granted;
    await _analytics?.setAnalyticsCollectionEnabled(granted);
  }

  Future<void> log(String name, [Map<String, Object>? params]) async {
    if (!_consented) return;
    await _analytics?.logEvent(name: name, parameters: params);
  }

  // Event taxonomy — the only names ever logged.
  static const signUp = 'fg_sign_up';
  static const signIn = 'fg_sign_in';
  static const txAddManual = 'fg_tx_add_manual';
  static const txAddOcr = 'fg_tx_add_ocr';
  static const txAddVoice = 'fg_tx_add_voice';
  static const ocrScanStarted = 'fg_ocr_scan_started';
  static const ocrScanSucceeded = 'fg_ocr_scan_succeeded';
  static const ocrScanFailed = 'fg_ocr_scan_failed';
  static const budgetCreated = 'fg_budget_created';
  static const goalCreated = 'fg_goal_created';
  static const goalContribution = 'fg_goal_contribution';
  static const aiQuestionAsked = 'fg_ai_question_asked';
  static const aiFallbackServed = 'fg_ai_fallback_served';
  static const subscriptionConfirmed = 'fg_subscription_confirmed';
  static const subscriptionDismissed = 'fg_subscription_dismissed';
  static const exportRequested = 'fg_export_requested';
  static const accountDeleted = 'fg_account_deleted';
  static const offlineTxQueued = 'fg_offline_tx_queued';
  static const syncCompleted = 'fg_sync_completed';
}

final analyticsProvider = Provider<AnalyticsService>((_) => AnalyticsService(null)); // overridden in bootstrap
