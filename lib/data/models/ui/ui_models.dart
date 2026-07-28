enum Priority { high, medium, low, none }

enum RepeatType { none, daily, weekly, monthly, yearly, custom }

enum MatrixBlock {
  urgentImportant,
  notUrgentImportant,
  urgentNotImportant,
  notUrgentNotImportant,
}

extension MatrixBlockX on MatrixBlock {
  String get apiValue => switch (this) {
    MatrixBlock.urgentImportant => 'urgent_important',
    MatrixBlock.notUrgentImportant => 'not_urgent_important',
    MatrixBlock.urgentNotImportant => 'urgent_not_important',
    MatrixBlock.notUrgentNotImportant => 'not_urgent_not_important',
  };

  String get id => switch (this) {
    MatrixBlock.urgentImportant => 'urgent-important',
    MatrixBlock.notUrgentImportant => 'not-urgent-important',
    MatrixBlock.urgentNotImportant => 'urgent-not-important',
    MatrixBlock.notUrgentNotImportant => 'not-urgent-not-important',
  };

  static MatrixBlock fromApi(String block) => switch (block) {
    'urgent_important' => MatrixBlock.urgentImportant,
    'not_urgent_important' => MatrixBlock.notUrgentImportant,
    'urgent_not_important' => MatrixBlock.urgentNotImportant,
    _ => MatrixBlock.notUrgentNotImportant,
  };

  static MatrixBlock fromId(String id) => switch (id) {
    'urgent-important' => MatrixBlock.urgentImportant,
    'not-urgent-important' => MatrixBlock.notUrgentImportant,
    'urgent-not-important' => MatrixBlock.urgentNotImportant,
    _ => MatrixBlock.notUrgentNotImportant,
  };
}

class TaskDuration {
  const TaskDuration({required this.start, required this.end});
  final String start;
  final String end;
}

class RepeatCustom {
  const RepeatCustom({
    required this.interval,
    required this.unit,
    this.weekdays,
    this.monthDay,
  });

  final int interval;
  /// `week` or `month`
  final String unit;
  final List<int>? weekdays;
  final int? monthDay;
}

class Task {
  Task({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.dueTime,
    this.duration,
    required this.priority,
    required this.completed,
    this.completedAt,
    this.notification,
    required this.repeat,
    this.repeatDays,
    this.repeatCustom,
    this.imageUrl,
    this.attachmentId,
    this.attachmentName,
    this.attachmentMimeType,
    this.isAllDay = false,
    this.listKey,
    this.matrixBlock,
    this.seriesId,
    this.parentTaskId,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? dueDate;
  final String? dueTime;
  final TaskDuration? duration;
  final Priority priority;
  final bool completed;
  final String? completedAt;
  final String? notification;
  final RepeatType repeat;
  final List<int>? repeatDays;
  final RepeatCustom? repeatCustom;
  final String? imageUrl;
  final int? attachmentId;
  final String? attachmentName;
  final String? attachmentMimeType;
  final bool isAllDay;
  final TaskGroupKey? listKey;
  final MatrixBlock? matrixBlock;
  final String? seriesId;
  final String? parentTaskId;
  final String createdAt;

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? dueDate,
    String? dueTime,
    TaskDuration? duration,
    Priority? priority,
    bool? completed,
    String? completedAt,
    String? notification,
    RepeatType? repeat,
    List<int>? repeatDays,
    RepeatCustom? repeatCustom,
    String? imageUrl,
    int? attachmentId,
    String? attachmentName,
    String? attachmentMimeType,
    bool? isAllDay,
    TaskGroupKey? listKey,
    MatrixBlock? matrixBlock,
    String? seriesId,
    String? parentTaskId,
    String? createdAt,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    dueDate: dueDate ?? this.dueDate,
    dueTime: dueTime ?? this.dueTime,
    duration: duration ?? this.duration,
    priority: priority ?? this.priority,
    completed: completed ?? this.completed,
    completedAt: completedAt ?? this.completedAt,
    notification: notification ?? this.notification,
    repeat: repeat ?? this.repeat,
    repeatDays: repeatDays ?? this.repeatDays,
    repeatCustom: repeatCustom ?? this.repeatCustom,
    imageUrl: imageUrl ?? this.imageUrl,
    attachmentId: attachmentId ?? this.attachmentId,
    attachmentName: attachmentName ?? this.attachmentName,
    attachmentMimeType: attachmentMimeType ?? this.attachmentMimeType,
    isAllDay: isAllDay ?? this.isAllDay,
    listKey: listKey ?? this.listKey,
    matrixBlock: matrixBlock ?? this.matrixBlock,
    seriesId: seriesId ?? this.seriesId,
    parentTaskId: parentTaskId ?? this.parentTaskId,
    createdAt: createdAt ?? this.createdAt,
  );
}

class OtterUser {
  OtterUser({
    required this.id,
    required this.email,
    required this.name,
    this.avatar,
    this.isPremium = false,
  });

