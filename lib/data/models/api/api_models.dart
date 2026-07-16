class ApiTask {
  ApiTask({
    required this.id,
    required this.title,
    this.description,
    this.dueAt,
    this.startAt,
    this.endAt,
    this.reminderAt,
    required this.repeatUnit,
    required this.repeatInterval,
    required this.priority,
    required this.matrixBlock,
    this.image,
    required this.isCompleted,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String? description;
  final String? dueAt;
  final String? startAt;
  final String? endAt;
  final String? reminderAt;
  final String repeatUnit;
  final int repeatInterval;
  final String priority;
  final String matrixBlock;
  final String? image;
  final bool isCompleted;
  final String? completedAt;
  final String createdAt;
  final String updatedAt;

  factory ApiTask.fromJson(Map<String, dynamic> json) => ApiTask(
        id: json['id'] as int,
        title: json['title'] as String,
        description: json['description'] as String?,
        dueAt: json['due_at'] as String?,
        startAt: json['start_at'] as String?,
        endAt: json['end_at'] as String?,
        reminderAt: json['reminder_at'] as String?,
        repeatUnit: json['repeat_unit'] as String? ?? 'none',
        repeatInterval: json['repeat_interval'] as int? ?? 1,
        priority: json['priority'] as String? ?? 'medium',
        matrixBlock:
            json['matrix_block'] as String? ?? 'not_urgent_not_important',
        image: json['image'] as String?,
        isCompleted: json['is_completed'] as bool? ?? false,
        completedAt: json['completed_at'] as String?,
        createdAt: json['created_at'] as String,
        updatedAt: json['updated_at'] as String,
      );
}

class ApiTaskGroup {
  ApiTaskGroup({
    required this.key,
    required this.title,
    required this.count,
    required this.tasks,
  });

  final String key;
  final String title;
  final int count;
  final List<ApiTask> tasks;

  factory ApiTaskGroup.fromJson(Map<String, dynamic> json) => ApiTaskGroup(
        key: json['key'] as String,
        title: json['title'] as String,
        count: json['count'] as int? ?? 0,
        tasks: (json['tasks'] as List<dynamic>? ?? [])
            .map((e) => ApiTask.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ApiCalendarResponse {
  ApiCalendarResponse({
    required this.view,
    required this.date,
    required this.tasks,
  });

  final String view;
  final String date;
  final List<ApiTask> tasks;

  factory ApiCalendarResponse.fromJson(Map<String, dynamic> json) =>
      ApiCalendarResponse(
        view: json['view'] as String,
        date: json['date'] as String,
        tasks: (json['tasks'] as List<dynamic>? ?? [])
            .map((e) => ApiTask.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ApiMatrixBlockData {
  ApiMatrixBlockData({
    required this.block,
    required this.title,
    required this.tasks,
    this.count = 0,
  });

  final String block;
  final String title;
  final int count;
  final List<ApiTask> tasks;

  factory ApiMatrixBlockData.fromJson(Map<String, dynamic> json) =>
      ApiMatrixBlockData(
        block: json['block'] as String,
        title: json['title'] as String? ?? '',
        count: json['count'] as int? ?? 0,
        tasks: (json['tasks'] as List<dynamic>? ?? [])
            .map((e) => ApiTask.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class ApiSound {
  ApiSound({
    required this.key,
    required this.category,
    required this.title,
    required this.emoji,
    this.audioUrl,
    required this.sortOrder,
  });

  final String key;
  final String category;
  final String title;
  final String emoji;
  final String? audioUrl;
  final int sortOrder;

  factory ApiSound.fromJson(Map<String, dynamic> json) => ApiSound(
        key: json['key'] as String? ?? '',
        category: json['category'] as String? ?? '',
        title: json['title'] as String? ?? '',
        emoji: json['emoji'] as String? ?? '',
        audioUrl: json['audio_url'] as String?,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}

class ApiPomodoroSettings {
  ApiPomodoroSettings({
    required this.durationMinutes,
    required this.shortBreakMinutes,
    required this.showOnLockScreen,
    required this.timerEndSound,
    this.timerEndSoundDetail,
    required this.workSound,
    this.workSoundDetail,
  });

  final int durationMinutes;
  final int shortBreakMinutes;
  final bool showOnLockScreen;
  final String timerEndSound;
  final ApiSound? timerEndSoundDetail;
  final String workSound;
  final ApiSound? workSoundDetail;

  factory ApiPomodoroSettings.fromJson(Map<String, dynamic> json) =>
      ApiPomodoroSettings(
        durationMinutes: json['duration_minutes'] as int? ?? 25,
        shortBreakMinutes: json['short_break_minutes'] as int? ?? 5,
        showOnLockScreen: json['show_on_lock_screen'] as bool? ?? false,
        timerEndSound: json['timer_end_sound'] as String? ?? 'bell',
        timerEndSoundDetail: json['timer_end_sound_detail'] != null
            ? ApiSound.fromJson(
                json['timer_end_sound_detail'] as Map<String, dynamic>,
              )
            : null,
        workSound: json['work_sound'] as String? ?? 'none',
        workSoundDetail: json['work_sound_detail'] != null
            ? ApiSound.fromJson(
                json['work_sound_detail'] as Map<String, dynamic>,
              )
            : null,
      );

  Map<String, dynamic> toJson() => {
        'duration_minutes': durationMinutes,
        'short_break_minutes': shortBreakMinutes,
        'show_on_lock_screen': showOnLockScreen,
        'timer_end_sound': timerEndSound,
        'work_sound': workSound,
      };
}

class ApiPomodoroSession {
  ApiPomodoroSession({
    required this.id,
    this.taskId,
    required this.durationMinutes,
    required this.state,
    this.startedAt,
    this.endedAt,
    required this.createdAt,
  });

  final int id;
  final int? taskId;
  final int durationMinutes;
  final String state;
  final String? startedAt;
  final String? endedAt;
  final String createdAt;

  factory ApiPomodoroSession.fromJson(Map<String, dynamic> json) =>
      ApiPomodoroSession(
        id: json['id'] as int,
        taskId: json['task'] as int?,
        durationMinutes: json['duration_minutes'] as int? ?? 25,
        state: json['state'] as String? ?? 'idle',
        startedAt: json['started_at'] as String?,
        endedAt: json['ended_at'] as String?,
        createdAt: json['created_at'] as String,
      );
}

class ApiAppSettings {
  ApiAppSettings({
    required this.language,
    required this.showOverdue,
    required this.showToday,
    required this.showTomorrow,
    required this.showLater,
    required this.showNoDeadline,
    required this.showCompleted,
    required this.bottomTabs,
    required this.notificationSound,
    required this.completionSound,
    required this.vibrationEnabled,
    required this.isPremium,
    this.premiumActivatedAt,
    this.premiumUntil,
  });

  final String language;
  final bool showOverdue;
  final bool showToday;
  final bool showTomorrow;
  final bool showLater;
  final bool showNoDeadline;
  final bool showCompleted;
  final List<String> bottomTabs;
  final String notificationSound;
  final String completionSound;
  final bool vibrationEnabled;
  final bool isPremium;
  final String? premiumActivatedAt;
  final String? premiumUntil;

  factory ApiAppSettings.fromJson(Map<String, dynamic> json) => ApiAppSettings(
        language: json['language'] as String? ?? 'ru',
        showOverdue: json['show_overdue'] as bool? ?? true,
        showToday: json['show_today'] as bool? ?? true,
        showTomorrow: json['show_tomorrow'] as bool? ?? true,
        showLater: json['show_later'] as bool? ?? true,
        showNoDeadline: json['show_no_deadline'] as bool? ?? true,
        showCompleted: json['show_completed'] as bool? ?? false,
        bottomTabs: (json['bottom_tabs'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        notificationSound:
            json['notification_sound'] as String? ?? 'default',
        completionSound: json['completion_sound'] as String? ?? 'default',
        vibrationEnabled: json['vibration_enabled'] as bool? ?? true,
        isPremium: json['is_premium'] as bool? ?? false,
        premiumActivatedAt: json['premium_activated_at'] as String?,
        premiumUntil: json['premium_until'] as String?,
      );
}

class ApiMatrixSetting {
  ApiMatrixSetting({
    required this.id,
    required this.block,
    required this.title,
    required this.allowedPriorities,
    required this.dateFilter,
  });

  final int id;
  final String block;
  final String title;
  final List<String> allowedPriorities;
  final String dateFilter;

  factory ApiMatrixSetting.fromJson(Map<String, dynamic> json) =>
      ApiMatrixSetting(
        id: json['id'] as int,
        block: json['block'] as String,
        title: json['title'] as String? ?? '',
        allowedPriorities:
            (json['allowed_priorities'] as List<dynamic>? ?? [])
                .map((e) => e.toString())
                .toList(),
        dateFilter: json['date_filter'] as String? ?? 'all',
      );
}

class ApiHelpItem {
  ApiHelpItem({required this.question, required this.answer});
  final String question;
  final String answer;

  factory ApiHelpItem.fromJson(Map<String, dynamic> json) => ApiHelpItem(
        question: json['question'] as String,
        answer: json['answer'] as String,
      );
}

class ApiPremiumFeature {
  ApiPremiumFeature({
    required this.key,
    required this.title,
    required this.isPremium,
    required this.isEnabled,
  });

  final String key;
  final String title;
  final bool isPremium;
  final bool isEnabled;

  factory ApiPremiumFeature.fromJson(Map<String, dynamic> json) =>
      ApiPremiumFeature(
        key: json['key'] as String,
        title: json['title'] as String,
        isPremium: json['is_premium'] as bool? ?? false,
        isEnabled: json['is_enabled'] as bool? ?? false,
      );
}

class ApiTariff {
  ApiTariff({
    required this.code,
    required this.title,
    required this.description,
    required this.price,
    required this.currency,
    required this.durationDays,
    required this.promoDays,
    required this.isRecurring,
    required this.sortOrder,
  });

  final String code;
  final String title;
  final String description;
  final String price;
  final String currency;
  final int durationDays;
  final int promoDays;
  final bool isRecurring;
  final int sortOrder;

  factory ApiTariff.fromJson(Map<String, dynamic> json) => ApiTariff(
        code: json['code'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        price: json['price']?.toString() ?? '0',
        currency: json['currency'] as String? ?? 'RUB',
        durationDays: json['duration_days'] as int? ?? 0,
        promoDays: json['promo_days'] as int? ?? 0,
        isRecurring: json['is_recurring'] as bool? ?? false,
        sortOrder: json['sort_order'] as int? ?? 0,
      );

  String get priceLabel {
    final amount = double.tryParse(price);
    final formatted = amount == null
        ? price
        : amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2);
    if (durationDays == 0) return '$formatted ₽';
    if (durationDays >= 365) return '$formatted ₽/год';
    return '$formatted ₽/мес';
  }
}

class ApiSubscription {
  ApiSubscription({
    required this.status,
    this.tariff,
    this.promoUntil,
    this.premiumUntil,
    required this.recurringEnabled,
    this.cancelledAt,
    required this.isPremium,
    required this.updatedAt,
  });

  final String status;
  final ApiTariff? tariff;
  final String? promoUntil;
  final String? premiumUntil;
  final bool recurringEnabled;
  final String? cancelledAt;
  final bool isPremium;
  final String updatedAt;

  factory ApiSubscription.fromJson(Map<String, dynamic> json) =>
      ApiSubscription(
        status: json['status'] as String? ?? 'none',
        tariff: json['tariff'] is Map<String, dynamic>
            ? ApiTariff.fromJson(json['tariff'] as Map<String, dynamic>)
            : null,
        promoUntil: json['promo_until'] as String?,
        premiumUntil: json['premium_until'] as String?,
        recurringEnabled: json['recurring_enabled'] as bool? ?? false,
        cancelledAt: json['cancelled_at'] as String?,
        isPremium: json['is_premium'] as bool? ?? false,
        updatedAt: json['updated_at'] as String? ?? '',
      );

  String? get expiresAt => premiumUntil ?? promoUntil;
}

class ApiPremiumCheckoutResponse {
  ApiPremiumCheckoutResponse({
    required this.checkoutUrl,
    required this.provider,
  });

  final String checkoutUrl;
  final String provider;

  factory ApiPremiumCheckoutResponse.fromJson(Map<String, dynamic> json) =>
      ApiPremiumCheckoutResponse(
        checkoutUrl: json['checkout_url'] as String? ?? '',
        provider: json['provider'] as String? ?? 'robokassa',
      );
}

class ApiLegalDocument {
  ApiLegalDocument({
    required this.docType,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  final String docType;
  final String title;
  final String content;
  final String updatedAt;

  factory ApiLegalDocument.fromJson(Map<String, dynamic> json) =>
      ApiLegalDocument(
        docType: json['doc_type'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        updatedAt: json['updated_at'] as String,
      );
}

class BackendUser {
  BackendUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.avatar,
  });

  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String? avatar;

  factory BackendUser.fromJson(Map<String, dynamic> json) => BackendUser(
        id: json['id'] as int,
        email: json['email'] as String,
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        avatar: json['avatar'] as String?,
      );
}
