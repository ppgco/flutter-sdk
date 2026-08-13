/// Lifecycle status of a Live Activity subscription.
///
/// Not every status is emitted on every platform — see the table in
/// `LIVE_ACTIVITIES.md`. Code defensively and treat unknown values as
/// [LiveActivityStatus.unknown].
enum LiveActivityStatus {
  /// The device was registered on the backend for this live notification.
  ///
  /// Emitted on both platforms.
  registered,

  /// The activity is now rendered on the device (Android notification /
  /// iOS Live Activity).
  ///
  /// On Android this is only reported for the catch-up case — subscribing to
  /// an activity that is already running. Later `start` pushes are rendered by
  /// the native SDK without surfacing an event.
  started,

  /// The activity's update push token was registered with the backend, so it
  /// can receive further updates.
  ///
  /// iOS only, diagnostic.
  tokenRegistered,

  /// The activity finished (backend `end` event).
  ///
  /// iOS only — on Android the SDK removes the notification on its own without
  /// surfacing an event.
  ended,

  /// The device was unregistered from the live notification.
  ///
  /// Emitted on both platforms.
  unsubscribed,

  /// Something went wrong — see [LiveActivityStatusEvent.error].
  error,

  /// A status this version of the SDK does not know about.
  unknown,
}

LiveActivityStatus _statusFromString(String? value) {
  switch (value) {
    case 'registered':
      return LiveActivityStatus.registered;
    case 'started':
      return LiveActivityStatus.started;
    case 'tokenRegistered':
      return LiveActivityStatus.tokenRegistered;
    case 'ended':
      return LiveActivityStatus.ended;
    case 'unsubscribed':
      return LiveActivityStatus.unsubscribed;
    case 'error':
      return LiveActivityStatus.error;
    default:
      return LiveActivityStatus.unknown;
  }
}

/// A lifecycle event emitted for a subscribed live notification.
class LiveActivityStatusEvent {
  /// What happened.
  final LiveActivityStatus status;

  /// Backend id of the live notification this event belongs to.
  final String liveNotificationId;

  /// Platform-local activity identifier, when the platform provides one.
  ///
  /// iOS only (the ActivityKit activity id).
  final String? activityId;

  /// Error description when [status] is [LiveActivityStatus.error].
  final String? error;

  const LiveActivityStatusEvent({
    required this.status,
    required this.liveNotificationId,
    this.activityId,
    this.error,
  });

  factory LiveActivityStatusEvent.fromMap(Map<dynamic, dynamic> map) {
    return LiveActivityStatusEvent(
      status: _statusFromString(map['status'] as String?),
      liveNotificationId: (map['liveNotificationId'] as String?) ?? '',
      activityId: map['activityId'] as String?,
      error: map['error'] as String?,
    );
  }

  @override
  String toString() {
    return 'LiveActivityStatusEvent(status: $status, '
        'liveNotificationId: $liveNotificationId, '
        'activityId: $activityId, error: $error)';
  }
}

/// A tap on a Live Activity — either on its body or on one of its action
/// buttons.
class LiveActivityClick {
  /// Backend id of the clicked live notification.
  final String liveNotificationId;

  /// Deep link carried by the clicked element, if any.
  ///
  /// On Android, whether the SDK already opened it depends on the
  /// `handleNotificationLink` flag passed to `PushpushgoSdk.initialize`. On iOS
  /// that flag does not apply — the native SDK always forwards the tap to this
  /// destination, and the handler is informational. See `LIVE_ACTIVITIES.md`.
  final String? deepLink;

  /// Index of the tapped action button, or `-1` for a tap on the body.
  ///
  /// Reported on both platforms.
  final int actionIndex;

  const LiveActivityClick({
    required this.liveNotificationId,
    this.deepLink,
    this.actionIndex = -1,
  });

  /// Whether the user tapped the notification body rather than a button.
  bool get isBodyClick => actionIndex < 0;

  factory LiveActivityClick.fromMap(Map<dynamic, dynamic> map) {
    return LiveActivityClick(
      liveNotificationId: (map['liveNotificationId'] as String?) ?? '',
      deepLink: map['deepLink'] as String?,
      actionIndex: (map['actionIndex'] as int?) ?? -1,
    );
  }

  @override
  String toString() {
    return 'LiveActivityClick(liveNotificationId: $liveNotificationId, '
        'deepLink: $deepLink, actionIndex: $actionIndex)';
  }
}

/// Snapshot of a Live Activity currently tracked by the native SDK.
///
/// **Android only** for the football-match fields: the iOS ActivityKit
/// bookkeeping exposes just the identifiers, so everything below [status] is
/// `null` there. On Android they are populated for the
/// `FOOTBALL_MATCH_TRACKING` template and `null` for other templates.
class LiveActivityInfo {
  /// Backend id of the live notification.
  final String id;

  /// Template name, e.g. `FOOTBALL_MATCH_TRACKING`.
  final String? template;

  /// Native tracking status, e.g. `active` / `ended`.
  final String? status;

  /// Home team name.
  final String? homeTeamName;

  /// Away team name.
  final String? awayTeamName;

  /// Home team score.
  final int? homeScore;

  /// Away team score.
  final int? awayScore;

  /// Current match phase, e.g. `FIRST_HALF`.
  final String? phase;

  const LiveActivityInfo({
    required this.id,
    this.template,
    this.status,
    this.homeTeamName,
    this.awayTeamName,
    this.homeScore,
    this.awayScore,
    this.phase,
  });

  factory LiveActivityInfo.fromMap(Map<dynamic, dynamic> map) {
    return LiveActivityInfo(
      id: (map['id'] as String?) ?? '',
      template: map['template'] as String?,
      status: map['status'] as String?,
      homeTeamName: map['homeTeamName'] as String?,
      awayTeamName: map['awayTeamName'] as String?,
      homeScore: map['homeScore'] as int?,
      awayScore: map['awayScore'] as int?,
      phase: map['phase'] as String?,
    );
  }

  @override
  String toString() {
    return 'LiveActivityInfo(id: $id, template: $template, status: $status, '
        '$homeTeamName $homeScore : $awayScore $awayTeamName, phase: $phase)';
  }
}
