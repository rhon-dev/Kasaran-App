// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class Plans extends Table with TableInfo<Plans, Plan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Plans(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _creatorUserIdMeta = const VerificationMeta(
    'creatorUserId',
  );
  late final GeneratedColumn<String> creatorUserId = GeneratedColumn<String>(
    'creator_user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _weddingDateMeta = const VerificationMeta(
    'weddingDate',
  );
  late final GeneratedColumn<String> weddingDate = GeneratedColumn<String>(
    'wedding_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _totalBudgetCentsMeta = const VerificationMeta(
    'totalBudgetCents',
  );
  late final GeneratedColumn<int> totalBudgetCents = GeneratedColumn<int>(
    'total_budget_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (total_budget_cents > 0)',
  );
  static const VerificationMeta _guestCapMeta = const VerificationMeta(
    'guestCap',
  );
  late final GeneratedColumn<int> guestCap = GeneratedColumn<int>(
    'guest_cap',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (guest_cap >= 0)',
  );
  static const VerificationMeta _regionCodeMeta = const VerificationMeta(
    'regionCode',
  );
  late final GeneratedColumn<String> regionCode = GeneratedColumn<String>(
    'region_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _ceremonyTypeMeta = const VerificationMeta(
    'ceremonyType',
  );
  late final GeneratedColumn<String> ceremonyType = GeneratedColumn<String>(
    'ceremony_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _venueTypeMeta = const VerificationMeta(
    'venueType',
  );
  late final GeneratedColumn<String> venueType = GeneratedColumn<String>(
    'venue_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _reminderEnabledMeta = const VerificationMeta(
    'reminderEnabled',
  );
  late final GeneratedColumn<int> reminderEnabled = GeneratedColumn<int>(
    'reminder_enabled',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1 CHECK (reminder_enabled IN (0, 1))',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _reminderWindowDaysMeta =
      const VerificationMeta('reminderWindowDays');
  late final GeneratedColumn<int> reminderWindowDays = GeneratedColumn<int>(
    'reminder_window_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 7 CHECK (reminder_window_days >= 0)',
    defaultValue: const CustomExpression('7'),
  );
  static const VerificationMeta _reminderDaysBeforeMeta =
      const VerificationMeta('reminderDaysBefore');
  late final GeneratedColumn<String> reminderDaysBefore =
      GeneratedColumn<String>(
        'reminder_days_before',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: 'NOT NULL DEFAULT \'[7,1]\'',
        defaultValue: const CustomExpression('\'[7,1]\''),
      );
  static const VerificationMeta _reminderOverdueMeta = const VerificationMeta(
    'reminderOverdue',
  );
  late final GeneratedColumn<int> reminderOverdue = GeneratedColumn<int>(
    'reminder_overdue',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1 CHECK (reminder_overdue IN (0, 1))',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _rulesetVersionMeta = const VerificationMeta(
    'rulesetVersion',
  );
  late final GeneratedColumn<String> rulesetVersion = GeneratedColumn<String>(
    'ruleset_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _drivingRsvpStatusMeta = const VerificationMeta(
    'drivingRsvpStatus',
  );
  late final GeneratedColumn<String> drivingRsvpStatus =
      GeneratedColumn<String>(
        'driving_rsvp_status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
        $customConstraints: 'NOT NULL',
      );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  late final GeneratedColumn<int> isActive = GeneratedColumn<int>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1))',
    defaultValue: const CustomExpression('1'),
  );
  static const VerificationMeta _setupCompletedAtMeta = const VerificationMeta(
    'setupCompletedAt',
  );
  late final GeneratedColumn<String> setupCompletedAt = GeneratedColumn<String>(
    'setup_completed_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    creatorUserId,
    weddingDate,
    totalBudgetCents,
    guestCap,
    regionCode,
    ceremonyType,
    venueType,
    reminderEnabled,
    reminderWindowDays,
    reminderDaysBefore,
    reminderOverdue,
    rulesetVersion,
    drivingRsvpStatus,
    isActive,
    setupCompletedAt,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<Plan> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('creator_user_id')) {
      context.handle(
        _creatorUserIdMeta,
        creatorUserId.isAcceptableOrUnknown(
          data['creator_user_id']!,
          _creatorUserIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_creatorUserIdMeta);
    }
    if (data.containsKey('wedding_date')) {
      context.handle(
        _weddingDateMeta,
        weddingDate.isAcceptableOrUnknown(
          data['wedding_date']!,
          _weddingDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_weddingDateMeta);
    }
    if (data.containsKey('total_budget_cents')) {
      context.handle(
        _totalBudgetCentsMeta,
        totalBudgetCents.isAcceptableOrUnknown(
          data['total_budget_cents']!,
          _totalBudgetCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalBudgetCentsMeta);
    }
    if (data.containsKey('guest_cap')) {
      context.handle(
        _guestCapMeta,
        guestCap.isAcceptableOrUnknown(data['guest_cap']!, _guestCapMeta),
      );
    } else if (isInserting) {
      context.missing(_guestCapMeta);
    }
    if (data.containsKey('region_code')) {
      context.handle(
        _regionCodeMeta,
        regionCode.isAcceptableOrUnknown(data['region_code']!, _regionCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_regionCodeMeta);
    }
    if (data.containsKey('ceremony_type')) {
      context.handle(
        _ceremonyTypeMeta,
        ceremonyType.isAcceptableOrUnknown(
          data['ceremony_type']!,
          _ceremonyTypeMeta,
        ),
      );
    }
    if (data.containsKey('venue_type')) {
      context.handle(
        _venueTypeMeta,
        venueType.isAcceptableOrUnknown(data['venue_type']!, _venueTypeMeta),
      );
    }
    if (data.containsKey('reminder_enabled')) {
      context.handle(
        _reminderEnabledMeta,
        reminderEnabled.isAcceptableOrUnknown(
          data['reminder_enabled']!,
          _reminderEnabledMeta,
        ),
      );
    }
    if (data.containsKey('reminder_window_days')) {
      context.handle(
        _reminderWindowDaysMeta,
        reminderWindowDays.isAcceptableOrUnknown(
          data['reminder_window_days']!,
          _reminderWindowDaysMeta,
        ),
      );
    }
    if (data.containsKey('reminder_days_before')) {
      context.handle(
        _reminderDaysBeforeMeta,
        reminderDaysBefore.isAcceptableOrUnknown(
          data['reminder_days_before']!,
          _reminderDaysBeforeMeta,
        ),
      );
    }
    if (data.containsKey('reminder_overdue')) {
      context.handle(
        _reminderOverdueMeta,
        reminderOverdue.isAcceptableOrUnknown(
          data['reminder_overdue']!,
          _reminderOverdueMeta,
        ),
      );
    }
    if (data.containsKey('ruleset_version')) {
      context.handle(
        _rulesetVersionMeta,
        rulesetVersion.isAcceptableOrUnknown(
          data['ruleset_version']!,
          _rulesetVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_rulesetVersionMeta);
    }
    if (data.containsKey('driving_rsvp_status')) {
      context.handle(
        _drivingRsvpStatusMeta,
        drivingRsvpStatus.isAcceptableOrUnknown(
          data['driving_rsvp_status']!,
          _drivingRsvpStatusMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_drivingRsvpStatusMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('setup_completed_at')) {
      context.handle(
        _setupCompletedAtMeta,
        setupCompletedAt.isAcceptableOrUnknown(
          data['setup_completed_at']!,
          _setupCompletedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Plan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Plan(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      creatorUserId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}creator_user_id'],
      )!,
      weddingDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wedding_date'],
      )!,
      totalBudgetCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_budget_cents'],
      )!,
      guestCap: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}guest_cap'],
      )!,
      regionCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}region_code'],
      )!,
      ceremonyType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ceremony_type'],
      ),
      venueType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}venue_type'],
      ),
      reminderEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_enabled'],
      )!,
      reminderWindowDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_window_days'],
      )!,
      reminderDaysBefore: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_days_before'],
      )!,
      reminderOverdue: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminder_overdue'],
      )!,
      rulesetVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ruleset_version'],
      )!,
      drivingRsvpStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}driving_rsvp_status'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}is_active'],
      )!,
      setupCompletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}setup_completed_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  Plans createAlias(String alias) {
    return Plans(attachedDatabase, alias);
  }

  @override
  bool get dontWriteConstraints => true;
}