  final String id;
  final String email;
  final String name;
  final String? avatar;
  final bool isPremium;
}

class AppSettings {
  AppSettings({
    required this.language,
    required this.theme,
    required this.visibleGroups,
    required this.notifications,
    required this.vibration,
    required this.notificationSound,
    required this.completionSound,
    required this.bottomNavItems,
    this.timezone,
    this.isPremium = false,
    this.calendarDefaultView = 'day',
    this.calendarCollapseEarlyHours = false,
    this.calendarCollapseLateHours = false,
  });

  final String language;
  final String theme;
  final List<String> visibleGroups;
  final bool notifications;
  final bool vibration;
  final String notificationSound;
  final String completionSound;
  final List<String> bottomNavItems;
  final String? timezone;
  final bool isPremium;

  /// Local-only: initial calendar view (`day` | `week` | `month` | `year`).
  final String calendarDefaultView;

  /// Local-only: collapse 00:00–06:00 by default.
  final bool calendarCollapseEarlyHours;

  /// Local-only: collapse 22:00–00:00 by default.
  final bool calendarCollapseLateHours;

  static AppSettings defaults() => AppSettings(
    language: 'ru',
    theme: 'light',
    visibleGroups: ['overdue', 'today', 'tomorrow', 'later', 'nodate'],
    notifications: true,
    vibration: true,
    notificationSound: 'default',
    completionSound: 'default',
    bottomNavItems: ['tasks', 'calendar', 'matrix', 'pomodoro', 'settings'],
  );

  AppSettings copyWith({
    String? language,
    String? theme,
    List<String>? visibleGroups,
    bool? notifications,
    bool? vibration,
    String? notificationSound,
    String? completionSound,
    List<String>? bottomNavItems,
    String? timezone,
    bool? isPremium,
    String? calendarDefaultView,
    bool? calendarCollapseEarlyHours,
    bool? calendarCollapseLateHours,
  }) => AppSettings(
    language: language ?? this.language,
    theme: theme ?? this.theme,
    visibleGroups: visibleGroups ?? this.visibleGroups,
    notifications: notifications ?? this.notifications,
    vibration: vibration ?? this.vibration,
    notificationSound: notificationSound ?? this.notificationSound,
    completionSound: completionSound ?? this.completionSound,
    bottomNavItems: bottomNavItems ?? this.bottomNavItems,
    timezone: timezone ?? this.timezone,
    isPremium: isPremium ?? this.isPremium,
    calendarDefaultView: calendarDefaultView ?? this.calendarDefaultView,
    calendarCollapseEarlyHours:
        calendarCollapseEarlyHours ?? this.calendarCollapseEarlyHours,
    calendarCollapseLateHours:
        calendarCollapseLateHours ?? this.calendarCollapseLateHours,
  );
}

class PomodoroSettings {
  PomodoroSettings({
    required this.duration,
    required this.shortBreak,
    required this.longBreak,
    required this.sessionsUntilLong,
    required this.sound,
    required this.workingSound,
    required this.showOnLockScreen,
  });

  final int duration;
  final int shortBreak;
  final int longBreak;
  final int sessionsUntilLong;
  final String sound;
  final String workingSound;
  final bool showOnLockScreen;

  static PomodoroSettings defaults() => PomodoroSettings(
    duration: 25,
    shortBreak: 5,
    longBreak: 15,
    sessionsUntilLong: 4,
    sound: 'default',
    workingSound: 'default',
    showOnLockScreen: false,
  );
}

enum TaskGroupKey { overdue, today, tomorrow, later, nodate, completed }

extension TaskGroupKeyX on TaskGroupKey {
  String get apiKey => switch (this) {
    TaskGroupKey.nodate => 'no_deadline',
    _ => name,
  };

  static TaskGroupKey fromApi(String key) => switch (key) {
    'no_deadline' => TaskGroupKey.nodate,
    'overdue' => TaskGroupKey.overdue,
    'today' => TaskGroupKey.today,
    'tomorrow' => TaskGroupKey.tomorrow,
    'later' => TaskGroupKey.later,
    'completed' => TaskGroupKey.completed,
    _ => TaskGroupKey.nodate,
  };

  String get titleRu => switch (this) {
    TaskGroupKey.overdue => 'Просрочено',
    TaskGroupKey.today => 'Сегодня',
    TaskGroupKey.tomorrow => 'Завтра',
    TaskGroupKey.later => 'Позже',
    TaskGroupKey.nodate => 'Без срока',
    TaskGroupKey.completed => 'Выполнено',
  };
}