class Plan extends DataClass implements Insertable<Plan> {
  final String id;
  final String creatorUserId;
  final String weddingDate;
  final int totalBudgetCents;
  final int guestCap;
  final String regionCode;
  final String? ceremonyType;
  final String? venueType;
  final int reminderEnabled;
  final int reminderWindowDays;
  final String reminderDaysBefore;
  final int reminderOverdue;
  final String rulesetVersion;
  final String drivingRsvpStatus;
  final int isActive;
  final String? setupCompletedAt;
  final String createdAt;
  final String? deletedAt;
  const Plan({
    required this.id,
    required this.creatorUserId,
    required this.weddingDate,
    required this.totalBudgetCents,
    required this.guestCap,
    required this.regionCode,
    this.ceremonyType,
    this.venueType,
    required this.reminderEnabled,
    required this.reminderWindowDays,
    required this.reminderDaysBefore,
    required this.reminderOverdue,
    required this.rulesetVersion,
    required this.drivingRsvpStatus,
    required this.isActive,
    this.setupCompletedAt,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['creator_user_id'] = Variable<String>(creatorUserId);
    map['wedding_date'] = Variable<String>(weddingDate);
    map['total_budget_cents'] = Variable<int>(totalBudgetCents);
    map['guest_cap'] = Variable<int>(guestCap);
    map['region_code'] = Variable<String>(regionCode);
    if (!nullToAbsent || ceremonyType != null) {
      map['ceremony_type'] = Variable<String>(ceremonyType);
    }
    if (!nullToAbsent || venueType != null) {
      map['venue_type'] = Variable<String>(venueType);
    }
    map['reminder_enabled'] = Variable<int>(reminderEnabled);
    map['reminder_window_days'] = Variable<int>(reminderWindowDays);
    map['reminder_days_before'] = Variable<String>(reminderDaysBefore);
    map['reminder_overdue'] = Variable<int>(reminderOverdue);
    map['ruleset_version'] = Variable<String>(rulesetVersion);
    map['driving_rsvp_status'] = Variable<String>(drivingRsvpStatus);
    map['is_active'] = Variable<int>(isActive);
    if (!nullToAbsent || setupCompletedAt != null) {
      map['setup_completed_at'] = Variable<String>(setupCompletedAt);
    }
    map['created_at'] = Variable<String>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  PlansCompanion toCompanion(bool nullToAbsent) {
    return PlansCompanion(
      id: Value(id),
      creatorUserId: Value(creatorUserId),
      weddingDate: Value(weddingDate),
      totalBudgetCents: Value(totalBudgetCents),
      guestCap: Value(guestCap),
      regionCode: Value(regionCode),
      ceremonyType: ceremonyType == null && nullToAbsent
          ? const Value.absent()
          : Value(ceremonyType),
      venueType: venueType == null && nullToAbsent
          ? const Value.absent()
          : Value(venueType),
      reminderEnabled: Value(reminderEnabled),
      reminderWindowDays: Value(reminderWindowDays),
      reminderDaysBefore: Value(reminderDaysBefore),
      reminderOverdue: Value(reminderOverdue),
      rulesetVersion: Value(rulesetVersion),
      drivingRsvpStatus: Value(drivingRsvpStatus),
      isActive: Value(isActive),
      setupCompletedAt: setupCompletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(setupCompletedAt),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Plan.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Plan(
      id: serializer.fromJson<String>(json['id']),
      creatorUserId: serializer.fromJson<String>(json['creator_user_id']),
      weddingDate: serializer.fromJson<String>(json['wedding_date']),
      totalBudgetCents: serializer.fromJson<int>(json['total_budget_cents']),
      guestCap: serializer.fromJson<int>(json['guest_cap']),
      regionCode: serializer.fromJson<String>(json['region_code']),
      ceremonyType: serializer.fromJson<String?>(json['ceremony_type']),
      venueType: serializer.fromJson<String?>(json['venue_type']),
      reminderEnabled: serializer.fromJson<int>(json['reminder_enabled']),
      reminderWindowDays: serializer.fromJson<int>(
        json['reminder_window_days'],
      ),
      reminderDaysBefore: serializer.fromJson<String>(
        json['reminder_days_before'],
      ),
      reminderOverdue: serializer.fromJson<int>(json['reminder_overdue']),
      rulesetVersion: serializer.fromJson<String>(json['ruleset_version']),
      drivingRsvpStatus: serializer.fromJson<String>(
        json['driving_rsvp_status'],
      ),
      isActive: serializer.fromJson<int>(json['is_active']),
      setupCompletedAt: serializer.fromJson<String?>(
        json['setup_completed_at'],
      ),
      createdAt: serializer.fromJson<String>(json['created_at']),
      deletedAt: serializer.fromJson<String?>(json['deleted_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'creator_user_id': serializer.toJson<String>(creatorUserId),
      'wedding_date': serializer.toJson<String>(weddingDate),
      'total_budget_cents': serializer.toJson<int>(totalBudgetCents),
      'guest_cap': serializer.toJson<int>(guestCap),
      'region_code': serializer.toJson<String>(regionCode),
      'ceremony_type': serializer.toJson<String?>(ceremonyType),
      'venue_type': serializer.toJson<String?>(venueType),
      'reminder_enabled': serializer.toJson<int>(reminderEnabled),
      'reminder_window_days': serializer.toJson<int>(reminderWindowDays),
      'reminder_days_before': serializer.toJson<String>(reminderDaysBefore),
      'reminder_overdue': serializer.toJson<int>(reminderOverdue),
      'ruleset_version': serializer.toJson<String>(rulesetVersion),
      'driving_rsvp_status': serializer.toJson<String>(drivingRsvpStatus),
      'is_active': serializer.toJson<int>(isActive),
      'setup_completed_at': serializer.toJson<String?>(setupCompletedAt),
      'created_at': serializer.toJson<String>(createdAt),
      'deleted_at': serializer.toJson<String?>(deletedAt),
    };
  }

  Plan copyWith({
    String? id,
    String? creatorUserId,
    String? weddingDate,
    int? totalBudgetCents,
    int? guestCap,
    String? regionCode,
    Value<String?> ceremonyType = const Value.absent(),
    Value<String?> venueType = const Value.absent(),
    int? reminderEnabled,
    int? reminderWindowDays,
    String? reminderDaysBefore,
    int? reminderOverdue,
    String? rulesetVersion,
    String? drivingRsvpStatus,
    int? isActive,
    Value<String?> setupCompletedAt = const Value.absent(),
    String? createdAt,
    Value<String?> deletedAt = const Value.absent(),
  }) => Plan(
    id: id ?? this.id,
    creatorUserId: creatorUserId ?? this.creatorUserId,
    weddingDate: weddingDate ?? this.weddingDate,
    totalBudgetCents: totalBudgetCents ?? this.totalBudgetCents,
    guestCap: guestCap ?? this.guestCap,
    regionCode: regionCode ?? this.regionCode,
    ceremonyType: ceremonyType.present ? ceremonyType.value : this.ceremonyType,
    venueType: venueType.present ? venueType.value : this.venueType,
    reminderEnabled: reminderEnabled ?? this.reminderEnabled,
    reminderWindowDays: reminderWindowDays ?? this.reminderWindowDays,
    reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
    reminderOverdue: reminderOverdue ?? this.reminderOverdue,
    rulesetVersion: rulesetVersion ?? this.rulesetVersion,
    drivingRsvpStatus: drivingRsvpStatus ?? this.drivingRsvpStatus,
    isActive: isActive ?? this.isActive,
    setupCompletedAt: setupCompletedAt.present
        ? setupCompletedAt.value
        : this.setupCompletedAt,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Plan copyWithCompanion(PlansCompanion data) {
    return Plan(
      id: data.id.present ? data.id.value : this.id,
      creatorUserId: data.creatorUserId.present
          ? data.creatorUserId.value
          : this.creatorUserId,
      weddingDate: data.weddingDate.present
          ? data.weddingDate.value
          : this.weddingDate,
      totalBudgetCents: data.totalBudgetCents.present
          ? data.totalBudgetCents.value
          : this.totalBudgetCents,
      guestCap: data.guestCap.present ? data.guestCap.value : this.guestCap,
      regionCode: data.regionCode.present
          ? data.regionCode.value
          : this.regionCode,
      ceremonyType: data.ceremonyType.present
          ? data.ceremonyType.value
          : this.ceremonyType,
      venueType: data.venueType.present ? data.venueType.value : this.venueType,
      reminderEnabled: data.reminderEnabled.present
          ? data.reminderEnabled.value
          : this.reminderEnabled,
      reminderWindowDays: data.reminderWindowDays.present
          ? data.reminderWindowDays.value
          : this.reminderWindowDays,
      reminderDaysBefore: data.reminderDaysBefore.present
          ? data.reminderDaysBefore.value
          : this.reminderDaysBefore,
      reminderOverdue: data.reminderOverdue.present
          ? data.reminderOverdue.value
          : this.reminderOverdue,
      rulesetVersion: data.rulesetVersion.present
          ? data.rulesetVersion.value
          : this.rulesetVersion,
      drivingRsvpStatus: data.drivingRsvpStatus.present
          ? data.drivingRsvpStatus.value
          : this.drivingRsvpStatus,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      setupCompletedAt: data.setupCompletedAt.present
          ? data.setupCompletedAt.value
          : this.setupCompletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Plan(')
          ..write('id: $id, ')
          ..write('creatorUserId: $creatorUserId, ')
          ..write('weddingDate: $weddingDate, ')
          ..write('totalBudgetCents: $totalBudgetCents, ')
          ..write('guestCap: $guestCap, ')
          ..write('regionCode: $regionCode, ')
          ..write('ceremonyType: $ceremonyType, ')
          ..write('venueType: $venueType, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderWindowDays: $reminderWindowDays, ')
          ..write('reminderDaysBefore: $reminderDaysBefore, ')
          ..write('reminderOverdue: $reminderOverdue, ')
          ..write('rulesetVersion: $rulesetVersion, ')
          ..write('drivingRsvpStatus: $drivingRsvpStatus, ')
          ..write('isActive: $isActive, ')
          ..write('setupCompletedAt: $setupCompletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    creatorUserId,
    weddingDate,
    totalBudgetCents,
    guestCap,
    regionCode,
    ceremonyType,
    venueType,
    reminderEnabled,
    reminderWindowDays,
    reminderDaysBefore,
    reminderOverdue,
    rulesetVersion,
    drivingRsvpStatus,
    isActive,
    setupCompletedAt,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Plan &&
          other.id == this.id &&
          other.creatorUserId == this.creatorUserId &&
          other.weddingDate == this.weddingDate &&
          other.totalBudgetCents == this.totalBudgetCents &&
          other.guestCap == this.guestCap &&
          other.regionCode == this.regionCode &&
          other.ceremonyType == this.ceremonyType &&
          other.venueType == this.venueType &&
          other.reminderEnabled == this.reminderEnabled &&
          other.reminderWindowDays == this.reminderWindowDays &&
          other.reminderDaysBefore == this.reminderDaysBefore &&
          other.reminderOverdue == this.reminderOverdue &&
          other.rulesetVersion == this.rulesetVersion &&
          other.drivingRsvpStatus == this.drivingRsvpStatus &&
          other.isActive == this.isActive &&
          other.setupCompletedAt == this.setupCompletedAt &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class PlansCompanion extends UpdateCompanion<Plan> {
  final Value<String> id;
  final Value<String> creatorUserId;
  final Value<String> weddingDate;
  final Value<int> totalBudgetCents;
  final Value<int> guestCap;
  final Value<String> regionCode;
  final Value<String?> ceremonyType;
  final Value<String?> venueType;
  final Value<int> reminderEnabled;
  final Value<int> reminderWindowDays;
  final Value<String> reminderDaysBefore;
  final Value<int> reminderOverdue;
  final Value<String> rulesetVersion;
  final Value<String> drivingRsvpStatus;
  final Value<int> isActive;
  final Value<String?> setupCompletedAt;
  final Value<String> createdAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const PlansCompanion({
    this.id = const Value.absent(),
    this.creatorUserId = const Value.absent(),
    this.weddingDate = const Value.absent(),
    this.totalBudgetCents = const Value.absent(),
    this.guestCap = const Value.absent(),
    this.regionCode = const Value.absent(),
    this.ceremonyType = const Value.absent(),
    this.venueType = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderWindowDays = const Value.absent(),
    this.reminderDaysBefore = const Value.absent(),
    this.reminderOverdue = const Value.absent(),
    this.rulesetVersion = const Value.absent(),
    this.drivingRsvpStatus = const Value.absent(),
    this.isActive = const Value.absent(),
    this.setupCompletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlansCompanion.insert({
    required String id,
    required String creatorUserId,
    required String weddingDate,
    required int totalBudgetCents,
    required int guestCap,
    required String regionCode,
    this.ceremonyType = const Value.absent(),
    this.venueType = const Value.absent(),
    this.reminderEnabled = const Value.absent(),
    this.reminderWindowDays = const Value.absent(),
    this.reminderDaysBefore = const Value.absent(),
    this.reminderOverdue = const Value.absent(),
    required String rulesetVersion,
    required String drivingRsvpStatus,
    this.isActive = const Value.absent(),
    this.setupCompletedAt = const Value.absent(),
    required String createdAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       creatorUserId = Value(creatorUserId),
       weddingDate = Value(weddingDate),
       totalBudgetCents = Value(totalBudgetCents),
       guestCap = Value(guestCap),
       regionCode = Value(regionCode),
       rulesetVersion = Value(rulesetVersion),
       drivingRsvpStatus = Value(drivingRsvpStatus),
       createdAt = Value(createdAt);
  static Insertable<Plan> custom({
    Expression<String>? id,
    Expression<String>? creatorUserId,
    Expression<String>? weddingDate,
    Expression<int>? totalBudgetCents,
    Expression<int>? guestCap,
    Expression<String>? regionCode,
    Expression<String>? ceremonyType,
    Expression<String>? venueType,
    Expression<int>? reminderEnabled,
    Expression<int>? reminderWindowDays,
    Expression<String>? reminderDaysBefore,
    Expression<int>? reminderOverdue,
    Expression<String>? rulesetVersion,
    Expression<String>? drivingRsvpStatus,
    Expression<int>? isActive,
    Expression<String>? setupCompletedAt,
    Expression<String>? createdAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (creatorUserId != null) 'creator_user_id': creatorUserId,
      if (weddingDate != null) 'wedding_date': weddingDate,
      if (totalBudgetCents != null) 'total_budget_cents': totalBudgetCents,
      if (guestCap != null) 'guest_cap': guestCap,
      if (regionCode != null) 'region_code': regionCode,
      if (ceremonyType != null) 'ceremony_type': ceremonyType,
      if (venueType != null) 'venue_type': venueType,
      if (reminderEnabled != null) 'reminder_enabled': reminderEnabled,
      if (reminderWindowDays != null)
        'reminder_window_days': reminderWindowDays,
      if (reminderDaysBefore != null)
        'reminder_days_before': reminderDaysBefore,
      if (reminderOverdue != null) 'reminder_overdue': reminderOverdue,
      if (rulesetVersion != null) 'ruleset_version': rulesetVersion,
      if (drivingRsvpStatus != null) 'driving_rsvp_status': drivingRsvpStatus,
      if (isActive != null) 'is_active': isActive,
      if (setupCompletedAt != null) 'setup_completed_at': setupCompletedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlansCompanion copyWith({
    Value<String>? id,
    Value<String>? creatorUserId,
    Value<String>? weddingDate,
    Value<int>? totalBudgetCents,
    Value<int>? guestCap,
    Value<String>? regionCode,
    Value<String?>? ceremonyType,
    Value<String?>? venueType,
    Value<int>? reminderEnabled,
    Value<int>? reminderWindowDays,
    Value<String>? reminderDaysBefore,
    Value<int>? reminderOverdue,
    Value<String>? rulesetVersion,
    Value<String>? drivingRsvpStatus,
    Value<int>? isActive,
    Value<String?>? setupCompletedAt,
    Value<String>? createdAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return PlansCompanion(
      id: id ?? this.id,
      creatorUserId: creatorUserId ?? this.creatorUserId,
      weddingDate: weddingDate ?? this.weddingDate,
      totalBudgetCents: totalBudgetCents ?? this.totalBudgetCents,
      guestCap: guestCap ?? this.guestCap,
      regionCode: regionCode ?? this.regionCode,
      ceremonyType: ceremonyType ?? this.ceremonyType,
      venueType: venueType ?? this.venueType,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderWindowDays: reminderWindowDays ?? this.reminderWindowDays,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      reminderOverdue: reminderOverdue ?? this.reminderOverdue,
      rulesetVersion: rulesetVersion ?? this.rulesetVersion,
      drivingRsvpStatus: drivingRsvpStatus ?? this.drivingRsvpStatus,
      isActive: isActive ?? this.isActive,
      setupCompletedAt: setupCompletedAt ?? this.setupCompletedAt,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (creatorUserId.present) {
      map['creator_user_id'] = Variable<String>(creatorUserId.value);
    }
    if (weddingDate.present) {
      map['wedding_date'] = Variable<String>(weddingDate.value);
    }
    if (totalBudgetCents.present) {
      map['total_budget_cents'] = Variable<int>(totalBudgetCents.value);
    }
    if (guestCap.present) {
      map['guest_cap'] = Variable<int>(guestCap.value);
    }
    if (regionCode.present) {
      map['region_code'] = Variable<String>(regionCode.value);
    }
    if (ceremonyType.present) {
      map['ceremony_type'] = Variable<String>(ceremonyType.value);
    }
    if (venueType.present) {
      map['venue_type'] = Variable<String>(venueType.value);
    }
    if (reminderEnabled.present) {
      map['reminder_enabled'] = Variable<int>(reminderEnabled.value);
    }
    if (reminderWindowDays.present) {
      map['reminder_window_days'] = Variable<int>(reminderWindowDays.value);
    }
    if (reminderDaysBefore.present) {
      map['reminder_days_before'] = Variable<String>(reminderDaysBefore.value);
    }
    if (reminderOverdue.present) {
      map['reminder_overdue'] = Variable<int>(reminderOverdue.value);
    }
    if (rulesetVersion.present) {
      map['ruleset_version'] = Variable<String>(rulesetVersion.value);
    }
    if (drivingRsvpStatus.present) {
      map['driving_rsvp_status'] = Variable<String>(drivingRsvpStatus.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<int>(isActive.value);
    }
    if (setupCompletedAt.present) {
      map['setup_completed_at'] = Variable<String>(setupCompletedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlansCompanion(')
          ..write('id: $id, ')
          ..write('creatorUserId: $creatorUserId, ')
          ..write('weddingDate: $weddingDate, ')
          ..write('totalBudgetCents: $totalBudgetCents, ')
          ..write('guestCap: $guestCap, ')
          ..write('regionCode: $regionCode, ')
          ..write('ceremonyType: $ceremonyType, ')
          ..write('venueType: $venueType, ')
          ..write('reminderEnabled: $reminderEnabled, ')
          ..write('reminderWindowDays: $reminderWindowDays, ')
          ..write('reminderDaysBefore: $reminderDaysBefore, ')
          ..write('reminderOverdue: $reminderOverdue, ')
          ..write('rulesetVersion: $rulesetVersion, ')
          ..write('drivingRsvpStatus: $drivingRsvpStatus, ')
          ..write('isActive: $isActive, ')
          ..write('setupCompletedAt: $setupCompletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PlanMemberAliases extends Table
    with TableInfo<PlanMemberAliases, PlanMemberAliase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PlanMemberAliases(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _planMemberIdMeta = const VerificationMeta(
    'planMemberId',
  );
  late final GeneratedColumn<String> planMemberId = GeneratedColumn<String>(
    'plan_member_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES plans(id)',
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [planMemberId, planId, userId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plan_member_aliases';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlanMemberAliase> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('plan_member_id')) {
      context.handle(
        _planMemberIdMeta,
        planMemberId.isAcceptableOrUnknown(
          data['plan_member_id']!,
          _planMemberIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_planMemberIdMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {planMemberId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {planId, planMemberId},
    {planId, userId, planMemberId},
  ];
  @override
  PlanMemberAliase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanMemberAliase(
      planMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_member_id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      ),
    );
  }

  @override
  PlanMemberAliases createAlias(String alias) {
    return PlanMemberAliases(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'UNIQUE(plan_id, plan_member_id)',
    'UNIQUE(plan_id, user_id, plan_member_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class PlanMemberAliase extends DataClass
    implements Insertable<PlanMemberAliase> {
  final String planMemberId;
  final String planId;
  final String? userId;
  const PlanMemberAliase({
    required this.planMemberId,
    required this.planId,
    this.userId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['plan_member_id'] = Variable<String>(planMemberId);
    map['plan_id'] = Variable<String>(planId);
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    return map;
  }

  PlanMemberAliasesCompanion toCompanion(bool nullToAbsent) {
    return PlanMemberAliasesCompanion(
      planMemberId: Value(planMemberId),
      planId: Value(planId),
      userId: userId == null && nullToAbsent
          ? const Value.absent()
          : Value(userId),
    );
  }

  factory PlanMemberAliase.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanMemberAliase(
      planMemberId: serializer.fromJson<String>(json['plan_member_id']),
      planId: serializer.fromJson<String>(json['plan_id']),
      userId: serializer.fromJson<String?>(json['user_id']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'plan_member_id': serializer.toJson<String>(planMemberId),
      'plan_id': serializer.toJson<String>(planId),
      'user_id': serializer.toJson<String?>(userId),
    };
  }

  PlanMemberAliase copyWith({
    String? planMemberId,
    String? planId,
    Value<String?> userId = const Value.absent(),
  }) => PlanMemberAliase(
    planMemberId: planMemberId ?? this.planMemberId,
    planId: planId ?? this.planId,
    userId: userId.present ? userId.value : this.userId,
  );
  PlanMemberAliase copyWithCompanion(PlanMemberAliasesCompanion data) {
    return PlanMemberAliase(
      planMemberId: data.planMemberId.present
          ? data.planMemberId.value
          : this.planMemberId,
      planId: data.planId.present ? data.planId.value : this.planId,
      userId: data.userId.present ? data.userId.value : this.userId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlanMemberAliase(')
          ..write('planMemberId: $planMemberId, ')
          ..write('planId: $planId, ')
          ..write('userId: $userId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(planMemberId, planId, userId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanMemberAliase &&
          other.planMemberId == this.planMemberId &&
          other.planId == this.planId &&
          other.userId == this.userId);
}

class PlanMemberAliasesCompanion extends UpdateCompanion<PlanMemberAliase> {
  final Value<String> planMemberId;
  final Value<String> planId;
  final Value<String?> userId;
  final Value<int> rowid;
  const PlanMemberAliasesCompanion({
    this.planMemberId = const Value.absent(),
    this.planId = const Value.absent(),
    this.userId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlanMemberAliasesCompanion.insert({
    required String planMemberId,
    required String planId,
    this.userId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : planMemberId = Value(planMemberId),
       planId = Value(planId);
  static Insertable<PlanMemberAliase> custom({
    Expression<String>? planMemberId,
    Expression<String>? planId,
    Expression<String>? userId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (planMemberId != null) 'plan_member_id': planMemberId,
      if (planId != null) 'plan_id': planId,
      if (userId != null) 'user_id': userId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlanMemberAliasesCompanion copyWith({
    Value<String>? planMemberId,
    Value<String>? planId,
    Value<String?>? userId,
    Value<int>? rowid,
  }) {
    return PlanMemberAliasesCompanion(
      planMemberId: planMemberId ?? this.planMemberId,
      planId: planId ?? this.planId,
      userId: userId ?? this.userId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (planMemberId.present) {
      map['plan_member_id'] = Variable<String>(planMemberId.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanMemberAliasesCompanion(')
          ..write('planMemberId: $planMemberId, ')
          ..write('planId: $planId, ')
          ..write('userId: $userId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class PlanMembers extends Table with TableInfo<PlanMembers, PlanMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  PlanMembers(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES plans(id)',
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _planMemberIdMeta = const VerificationMeta(
    'planMemberId',
  );
  late final GeneratedColumn<String> planMemberId = GeneratedColumn<String>(
    'plan_member_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL UNIQUE',
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (role IN (\'creator\', \'partner\'))',
  );
  static const VerificationMeta _joinedAtMeta = const VerificationMeta(
    'joinedAt',
  );
  late final GeneratedColumn<String> joinedAt = GeneratedColumn<String>(
    'joined_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    planId,
    userId,
    planMemberId,
    role,
    joinedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plan_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlanMember> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('plan_member_id')) {
      context.handle(
        _planMemberIdMeta,
        planMemberId.isAcceptableOrUnknown(
          data['plan_member_id']!,
          _planMemberIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_planMemberIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('joined_at')) {
      context.handle(
        _joinedAtMeta,
        joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_joinedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {planId, userId};
  @override
  PlanMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanMember(
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      planMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_member_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      joinedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}joined_at'],
      )!,
    );
  }

  @override
  PlanMembers createAlias(String alias) {
    return PlanMembers(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(plan_id, user_id)',
    'FOREIGN KEY(plan_id, user_id, plan_member_id)REFERENCES plan_member_aliases(plan_id, user_id, plan_member_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class PlanMember extends DataClass implements Insertable<PlanMember> {
  final String planId;
  final String userId;
  final String planMemberId;
  final String role;
  final String joinedAt;
  const PlanMember({
    required this.planId,
    required this.userId,
    required this.planMemberId,
    required this.role,
    required this.joinedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['plan_id'] = Variable<String>(planId);
    map['user_id'] = Variable<String>(userId);
    map['plan_member_id'] = Variable<String>(planMemberId);
    map['role'] = Variable<String>(role);
    map['joined_at'] = Variable<String>(joinedAt);
    return map;
  }

  PlanMembersCompanion toCompanion(bool nullToAbsent) {
    return PlanMembersCompanion(
      planId: Value(planId),
      userId: Value(userId),
      planMemberId: Value(planMemberId),
      role: Value(role),
      joinedAt: Value(joinedAt),
    );
  }

  factory PlanMember.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanMember(
      planId: serializer.fromJson<String>(json['plan_id']),
      userId: serializer.fromJson<String>(json['user_id']),
      planMemberId: serializer.fromJson<String>(json['plan_member_id']),
      role: serializer.fromJson<String>(json['role']),
      joinedAt: serializer.fromJson<String>(json['joined_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'plan_id': serializer.toJson<String>(planId),
      'user_id': serializer.toJson<String>(userId),
      'plan_member_id': serializer.toJson<String>(planMemberId),
      'role': serializer.toJson<String>(role),
      'joined_at': serializer.toJson<String>(joinedAt),
    };
  }

  PlanMember copyWith({
    String? planId,
    String? userId,
    String? planMemberId,
    String? role,
    String? joinedAt,
  }) => PlanMember(
    planId: planId ?? this.planId,
    userId: userId ?? this.userId,
    planMemberId: planMemberId ?? this.planMemberId,
    role: role ?? this.role,
    joinedAt: joinedAt ?? this.joinedAt,
  );
  PlanMember copyWithCompanion(PlanMembersCompanion data) {
    return PlanMember(
      planId: data.planId.present ? data.planId.value : this.planId,
      userId: data.userId.present ? data.userId.value : this.userId,
      planMemberId: data.planMemberId.present
          ? data.planMemberId.value
          : this.planMemberId,
      role: data.role.present ? data.role.value : this.role,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlanMember(')
          ..write('planId: $planId, ')
          ..write('userId: $userId, ')
          ..write('planMemberId: $planMemberId, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(planId, userId, planMemberId, role, joinedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanMember &&
          other.planId == this.planId &&
          other.userId == this.userId &&
          other.planMemberId == this.planMemberId &&
          other.role == this.role &&
          other.joinedAt == this.joinedAt);
}

class PlanMembersCompanion extends UpdateCompanion<PlanMember> {
  final Value<String> planId;
  final Value<String> userId;
  final Value<String> planMemberId;
  final Value<String> role;
  final Value<String> joinedAt;
  final Value<int> rowid;
  const PlanMembersCompanion({
    this.planId = const Value.absent(),
    this.userId = const Value.absent(),
    this.planMemberId = const Value.absent(),
    this.role = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlanMembersCompanion.insert({
    required String planId,
    required String userId,
    required String planMemberId,
    required String role,
    required String joinedAt,
    this.rowid = const Value.absent(),
  }) : planId = Value(planId),
       userId = Value(userId),
       planMemberId = Value(planMemberId),
       role = Value(role),
       joinedAt = Value(joinedAt);
  static Insertable<PlanMember> custom({
    Expression<String>? planId,
    Expression<String>? userId,
    Expression<String>? planMemberId,
    Expression<String>? role,
    Expression<String>? joinedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (planId != null) 'plan_id': planId,
      if (userId != null) 'user_id': userId,
      if (planMemberId != null) 'plan_member_id': planMemberId,
      if (role != null) 'role': role,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlanMembersCompanion copyWith({
    Value<String>? planId,
    Value<String>? userId,
    Value<String>? planMemberId,
    Value<String>? role,
    Value<String>? joinedAt,
    Value<int>? rowid,
  }) {
    return PlanMembersCompanion(
      planId: planId ?? this.planId,
      userId: userId ?? this.userId,
      planMemberId: planMemberId ?? this.planMemberId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (planMemberId.present) {
      map['plan_member_id'] = Variable<String>(planMemberId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<String>(joinedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanMembersCompanion(')
          ..write('planId: $planId, ')
          ..write('userId: $userId, ')
          ..write('planMemberId: $planMemberId, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class LedgerEntries extends Table with TableInfo<LedgerEntries, LedgerEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  LedgerEntries(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES plans(id)',
  );
  static const VerificationMeta _categoryCodeMeta = const VerificationMeta(
    'categoryCode',
  );
  late final GeneratedColumn<String> categoryCode = GeneratedColumn<String>(
    'category_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (category_code IN (\'catering_venue\', \'photo_video\', \'attire_styling\', \'coordination\', \'entourage_misc\', \'buffer\'))',
  );
  static const VerificationMeta _entryTypeMeta = const VerificationMeta(
    'entryType',
  );
  late final GeneratedColumn<String> entryType = GeneratedColumn<String>(
    'entry_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (entry_type IN (\'standard\', \'crew_meals\', \'oot_fees\', \'church_aircon\', \'corkage\', \'overtime\', \'venue_power\'))',
  );
  static const VerificationMeta _supplierNameMeta = const VerificationMeta(
    'supplierName',
  );
  late final GeneratedColumn<String> supplierName = GeneratedColumn<String>(
    'supplier_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (length(trim(supplier_name)) BETWEEN 1 AND 200)',
  );
  static const VerificationMeta _estimatedCentsMeta = const VerificationMeta(
    'estimatedCents',
  );
  late final GeneratedColumn<int> estimatedCents = GeneratedColumn<int>(
    'estimated_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _actualCentsMeta = const VerificationMeta(
    'actualCents',
  );
  late final GeneratedColumn<int> actualCents = GeneratedColumn<int>(
    'actual_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (actual_cents >= 0)',
  );
  static const VerificationMeta _pricingModeMeta = const VerificationMeta(
    'pricingMode',
  );
  late final GeneratedColumn<String> pricingMode = GeneratedColumn<String>(
    'pricing_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (pricing_mode IN (\'flat\', \'per_head\'))',
  );
  static const VerificationMeta _perHeadRateCentsMeta = const VerificationMeta(
    'perHeadRateCents',
  );
  late final GeneratedColumn<int> perHeadRateCents = GeneratedColumn<int>(
    'per_head_rate_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _manuallyValuedMeta = const VerificationMeta(
    'manuallyValued',
  );
  late final GeneratedColumn<int> manuallyValued = GeneratedColumn<int>(
    'manually_valued',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (manually_valued IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'CHECK (length(notes) <= 2000)',
  );
  static const VerificationMeta _templateSuggestionIdMeta =
      const VerificationMeta('templateSuggestionId');
  late final GeneratedColumn<String> templateSuggestionId =
      GeneratedColumn<String>(
        'template_suggestion_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        $customConstraints: '',
      );
  static const VerificationMeta _checklistItemIdMeta = const VerificationMeta(
    'checklistItemId',
  );
  late final GeneratedColumn<String> checklistItemId = GeneratedColumn<String>(
    'checklist_item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  late final GeneratedColumn<String> deletedAt = GeneratedColumn<String>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    planId,
    categoryCode,
    entryType,
    supplierName,
    estimatedCents,
    actualCents,
    pricingMode,
    perHeadRateCents,
    manuallyValued,
    notes,
    templateSuggestionId,
    checklistItemId,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ledger_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LedgerEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('category_code')) {
      context.handle(
        _categoryCodeMeta,
        categoryCode.isAcceptableOrUnknown(
          data['category_code']!,
          _categoryCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_categoryCodeMeta);
    }
    if (data.containsKey('entry_type')) {
      context.handle(
        _entryTypeMeta,
        entryType.isAcceptableOrUnknown(data['entry_type']!, _entryTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entryTypeMeta);
    }
    if (data.containsKey('supplier_name')) {
      context.handle(
        _supplierNameMeta,
        supplierName.isAcceptableOrUnknown(
          data['supplier_name']!,
          _supplierNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_supplierNameMeta);
    }
    if (data.containsKey('estimated_cents')) {
      context.handle(
        _estimatedCentsMeta,
        estimatedCents.isAcceptableOrUnknown(
          data['estimated_cents']!,
          _estimatedCentsMeta,
        ),
      );
    }
    if (data.containsKey('actual_cents')) {
      context.handle(
        _actualCentsMeta,
        actualCents.isAcceptableOrUnknown(
          data['actual_cents']!,
          _actualCentsMeta,
        ),
      );
    }
    if (data.containsKey('pricing_mode')) {
      context.handle(
        _pricingModeMeta,
        pricingMode.isAcceptableOrUnknown(
          data['pricing_mode']!,
          _pricingModeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_pricingModeMeta);
    }
    if (data.containsKey('per_head_rate_cents')) {
      context.handle(
        _perHeadRateCentsMeta,
        perHeadRateCents.isAcceptableOrUnknown(
          data['per_head_rate_cents']!,
          _perHeadRateCentsMeta,
        ),
      );
    }
    if (data.containsKey('manually_valued')) {
      context.handle(
        _manuallyValuedMeta,
        manuallyValued.isAcceptableOrUnknown(
          data['manually_valued']!,
          _manuallyValuedMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('template_suggestion_id')) {
      context.handle(
        _templateSuggestionIdMeta,
        templateSuggestionId.isAcceptableOrUnknown(
          data['template_suggestion_id']!,
          _templateSuggestionIdMeta,
        ),
      );
    }
    if (data.containsKey('checklist_item_id')) {
      context.handle(
        _checklistItemIdMeta,
        checklistItemId.isAcceptableOrUnknown(
          data['checklist_item_id']!,
          _checklistItemIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LedgerEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LedgerEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      categoryCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_code'],
      )!,
      entryType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_type'],
      )!,
      supplierName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_name'],
      )!,
      estimatedCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_cents'],
      ),
      actualCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_cents'],
      ),
      pricingMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pricing_mode'],
      )!,
      perHeadRateCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}per_head_rate_cents'],
      ),
      manuallyValued: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manually_valued'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      templateSuggestionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}template_suggestion_id'],
      ),
      checklistItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}checklist_item_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  LedgerEntries createAlias(String alias) {
    return LedgerEntries(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'CHECK((pricing_mode = \'flat\' AND estimated_cents IS NOT NULL AND estimated_cents >= 0 AND per_head_rate_cents IS NULL)OR(pricing_mode = \'per_head\' AND estimated_cents IS NULL AND per_head_rate_cents IS NOT NULL AND per_head_rate_cents >= 0))',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class LedgerEntry extends DataClass implements Insertable<LedgerEntry> {
  final String id;
  final String planId;
  final String categoryCode;
  final String entryType;
  final String supplierName;
  final int? estimatedCents;
  final int? actualCents;
  final String pricingMode;
  final int? perHeadRateCents;
  final int manuallyValued;
  final String? notes;
  final String? templateSuggestionId;
  final String? checklistItemId;
  final String createdAt;
  final String? deletedAt;
  const LedgerEntry({
    required this.id,
    required this.planId,
    required this.categoryCode,
    required this.entryType,
    required this.supplierName,
    this.estimatedCents,
    this.actualCents,
    required this.pricingMode,
    this.perHeadRateCents,
    required this.manuallyValued,
    this.notes,
    this.templateSuggestionId,
    this.checklistItemId,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['plan_id'] = Variable<String>(planId);
    map['category_code'] = Variable<String>(categoryCode);
    map['entry_type'] = Variable<String>(entryType);
    map['supplier_name'] = Variable<String>(supplierName);
    if (!nullToAbsent || estimatedCents != null) {
      map['estimated_cents'] = Variable<int>(estimatedCents);
    }
    if (!nullToAbsent || actualCents != null) {
      map['actual_cents'] = Variable<int>(actualCents);
    }
    map['pricing_mode'] = Variable<String>(pricingMode);
    if (!nullToAbsent || perHeadRateCents != null) {
      map['per_head_rate_cents'] = Variable<int>(perHeadRateCents);
    }
    map['manually_valued'] = Variable<int>(manuallyValued);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || templateSuggestionId != null) {
      map['template_suggestion_id'] = Variable<String>(templateSuggestionId);
    }
    if (!nullToAbsent || checklistItemId != null) {
      map['checklist_item_id'] = Variable<String>(checklistItemId);
    }
    map['created_at'] = Variable<String>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<String>(deletedAt);
    }
    return map;
  }

  LedgerEntriesCompanion toCompanion(bool nullToAbsent) {
    return LedgerEntriesCompanion(
      id: Value(id),
      planId: Value(planId),
      categoryCode: Value(categoryCode),
      entryType: Value(entryType),
      supplierName: Value(supplierName),
      estimatedCents: estimatedCents == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedCents),
      actualCents: actualCents == null && nullToAbsent
          ? const Value.absent()
          : Value(actualCents),
      pricingMode: Value(pricingMode),
      perHeadRateCents: perHeadRateCents == null && nullToAbsent
          ? const Value.absent()
          : Value(perHeadRateCents),
      manuallyValued: Value(manuallyValued),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      templateSuggestionId: templateSuggestionId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateSuggestionId),
      checklistItemId: checklistItemId == null && nullToAbsent
          ? const Value.absent()
          : Value(checklistItemId),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory LedgerEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LedgerEntry(
      id: serializer.fromJson<String>(json['id']),
      planId: serializer.fromJson<String>(json['plan_id']),
      categoryCode: serializer.fromJson<String>(json['category_code']),
      entryType: serializer.fromJson<String>(json['entry_type']),
      supplierName: serializer.fromJson<String>(json['supplier_name']),
      estimatedCents: serializer.fromJson<int?>(json['estimated_cents']),
      actualCents: serializer.fromJson<int?>(json['actual_cents']),
      pricingMode: serializer.fromJson<String>(json['pricing_mode']),
      perHeadRateCents: serializer.fromJson<int?>(json['per_head_rate_cents']),
      manuallyValued: serializer.fromJson<int>(json['manually_valued']),
      notes: serializer.fromJson<String?>(json['notes']),
      templateSuggestionId: serializer.fromJson<String?>(
        json['template_suggestion_id'],
      ),
      checklistItemId: serializer.fromJson<String?>(json['checklist_item_id']),
      createdAt: serializer.fromJson<String>(json['created_at']),
      deletedAt: serializer.fromJson<String?>(json['deleted_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'plan_id': serializer.toJson<String>(planId),
      'category_code': serializer.toJson<String>(categoryCode),
      'entry_type': serializer.toJson<String>(entryType),
      'supplier_name': serializer.toJson<String>(supplierName),
      'estimated_cents': serializer.toJson<int?>(estimatedCents),
      'actual_cents': serializer.toJson<int?>(actualCents),
      'pricing_mode': serializer.toJson<String>(pricingMode),
      'per_head_rate_cents': serializer.toJson<int?>(perHeadRateCents),
      'manually_valued': serializer.toJson<int>(manuallyValued),
      'notes': serializer.toJson<String?>(notes),
      'template_suggestion_id': serializer.toJson<String?>(
        templateSuggestionId,
      ),
      'checklist_item_id': serializer.toJson<String?>(checklistItemId),
      'created_at': serializer.toJson<String>(createdAt),
      'deleted_at': serializer.toJson<String?>(deletedAt),
    };
  }

  LedgerEntry copyWith({
    String? id,
    String? planId,
    String? categoryCode,
    String? entryType,
    String? supplierName,
    Value<int?> estimatedCents = const Value.absent(),
    Value<int?> actualCents = const Value.absent(),
    String? pricingMode,
    Value<int?> perHeadRateCents = const Value.absent(),
    int? manuallyValued,
    Value<String?> notes = const Value.absent(),
    Value<String?> templateSuggestionId = const Value.absent(),
    Value<String?> checklistItemId = const Value.absent(),
    String? createdAt,
    Value<String?> deletedAt = const Value.absent(),
  }) => LedgerEntry(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    categoryCode: categoryCode ?? this.categoryCode,
    entryType: entryType ?? this.entryType,
    supplierName: supplierName ?? this.supplierName,
    estimatedCents: estimatedCents.present
        ? estimatedCents.value
        : this.estimatedCents,
    actualCents: actualCents.present ? actualCents.value : this.actualCents,
    pricingMode: pricingMode ?? this.pricingMode,
    perHeadRateCents: perHeadRateCents.present
        ? perHeadRateCents.value
        : this.perHeadRateCents,
    manuallyValued: manuallyValued ?? this.manuallyValued,
    notes: notes.present ? notes.value : this.notes,
    templateSuggestionId: templateSuggestionId.present
        ? templateSuggestionId.value
        : this.templateSuggestionId,
    checklistItemId: checklistItemId.present
        ? checklistItemId.value
        : this.checklistItemId,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  LedgerEntry copyWithCompanion(LedgerEntriesCompanion data) {
    return LedgerEntry(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      categoryCode: data.categoryCode.present
          ? data.categoryCode.value
          : this.categoryCode,
      entryType: data.entryType.present ? data.entryType.value : this.entryType,
      supplierName: data.supplierName.present
          ? data.supplierName.value
          : this.supplierName,
      estimatedCents: data.estimatedCents.present
          ? data.estimatedCents.value
          : this.estimatedCents,
      actualCents: data.actualCents.present
          ? data.actualCents.value
          : this.actualCents,
      pricingMode: data.pricingMode.present
          ? data.pricingMode.value
          : this.pricingMode,
      perHeadRateCents: data.perHeadRateCents.present
          ? data.perHeadRateCents.value
          : this.perHeadRateCents,
      manuallyValued: data.manuallyValued.present
          ? data.manuallyValued.value
          : this.manuallyValued,
      notes: data.notes.present ? data.notes.value : this.notes,
      templateSuggestionId: data.templateSuggestionId.present
          ? data.templateSuggestionId.value
          : this.templateSuggestionId,
      checklistItemId: data.checklistItemId.present
          ? data.checklistItemId.value
          : this.checklistItemId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LedgerEntry(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('categoryCode: $categoryCode, ')
          ..write('entryType: $entryType, ')
          ..write('supplierName: $supplierName, ')
          ..write('estimatedCents: $estimatedCents, ')
          ..write('actualCents: $actualCents, ')
          ..write('pricingMode: $pricingMode, ')
          ..write('perHeadRateCents: $perHeadRateCents, ')
          ..write('manuallyValued: $manuallyValued, ')
          ..write('notes: $notes, ')
          ..write('templateSuggestionId: $templateSuggestionId, ')
          ..write('checklistItemId: $checklistItemId, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    planId,
    categoryCode,
    entryType,
    supplierName,
    estimatedCents,
    actualCents,
    pricingMode,
    perHeadRateCents,
    manuallyValued,
    notes,
    templateSuggestionId,
    checklistItemId,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LedgerEntry &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.categoryCode == this.categoryCode &&
          other.entryType == this.entryType &&
          other.supplierName == this.supplierName &&
          other.estimatedCents == this.estimatedCents &&
          other.actualCents == this.actualCents &&
          other.pricingMode == this.pricingMode &&
          other.perHeadRateCents == this.perHeadRateCents &&
          other.manuallyValued == this.manuallyValued &&
          other.notes == this.notes &&
          other.templateSuggestionId == this.templateSuggestionId &&
          other.checklistItemId == this.checklistItemId &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class LedgerEntriesCompanion extends UpdateCompanion<LedgerEntry> {
  final Value<String> id;
  final Value<String> planId;
  final Value<String> categoryCode;
  final Value<String> entryType;
  final Value<String> supplierName;
  final Value<int?> estimatedCents;
  final Value<int?> actualCents;
  final Value<String> pricingMode;
  final Value<int?> perHeadRateCents;
  final Value<int> manuallyValued;
  final Value<String?> notes;
  final Value<String?> templateSuggestionId;
  final Value<String?> checklistItemId;
  final Value<String> createdAt;
  final Value<String?> deletedAt;
  final Value<int> rowid;
  const LedgerEntriesCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.categoryCode = const Value.absent(),
    this.entryType = const Value.absent(),
    this.supplierName = const Value.absent(),
    this.estimatedCents = const Value.absent(),
    this.actualCents = const Value.absent(),
    this.pricingMode = const Value.absent(),
    this.perHeadRateCents = const Value.absent(),
    this.manuallyValued = const Value.absent(),
    this.notes = const Value.absent(),
    this.templateSuggestionId = const Value.absent(),
    this.checklistItemId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LedgerEntriesCompanion.insert({
    required String id,
    required String planId,
    required String categoryCode,
    required String entryType,
    required String supplierName,
    this.estimatedCents = const Value.absent(),
    this.actualCents = const Value.absent(),
    required String pricingMode,
    this.perHeadRateCents = const Value.absent(),
    this.manuallyValued = const Value.absent(),
    this.notes = const Value.absent(),
    this.templateSuggestionId = const Value.absent(),
    this.checklistItemId = const Value.absent(),
    required String createdAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       planId = Value(planId),
       categoryCode = Value(categoryCode),
       entryType = Value(entryType),
       supplierName = Value(supplierName),
       pricingMode = Value(pricingMode),
       createdAt = Value(createdAt);
  static Insertable<LedgerEntry> custom({
    Expression<String>? id,
    Expression<String>? planId,
    Expression<String>? categoryCode,
    Expression<String>? entryType,
    Expression<String>? supplierName,
    Expression<int>? estimatedCents,
    Expression<int>? actualCents,
    Expression<String>? pricingMode,
    Expression<int>? perHeadRateCents,
    Expression<int>? manuallyValued,
    Expression<String>? notes,
    Expression<String>? templateSuggestionId,
    Expression<String>? checklistItemId,
    Expression<String>? createdAt,
    Expression<String>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (categoryCode != null) 'category_code': categoryCode,
      if (entryType != null) 'entry_type': entryType,
      if (supplierName != null) 'supplier_name': supplierName,
      if (estimatedCents != null) 'estimated_cents': estimatedCents,
      if (actualCents != null) 'actual_cents': actualCents,
      if (pricingMode != null) 'pricing_mode': pricingMode,
      if (perHeadRateCents != null) 'per_head_rate_cents': perHeadRateCents,
      if (manuallyValued != null) 'manually_valued': manuallyValued,
      if (notes != null) 'notes': notes,
      if (templateSuggestionId != null)
        'template_suggestion_id': templateSuggestionId,
      if (checklistItemId != null) 'checklist_item_id': checklistItemId,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LedgerEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? planId,
    Value<String>? categoryCode,
    Value<String>? entryType,
    Value<String>? supplierName,
    Value<int?>? estimatedCents,
    Value<int?>? actualCents,
    Value<String>? pricingMode,
    Value<int?>? perHeadRateCents,
    Value<int>? manuallyValued,
    Value<String?>? notes,
    Value<String?>? templateSuggestionId,
    Value<String?>? checklistItemId,
    Value<String>? createdAt,
    Value<String?>? deletedAt,
    Value<int>? rowid,
  }) {
    return LedgerEntriesCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      categoryCode: categoryCode ?? this.categoryCode,
      entryType: entryType ?? this.entryType,
      supplierName: supplierName ?? this.supplierName,
      estimatedCents: estimatedCents ?? this.estimatedCents,
      actualCents: actualCents ?? this.actualCents,
      pricingMode: pricingMode ?? this.pricingMode,
      perHeadRateCents: perHeadRateCents ?? this.perHeadRateCents,
      manuallyValued: manuallyValued ?? this.manuallyValued,
      notes: notes ?? this.notes,
      templateSuggestionId: templateSuggestionId ?? this.templateSuggestionId,
      checklistItemId: checklistItemId ?? this.checklistItemId,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (categoryCode.present) {
      map['category_code'] = Variable<String>(categoryCode.value);
    }
    if (entryType.present) {
      map['entry_type'] = Variable<String>(entryType.value);
    }
    if (supplierName.present) {
      map['supplier_name'] = Variable<String>(supplierName.value);
    }
    if (estimatedCents.present) {
      map['estimated_cents'] = Variable<int>(estimatedCents.value);
    }
    if (actualCents.present) {
      map['actual_cents'] = Variable<int>(actualCents.value);
    }
    if (pricingMode.present) {
      map['pricing_mode'] = Variable<String>(pricingMode.value);
    }
    if (perHeadRateCents.present) {
      map['per_head_rate_cents'] = Variable<int>(perHeadRateCents.value);
    }
    if (manuallyValued.present) {
      map['manually_valued'] = Variable<int>(manuallyValued.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (templateSuggestionId.present) {
      map['template_suggestion_id'] = Variable<String>(
        templateSuggestionId.value,
      );
    }
    if (checklistItemId.present) {
      map['checklist_item_id'] = Variable<String>(checklistItemId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<String>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LedgerEntriesCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('categoryCode: $categoryCode, ')
          ..write('entryType: $entryType, ')
          ..write('supplierName: $supplierName, ')
          ..write('estimatedCents: $estimatedCents, ')
          ..write('actualCents: $actualCents, ')
          ..write('pricingMode: $pricingMode, ')
          ..write('perHeadRateCents: $perHeadRateCents, ')
          ..write('manuallyValued: $manuallyValued, ')
          ..write('notes: $notes, ')
          ..write('templateSuggestionId: $templateSuggestionId, ')
          ..write('checklistItemId: $checklistItemId, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class ChangeLog extends Table with TableInfo<ChangeLog, ChangeLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  ChangeLog(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES plans(id)',
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(entity_type) > 0)',
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _fieldNameMeta = const VerificationMeta(
    'fieldName',
  );
  late final GeneratedColumn<String> fieldName = GeneratedColumn<String>(
    'field_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (length(field_name) > 0)',
  );
  static const VerificationMeta _changeGroupIdMeta = const VerificationMeta(
    'changeGroupId',
  );
  late final GeneratedColumn<String> changeGroupId = GeneratedColumn<String>(
    'change_group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _schemaVersionMeta = const VerificationMeta(
    'schemaVersion',
  );
  late final GeneratedColumn<int> schemaVersion = GeneratedColumn<int>(
    'schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (schema_version > 0)',
  );
  static const VerificationMeta _oldValueMeta = const VerificationMeta(
    'oldValue',
  );
  late final GeneratedColumn<String> oldValue = GeneratedColumn<String>(
    'old_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _newValueMeta = const VerificationMeta(
    'newValue',
  );
  late final GeneratedColumn<String> newValue = GeneratedColumn<String>(
    'new_value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _serverTsMeta = const VerificationMeta(
    'serverTs',
  );
  late final GeneratedColumn<int> serverTs = GeneratedColumn<int>(
    'server_ts',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deviceMonotonicMeta = const VerificationMeta(
    'deviceMonotonic',
  );
  late final GeneratedColumn<int> deviceMonotonic = GeneratedColumn<int>(
    'device_monotonic',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (device_monotonic >= 0)',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _planMemberIdMeta = const VerificationMeta(
    'planMemberId',
  );
  late final GeneratedColumn<String> planMemberId = GeneratedColumn<String>(
    'plan_member_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    planId,
    entityType,
    entityId,
    fieldName,
    changeGroupId,
    schemaVersion,
    oldValue,
    newValue,
    serverTs,
    deviceMonotonic,
    deviceId,
    planMemberId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'change_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChangeLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('field_name')) {
      context.handle(
        _fieldNameMeta,
        fieldName.isAcceptableOrUnknown(data['field_name']!, _fieldNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldNameMeta);
    }
    if (data.containsKey('change_group_id')) {
      context.handle(
        _changeGroupIdMeta,
        changeGroupId.isAcceptableOrUnknown(
          data['change_group_id']!,
          _changeGroupIdMeta,
        ),
      );
    }
    if (data.containsKey('schema_version')) {
      context.handle(
        _schemaVersionMeta,
        schemaVersion.isAcceptableOrUnknown(
          data['schema_version']!,
          _schemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schemaVersionMeta);
    }
    if (data.containsKey('old_value')) {
      context.handle(
        _oldValueMeta,
        oldValue.isAcceptableOrUnknown(data['old_value']!, _oldValueMeta),
      );
    }
    if (data.containsKey('new_value')) {
      context.handle(
        _newValueMeta,
        newValue.isAcceptableOrUnknown(data['new_value']!, _newValueMeta),
      );
    }
    if (data.containsKey('server_ts')) {
      context.handle(
        _serverTsMeta,
        serverTs.isAcceptableOrUnknown(data['server_ts']!, _serverTsMeta),
      );
    }
    if (data.containsKey('device_monotonic')) {
      context.handle(
        _deviceMonotonicMeta,
        deviceMonotonic.isAcceptableOrUnknown(
          data['device_monotonic']!,
          _deviceMonotonicMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deviceMonotonicMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('plan_member_id')) {
      context.handle(
        _planMemberIdMeta,
        planMemberId.isAcceptableOrUnknown(
          data['plan_member_id']!,
          _planMemberIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_planMemberIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {id, planId},
  ];
  @override
  ChangeLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChangeLogData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      fieldName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field_name'],
      )!,
      changeGroupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}change_group_id'],
      ),
      schemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schema_version'],
      )!,
      oldValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}old_value'],
      ),
      newValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}new_value'],
      ),
      serverTs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_ts'],
      ),
      deviceMonotonic: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}device_monotonic'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      planMemberId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_member_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  ChangeLog createAlias(String alias) {
    return ChangeLog(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY(plan_id, plan_member_id)REFERENCES plan_member_aliases(plan_id, plan_member_id)',
    'UNIQUE(id, plan_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class ChangeLogData extends DataClass implements Insertable<ChangeLogData> {
  final String id;
  final String planId;
  final String entityType;
  final String entityId;
  final String fieldName;
  final String? changeGroupId;
  final int schemaVersion;
  final String? oldValue;
  final String? newValue;
  final int? serverTs;
  final int deviceMonotonic;
  final String deviceId;
  final String planMemberId;
  final String createdAt;
  const ChangeLogData({
    required this.id,
    required this.planId,
    required this.entityType,
    required this.entityId,
    required this.fieldName,
    this.changeGroupId,
    required this.schemaVersion,
    this.oldValue,
    this.newValue,
    this.serverTs,
    required this.deviceMonotonic,
    required this.deviceId,
    required this.planMemberId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['plan_id'] = Variable<String>(planId);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['field_name'] = Variable<String>(fieldName);
    if (!nullToAbsent || changeGroupId != null) {
      map['change_group_id'] = Variable<String>(changeGroupId);
    }
    map['schema_version'] = Variable<int>(schemaVersion);
    if (!nullToAbsent || oldValue != null) {
      map['old_value'] = Variable<String>(oldValue);
    }
    if (!nullToAbsent || newValue != null) {
      map['new_value'] = Variable<String>(newValue);
    }
    if (!nullToAbsent || serverTs != null) {
      map['server_ts'] = Variable<int>(serverTs);
    }
    map['device_monotonic'] = Variable<int>(deviceMonotonic);
    map['device_id'] = Variable<String>(deviceId);
    map['plan_member_id'] = Variable<String>(planMemberId);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  ChangeLogCompanion toCompanion(bool nullToAbsent) {
    return ChangeLogCompanion(
      id: Value(id),
      planId: Value(planId),
      entityType: Value(entityType),
      entityId: Value(entityId),
      fieldName: Value(fieldName),
      changeGroupId: changeGroupId == null && nullToAbsent
          ? const Value.absent()
          : Value(changeGroupId),
      schemaVersion: Value(schemaVersion),
      oldValue: oldValue == null && nullToAbsent
          ? const Value.absent()
          : Value(oldValue),
      newValue: newValue == null && nullToAbsent
          ? const Value.absent()
          : Value(newValue),
      serverTs: serverTs == null && nullToAbsent
          ? const Value.absent()
          : Value(serverTs),
      deviceMonotonic: Value(deviceMonotonic),
      deviceId: Value(deviceId),
      planMemberId: Value(planMemberId),
      createdAt: Value(createdAt),
    );
  }

  factory ChangeLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChangeLogData(
      id: serializer.fromJson<String>(json['id']),
      planId: serializer.fromJson<String>(json['plan_id']),
      entityType: serializer.fromJson<String>(json['entity_type']),
      entityId: serializer.fromJson<String>(json['entity_id']),
      fieldName: serializer.fromJson<String>(json['field_name']),
      changeGroupId: serializer.fromJson<String?>(json['change_group_id']),
      schemaVersion: serializer.fromJson<int>(json['schema_version']),
      oldValue: serializer.fromJson<String?>(json['old_value']),
      newValue: serializer.fromJson<String?>(json['new_value']),
      serverTs: serializer.fromJson<int?>(json['server_ts']),
      deviceMonotonic: serializer.fromJson<int>(json['device_monotonic']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      planMemberId: serializer.fromJson<String>(json['plan_member_id']),
      createdAt: serializer.fromJson<String>(json['created_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'plan_id': serializer.toJson<String>(planId),
      'entity_type': serializer.toJson<String>(entityType),
      'entity_id': serializer.toJson<String>(entityId),
      'field_name': serializer.toJson<String>(fieldName),
      'change_group_id': serializer.toJson<String?>(changeGroupId),
      'schema_version': serializer.toJson<int>(schemaVersion),
      'old_value': serializer.toJson<String?>(oldValue),
      'new_value': serializer.toJson<String?>(newValue),
      'server_ts': serializer.toJson<int?>(serverTs),
      'device_monotonic': serializer.toJson<int>(deviceMonotonic),
      'device_id': serializer.toJson<String>(deviceId),
      'plan_member_id': serializer.toJson<String>(planMemberId),
      'created_at': serializer.toJson<String>(createdAt),
    };
  }

  ChangeLogData copyWith({
    String? id,
    String? planId,
    String? entityType,
    String? entityId,
    String? fieldName,
    Value<String?> changeGroupId = const Value.absent(),
    int? schemaVersion,
    Value<String?> oldValue = const Value.absent(),
    Value<String?> newValue = const Value.absent(),
    Value<int?> serverTs = const Value.absent(),
    int? deviceMonotonic,
    String? deviceId,
    String? planMemberId,
    String? createdAt,
  }) => ChangeLogData(
    id: id ?? this.id,
    planId: planId ?? this.planId,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    fieldName: fieldName ?? this.fieldName,
    changeGroupId: changeGroupId.present
        ? changeGroupId.value
        : this.changeGroupId,
    schemaVersion: schemaVersion ?? this.schemaVersion,
    oldValue: oldValue.present ? oldValue.value : this.oldValue,
    newValue: newValue.present ? newValue.value : this.newValue,
    serverTs: serverTs.present ? serverTs.value : this.serverTs,
    deviceMonotonic: deviceMonotonic ?? this.deviceMonotonic,
    deviceId: deviceId ?? this.deviceId,
    planMemberId: planMemberId ?? this.planMemberId,
    createdAt: createdAt ?? this.createdAt,
  );
  ChangeLogData copyWithCompanion(ChangeLogCompanion data) {
    return ChangeLogData(
      id: data.id.present ? data.id.value : this.id,
      planId: data.planId.present ? data.planId.value : this.planId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      fieldName: data.fieldName.present ? data.fieldName.value : this.fieldName,
      changeGroupId: data.changeGroupId.present
          ? data.changeGroupId.value
          : this.changeGroupId,
      schemaVersion: data.schemaVersion.present
          ? data.schemaVersion.value
          : this.schemaVersion,
      oldValue: data.oldValue.present ? data.oldValue.value : this.oldValue,
      newValue: data.newValue.present ? data.newValue.value : this.newValue,
      serverTs: data.serverTs.present ? data.serverTs.value : this.serverTs,
      deviceMonotonic: data.deviceMonotonic.present
          ? data.deviceMonotonic.value
          : this.deviceMonotonic,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      planMemberId: data.planMemberId.present
          ? data.planMemberId.value
          : this.planMemberId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChangeLogData(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('fieldName: $fieldName, ')
          ..write('changeGroupId: $changeGroupId, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('oldValue: $oldValue, ')
          ..write('newValue: $newValue, ')
          ..write('serverTs: $serverTs, ')
          ..write('deviceMonotonic: $deviceMonotonic, ')
          ..write('deviceId: $deviceId, ')
          ..write('planMemberId: $planMemberId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    planId,
    entityType,
    entityId,
    fieldName,
    changeGroupId,
    schemaVersion,
    oldValue,
    newValue,
    serverTs,
    deviceMonotonic,
    deviceId,
    planMemberId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChangeLogData &&
          other.id == this.id &&
          other.planId == this.planId &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.fieldName == this.fieldName &&
          other.changeGroupId == this.changeGroupId &&
          other.schemaVersion == this.schemaVersion &&
          other.oldValue == this.oldValue &&
          other.newValue == this.newValue &&
          other.serverTs == this.serverTs &&
          other.deviceMonotonic == this.deviceMonotonic &&
          other.deviceId == this.deviceId &&
          other.planMemberId == this.planMemberId &&
          other.createdAt == this.createdAt);
}

class ChangeLogCompanion extends UpdateCompanion<ChangeLogData> {
  final Value<String> id;
  final Value<String> planId;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<String> fieldName;
  final Value<String?> changeGroupId;
  final Value<int> schemaVersion;
  final Value<String?> oldValue;
  final Value<String?> newValue;
  final Value<int?> serverTs;
  final Value<int> deviceMonotonic;
  final Value<String> deviceId;
  final Value<String> planMemberId;
  final Value<String> createdAt;
  final Value<int> rowid;
  const ChangeLogCompanion({
    this.id = const Value.absent(),
    this.planId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.fieldName = const Value.absent(),
    this.changeGroupId = const Value.absent(),
    this.schemaVersion = const Value.absent(),
    this.oldValue = const Value.absent(),
    this.newValue = const Value.absent(),
    this.serverTs = const Value.absent(),
    this.deviceMonotonic = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.planMemberId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChangeLogCompanion.insert({
    required String id,
    required String planId,
    required String entityType,
    required String entityId,
    required String fieldName,
    this.changeGroupId = const Value.absent(),
    required int schemaVersion,
    this.oldValue = const Value.absent(),
    this.newValue = const Value.absent(),
    this.serverTs = const Value.absent(),
    required int deviceMonotonic,
    required String deviceId,
    required String planMemberId,
    required String createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       planId = Value(planId),
       entityType = Value(entityType),
       entityId = Value(entityId),
       fieldName = Value(fieldName),
       schemaVersion = Value(schemaVersion),
       deviceMonotonic = Value(deviceMonotonic),
       deviceId = Value(deviceId),
       planMemberId = Value(planMemberId),
       createdAt = Value(createdAt);
  static Insertable<ChangeLogData> custom({
    Expression<String>? id,
    Expression<String>? planId,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<String>? fieldName,
    Expression<String>? changeGroupId,
    Expression<int>? schemaVersion,
    Expression<String>? oldValue,
    Expression<String>? newValue,
    Expression<int>? serverTs,
    Expression<int>? deviceMonotonic,
    Expression<String>? deviceId,
    Expression<String>? planMemberId,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (planId != null) 'plan_id': planId,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (fieldName != null) 'field_name': fieldName,
      if (changeGroupId != null) 'change_group_id': changeGroupId,
      if (schemaVersion != null) 'schema_version': schemaVersion,
      if (oldValue != null) 'old_value': oldValue,
      if (newValue != null) 'new_value': newValue,
      if (serverTs != null) 'server_ts': serverTs,
      if (deviceMonotonic != null) 'device_monotonic': deviceMonotonic,
      if (deviceId != null) 'device_id': deviceId,
      if (planMemberId != null) 'plan_member_id': planMemberId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChangeLogCompanion copyWith({
    Value<String>? id,
    Value<String>? planId,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<String>? fieldName,
    Value<String?>? changeGroupId,
    Value<int>? schemaVersion,
    Value<String?>? oldValue,
    Value<String?>? newValue,
    Value<int?>? serverTs,
    Value<int>? deviceMonotonic,
    Value<String>? deviceId,
    Value<String>? planMemberId,
    Value<String>? createdAt,
    Value<int>? rowid,
  }) {
    return ChangeLogCompanion(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      fieldName: fieldName ?? this.fieldName,
      changeGroupId: changeGroupId ?? this.changeGroupId,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      oldValue: oldValue ?? this.oldValue,
      newValue: newValue ?? this.newValue,
      serverTs: serverTs ?? this.serverTs,
      deviceMonotonic: deviceMonotonic ?? this.deviceMonotonic,
      deviceId: deviceId ?? this.deviceId,
      planMemberId: planMemberId ?? this.planMemberId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (fieldName.present) {
      map['field_name'] = Variable<String>(fieldName.value);
    }
    if (changeGroupId.present) {
      map['change_group_id'] = Variable<String>(changeGroupId.value);
    }
    if (schemaVersion.present) {
      map['schema_version'] = Variable<int>(schemaVersion.value);
    }
    if (oldValue.present) {
      map['old_value'] = Variable<String>(oldValue.value);
    }
    if (newValue.present) {
      map['new_value'] = Variable<String>(newValue.value);
    }
    if (serverTs.present) {
      map['server_ts'] = Variable<int>(serverTs.value);
    }
    if (deviceMonotonic.present) {
      map['device_monotonic'] = Variable<int>(deviceMonotonic.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (planMemberId.present) {
      map['plan_member_id'] = Variable<String>(planMemberId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChangeLogCompanion(')
          ..write('id: $id, ')
          ..write('planId: $planId, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('fieldName: $fieldName, ')
          ..write('changeGroupId: $changeGroupId, ')
          ..write('schemaVersion: $schemaVersion, ')
          ..write('oldValue: $oldValue, ')
          ..write('newValue: $newValue, ')
          ..write('serverTs: $serverTs, ')
          ..write('deviceMonotonic: $deviceMonotonic, ')
          ..write('deviceId: $deviceId, ')
          ..write('planMemberId: $planMemberId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class SyncState extends Table with TableInfo<SyncState, SyncStateData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  SyncState(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES plans(id)',
  );
  static const VerificationMeta _lastPushedServerTsMeta =
      const VerificationMeta('lastPushedServerTs');
  late final GeneratedColumn<int> lastPushedServerTs = GeneratedColumn<int>(
    'last_pushed_server_ts',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _lastPulledServerTsMeta =
      const VerificationMeta('lastPulledServerTs');
  late final GeneratedColumn<int> lastPulledServerTs = GeneratedColumn<int>(
    'last_pulled_server_ts',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: '',
  );
  static const VerificationMeta _deviceMonotonicMeta = const VerificationMeta(
    'deviceMonotonic',
  );
  late final GeneratedColumn<int> deviceMonotonic = GeneratedColumn<int>(
    'device_monotonic',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (device_monotonic >= 0)',
    defaultValue: const CustomExpression('0'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceId,
    planId,
    lastPushedServerTs,
    lastPulledServerTs,
    deviceMonotonic,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('last_pushed_server_ts')) {
      context.handle(
        _lastPushedServerTsMeta,
        lastPushedServerTs.isAcceptableOrUnknown(
          data['last_pushed_server_ts']!,
          _lastPushedServerTsMeta,
        ),
      );
    }
    if (data.containsKey('last_pulled_server_ts')) {
      context.handle(
        _lastPulledServerTsMeta,
        lastPulledServerTs.isAcceptableOrUnknown(
          data['last_pulled_server_ts']!,
          _lastPulledServerTsMeta,
        ),
      );
    }
    if (data.containsKey('device_monotonic')) {
      context.handle(
        _deviceMonotonicMeta,
        deviceMonotonic.isAcceptableOrUnknown(
          data['device_monotonic']!,
          _deviceMonotonicMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId, planId};
  @override
  SyncStateData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateData(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      lastPushedServerTs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_pushed_server_ts'],
      ),
      lastPulledServerTs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_pulled_server_ts'],
      ),
      deviceMonotonic: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}device_monotonic'],
      )!,
    );
  }

  @override
  SyncState createAlias(String alias) {
    return SyncState(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'PRIMARY KEY(device_id, plan_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class SyncStateData extends DataClass implements Insertable<SyncStateData> {
  final String deviceId;
  final String planId;
  final int? lastPushedServerTs;
  final int? lastPulledServerTs;
  final int deviceMonotonic;
  const SyncStateData({
    required this.deviceId,
    required this.planId,
    this.lastPushedServerTs,
    this.lastPulledServerTs,
    required this.deviceMonotonic,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['plan_id'] = Variable<String>(planId);
    if (!nullToAbsent || lastPushedServerTs != null) {
      map['last_pushed_server_ts'] = Variable<int>(lastPushedServerTs);
    }
    if (!nullToAbsent || lastPulledServerTs != null) {
      map['last_pulled_server_ts'] = Variable<int>(lastPulledServerTs);
    }
    map['device_monotonic'] = Variable<int>(deviceMonotonic);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(
      deviceId: Value(deviceId),
      planId: Value(planId),
      lastPushedServerTs: lastPushedServerTs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPushedServerTs),
      lastPulledServerTs: lastPulledServerTs == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPulledServerTs),
      deviceMonotonic: Value(deviceMonotonic),
    );
  }

  factory SyncStateData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateData(
      deviceId: serializer.fromJson<String>(json['device_id']),
      planId: serializer.fromJson<String>(json['plan_id']),
      lastPushedServerTs: serializer.fromJson<int?>(
        json['last_pushed_server_ts'],
      ),
      lastPulledServerTs: serializer.fromJson<int?>(
        json['last_pulled_server_ts'],
      ),
      deviceMonotonic: serializer.fromJson<int>(json['device_monotonic']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'device_id': serializer.toJson<String>(deviceId),
      'plan_id': serializer.toJson<String>(planId),
      'last_pushed_server_ts': serializer.toJson<int?>(lastPushedServerTs),
      'last_pulled_server_ts': serializer.toJson<int?>(lastPulledServerTs),
      'device_monotonic': serializer.toJson<int>(deviceMonotonic),
    };
  }

  SyncStateData copyWith({
    String? deviceId,
    String? planId,
    Value<int?> lastPushedServerTs = const Value.absent(),
    Value<int?> lastPulledServerTs = const Value.absent(),
    int? deviceMonotonic,
  }) => SyncStateData(
    deviceId: deviceId ?? this.deviceId,
    planId: planId ?? this.planId,
    lastPushedServerTs: lastPushedServerTs.present
        ? lastPushedServerTs.value
        : this.lastPushedServerTs,
    lastPulledServerTs: lastPulledServerTs.present
        ? lastPulledServerTs.value
        : this.lastPulledServerTs,
    deviceMonotonic: deviceMonotonic ?? this.deviceMonotonic,
  );
  SyncStateData copyWithCompanion(SyncStateCompanion data) {
    return SyncStateData(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      planId: data.planId.present ? data.planId.value : this.planId,
      lastPushedServerTs: data.lastPushedServerTs.present
          ? data.lastPushedServerTs.value
          : this.lastPushedServerTs,
      lastPulledServerTs: data.lastPulledServerTs.present
          ? data.lastPulledServerTs.value
          : this.lastPulledServerTs,
      deviceMonotonic: data.deviceMonotonic.present
          ? data.deviceMonotonic.value
          : this.deviceMonotonic,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateData(')
          ..write('deviceId: $deviceId, ')
          ..write('planId: $planId, ')
          ..write('lastPushedServerTs: $lastPushedServerTs, ')
          ..write('lastPulledServerTs: $lastPulledServerTs, ')
          ..write('deviceMonotonic: $deviceMonotonic')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    deviceId,
    planId,
    lastPushedServerTs,
    lastPulledServerTs,
    deviceMonotonic,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateData &&
          other.deviceId == this.deviceId &&
          other.planId == this.planId &&
          other.lastPushedServerTs == this.lastPushedServerTs &&
          other.lastPulledServerTs == this.lastPulledServerTs &&
          other.deviceMonotonic == this.deviceMonotonic);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateData> {
  final Value<String> deviceId;
  final Value<String> planId;
  final Value<int?> lastPushedServerTs;
  final Value<int?> lastPulledServerTs;
  final Value<int> deviceMonotonic;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.deviceId = const Value.absent(),
    this.planId = const Value.absent(),
    this.lastPushedServerTs = const Value.absent(),
    this.lastPulledServerTs = const Value.absent(),
    this.deviceMonotonic = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String deviceId,
    required String planId,
    this.lastPushedServerTs = const Value.absent(),
    this.lastPulledServerTs = const Value.absent(),
    this.deviceMonotonic = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       planId = Value(planId);
  static Insertable<SyncStateData> custom({
    Expression<String>? deviceId,
    Expression<String>? planId,
    Expression<int>? lastPushedServerTs,
    Expression<int>? lastPulledServerTs,
    Expression<int>? deviceMonotonic,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (planId != null) 'plan_id': planId,
      if (lastPushedServerTs != null)
        'last_pushed_server_ts': lastPushedServerTs,
      if (lastPulledServerTs != null)
        'last_pulled_server_ts': lastPulledServerTs,
      if (deviceMonotonic != null) 'device_monotonic': deviceMonotonic,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? deviceId,
    Value<String>? planId,
    Value<int?>? lastPushedServerTs,
    Value<int?>? lastPulledServerTs,
    Value<int>? deviceMonotonic,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      deviceId: deviceId ?? this.deviceId,
      planId: planId ?? this.planId,
      lastPushedServerTs: lastPushedServerTs ?? this.lastPushedServerTs,
      lastPulledServerTs: lastPulledServerTs ?? this.lastPulledServerTs,
      deviceMonotonic: deviceMonotonic ?? this.deviceMonotonic,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (lastPushedServerTs.present) {
      map['last_pushed_server_ts'] = Variable<int>(lastPushedServerTs.value);
    }
    if (lastPulledServerTs.present) {
      map['last_pulled_server_ts'] = Variable<int>(lastPulledServerTs.value);
    }
    if (deviceMonotonic.present) {
      map['device_monotonic'] = Variable<int>(deviceMonotonic.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('planId: $planId, ')
          ..write('lastPushedServerTs: $lastPushedServerTs, ')
          ..write('lastPulledServerTs: $lastPulledServerTs, ')
          ..write('deviceMonotonic: $deviceMonotonic, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class Outbox extends Table with TableInfo<Outbox, OutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  Outbox(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL PRIMARY KEY',
  );
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
    'plan_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL REFERENCES plans(id)',
  );
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  static const VerificationMeta _queuedAtMeta = const VerificationMeta(
    'queuedAt',
  );
  late final GeneratedColumn<String> queuedAt = GeneratedColumn<String>(
    'queued_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL',
  );
  @override
  List<GeneratedColumn> get $columns => [eventId, planId, deviceId, queuedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(
        _planIdMeta,
        planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta),
      );
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('queued_at')) {
      context.handle(
        _queuedAtMeta,
        queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {eventId};
  @override
  OutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxData(
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      planId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      queuedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}queued_at'],
      )!,
    );
  }

  @override
  Outbox createAlias(String alias) {
    return Outbox(attachedDatabase, alias);
  }

  @override
  List<String> get customConstraints => const [
    'FOREIGN KEY(event_id, plan_id)REFERENCES change_log(id, plan_id)',
  ];
  @override
  bool get dontWriteConstraints => true;
}

class OutboxData extends DataClass implements Insertable<OutboxData> {
  final String eventId;
  final String planId;
  final String deviceId;
  final String queuedAt;
  const OutboxData({
    required this.eventId,
    required this.planId,
    required this.deviceId,
    required this.queuedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['event_id'] = Variable<String>(eventId);
    map['plan_id'] = Variable<String>(planId);
    map['device_id'] = Variable<String>(deviceId);
    map['queued_at'] = Variable<String>(queuedAt);
    return map;
  }

  OutboxCompanion toCompanion(bool nullToAbsent) {
    return OutboxCompanion(
      eventId: Value(eventId),
      planId: Value(planId),
      deviceId: Value(deviceId),
      queuedAt: Value(queuedAt),
    );
  }

  factory OutboxData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxData(
      eventId: serializer.fromJson<String>(json['event_id']),
      planId: serializer.fromJson<String>(json['plan_id']),
      deviceId: serializer.fromJson<String>(json['device_id']),
      queuedAt: serializer.fromJson<String>(json['queued_at']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'event_id': serializer.toJson<String>(eventId),
      'plan_id': serializer.toJson<String>(planId),
      'device_id': serializer.toJson<String>(deviceId),
      'queued_at': serializer.toJson<String>(queuedAt),
    };
  }

  OutboxData copyWith({
    String? eventId,
    String? planId,
    String? deviceId,
    String? queuedAt,
  }) => OutboxData(
    eventId: eventId ?? this.eventId,
    planId: planId ?? this.planId,
    deviceId: deviceId ?? this.deviceId,
    queuedAt: queuedAt ?? this.queuedAt,
  );
  OutboxData copyWithCompanion(OutboxCompanion data) {
    return OutboxData(
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      planId: data.planId.present ? data.planId.value : this.planId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxData(')
          ..write('eventId: $eventId, ')
          ..write('planId: $planId, ')
          ..write('deviceId: $deviceId, ')
          ..write('queuedAt: $queuedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(eventId, planId, deviceId, queuedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxData &&
          other.eventId == this.eventId &&
          other.planId == this.planId &&
          other.deviceId == this.deviceId &&
          other.queuedAt == this.queuedAt);
}

class OutboxCompanion extends UpdateCompanion<OutboxData> {
  final Value<String> eventId;
  final Value<String> planId;
  final Value<String> deviceId;
  final Value<String> queuedAt;
  final Value<int> rowid;
  const OutboxCompanion({
    this.eventId = const Value.absent(),
    this.planId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCompanion.insert({
    required String eventId,
    required String planId,
    required String deviceId,
    required String queuedAt,
    this.rowid = const Value.absent(),
  }) : eventId = Value(eventId),
       planId = Value(planId),
       deviceId = Value(deviceId),
       queuedAt = Value(queuedAt);
  static Insertable<OutboxData> custom({
    Expression<String>? eventId,
    Expression<String>? planId,
    Expression<String>? deviceId,
    Expression<String>? queuedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (eventId != null) 'event_id': eventId,
      if (planId != null) 'plan_id': planId,
      if (deviceId != null) 'device_id': deviceId,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCompanion copyWith({
    Value<String>? eventId,
    Value<String>? planId,
    Value<String>? deviceId,
    Value<String>? queuedAt,
    Value<int>? rowid,
  }) {
    return OutboxCompanion(
      eventId: eventId ?? this.eventId,
      planId: planId ?? this.planId,
      deviceId: deviceId ?? this.deviceId,
      queuedAt: queuedAt ?? this.queuedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<String>(queuedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCompanion(')
          ..write('eventId: $eventId, ')
          ..write('planId: $planId, ')
          ..write('deviceId: $deviceId, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final Plans plans = Plans(this);
  late final PlanMemberAliases planMemberAliases = PlanMemberAliases(this);
  late final PlanMembers planMembers = PlanMembers(this);
  late final LedgerEntries ledgerEntries = LedgerEntries(this);
  late final ChangeLog changeLog = ChangeLog(this);
  late final SyncState syncState = SyncState(this);
  late final Outbox outbox = Outbox(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    plans,
    planMemberAliases,
    planMembers,
    ledgerEntries,
    changeLog,
    syncState,
    outbox,
  ];
}

typedef $PlansCreateCompanionBuilder =
    PlansCompanion Function({
      required String id,
      required String creatorUserId,
      required String weddingDate,
      required int totalBudgetCents,
      required int guestCap,
      required String regionCode,
      Value<String?> ceremonyType,
      Value<String?> venueType,
      Value<int> reminderEnabled,
      Value<int> reminderWindowDays,
      Value<String> reminderDaysBefore,
      Value<int> reminderOverdue,
      required String rulesetVersion,
      required String drivingRsvpStatus,
      Value<int> isActive,
      Value<String?> setupCompletedAt,
      required String createdAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $PlansUpdateCompanionBuilder =
    PlansCompanion Function({
      Value<String> id,
      Value<String> creatorUserId,
      Value<String> weddingDate,
      Value<int> totalBudgetCents,
      Value<int> guestCap,
      Value<String> regionCode,
      Value<String?> ceremonyType,
      Value<String?> venueType,
      Value<int> reminderEnabled,
      Value<int> reminderWindowDays,
      Value<String> reminderDaysBefore,
      Value<int> reminderOverdue,
      Value<String> rulesetVersion,
      Value<String> drivingRsvpStatus,
      Value<int> isActive,
      Value<String?> setupCompletedAt,
      Value<String> createdAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

final class $PlansReferences
    extends BaseReferences<_$AppDatabase, Plans, Plan> {
  $PlansReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<PlanMemberAliases, List<PlanMemberAliase>>
  _planMemberAliasesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.planMemberAliases,
        aliasName: 'plans__id__plan_member_aliases__plan_id',
      );

  $PlanMemberAliasesProcessedTableManager get planMemberAliasesRefs {
    final manager = $PlanMemberAliasesTableManager(
      $_db,
      $_db.planMemberAliases,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _planMemberAliasesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<PlanMembers, List<PlanMember>>
  _planMembersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.planMembers,
    aliasName: 'plans__id__plan_members__plan_id',
  );

  $PlanMembersProcessedTableManager get planMembersRefs {
    final manager = $PlanMembersTableManager(
      $_db,
      $_db.planMembers,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_planMembersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<LedgerEntries, List<LedgerEntry>>
  _ledgerEntriesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.ledgerEntries,
    aliasName: 'plans__id__ledger_entries__plan_id',
  );

  $LedgerEntriesProcessedTableManager get ledgerEntriesRefs {
    final manager = $LedgerEntriesTableManager(
      $_db,
      $_db.ledgerEntries,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_ledgerEntriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<ChangeLog, List<ChangeLogData>>
  _changeLogRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.changeLog,
    aliasName: 'plans__id__change_log__plan_id',
  );

  $ChangeLogProcessedTableManager get changeLogRefs {
    final manager = $ChangeLogTableManager(
      $_db,
      $_db.changeLog,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_changeLogRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<SyncState, List<SyncStateData>>
  _syncStateRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.syncState,
    aliasName: 'plans__id__sync_state__plan_id',
  );

  $SyncStateProcessedTableManager get syncStateRefs {
    final manager = $SyncStateTableManager(
      $_db,
      $_db.syncState,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_syncStateRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<Outbox, List<OutboxData>> _outboxRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.outbox,
    aliasName: 'plans__id__outbox__plan_id',
  );

  $OutboxProcessedTableManager get outboxRefs {
    final manager = $OutboxTableManager(
      $_db,
      $_db.outbox,
    ).filter((f) => f.planId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_outboxRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $PlansFilterComposer extends Composer<_$AppDatabase, Plans> {
  $PlansFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get creatorUserId => $composableBuilder(
    column: $table.creatorUserId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get weddingDate => $composableBuilder(
    column: $table.weddingDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBudgetCents => $composableBuilder(
    column: $table.totalBudgetCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get guestCap => $composableBuilder(
    column: $table.guestCap,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get regionCode => $composableBuilder(
    column: $table.regionCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ceremonyType => $composableBuilder(
    column: $table.ceremonyType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get venueType => $composableBuilder(
    column: $table.venueType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderWindowDays => $composableBuilder(
    column: $table.reminderWindowDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reminderDaysBefore => $composableBuilder(
    column: $table.reminderDaysBefore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reminderOverdue => $composableBuilder(
    column: $table.reminderOverdue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rulesetVersion => $composableBuilder(
    column: $table.rulesetVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get drivingRsvpStatus => $composableBuilder(
    column: $table.drivingRsvpStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get setupCompletedAt => $composableBuilder(
    column: $table.setupCompletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> planMemberAliasesRefs(
    Expression<bool> Function($PlanMemberAliasesFilterComposer f) f,
  ) {
    final $PlanMemberAliasesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.planMemberAliases,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlanMemberAliasesFilterComposer(
            $db: $db,
            $table: $db.planMemberAliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> planMembersRefs(
    Expression<bool> Function($PlanMembersFilterComposer f) f,
  ) {
    final $PlanMembersFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.planMembers,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlanMembersFilterComposer(
            $db: $db,
            $table: $db.planMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> ledgerEntriesRefs(
    Expression<bool> Function($LedgerEntriesFilterComposer f) f,
  ) {
    final $LedgerEntriesFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ledgerEntries,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $LedgerEntriesFilterComposer(
            $db: $db,
            $table: $db.ledgerEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> changeLogRefs(
    Expression<bool> Function($ChangeLogFilterComposer f) f,
  ) {
    final $ChangeLogFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.changeLog,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ChangeLogFilterComposer(
            $db: $db,
            $table: $db.changeLog,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> syncStateRefs(
    Expression<bool> Function($SyncStateFilterComposer f) f,
  ) {
    final $SyncStateFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncState,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SyncStateFilterComposer(
            $db: $db,
            $table: $db.syncState,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> outboxRefs(
    Expression<bool> Function($OutboxFilterComposer f) f,
  ) {
    final $OutboxFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.outbox,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $OutboxFilterComposer(
            $db: $db,
            $table: $db.outbox,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $PlansOrderingComposer extends Composer<_$AppDatabase, Plans> {
  $PlansOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get creatorUserId => $composableBuilder(
    column: $table.creatorUserId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get weddingDate => $composableBuilder(
    column: $table.weddingDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBudgetCents => $composableBuilder(
    column: $table.totalBudgetCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get guestCap => $composableBuilder(
    column: $table.guestCap,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get regionCode => $composableBuilder(
    column: $table.regionCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ceremonyType => $composableBuilder(
    column: $table.ceremonyType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get venueType => $composableBuilder(
    column: $table.venueType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderWindowDays => $composableBuilder(
    column: $table.reminderWindowDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reminderDaysBefore => $composableBuilder(
    column: $table.reminderDaysBefore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reminderOverdue => $composableBuilder(
    column: $table.reminderOverdue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rulesetVersion => $composableBuilder(
    column: $table.rulesetVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get drivingRsvpStatus => $composableBuilder(
    column: $table.drivingRsvpStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get setupCompletedAt => $composableBuilder(
    column: $table.setupCompletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $PlansAnnotationComposer extends Composer<_$AppDatabase, Plans> {
  $PlansAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get creatorUserId => $composableBuilder(
    column: $table.creatorUserId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get weddingDate => $composableBuilder(
    column: $table.weddingDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBudgetCents => $composableBuilder(
    column: $table.totalBudgetCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get guestCap =>
      $composableBuilder(column: $table.guestCap, builder: (column) => column);

  GeneratedColumn<String> get regionCode => $composableBuilder(
    column: $table.regionCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ceremonyType => $composableBuilder(
    column: $table.ceremonyType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get venueType =>
      $composableBuilder(column: $table.venueType, builder: (column) => column);

  GeneratedColumn<int> get reminderEnabled => $composableBuilder(
    column: $table.reminderEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderWindowDays => $composableBuilder(
    column: $table.reminderWindowDays,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reminderDaysBefore => $composableBuilder(
    column: $table.reminderDaysBefore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get reminderOverdue => $composableBuilder(
    column: $table.reminderOverdue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rulesetVersion => $composableBuilder(
    column: $table.rulesetVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get drivingRsvpStatus => $composableBuilder(
    column: $table.drivingRsvpStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get setupCompletedAt => $composableBuilder(
    column: $table.setupCompletedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  Expression<T> planMemberAliasesRefs<T extends Object>(
    Expression<T> Function($PlanMemberAliasesAnnotationComposer a) f,
  ) {
    final $PlanMemberAliasesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.planMemberAliases,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlanMemberAliasesAnnotationComposer(
            $db: $db,
            $table: $db.planMemberAliases,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> planMembersRefs<T extends Object>(
    Expression<T> Function($PlanMembersAnnotationComposer a) f,
  ) {
    final $PlanMembersAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.planMembers,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlanMembersAnnotationComposer(
            $db: $db,
            $table: $db.planMembers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> ledgerEntriesRefs<T extends Object>(
    Expression<T> Function($LedgerEntriesAnnotationComposer a) f,
  ) {
    final $LedgerEntriesAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ledgerEntries,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $LedgerEntriesAnnotationComposer(
            $db: $db,
            $table: $db.ledgerEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> changeLogRefs<T extends Object>(
    Expression<T> Function($ChangeLogAnnotationComposer a) f,
  ) {
    final $ChangeLogAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.changeLog,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $ChangeLogAnnotationComposer(
            $db: $db,
            $table: $db.changeLog,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> syncStateRefs<T extends Object>(
    Expression<T> Function($SyncStateAnnotationComposer a) f,
  ) {
    final $SyncStateAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.syncState,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $SyncStateAnnotationComposer(
            $db: $db,
            $table: $db.syncState,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> outboxRefs<T extends Object>(
    Expression<T> Function($OutboxAnnotationComposer a) f,
  ) {
    final $OutboxAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.outbox,
      getReferencedColumn: (t) => t.planId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $OutboxAnnotationComposer(
            $db: $db,
            $table: $db.outbox,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $PlansTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Plans,
          Plan,
          $PlansFilterComposer,
          $PlansOrderingComposer,
          $PlansAnnotationComposer,
          $PlansCreateCompanionBuilder,
          $PlansUpdateCompanionBuilder,
          (Plan, $PlansReferences),
          Plan,
          PrefetchHooks Function({
            bool planMemberAliasesRefs,
            bool planMembersRefs,
            bool ledgerEntriesRefs,
            bool changeLogRefs,
            bool syncStateRefs,
            bool outboxRefs,
          })
        > {
  $PlansTableManager(_$AppDatabase db, Plans table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PlansFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PlansOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PlansAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> creatorUserId = const Value.absent(),
                Value<String> weddingDate = const Value.absent(),
                Value<int> totalBudgetCents = const Value.absent(),
                Value<int> guestCap = const Value.absent(),
                Value<String> regionCode = const Value.absent(),
                Value<String?> ceremonyType = const Value.absent(),
                Value<String?> venueType = const Value.absent(),
                Value<int> reminderEnabled = const Value.absent(),
                Value<int> reminderWindowDays = const Value.absent(),
                Value<String> reminderDaysBefore = const Value.absent(),
                Value<int> reminderOverdue = const Value.absent(),
                Value<String> rulesetVersion = const Value.absent(),
                Value<String> drivingRsvpStatus = const Value.absent(),
                Value<int> isActive = const Value.absent(),
                Value<String?> setupCompletedAt = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlansCompanion(
                id: id,
                creatorUserId: creatorUserId,
                weddingDate: weddingDate,
                totalBudgetCents: totalBudgetCents,
                guestCap: guestCap,
                regionCode: regionCode,
                ceremonyType: ceremonyType,
                venueType: venueType,
                reminderEnabled: reminderEnabled,
                reminderWindowDays: reminderWindowDays,
                reminderDaysBefore: reminderDaysBefore,
                reminderOverdue: reminderOverdue,
                rulesetVersion: rulesetVersion,
                drivingRsvpStatus: drivingRsvpStatus,
                isActive: isActive,
                setupCompletedAt: setupCompletedAt,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String creatorUserId,
                required String weddingDate,
                required int totalBudgetCents,
                required int guestCap,
                required String regionCode,
                Value<String?> ceremonyType = const Value.absent(),
                Value<String?> venueType = const Value.absent(),
                Value<int> reminderEnabled = const Value.absent(),
                Value<int> reminderWindowDays = const Value.absent(),
                Value<String> reminderDaysBefore = const Value.absent(),
                Value<int> reminderOverdue = const Value.absent(),
                required String rulesetVersion,
                required String drivingRsvpStatus,
                Value<int> isActive = const Value.absent(),
                Value<String?> setupCompletedAt = const Value.absent(),
                required String createdAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlansCompanion.insert(
                id: id,
                creatorUserId: creatorUserId,
                weddingDate: weddingDate,
                totalBudgetCents: totalBudgetCents,
                guestCap: guestCap,
                regionCode: regionCode,
                ceremonyType: ceremonyType,
                venueType: venueType,
                reminderEnabled: reminderEnabled,
                reminderWindowDays: reminderWindowDays,
                reminderDaysBefore: reminderDaysBefore,
                reminderOverdue: reminderOverdue,
                rulesetVersion: rulesetVersion,
                drivingRsvpStatus: drivingRsvpStatus,
                isActive: isActive,
                setupCompletedAt: setupCompletedAt,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Plans, Plan>(table),
                  $PlansReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                planMemberAliasesRefs = false,
                planMembersRefs = false,
                ledgerEntriesRefs = false,
                changeLogRefs = false,
                syncStateRefs = false,
                outboxRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (planMemberAliasesRefs) db.planMemberAliases,
                    if (planMembersRefs) db.planMembers,
                    if (ledgerEntriesRefs) db.ledgerEntries,
                    if (changeLogRefs) db.changeLog,
                    if (syncStateRefs) db.syncState,
                    if (outboxRefs) db.outbox,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (planMemberAliasesRefs)
                        await $_getPrefetchedData<
                          Plan,
                          Plans,
                          PlanMemberAliase
                        >(
                          currentTable: table,
                          referencedTable: $PlansReferences
                              ._planMemberAliasesRefsTable(db),
                          managerFromTypedResult: (p0) => $PlansReferences(
                            db,
                            table,
                            p0,
                          ).planMemberAliasesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.planId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (planMembersRefs)
                        await $_getPrefetchedData<Plan, Plans, PlanMember>(
                          currentTable: table,
                          referencedTable: $PlansReferences
                              ._planMembersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $PlansReferences(db, table, p0).planMembersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.planId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (ledgerEntriesRefs)
                        await $_getPrefetchedData<Plan, Plans, LedgerEntry>(
                          currentTable: table,
                          referencedTable: $PlansReferences
                              ._ledgerEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $PlansReferences(db, table, p0).ledgerEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.planId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (changeLogRefs)
                        await $_getPrefetchedData<Plan, Plans, ChangeLogData>(
                          currentTable: table,
                          referencedTable: $PlansReferences._changeLogRefsTable(
                            db,
                          ),
                          managerFromTypedResult: (p0) =>
                              $PlansReferences(db, table, p0).changeLogRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.planId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (syncStateRefs)
                        await $_getPrefetchedData<Plan, Plans, SyncStateData>(
                          currentTable: table,
                          referencedTable: $PlansReferences._syncStateRefsTable(
                            db,
                          ),
                          managerFromTypedResult: (p0) =>
                              $PlansReferences(db, table, p0).syncStateRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.planId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (outboxRefs)
                        await $_getPrefetchedData<Plan, Plans, OutboxData>(
                          currentTable: table,
                          referencedTable: $PlansReferences._outboxRefsTable(
                            db,
                          ),
                          managerFromTypedResult: (p0) =>
                              $PlansReferences(db, table, p0).outboxRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.planId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $PlansProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Plans,
      Plan,
      $PlansFilterComposer,
      $PlansOrderingComposer,
      $PlansAnnotationComposer,
      $PlansCreateCompanionBuilder,
      $PlansUpdateCompanionBuilder,
      (Plan, $PlansReferences),
      Plan,
      PrefetchHooks Function({
        bool planMemberAliasesRefs,
        bool planMembersRefs,
        bool ledgerEntriesRefs,
        bool changeLogRefs,
        bool syncStateRefs,
        bool outboxRefs,
      })
    >;
typedef $PlanMemberAliasesCreateCompanionBuilder =
    PlanMemberAliasesCompanion Function({
      required String planMemberId,
      required String planId,
      Value<String?> userId,
      Value<int> rowid,
    });
typedef $PlanMemberAliasesUpdateCompanionBuilder =
    PlanMemberAliasesCompanion Function({
      Value<String> planMemberId,
      Value<String> planId,
      Value<String?> userId,
      Value<int> rowid,
    });

final class $PlanMemberAliasesReferences
    extends BaseReferences<_$AppDatabase, PlanMemberAliases, PlanMemberAliase> {
  $PlanMemberAliasesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Plans _planIdTable(_$AppDatabase db) =>
      db.plans.createAlias('plan_member_aliases__plan_id__plans__id');

  $PlansProcessedTableManager get planId {
    final $_column = $_itemColumn<String>('plan_id')!;

    final manager = $PlansTableManager(
      $_db,
      $_db.plans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $PlanMemberAliasesFilterComposer
    extends Composer<_$AppDatabase, PlanMemberAliases> {
  $PlanMemberAliasesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get planMemberId => $composableBuilder(
    column: $table.planMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  $PlansFilterComposer get planId {
    final $PlansFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansFilterComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $PlanMemberAliasesOrderingComposer
    extends Composer<_$AppDatabase, PlanMemberAliases> {
  $PlanMemberAliasesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get planMemberId => $composableBuilder(
    column: $table.planMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  $PlansOrderingComposer get planId {
    final $PlansOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansOrderingComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $PlanMemberAliasesAnnotationComposer
    extends Composer<_$AppDatabase, PlanMemberAliases> {
  $PlanMemberAliasesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get planMemberId => $composableBuilder(
    column: $table.planMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  $PlansAnnotationComposer get planId {
    final $PlansAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansAnnotationComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $PlanMemberAliasesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          PlanMemberAliases,
          PlanMemberAliase,
          $PlanMemberAliasesFilterComposer,
          $PlanMemberAliasesOrderingComposer,
          $PlanMemberAliasesAnnotationComposer,
          $PlanMemberAliasesCreateCompanionBuilder,
          $PlanMemberAliasesUpdateCompanionBuilder,
          (PlanMemberAliase, $PlanMemberAliasesReferences),
          PlanMemberAliase,
          PrefetchHooks Function({bool planId})
        > {
  $PlanMemberAliasesTableManager(_$AppDatabase db, PlanMemberAliases table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PlanMemberAliasesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PlanMemberAliasesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PlanMemberAliasesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> planMemberId = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<String?> userId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlanMemberAliasesCompanion(
                planMemberId: planMemberId,
                planId: planId,
                userId: userId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String planMemberId,
                required String planId,
                Value<String?> userId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlanMemberAliasesCompanion.insert(
                planMemberId: planMemberId,
                planId: planId,
                userId: userId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PlanMemberAliases, PlanMemberAliase>(table),
                  $PlanMemberAliasesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({planId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (planId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.planId,
                                referencedTable: $PlanMemberAliasesReferences
                                    ._planIdTable(db),
                                referencedColumn: $PlanMemberAliasesReferences
                                    ._planIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $PlanMemberAliasesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      PlanMemberAliases,
      PlanMemberAliase,
      $PlanMemberAliasesFilterComposer,
      $PlanMemberAliasesOrderingComposer,
      $PlanMemberAliasesAnnotationComposer,
      $PlanMemberAliasesCreateCompanionBuilder,
      $PlanMemberAliasesUpdateCompanionBuilder,
      (PlanMemberAliase, $PlanMemberAliasesReferences),
      PlanMemberAliase,
      PrefetchHooks Function({bool planId})
    >;
typedef $PlanMembersCreateCompanionBuilder =
    PlanMembersCompanion Function({
      required String planId,
      required String userId,
      required String planMemberId,
      required String role,
      required String joinedAt,
      Value<int> rowid,
    });
typedef $PlanMembersUpdateCompanionBuilder =
    PlanMembersCompanion Function({
      Value<String> planId,
      Value<String> userId,
      Value<String> planMemberId,
      Value<String> role,
      Value<String> joinedAt,
      Value<int> rowid,
    });

final class $PlanMembersReferences
    extends BaseReferences<_$AppDatabase, PlanMembers, PlanMember> {
  $PlanMembersReferences(super.$_db, super.$_table, super.$_typedResult);

  static Plans _planIdTable(_$AppDatabase db) =>
      db.plans.createAlias('plan_members__plan_id__plans__id');

  $PlansProcessedTableManager get planId {
    final $_column = $_itemColumn<String>('plan_id')!;

    final manager = $PlansTableManager(
      $_db,
      $_db.plans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $PlanMembersFilterComposer extends Composer<_$AppDatabase, PlanMembers> {
  $PlanMembersFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planMemberId => $composableBuilder(
    column: $table.planMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnFilters(column),
  );

  $PlansFilterComposer get planId {
    final $PlansFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansFilterComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $PlanMembersOrderingComposer
    extends Composer<_$AppDatabase, PlanMembers> {
  $PlanMembersOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planMemberId => $composableBuilder(
    column: $table.planMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get joinedAt => $composableBuilder(
    column: $table.joinedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $PlansOrderingComposer get planId {
    final $PlansOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansOrderingComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $PlanMembersAnnotationComposer
    extends Composer<_$AppDatabase, PlanMembers> {
  $PlanMembersAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get planMemberId => $composableBuilder(
    column: $table.planMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);

  $PlansAnnotationComposer get planId {
    final $PlansAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansAnnotationComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $PlanMembersTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          PlanMembers,
          PlanMember,
          $PlanMembersFilterComposer,
          $PlanMembersOrderingComposer,
          $PlanMembersAnnotationComposer,
          $PlanMembersCreateCompanionBuilder,
          $PlanMembersUpdateCompanionBuilder,
          (PlanMember, $PlanMembersReferences),
          PlanMember,
          PrefetchHooks Function({bool planId})
        > {
  $PlanMembersTableManager(_$AppDatabase db, PlanMembers table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $PlanMembersFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $PlanMembersOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $PlanMembersAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> planId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> planMemberId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> joinedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlanMembersCompanion(
                planId: planId,
                userId: userId,
                planMemberId: planMemberId,
                role: role,
                joinedAt: joinedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String planId,
                required String userId,
                required String planMemberId,
                required String role,
                required String joinedAt,
                Value<int> rowid = const Value.absent(),
              }) => PlanMembersCompanion.insert(
                planId: planId,
                userId: userId,
                planMemberId: planMemberId,
                role: role,
                joinedAt: joinedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<PlanMembers, PlanMember>(table),
                  $PlanMembersReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({planId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (planId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.planId,
                                referencedTable: $PlanMembersReferences
                                    ._planIdTable(db),
                                referencedColumn: $PlanMembersReferences
                                    ._planIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $PlanMembersProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      PlanMembers,
      PlanMember,
      $PlanMembersFilterComposer,
      $PlanMembersOrderingComposer,
      $PlanMembersAnnotationComposer,
      $PlanMembersCreateCompanionBuilder,
      $PlanMembersUpdateCompanionBuilder,
      (PlanMember, $PlanMembersReferences),
      PlanMember,
      PrefetchHooks Function({bool planId})
    >;
typedef $LedgerEntriesCreateCompanionBuilder =
    LedgerEntriesCompanion Function({
      required String id,
      required String planId,
      required String categoryCode,
      required String entryType,
      required String supplierName,
      Value<int?> estimatedCents,
      Value<int?> actualCents,
      required String pricingMode,
      Value<int?> perHeadRateCents,
      Value<int> manuallyValued,
      Value<String?> notes,
      Value<String?> templateSuggestionId,
      Value<String?> checklistItemId,
      required String createdAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });
typedef $LedgerEntriesUpdateCompanionBuilder =
    LedgerEntriesCompanion Function({
      Value<String> id,
      Value<String> planId,
      Value<String> categoryCode,
      Value<String> entryType,
      Value<String> supplierName,
      Value<int?> estimatedCents,
      Value<int?> actualCents,
      Value<String> pricingMode,
      Value<int?> perHeadRateCents,
      Value<int> manuallyValued,
      Value<String?> notes,
      Value<String?> templateSuggestionId,
      Value<String?> checklistItemId,
      Value<String> createdAt,
      Value<String?> deletedAt,
      Value<int> rowid,
    });

final class $LedgerEntriesReferences
    extends BaseReferences<_$AppDatabase, LedgerEntries, LedgerEntry> {
  $LedgerEntriesReferences(super.$_db, super.$_table, super.$_typedResult);

  static Plans _planIdTable(_$AppDatabase db) =>
      db.plans.createAlias('ledger_entries__plan_id__plans__id');

  $PlansProcessedTableManager get planId {
    final $_column = $_itemColumn<String>('plan_id')!;

    final manager = $PlansTableManager(
      $_db,
      $_db.plans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $LedgerEntriesFilterComposer
    extends Composer<_$AppDatabase, LedgerEntries> {
  $LedgerEntriesFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryCode => $composableBuilder(
    column: $table.categoryCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryType => $composableBuilder(
    column: $table.entryType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get supplierName => $composableBuilder(
    column: $table.supplierName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedCents => $composableBuilder(
    column: $table.estimatedCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualCents => $composableBuilder(
    column: $table.actualCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pricingMode => $composableBuilder(
    column: $table.pricingMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get perHeadRateCents => $composableBuilder(
    column: $table.perHeadRateCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get manuallyValued => $composableBuilder(
    column: $table.manuallyValued,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get templateSuggestionId => $composableBuilder(
    column: $table.templateSuggestionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get checklistItemId => $composableBuilder(
    column: $table.checklistItemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $PlansFilterComposer get planId {
    final $PlansFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansFilterComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $LedgerEntriesOrderingComposer
    extends Composer<_$AppDatabase, LedgerEntries> {
  $LedgerEntriesOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryCode => $composableBuilder(
    column: $table.categoryCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryType => $composableBuilder(
    column: $table.entryType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get supplierName => $composableBuilder(
    column: $table.supplierName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedCents => $composableBuilder(
    column: $table.estimatedCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualCents => $composableBuilder(
    column: $table.actualCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pricingMode => $composableBuilder(
    column: $table.pricingMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get perHeadRateCents => $composableBuilder(
    column: $table.perHeadRateCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get manuallyValued => $composableBuilder(
    column: $table.manuallyValued,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get templateSuggestionId => $composableBuilder(
    column: $table.templateSuggestionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get checklistItemId => $composableBuilder(
    column: $table.checklistItemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $PlansOrderingComposer get planId {
    final $PlansOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansOrderingComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $LedgerEntriesAnnotationComposer
    extends Composer<_$AppDatabase, LedgerEntries> {
  $LedgerEntriesAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get categoryCode => $composableBuilder(
    column: $table.categoryCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entryType =>
      $composableBuilder(column: $table.entryType, builder: (column) => column);

  GeneratedColumn<String> get supplierName => $composableBuilder(
    column: $table.supplierName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estimatedCents => $composableBuilder(
    column: $table.estimatedCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualCents => $composableBuilder(
    column: $table.actualCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pricingMode => $composableBuilder(
    column: $table.pricingMode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get perHeadRateCents => $composableBuilder(
    column: $table.perHeadRateCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get manuallyValued => $composableBuilder(
    column: $table.manuallyValued,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get templateSuggestionId => $composableBuilder(
    column: $table.templateSuggestionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get checklistItemId => $composableBuilder(
    column: $table.checklistItemId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $PlansAnnotationComposer get planId {
    final $PlansAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansAnnotationComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $LedgerEntriesTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          LedgerEntries,
          LedgerEntry,
          $LedgerEntriesFilterComposer,
          $LedgerEntriesOrderingComposer,
          $LedgerEntriesAnnotationComposer,
          $LedgerEntriesCreateCompanionBuilder,
          $LedgerEntriesUpdateCompanionBuilder,
          (LedgerEntry, $LedgerEntriesReferences),
          LedgerEntry,
          PrefetchHooks Function({bool planId})
        > {
  $LedgerEntriesTableManager(_$AppDatabase db, LedgerEntries table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $LedgerEntriesFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $LedgerEntriesOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $LedgerEntriesAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<String> categoryCode = const Value.absent(),
                Value<String> entryType = const Value.absent(),
                Value<String> supplierName = const Value.absent(),
                Value<int?> estimatedCents = const Value.absent(),
                Value<int?> actualCents = const Value.absent(),
                Value<String> pricingMode = const Value.absent(),
                Value<int?> perHeadRateCents = const Value.absent(),
                Value<int> manuallyValued = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> templateSuggestionId = const Value.absent(),
                Value<String?> checklistItemId = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerEntriesCompanion(
                id: id,
                planId: planId,
                categoryCode: categoryCode,
                entryType: entryType,
                supplierName: supplierName,
                estimatedCents: estimatedCents,
                actualCents: actualCents,
                pricingMode: pricingMode,
                perHeadRateCents: perHeadRateCents,
                manuallyValued: manuallyValued,
                notes: notes,
                templateSuggestionId: templateSuggestionId,
                checklistItemId: checklistItemId,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String planId,
                required String categoryCode,
                required String entryType,
                required String supplierName,
                Value<int?> estimatedCents = const Value.absent(),
                Value<int?> actualCents = const Value.absent(),
                required String pricingMode,
                Value<int?> perHeadRateCents = const Value.absent(),
                Value<int> manuallyValued = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> templateSuggestionId = const Value.absent(),
                Value<String?> checklistItemId = const Value.absent(),
                required String createdAt,
                Value<String?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LedgerEntriesCompanion.insert(
                id: id,
                planId: planId,
                categoryCode: categoryCode,
                entryType: entryType,
                supplierName: supplierName,
                estimatedCents: estimatedCents,
                actualCents: actualCents,
                pricingMode: pricingMode,
                perHeadRateCents: perHeadRateCents,
                manuallyValued: manuallyValued,
                notes: notes,
                templateSuggestionId: templateSuggestionId,
                checklistItemId: checklistItemId,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<LedgerEntries, LedgerEntry>(table),
                  $LedgerEntriesReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({planId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (planId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.planId,
                                referencedTable: $LedgerEntriesReferences
                                    ._planIdTable(db),
                                referencedColumn: $LedgerEntriesReferences
                                    ._planIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $LedgerEntriesProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      LedgerEntries,
      LedgerEntry,
      $LedgerEntriesFilterComposer,
      $LedgerEntriesOrderingComposer,
      $LedgerEntriesAnnotationComposer,
      $LedgerEntriesCreateCompanionBuilder,
      $LedgerEntriesUpdateCompanionBuilder,
      (LedgerEntry, $LedgerEntriesReferences),
      LedgerEntry,
      PrefetchHooks Function({bool planId})
    >;
typedef $ChangeLogCreateCompanionBuilder =
    ChangeLogCompanion Function({
      required String id,
      required String planId,
      required String entityType,
      required String entityId,
      required String fieldName,
      Value<String?> changeGroupId,
      required int schemaVersion,
      Value<String?> oldValue,
      Value<String?> newValue,
      Value<int?> serverTs,
      required int deviceMonotonic,
      required String deviceId,
      required String planMemberId,
      required String createdAt,
      Value<int> rowid,
    });
typedef $ChangeLogUpdateCompanionBuilder =
    ChangeLogCompanion Function({
      Value<String> id,
      Value<String> planId,
      Value<String> entityType,
      Value<String> entityId,
      Value<String> fieldName,
      Value<String?> changeGroupId,
      Value<int> schemaVersion,
      Value<String?> oldValue,
      Value<String?> newValue,
      Value<int?> serverTs,
      Value<int> deviceMonotonic,
      Value<String> deviceId,
      Value<String> planMemberId,
      Value<String> createdAt,
      Value<int> rowid,
    });

final class $ChangeLogReferences
    extends BaseReferences<_$AppDatabase, ChangeLog, ChangeLogData> {
  $ChangeLogReferences(super.$_db, super.$_table, super.$_typedResult);

  static Plans _planIdTable(_$AppDatabase db) =>
      db.plans.createAlias('change_log__plan_id__plans__id');

  $PlansProcessedTableManager get planId {
    final $_column = $_itemColumn<String>('plan_id')!;

    final manager = $PlansTableManager(
      $_db,
      $_db.plans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $ChangeLogFilterComposer extends Composer<_$AppDatabase, ChangeLog> {
  $ChangeLogFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fieldName => $composableBuilder(
    column: $table.fieldName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get changeGroupId => $composableBuilder(
    column: $table.changeGroupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get oldValue => $composableBuilder(
    column: $table.oldValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get newValue => $composableBuilder(
    column: $table.newValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverTs => $composableBuilder(
    column: $table.serverTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deviceMonotonic => $composableBuilder(
    column: $table.deviceMonotonic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planMemberId => $composableBuilder(
    column: $table.planMemberId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $PlansFilterComposer get planId {
    final $PlansFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansFilterComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ChangeLogOrderingComposer extends Composer<_$AppDatabase, ChangeLog> {
  $ChangeLogOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fieldName => $composableBuilder(
    column: $table.fieldName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get changeGroupId => $composableBuilder(
    column: $table.changeGroupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get oldValue => $composableBuilder(
    column: $table.oldValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get newValue => $composableBuilder(
    column: $table.newValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverTs => $composableBuilder(
    column: $table.serverTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deviceMonotonic => $composableBuilder(
    column: $table.deviceMonotonic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planMemberId => $composableBuilder(
    column: $table.planMemberId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $PlansOrderingComposer get planId {
    final $PlansOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansOrderingComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ChangeLogAnnotationComposer extends Composer<_$AppDatabase, ChangeLog> {
  $ChangeLogAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get fieldName =>
      $composableBuilder(column: $table.fieldName, builder: (column) => column);

  GeneratedColumn<String> get changeGroupId => $composableBuilder(
    column: $table.changeGroupId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get schemaVersion => $composableBuilder(
    column: $table.schemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get oldValue =>
      $composableBuilder(column: $table.oldValue, builder: (column) => column);

  GeneratedColumn<String> get newValue =>
      $composableBuilder(column: $table.newValue, builder: (column) => column);

  GeneratedColumn<int> get serverTs =>
      $composableBuilder(column: $table.serverTs, builder: (column) => column);

  GeneratedColumn<int> get deviceMonotonic => $composableBuilder(
    column: $table.deviceMonotonic,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get planMemberId => $composableBuilder(
    column: $table.planMemberId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $PlansAnnotationComposer get planId {
    final $PlansAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansAnnotationComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $ChangeLogTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          ChangeLog,
          ChangeLogData,
          $ChangeLogFilterComposer,
          $ChangeLogOrderingComposer,
          $ChangeLogAnnotationComposer,
          $ChangeLogCreateCompanionBuilder,
          $ChangeLogUpdateCompanionBuilder,
          (ChangeLogData, $ChangeLogReferences),
          ChangeLogData,
          PrefetchHooks Function({bool planId})
        > {
  $ChangeLogTableManager(_$AppDatabase db, ChangeLog table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $ChangeLogFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $ChangeLogOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $ChangeLogAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String> fieldName = const Value.absent(),
                Value<String?> changeGroupId = const Value.absent(),
                Value<int> schemaVersion = const Value.absent(),
                Value<String?> oldValue = const Value.absent(),
                Value<String?> newValue = const Value.absent(),
                Value<int?> serverTs = const Value.absent(),
                Value<int> deviceMonotonic = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> planMemberId = const Value.absent(),
                Value<String> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChangeLogCompanion(
                id: id,
                planId: planId,
                entityType: entityType,
                entityId: entityId,
                fieldName: fieldName,
                changeGroupId: changeGroupId,
                schemaVersion: schemaVersion,
                oldValue: oldValue,
                newValue: newValue,
                serverTs: serverTs,
                deviceMonotonic: deviceMonotonic,
                deviceId: deviceId,
                planMemberId: planMemberId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String planId,
                required String entityType,
                required String entityId,
                required String fieldName,
                Value<String?> changeGroupId = const Value.absent(),
                required int schemaVersion,
                Value<String?> oldValue = const Value.absent(),
                Value<String?> newValue = const Value.absent(),
                Value<int?> serverTs = const Value.absent(),
                required int deviceMonotonic,
                required String deviceId,
                required String planMemberId,
                required String createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ChangeLogCompanion.insert(
                id: id,
                planId: planId,
                entityType: entityType,
                entityId: entityId,
                fieldName: fieldName,
                changeGroupId: changeGroupId,
                schemaVersion: schemaVersion,
                oldValue: oldValue,
                newValue: newValue,
                serverTs: serverTs,
                deviceMonotonic: deviceMonotonic,
                deviceId: deviceId,
                planMemberId: planMemberId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<ChangeLog, ChangeLogData>(table),
                  $ChangeLogReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({planId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (planId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.planId,
                                referencedTable: $ChangeLogReferences
                                    ._planIdTable(db),
                                referencedColumn: $ChangeLogReferences
                                    ._planIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $ChangeLogProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      ChangeLog,
      ChangeLogData,
      $ChangeLogFilterComposer,
      $ChangeLogOrderingComposer,
      $ChangeLogAnnotationComposer,
      $ChangeLogCreateCompanionBuilder,
      $ChangeLogUpdateCompanionBuilder,
      (ChangeLogData, $ChangeLogReferences),
      ChangeLogData,
      PrefetchHooks Function({bool planId})
    >;
typedef $SyncStateCreateCompanionBuilder =
    SyncStateCompanion Function({
      required String deviceId,
      required String planId,
      Value<int?> lastPushedServerTs,
      Value<int?> lastPulledServerTs,
      Value<int> deviceMonotonic,
      Value<int> rowid,
    });
typedef $SyncStateUpdateCompanionBuilder =
    SyncStateCompanion Function({
      Value<String> deviceId,
      Value<String> planId,
      Value<int?> lastPushedServerTs,
      Value<int?> lastPulledServerTs,
      Value<int> deviceMonotonic,
      Value<int> rowid,
    });

final class $SyncStateReferences
    extends BaseReferences<_$AppDatabase, SyncState, SyncStateData> {
  $SyncStateReferences(super.$_db, super.$_table, super.$_typedResult);

  static Plans _planIdTable(_$AppDatabase db) =>
      db.plans.createAlias('sync_state__plan_id__plans__id');

  $PlansProcessedTableManager get planId {
    final $_column = $_itemColumn<String>('plan_id')!;

    final manager = $PlansTableManager(
      $_db,
      $_db.plans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $SyncStateFilterComposer extends Composer<_$AppDatabase, SyncState> {
  $SyncStateFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPushedServerTs => $composableBuilder(
    column: $table.lastPushedServerTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastPulledServerTs => $composableBuilder(
    column: $table.lastPulledServerTs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deviceMonotonic => $composableBuilder(
    column: $table.deviceMonotonic,
    builder: (column) => ColumnFilters(column),
  );

  $PlansFilterComposer get planId {
    final $PlansFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansFilterComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SyncStateOrderingComposer extends Composer<_$AppDatabase, SyncState> {
  $SyncStateOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPushedServerTs => $composableBuilder(
    column: $table.lastPushedServerTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastPulledServerTs => $composableBuilder(
    column: $table.lastPulledServerTs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deviceMonotonic => $composableBuilder(
    column: $table.deviceMonotonic,
    builder: (column) => ColumnOrderings(column),
  );

  $PlansOrderingComposer get planId {
    final $PlansOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansOrderingComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SyncStateAnnotationComposer extends Composer<_$AppDatabase, SyncState> {
  $SyncStateAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<int> get lastPushedServerTs => $composableBuilder(
    column: $table.lastPushedServerTs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastPulledServerTs => $composableBuilder(
    column: $table.lastPulledServerTs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deviceMonotonic => $composableBuilder(
    column: $table.deviceMonotonic,
    builder: (column) => column,
  );

  $PlansAnnotationComposer get planId {
    final $PlansAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansAnnotationComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $SyncStateTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          SyncState,
          SyncStateData,
          $SyncStateFilterComposer,
          $SyncStateOrderingComposer,
          $SyncStateAnnotationComposer,
          $SyncStateCreateCompanionBuilder,
          $SyncStateUpdateCompanionBuilder,
          (SyncStateData, $SyncStateReferences),
          SyncStateData,
          PrefetchHooks Function({bool planId})
        > {
  $SyncStateTableManager(_$AppDatabase db, SyncState table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $SyncStateFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $SyncStateOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $SyncStateAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<int?> lastPushedServerTs = const Value.absent(),
                Value<int?> lastPulledServerTs = const Value.absent(),
                Value<int> deviceMonotonic = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion(
                deviceId: deviceId,
                planId: planId,
                lastPushedServerTs: lastPushedServerTs,
                lastPulledServerTs: lastPulledServerTs,
                deviceMonotonic: deviceMonotonic,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required String planId,
                Value<int?> lastPushedServerTs = const Value.absent(),
                Value<int?> lastPulledServerTs = const Value.absent(),
                Value<int> deviceMonotonic = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateCompanion.insert(
                deviceId: deviceId,
                planId: planId,
                lastPushedServerTs: lastPushedServerTs,
                lastPulledServerTs: lastPulledServerTs,
                deviceMonotonic: deviceMonotonic,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<SyncState, SyncStateData>(table),
                  $SyncStateReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({planId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (planId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.planId,
                                referencedTable: $SyncStateReferences
                                    ._planIdTable(db),
                                referencedColumn: $SyncStateReferences
                                    ._planIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $SyncStateProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      SyncState,
      SyncStateData,
      $SyncStateFilterComposer,
      $SyncStateOrderingComposer,
      $SyncStateAnnotationComposer,
      $SyncStateCreateCompanionBuilder,
      $SyncStateUpdateCompanionBuilder,
      (SyncStateData, $SyncStateReferences),
      SyncStateData,
      PrefetchHooks Function({bool planId})
    >;
typedef $OutboxCreateCompanionBuilder =
    OutboxCompanion Function({
      required String eventId,
      required String planId,
      required String deviceId,
      required String queuedAt,
      Value<int> rowid,
    });
typedef $OutboxUpdateCompanionBuilder =
    OutboxCompanion Function({
      Value<String> eventId,
      Value<String> planId,
      Value<String> deviceId,
      Value<String> queuedAt,
      Value<int> rowid,
    });

final class $OutboxReferences
    extends BaseReferences<_$AppDatabase, Outbox, OutboxData> {
  $OutboxReferences(super.$_db, super.$_table, super.$_typedResult);

  static Plans _planIdTable(_$AppDatabase db) =>
      db.plans.createAlias('outbox__plan_id__plans__id');

  $PlansProcessedTableManager get planId {
    final $_column = $_itemColumn<String>('plan_id')!;

    final manager = $PlansTableManager(
      $_db,
      $_db.plans,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_planIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $OutboxFilterComposer extends Composer<_$AppDatabase, Outbox> {
  $OutboxFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnFilters(column),
  );

  $PlansFilterComposer get planId {
    final $PlansFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansFilterComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $OutboxOrderingComposer extends Composer<_$AppDatabase, Outbox> {
  $OutboxOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get queuedAt => $composableBuilder(
    column: $table.queuedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $PlansOrderingComposer get planId {
    final $PlansOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansOrderingComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $OutboxAnnotationComposer extends Composer<_$AppDatabase, Outbox> {
  $OutboxAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);

  $PlansAnnotationComposer get planId {
    final $PlansAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.planId,
      referencedTable: $db.plans,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $PlansAnnotationComposer(
            $db: $db,
            $table: $db.plans,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $OutboxTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          Outbox,
          OutboxData,
          $OutboxFilterComposer,
          $OutboxOrderingComposer,
          $OutboxAnnotationComposer,
          $OutboxCreateCompanionBuilder,
          $OutboxUpdateCompanionBuilder,
          (OutboxData, $OutboxReferences),
          OutboxData,
          PrefetchHooks Function({bool planId})
        > {
  $OutboxTableManager(_$AppDatabase db, Outbox table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $OutboxFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $OutboxOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $OutboxAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> eventId = const Value.absent(),
                Value<String> planId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> queuedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion(
                eventId: eventId,
                planId: planId,
                deviceId: deviceId,
                queuedAt: queuedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String eventId,
                required String planId,
                required String deviceId,
                required String queuedAt,
                Value<int> rowid = const Value.absent(),
              }) => OutboxCompanion.insert(
                eventId: eventId,
                planId: planId,
                deviceId: deviceId,
                queuedAt: queuedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<Outbox, OutboxData>(table),
                  $OutboxReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({planId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (planId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.planId,
                                referencedTable: $OutboxReferences._planIdTable(
                                  db,
                                ),
                                referencedColumn: $OutboxReferences
                                    ._planIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $OutboxProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      Outbox,
      OutboxData,
      $OutboxFilterComposer,
      $OutboxOrderingComposer,
      $OutboxAnnotationComposer,
      $OutboxCreateCompanionBuilder,
      $OutboxUpdateCompanionBuilder,
      (OutboxData, $OutboxReferences),
      OutboxData,
      PrefetchHooks Function({bool planId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $PlansTableManager get plans => $PlansTableManager(_db, _db.plans);
  $PlanMemberAliasesTableManager get planMemberAliases =>
      $PlanMemberAliasesTableManager(_db, _db.planMemberAliases);
  $PlanMembersTableManager get planMembers =>
      $PlanMembersTableManager(_db, _db.planMembers);
  $LedgerEntriesTableManager get ledgerEntries =>
      $LedgerEntriesTableManager(_db, _db.ledgerEntries);
  $ChangeLogTableManager get changeLog =>
      $ChangeLogTableManager(_db, _db.changeLog);
  $SyncStateTableManager get syncState =>
      $SyncStateTableManager(_db, _db.syncState);
  $OutboxTableManager get outbox => $OutboxTableManager(_db, _db.outbox);
}
