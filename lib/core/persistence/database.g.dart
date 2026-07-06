// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SettingsTable extends Settings with TableInfo<$SettingsTable, Setting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Setting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Setting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Setting(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class Setting extends DataClass implements Insertable<Setting> {
  final int id;
  final String key;
  final String value;
  const Setting({required this.id, required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      id: Value(id),
      key: Value(key),
      value: Value(value),
    );
  }

  factory Setting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Setting(
      id: serializer.fromJson<int>(json['id']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  Setting copyWith({int? id, String? key, String? value}) => Setting(
    id: id ?? this.id,
    key: key ?? this.key,
    value: value ?? this.value,
  );
  Setting copyWithCompanion(SettingsCompanion data) {
    return Setting(
      id: data.id.present ? data.id.value : this.id,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Setting(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Setting &&
          other.id == this.id &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<Setting> {
  final Value<int> id;
  final Value<String> key;
  final Value<String> value;
  const SettingsCompanion({
    this.id = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
  });
  SettingsCompanion.insert({
    this.id = const Value.absent(),
    required String key,
    required String value,
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Setting> custom({
    Expression<int>? id,
    Expression<String>? key,
    Expression<String>? value,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
    });
  }

  SettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? key,
    Value<String>? value,
  }) {
    return SettingsCompanion(
      id: id ?? this.id,
      key: key ?? this.key,
      value: value ?? this.value,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }
}

class $SharesTable extends Shares with TableInfo<$SharesTable, Share> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SharesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _scanStatusMeta = const VerificationMeta(
    'scanStatus',
  );
  @override
  late final GeneratedColumn<String> scanStatus = GeneratedColumn<String>(
    'scan_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('idle'),
  );
  static const VerificationMeta _storageTypeMeta = const VerificationMeta(
    'storageType',
  );
  @override
  late final GeneratedColumn<String> storageType = GeneratedColumn<String>(
    'storage_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('filesystem'),
  );
  static const VerificationMeta _totalFilesMeta = const VerificationMeta(
    'totalFiles',
  );
  @override
  late final GeneratedColumn<int> totalFiles = GeneratedColumn<int>(
    'total_files',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hashedFilesMeta = const VerificationMeta(
    'hashedFiles',
  );
  @override
  late final GeneratedColumn<int> hashedFiles = GeneratedColumn<int>(
    'hashed_files',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalHashBytesMeta = const VerificationMeta(
    'totalHashBytes',
  );
  @override
  late final GeneratedColumn<int> totalHashBytes = GeneratedColumn<int>(
    'total_hash_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hashedBytesMeta = const VerificationMeta(
    'hashedBytes',
  );
  @override
  late final GeneratedColumn<int> hashedBytes = GeneratedColumn<int>(
    'hashed_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _currentFileMeta = const VerificationMeta(
    'currentFile',
  );
  @override
  late final GeneratedColumn<String> currentFile = GeneratedColumn<String>(
    'current_file',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    displayName,
    localPath,
    enabled,
    scanStatus,
    storageType,
    totalFiles,
    hashedFiles,
    totalHashBytes,
    hashedBytes,
    currentFile,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'shares';
  @override
  VerificationContext validateIntegrity(
    Insertable<Share> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    if (data.containsKey('scan_status')) {
      context.handle(
        _scanStatusMeta,
        scanStatus.isAcceptableOrUnknown(data['scan_status']!, _scanStatusMeta),
      );
    }
    if (data.containsKey('storage_type')) {
      context.handle(
        _storageTypeMeta,
        storageType.isAcceptableOrUnknown(
          data['storage_type']!,
          _storageTypeMeta,
        ),
      );
    }
    if (data.containsKey('total_files')) {
      context.handle(
        _totalFilesMeta,
        totalFiles.isAcceptableOrUnknown(data['total_files']!, _totalFilesMeta),
      );
    }
    if (data.containsKey('hashed_files')) {
      context.handle(
        _hashedFilesMeta,
        hashedFiles.isAcceptableOrUnknown(
          data['hashed_files']!,
          _hashedFilesMeta,
        ),
      );
    }
    if (data.containsKey('total_hash_bytes')) {
      context.handle(
        _totalHashBytesMeta,
        totalHashBytes.isAcceptableOrUnknown(
          data['total_hash_bytes']!,
          _totalHashBytesMeta,
        ),
      );
    }
    if (data.containsKey('hashed_bytes')) {
      context.handle(
        _hashedBytesMeta,
        hashedBytes.isAcceptableOrUnknown(
          data['hashed_bytes']!,
          _hashedBytesMeta,
        ),
      );
    }
    if (data.containsKey('current_file')) {
      context.handle(
        _currentFileMeta,
        currentFile.isAcceptableOrUnknown(
          data['current_file']!,
          _currentFileMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Share map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Share(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      scanStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_status'],
      )!,
      storageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}storage_type'],
      )!,
      totalFiles: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_files'],
      )!,
      hashedFiles: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hashed_files'],
      )!,
      totalHashBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_hash_bytes'],
      )!,
      hashedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hashed_bytes'],
      )!,
      currentFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_file'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SharesTable createAlias(String alias) {
    return $SharesTable(attachedDatabase, alias);
  }
}

class Share extends DataClass implements Insertable<Share> {
  final String id;
  final String displayName;
  final String localPath;
  final bool enabled;
  final String scanStatus;
  final String storageType;
  final int totalFiles;
  final int hashedFiles;
  final int totalHashBytes;
  final int hashedBytes;
  final String? currentFile;
  final DateTime updatedAt;
  const Share({
    required this.id,
    required this.displayName,
    required this.localPath,
    required this.enabled,
    required this.scanStatus,
    required this.storageType,
    required this.totalFiles,
    required this.hashedFiles,
    required this.totalHashBytes,
    required this.hashedBytes,
    this.currentFile,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['display_name'] = Variable<String>(displayName);
    map['local_path'] = Variable<String>(localPath);
    map['enabled'] = Variable<bool>(enabled);
    map['scan_status'] = Variable<String>(scanStatus);
    map['storage_type'] = Variable<String>(storageType);
    map['total_files'] = Variable<int>(totalFiles);
    map['hashed_files'] = Variable<int>(hashedFiles);
    map['total_hash_bytes'] = Variable<int>(totalHashBytes);
    map['hashed_bytes'] = Variable<int>(hashedBytes);
    if (!nullToAbsent || currentFile != null) {
      map['current_file'] = Variable<String>(currentFile);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SharesCompanion toCompanion(bool nullToAbsent) {
    return SharesCompanion(
      id: Value(id),
      displayName: Value(displayName),
      localPath: Value(localPath),
      enabled: Value(enabled),
      scanStatus: Value(scanStatus),
      storageType: Value(storageType),
      totalFiles: Value(totalFiles),
      hashedFiles: Value(hashedFiles),
      totalHashBytes: Value(totalHashBytes),
      hashedBytes: Value(hashedBytes),
      currentFile: currentFile == null && nullToAbsent
          ? const Value.absent()
          : Value(currentFile),
      updatedAt: Value(updatedAt),
    );
  }

  factory Share.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Share(
      id: serializer.fromJson<String>(json['id']),
      displayName: serializer.fromJson<String>(json['displayName']),
      localPath: serializer.fromJson<String>(json['localPath']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      scanStatus: serializer.fromJson<String>(json['scanStatus']),
      storageType: serializer.fromJson<String>(json['storageType']),
      totalFiles: serializer.fromJson<int>(json['totalFiles']),
      hashedFiles: serializer.fromJson<int>(json['hashedFiles']),
      totalHashBytes: serializer.fromJson<int>(json['totalHashBytes']),
      hashedBytes: serializer.fromJson<int>(json['hashedBytes']),
      currentFile: serializer.fromJson<String?>(json['currentFile']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'displayName': serializer.toJson<String>(displayName),
      'localPath': serializer.toJson<String>(localPath),
      'enabled': serializer.toJson<bool>(enabled),
      'scanStatus': serializer.toJson<String>(scanStatus),
      'storageType': serializer.toJson<String>(storageType),
      'totalFiles': serializer.toJson<int>(totalFiles),
      'hashedFiles': serializer.toJson<int>(hashedFiles),
      'totalHashBytes': serializer.toJson<int>(totalHashBytes),
      'hashedBytes': serializer.toJson<int>(hashedBytes),
      'currentFile': serializer.toJson<String?>(currentFile),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Share copyWith({
    String? id,
    String? displayName,
    String? localPath,
    bool? enabled,
    String? scanStatus,
    String? storageType,
    int? totalFiles,
    int? hashedFiles,
    int? totalHashBytes,
    int? hashedBytes,
    Value<String?> currentFile = const Value.absent(),
    DateTime? updatedAt,
  }) => Share(
    id: id ?? this.id,
    displayName: displayName ?? this.displayName,
    localPath: localPath ?? this.localPath,
    enabled: enabled ?? this.enabled,
    scanStatus: scanStatus ?? this.scanStatus,
    storageType: storageType ?? this.storageType,
    totalFiles: totalFiles ?? this.totalFiles,
    hashedFiles: hashedFiles ?? this.hashedFiles,
    totalHashBytes: totalHashBytes ?? this.totalHashBytes,
    hashedBytes: hashedBytes ?? this.hashedBytes,
    currentFile: currentFile.present ? currentFile.value : this.currentFile,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Share copyWithCompanion(SharesCompanion data) {
    return Share(
      id: data.id.present ? data.id.value : this.id,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      scanStatus: data.scanStatus.present
          ? data.scanStatus.value
          : this.scanStatus,
      storageType: data.storageType.present
          ? data.storageType.value
          : this.storageType,
      totalFiles: data.totalFiles.present
          ? data.totalFiles.value
          : this.totalFiles,
      hashedFiles: data.hashedFiles.present
          ? data.hashedFiles.value
          : this.hashedFiles,
      totalHashBytes: data.totalHashBytes.present
          ? data.totalHashBytes.value
          : this.totalHashBytes,
      hashedBytes: data.hashedBytes.present
          ? data.hashedBytes.value
          : this.hashedBytes,
      currentFile: data.currentFile.present
          ? data.currentFile.value
          : this.currentFile,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Share(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('localPath: $localPath, ')
          ..write('enabled: $enabled, ')
          ..write('scanStatus: $scanStatus, ')
          ..write('storageType: $storageType, ')
          ..write('totalFiles: $totalFiles, ')
          ..write('hashedFiles: $hashedFiles, ')
          ..write('totalHashBytes: $totalHashBytes, ')
          ..write('hashedBytes: $hashedBytes, ')
          ..write('currentFile: $currentFile, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    localPath,
    enabled,
    scanStatus,
    storageType,
    totalFiles,
    hashedFiles,
    totalHashBytes,
    hashedBytes,
    currentFile,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Share &&
          other.id == this.id &&
          other.displayName == this.displayName &&
          other.localPath == this.localPath &&
          other.enabled == this.enabled &&
          other.scanStatus == this.scanStatus &&
          other.storageType == this.storageType &&
          other.totalFiles == this.totalFiles &&
          other.hashedFiles == this.hashedFiles &&
          other.totalHashBytes == this.totalHashBytes &&
          other.hashedBytes == this.hashedBytes &&
          other.currentFile == this.currentFile &&
          other.updatedAt == this.updatedAt);
}

class SharesCompanion extends UpdateCompanion<Share> {
  final Value<String> id;
  final Value<String> displayName;
  final Value<String> localPath;
  final Value<bool> enabled;
  final Value<String> scanStatus;
  final Value<String> storageType;
  final Value<int> totalFiles;
  final Value<int> hashedFiles;
  final Value<int> totalHashBytes;
  final Value<int> hashedBytes;
  final Value<String?> currentFile;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SharesCompanion({
    this.id = const Value.absent(),
    this.displayName = const Value.absent(),
    this.localPath = const Value.absent(),
    this.enabled = const Value.absent(),
    this.scanStatus = const Value.absent(),
    this.storageType = const Value.absent(),
    this.totalFiles = const Value.absent(),
    this.hashedFiles = const Value.absent(),
    this.totalHashBytes = const Value.absent(),
    this.hashedBytes = const Value.absent(),
    this.currentFile = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SharesCompanion.insert({
    required String id,
    required String displayName,
    required String localPath,
    this.enabled = const Value.absent(),
    this.scanStatus = const Value.absent(),
    this.storageType = const Value.absent(),
    this.totalFiles = const Value.absent(),
    this.hashedFiles = const Value.absent(),
    this.totalHashBytes = const Value.absent(),
    this.hashedBytes = const Value.absent(),
    this.currentFile = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       displayName = Value(displayName),
       localPath = Value(localPath);
  static Insertable<Share> custom({
    Expression<String>? id,
    Expression<String>? displayName,
    Expression<String>? localPath,
    Expression<bool>? enabled,
    Expression<String>? scanStatus,
    Expression<String>? storageType,
    Expression<int>? totalFiles,
    Expression<int>? hashedFiles,
    Expression<int>? totalHashBytes,
    Expression<int>? hashedBytes,
    Expression<String>? currentFile,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (displayName != null) 'display_name': displayName,
      if (localPath != null) 'local_path': localPath,
      if (enabled != null) 'enabled': enabled,
      if (scanStatus != null) 'scan_status': scanStatus,
      if (storageType != null) 'storage_type': storageType,
      if (totalFiles != null) 'total_files': totalFiles,
      if (hashedFiles != null) 'hashed_files': hashedFiles,
      if (totalHashBytes != null) 'total_hash_bytes': totalHashBytes,
      if (hashedBytes != null) 'hashed_bytes': hashedBytes,
      if (currentFile != null) 'current_file': currentFile,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SharesCompanion copyWith({
    Value<String>? id,
    Value<String>? displayName,
    Value<String>? localPath,
    Value<bool>? enabled,
    Value<String>? scanStatus,
    Value<String>? storageType,
    Value<int>? totalFiles,
    Value<int>? hashedFiles,
    Value<int>? totalHashBytes,
    Value<int>? hashedBytes,
    Value<String?>? currentFile,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SharesCompanion(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      localPath: localPath ?? this.localPath,
      enabled: enabled ?? this.enabled,
      scanStatus: scanStatus ?? this.scanStatus,
      storageType: storageType ?? this.storageType,
      totalFiles: totalFiles ?? this.totalFiles,
      hashedFiles: hashedFiles ?? this.hashedFiles,
      totalHashBytes: totalHashBytes ?? this.totalHashBytes,
      hashedBytes: hashedBytes ?? this.hashedBytes,
      currentFile: currentFile ?? this.currentFile,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (scanStatus.present) {
      map['scan_status'] = Variable<String>(scanStatus.value);
    }
    if (storageType.present) {
      map['storage_type'] = Variable<String>(storageType.value);
    }
    if (totalFiles.present) {
      map['total_files'] = Variable<int>(totalFiles.value);
    }
    if (hashedFiles.present) {
      map['hashed_files'] = Variable<int>(hashedFiles.value);
    }
    if (totalHashBytes.present) {
      map['total_hash_bytes'] = Variable<int>(totalHashBytes.value);
    }
    if (hashedBytes.present) {
      map['hashed_bytes'] = Variable<int>(hashedBytes.value);
    }
    if (currentFile.present) {
      map['current_file'] = Variable<String>(currentFile.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SharesCompanion(')
          ..write('id: $id, ')
          ..write('displayName: $displayName, ')
          ..write('localPath: $localPath, ')
          ..write('enabled: $enabled, ')
          ..write('scanStatus: $scanStatus, ')
          ..write('storageType: $storageType, ')
          ..write('totalFiles: $totalFiles, ')
          ..write('hashedFiles: $hashedFiles, ')
          ..write('totalHashBytes: $totalHashBytes, ')
          ..write('hashedBytes: $hashedBytes, ')
          ..write('currentFile: $currentFile, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntriesTable extends Entries with TableInfo<$EntriesTable, Entry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _shareIdMeta = const VerificationMeta(
    'shareId',
  );
  @override
  late final GeneratedColumn<String> shareId = GeneratedColumn<String>(
    'share_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES shares (id)',
    ),
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDirectoryMeta = const VerificationMeta(
    'isDirectory',
  );
  @override
  late final GeneratedColumn<bool> isDirectory = GeneratedColumn<bool>(
    'is_directory',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_directory" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mtimeMsMeta = const VerificationMeta(
    'mtimeMs',
  );
  @override
  late final GeneratedColumn<int> mtimeMs = GeneratedColumn<int>(
    'mtime_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hashStatusMeta = const VerificationMeta(
    'hashStatus',
  );
  @override
  late final GeneratedColumn<String> hashStatus = GeneratedColumn<String>(
    'hash_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _chunkSizeMeta = const VerificationMeta(
    'chunkSize',
  );
  @override
  late final GeneratedColumn<int> chunkSize = GeneratedColumn<int>(
    'chunk_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _localUriMeta = const VerificationMeta(
    'localUri',
  );
  @override
  late final GeneratedColumn<String> localUri = GeneratedColumn<String>(
    'local_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    shareId,
    relativePath,
    name,
    isDirectory,
    size,
    mtimeMs,
    hashStatus,
    chunkSize,
    localUri,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<Entry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('share_id')) {
      context.handle(
        _shareIdMeta,
        shareId.isAcceptableOrUnknown(data['share_id']!, _shareIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shareIdMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_directory')) {
      context.handle(
        _isDirectoryMeta,
        isDirectory.isAcceptableOrUnknown(
          data['is_directory']!,
          _isDirectoryMeta,
        ),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('mtime_ms')) {
      context.handle(
        _mtimeMsMeta,
        mtimeMs.isAcceptableOrUnknown(data['mtime_ms']!, _mtimeMsMeta),
      );
    }
    if (data.containsKey('hash_status')) {
      context.handle(
        _hashStatusMeta,
        hashStatus.isAcceptableOrUnknown(data['hash_status']!, _hashStatusMeta),
      );
    }
    if (data.containsKey('chunk_size')) {
      context.handle(
        _chunkSizeMeta,
        chunkSize.isAcceptableOrUnknown(data['chunk_size']!, _chunkSizeMeta),
      );
    }
    if (data.containsKey('local_uri')) {
      context.handle(
        _localUriMeta,
        localUri.isAcceptableOrUnknown(data['local_uri']!, _localUriMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Entry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      shareId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}share_id'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isDirectory: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_directory'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      mtimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime_ms'],
      )!,
      hashStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash_status'],
      )!,
      chunkSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk_size'],
      ),
      localUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_uri'],
      ),
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }
}

class Entry extends DataClass implements Insertable<Entry> {
  final String id;
  final String shareId;
  final String relativePath;
  final String name;
  final bool isDirectory;
  final int size;
  final int mtimeMs;
  final String hashStatus;
  final int? chunkSize;
  final String? localUri;
  const Entry({
    required this.id,
    required this.shareId,
    required this.relativePath,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.mtimeMs,
    required this.hashStatus,
    this.chunkSize,
    this.localUri,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['share_id'] = Variable<String>(shareId);
    map['relative_path'] = Variable<String>(relativePath);
    map['name'] = Variable<String>(name);
    map['is_directory'] = Variable<bool>(isDirectory);
    map['size'] = Variable<int>(size);
    map['mtime_ms'] = Variable<int>(mtimeMs);
    map['hash_status'] = Variable<String>(hashStatus);
    if (!nullToAbsent || chunkSize != null) {
      map['chunk_size'] = Variable<int>(chunkSize);
    }
    if (!nullToAbsent || localUri != null) {
      map['local_uri'] = Variable<String>(localUri);
    }
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      shareId: Value(shareId),
      relativePath: Value(relativePath),
      name: Value(name),
      isDirectory: Value(isDirectory),
      size: Value(size),
      mtimeMs: Value(mtimeMs),
      hashStatus: Value(hashStatus),
      chunkSize: chunkSize == null && nullToAbsent
          ? const Value.absent()
          : Value(chunkSize),
      localUri: localUri == null && nullToAbsent
          ? const Value.absent()
          : Value(localUri),
    );
  }

  factory Entry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entry(
      id: serializer.fromJson<String>(json['id']),
      shareId: serializer.fromJson<String>(json['shareId']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      name: serializer.fromJson<String>(json['name']),
      isDirectory: serializer.fromJson<bool>(json['isDirectory']),
      size: serializer.fromJson<int>(json['size']),
      mtimeMs: serializer.fromJson<int>(json['mtimeMs']),
      hashStatus: serializer.fromJson<String>(json['hashStatus']),
      chunkSize: serializer.fromJson<int?>(json['chunkSize']),
      localUri: serializer.fromJson<String?>(json['localUri']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'shareId': serializer.toJson<String>(shareId),
      'relativePath': serializer.toJson<String>(relativePath),
      'name': serializer.toJson<String>(name),
      'isDirectory': serializer.toJson<bool>(isDirectory),
      'size': serializer.toJson<int>(size),
      'mtimeMs': serializer.toJson<int>(mtimeMs),
      'hashStatus': serializer.toJson<String>(hashStatus),
      'chunkSize': serializer.toJson<int?>(chunkSize),
      'localUri': serializer.toJson<String?>(localUri),
    };
  }

  Entry copyWith({
    String? id,
    String? shareId,
    String? relativePath,
    String? name,
    bool? isDirectory,
    int? size,
    int? mtimeMs,
    String? hashStatus,
    Value<int?> chunkSize = const Value.absent(),
    Value<String?> localUri = const Value.absent(),
  }) => Entry(
    id: id ?? this.id,
    shareId: shareId ?? this.shareId,
    relativePath: relativePath ?? this.relativePath,
    name: name ?? this.name,
    isDirectory: isDirectory ?? this.isDirectory,
    size: size ?? this.size,
    mtimeMs: mtimeMs ?? this.mtimeMs,
    hashStatus: hashStatus ?? this.hashStatus,
    chunkSize: chunkSize.present ? chunkSize.value : this.chunkSize,
    localUri: localUri.present ? localUri.value : this.localUri,
  );
  Entry copyWithCompanion(EntriesCompanion data) {
    return Entry(
      id: data.id.present ? data.id.value : this.id,
      shareId: data.shareId.present ? data.shareId.value : this.shareId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      name: data.name.present ? data.name.value : this.name,
      isDirectory: data.isDirectory.present
          ? data.isDirectory.value
          : this.isDirectory,
      size: data.size.present ? data.size.value : this.size,
      mtimeMs: data.mtimeMs.present ? data.mtimeMs.value : this.mtimeMs,
      hashStatus: data.hashStatus.present
          ? data.hashStatus.value
          : this.hashStatus,
      chunkSize: data.chunkSize.present ? data.chunkSize.value : this.chunkSize,
      localUri: data.localUri.present ? data.localUri.value : this.localUri,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entry(')
          ..write('id: $id, ')
          ..write('shareId: $shareId, ')
          ..write('relativePath: $relativePath, ')
          ..write('name: $name, ')
          ..write('isDirectory: $isDirectory, ')
          ..write('size: $size, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('hashStatus: $hashStatus, ')
          ..write('chunkSize: $chunkSize, ')
          ..write('localUri: $localUri')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    shareId,
    relativePath,
    name,
    isDirectory,
    size,
    mtimeMs,
    hashStatus,
    chunkSize,
    localUri,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entry &&
          other.id == this.id &&
          other.shareId == this.shareId &&
          other.relativePath == this.relativePath &&
          other.name == this.name &&
          other.isDirectory == this.isDirectory &&
          other.size == this.size &&
          other.mtimeMs == this.mtimeMs &&
          other.hashStatus == this.hashStatus &&
          other.chunkSize == this.chunkSize &&
          other.localUri == this.localUri);
}

class EntriesCompanion extends UpdateCompanion<Entry> {
  final Value<String> id;
  final Value<String> shareId;
  final Value<String> relativePath;
  final Value<String> name;
  final Value<bool> isDirectory;
  final Value<int> size;
  final Value<int> mtimeMs;
  final Value<String> hashStatus;
  final Value<int?> chunkSize;
  final Value<String?> localUri;
  final Value<int> rowid;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.shareId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.name = const Value.absent(),
    this.isDirectory = const Value.absent(),
    this.size = const Value.absent(),
    this.mtimeMs = const Value.absent(),
    this.hashStatus = const Value.absent(),
    this.chunkSize = const Value.absent(),
    this.localUri = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntriesCompanion.insert({
    required String id,
    required String shareId,
    required String relativePath,
    required String name,
    this.isDirectory = const Value.absent(),
    this.size = const Value.absent(),
    this.mtimeMs = const Value.absent(),
    this.hashStatus = const Value.absent(),
    this.chunkSize = const Value.absent(),
    this.localUri = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       shareId = Value(shareId),
       relativePath = Value(relativePath),
       name = Value(name);
  static Insertable<Entry> custom({
    Expression<String>? id,
    Expression<String>? shareId,
    Expression<String>? relativePath,
    Expression<String>? name,
    Expression<bool>? isDirectory,
    Expression<int>? size,
    Expression<int>? mtimeMs,
    Expression<String>? hashStatus,
    Expression<int>? chunkSize,
    Expression<String>? localUri,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (shareId != null) 'share_id': shareId,
      if (relativePath != null) 'relative_path': relativePath,
      if (name != null) 'name': name,
      if (isDirectory != null) 'is_directory': isDirectory,
      if (size != null) 'size': size,
      if (mtimeMs != null) 'mtime_ms': mtimeMs,
      if (hashStatus != null) 'hash_status': hashStatus,
      if (chunkSize != null) 'chunk_size': chunkSize,
      if (localUri != null) 'local_uri': localUri,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? shareId,
    Value<String>? relativePath,
    Value<String>? name,
    Value<bool>? isDirectory,
    Value<int>? size,
    Value<int>? mtimeMs,
    Value<String>? hashStatus,
    Value<int?>? chunkSize,
    Value<String?>? localUri,
    Value<int>? rowid,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      shareId: shareId ?? this.shareId,
      relativePath: relativePath ?? this.relativePath,
      name: name ?? this.name,
      isDirectory: isDirectory ?? this.isDirectory,
      size: size ?? this.size,
      mtimeMs: mtimeMs ?? this.mtimeMs,
      hashStatus: hashStatus ?? this.hashStatus,
      chunkSize: chunkSize ?? this.chunkSize,
      localUri: localUri ?? this.localUri,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (shareId.present) {
      map['share_id'] = Variable<String>(shareId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isDirectory.present) {
      map['is_directory'] = Variable<bool>(isDirectory.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (mtimeMs.present) {
      map['mtime_ms'] = Variable<int>(mtimeMs.value);
    }
    if (hashStatus.present) {
      map['hash_status'] = Variable<String>(hashStatus.value);
    }
    if (chunkSize.present) {
      map['chunk_size'] = Variable<int>(chunkSize.value);
    }
    if (localUri.present) {
      map['local_uri'] = Variable<String>(localUri.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('shareId: $shareId, ')
          ..write('relativePath: $relativePath, ')
          ..write('name: $name, ')
          ..write('isDirectory: $isDirectory, ')
          ..write('size: $size, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('hashStatus: $hashStatus, ')
          ..write('chunkSize: $chunkSize, ')
          ..write('localUri: $localUri, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChunksTable extends Chunks with TableInfo<$ChunksTable, Chunk> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChunksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES entries (id)',
    ),
  );
  static const VerificationMeta _chunkIndexMeta = const VerificationMeta(
    'chunkIndex',
  );
  @override
  late final GeneratedColumn<int> chunkIndex = GeneratedColumn<int>(
    'chunk_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _offsetMeta = const VerificationMeta('offset');
  @override
  late final GeneratedColumn<int> offset = GeneratedColumn<int>(
    'offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lengthMeta = const VerificationMeta('length');
  @override
  late final GeneratedColumn<int> length = GeneratedColumn<int>(
    'length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashAlgorithmMeta = const VerificationMeta(
    'hashAlgorithm',
  );
  @override
  late final GeneratedColumn<String> hashAlgorithm = GeneratedColumn<String>(
    'hash_algorithm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('sha256'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entryId,
    chunkIndex,
    offset,
    length,
    hash,
    hashAlgorithm,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chunks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Chunk> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('chunk_index')) {
      context.handle(
        _chunkIndexMeta,
        chunkIndex.isAcceptableOrUnknown(data['chunk_index']!, _chunkIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_chunkIndexMeta);
    }
    if (data.containsKey('offset')) {
      context.handle(
        _offsetMeta,
        offset.isAcceptableOrUnknown(data['offset']!, _offsetMeta),
      );
    } else if (isInserting) {
      context.missing(_offsetMeta);
    }
    if (data.containsKey('length')) {
      context.handle(
        _lengthMeta,
        length.isAcceptableOrUnknown(data['length']!, _lengthMeta),
      );
    } else if (isInserting) {
      context.missing(_lengthMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('hash_algorithm')) {
      context.handle(
        _hashAlgorithmMeta,
        hashAlgorithm.isAcceptableOrUnknown(
          data['hash_algorithm']!,
          _hashAlgorithmMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Chunk map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Chunk(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      chunkIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk_index'],
      )!,
      offset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset'],
      )!,
      length: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}length'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      hashAlgorithm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash_algorithm'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $ChunksTable createAlias(String alias) {
    return $ChunksTable(attachedDatabase, alias);
  }
}

class Chunk extends DataClass implements Insertable<Chunk> {
  final int id;
  final String entryId;
  final int chunkIndex;
  final int offset;
  final int length;
  final String hash;
  final String hashAlgorithm;
  final String status;
  const Chunk({
    required this.id,
    required this.entryId,
    required this.chunkIndex,
    required this.offset,
    required this.length,
    required this.hash,
    required this.hashAlgorithm,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entry_id'] = Variable<String>(entryId);
    map['chunk_index'] = Variable<int>(chunkIndex);
    map['offset'] = Variable<int>(offset);
    map['length'] = Variable<int>(length);
    map['hash'] = Variable<String>(hash);
    map['hash_algorithm'] = Variable<String>(hashAlgorithm);
    map['status'] = Variable<String>(status);
    return map;
  }

  ChunksCompanion toCompanion(bool nullToAbsent) {
    return ChunksCompanion(
      id: Value(id),
      entryId: Value(entryId),
      chunkIndex: Value(chunkIndex),
      offset: Value(offset),
      length: Value(length),
      hash: Value(hash),
      hashAlgorithm: Value(hashAlgorithm),
      status: Value(status),
    );
  }

  factory Chunk.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Chunk(
      id: serializer.fromJson<int>(json['id']),
      entryId: serializer.fromJson<String>(json['entryId']),
      chunkIndex: serializer.fromJson<int>(json['chunkIndex']),
      offset: serializer.fromJson<int>(json['offset']),
      length: serializer.fromJson<int>(json['length']),
      hash: serializer.fromJson<String>(json['hash']),
      hashAlgorithm: serializer.fromJson<String>(json['hashAlgorithm']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entryId': serializer.toJson<String>(entryId),
      'chunkIndex': serializer.toJson<int>(chunkIndex),
      'offset': serializer.toJson<int>(offset),
      'length': serializer.toJson<int>(length),
      'hash': serializer.toJson<String>(hash),
      'hashAlgorithm': serializer.toJson<String>(hashAlgorithm),
      'status': serializer.toJson<String>(status),
    };
  }

  Chunk copyWith({
    int? id,
    String? entryId,
    int? chunkIndex,
    int? offset,
    int? length,
    String? hash,
    String? hashAlgorithm,
    String? status,
  }) => Chunk(
    id: id ?? this.id,
    entryId: entryId ?? this.entryId,
    chunkIndex: chunkIndex ?? this.chunkIndex,
    offset: offset ?? this.offset,
    length: length ?? this.length,
    hash: hash ?? this.hash,
    hashAlgorithm: hashAlgorithm ?? this.hashAlgorithm,
    status: status ?? this.status,
  );
  Chunk copyWithCompanion(ChunksCompanion data) {
    return Chunk(
      id: data.id.present ? data.id.value : this.id,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      chunkIndex: data.chunkIndex.present
          ? data.chunkIndex.value
          : this.chunkIndex,
      offset: data.offset.present ? data.offset.value : this.offset,
      length: data.length.present ? data.length.value : this.length,
      hash: data.hash.present ? data.hash.value : this.hash,
      hashAlgorithm: data.hashAlgorithm.present
          ? data.hashAlgorithm.value
          : this.hashAlgorithm,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Chunk(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('chunkIndex: $chunkIndex, ')
          ..write('offset: $offset, ')
          ..write('length: $length, ')
          ..write('hash: $hash, ')
          ..write('hashAlgorithm: $hashAlgorithm, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entryId,
    chunkIndex,
    offset,
    length,
    hash,
    hashAlgorithm,
    status,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Chunk &&
          other.id == this.id &&
          other.entryId == this.entryId &&
          other.chunkIndex == this.chunkIndex &&
          other.offset == this.offset &&
          other.length == this.length &&
          other.hash == this.hash &&
          other.hashAlgorithm == this.hashAlgorithm &&
          other.status == this.status);
}

class ChunksCompanion extends UpdateCompanion<Chunk> {
  final Value<int> id;
  final Value<String> entryId;
  final Value<int> chunkIndex;
  final Value<int> offset;
  final Value<int> length;
  final Value<String> hash;
  final Value<String> hashAlgorithm;
  final Value<String> status;
  const ChunksCompanion({
    this.id = const Value.absent(),
    this.entryId = const Value.absent(),
    this.chunkIndex = const Value.absent(),
    this.offset = const Value.absent(),
    this.length = const Value.absent(),
    this.hash = const Value.absent(),
    this.hashAlgorithm = const Value.absent(),
    this.status = const Value.absent(),
  });
  ChunksCompanion.insert({
    this.id = const Value.absent(),
    required String entryId,
    required int chunkIndex,
    required int offset,
    required int length,
    required String hash,
    this.hashAlgorithm = const Value.absent(),
    this.status = const Value.absent(),
  }) : entryId = Value(entryId),
       chunkIndex = Value(chunkIndex),
       offset = Value(offset),
       length = Value(length),
       hash = Value(hash);
  static Insertable<Chunk> custom({
    Expression<int>? id,
    Expression<String>? entryId,
    Expression<int>? chunkIndex,
    Expression<int>? offset,
    Expression<int>? length,
    Expression<String>? hash,
    Expression<String>? hashAlgorithm,
    Expression<String>? status,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entryId != null) 'entry_id': entryId,
      if (chunkIndex != null) 'chunk_index': chunkIndex,
      if (offset != null) 'offset': offset,
      if (length != null) 'length': length,
      if (hash != null) 'hash': hash,
      if (hashAlgorithm != null) 'hash_algorithm': hashAlgorithm,
      if (status != null) 'status': status,
    });
  }

  ChunksCompanion copyWith({
    Value<int>? id,
    Value<String>? entryId,
    Value<int>? chunkIndex,
    Value<int>? offset,
    Value<int>? length,
    Value<String>? hash,
    Value<String>? hashAlgorithm,
    Value<String>? status,
  }) {
    return ChunksCompanion(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      offset: offset ?? this.offset,
      length: length ?? this.length,
      hash: hash ?? this.hash,
      hashAlgorithm: hashAlgorithm ?? this.hashAlgorithm,
      status: status ?? this.status,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (chunkIndex.present) {
      map['chunk_index'] = Variable<int>(chunkIndex.value);
    }
    if (offset.present) {
      map['offset'] = Variable<int>(offset.value);
    }
    if (length.present) {
      map['length'] = Variable<int>(length.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (hashAlgorithm.present) {
      map['hash_algorithm'] = Variable<String>(hashAlgorithm.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChunksCompanion(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('chunkIndex: $chunkIndex, ')
          ..write('offset: $offset, ')
          ..write('length: $length, ')
          ..write('hash: $hash, ')
          ..write('hashAlgorithm: $hashAlgorithm, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }
}

class $PeersTable extends Peers with TableInfo<$PeersTable, Peer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nickMeta = const VerificationMeta('nick');
  @override
  late final GeneratedColumn<String> nick = GeneratedColumn<String>(
    'nick',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hostMeta = const VerificationMeta('host');
  @override
  late final GeneratedColumn<String> host = GeneratedColumn<String>(
    'host',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portMeta = const VerificationMeta('port');
  @override
  late final GeneratedColumn<int> port = GeneratedColumn<int>(
    'port',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schemeMeta = const VerificationMeta('scheme');
  @override
  late final GeneratedColumn<String> scheme = GeneratedColumn<String>(
    'scheme',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(peerSchemeHttps),
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta(
    'fingerprint',
  );
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tlsCertFingerprintMeta =
      const VerificationMeta('tlsCertFingerprint');
  @override
  late final GeneratedColumn<String> tlsCertFingerprint =
      GeneratedColumn<String>(
        'tls_cert_fingerprint',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _trustedMeta = const VerificationMeta(
    'trusted',
  );
  @override
  late final GeneratedColumn<bool> trusted = GeneratedColumn<bool>(
    'trusted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("trusted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _identityStatusMeta = const VerificationMeta(
    'identityStatus',
  );
  @override
  late final GeneratedColumn<String> identityStatus = GeneratedColumn<String>(
    'identity_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('normal'),
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
    'last_seen',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manualMeta = const VerificationMeta('manual');
  @override
  late final GeneratedColumn<bool> manual = GeneratedColumn<bool>(
    'manual',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("manual" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _staleMeta = const VerificationMeta('stale');
  @override
  late final GeneratedColumn<bool> stale = GeneratedColumn<bool>(
    'stale',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("stale" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nick,
    host,
    port,
    scheme,
    fingerprint,
    tlsCertFingerprint,
    trusted,
    identityStatus,
    lastSeen,
    manual,
    stale,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'peers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Peer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('nick')) {
      context.handle(
        _nickMeta,
        nick.isAcceptableOrUnknown(data['nick']!, _nickMeta),
      );
    } else if (isInserting) {
      context.missing(_nickMeta);
    }
    if (data.containsKey('host')) {
      context.handle(
        _hostMeta,
        host.isAcceptableOrUnknown(data['host']!, _hostMeta),
      );
    } else if (isInserting) {
      context.missing(_hostMeta);
    }
    if (data.containsKey('port')) {
      context.handle(
        _portMeta,
        port.isAcceptableOrUnknown(data['port']!, _portMeta),
      );
    } else if (isInserting) {
      context.missing(_portMeta);
    }
    if (data.containsKey('scheme')) {
      context.handle(
        _schemeMeta,
        scheme.isAcceptableOrUnknown(data['scheme']!, _schemeMeta),
      );
    }
    if (data.containsKey('fingerprint')) {
      context.handle(
        _fingerprintMeta,
        fingerprint.isAcceptableOrUnknown(
          data['fingerprint']!,
          _fingerprintMeta,
        ),
      );
    }
    if (data.containsKey('tls_cert_fingerprint')) {
      context.handle(
        _tlsCertFingerprintMeta,
        tlsCertFingerprint.isAcceptableOrUnknown(
          data['tls_cert_fingerprint']!,
          _tlsCertFingerprintMeta,
        ),
      );
    }
    if (data.containsKey('trusted')) {
      context.handle(
        _trustedMeta,
        trusted.isAcceptableOrUnknown(data['trusted']!, _trustedMeta),
      );
    }
    if (data.containsKey('identity_status')) {
      context.handle(
        _identityStatusMeta,
        identityStatus.isAcceptableOrUnknown(
          data['identity_status']!,
          _identityStatusMeta,
        ),
      );
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    }
    if (data.containsKey('manual')) {
      context.handle(
        _manualMeta,
        manual.isAcceptableOrUnknown(data['manual']!, _manualMeta),
      );
    }
    if (data.containsKey('stale')) {
      context.handle(
        _staleMeta,
        stale.isAcceptableOrUnknown(data['stale']!, _staleMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Peer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Peer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      nick: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nick'],
      )!,
      host: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}host'],
      )!,
      port: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}port'],
      )!,
      scheme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheme'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      ),
      tlsCertFingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tls_cert_fingerprint'],
      ),
      trusted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}trusted'],
      )!,
      identityStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}identity_status'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen'],
      ),
      manual: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}manual'],
      )!,
      stale: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}stale'],
      )!,
    );
  }

  @override
  $PeersTable createAlias(String alias) {
    return $PeersTable(attachedDatabase, alias);
  }
}

class Peer extends DataClass implements Insertable<Peer> {
  final String id;
  final String nick;
  final String host;
  final int port;
  final String scheme;
  final String? fingerprint;
  final String? tlsCertFingerprint;
  final bool trusted;
  final String identityStatus;
  final DateTime? lastSeen;
  final bool manual;
  final bool stale;
  const Peer({
    required this.id,
    required this.nick,
    required this.host,
    required this.port,
    required this.scheme,
    this.fingerprint,
    this.tlsCertFingerprint,
    required this.trusted,
    required this.identityStatus,
    this.lastSeen,
    required this.manual,
    required this.stale,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['nick'] = Variable<String>(nick);
    map['host'] = Variable<String>(host);
    map['port'] = Variable<int>(port);
    map['scheme'] = Variable<String>(scheme);
    if (!nullToAbsent || fingerprint != null) {
      map['fingerprint'] = Variable<String>(fingerprint);
    }
    if (!nullToAbsent || tlsCertFingerprint != null) {
      map['tls_cert_fingerprint'] = Variable<String>(tlsCertFingerprint);
    }
    map['trusted'] = Variable<bool>(trusted);
    map['identity_status'] = Variable<String>(identityStatus);
    if (!nullToAbsent || lastSeen != null) {
      map['last_seen'] = Variable<DateTime>(lastSeen);
    }
    map['manual'] = Variable<bool>(manual);
    map['stale'] = Variable<bool>(stale);
    return map;
  }

  PeersCompanion toCompanion(bool nullToAbsent) {
    return PeersCompanion(
      id: Value(id),
      nick: Value(nick),
      host: Value(host),
      port: Value(port),
      scheme: Value(scheme),
      fingerprint: fingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(fingerprint),
      tlsCertFingerprint: tlsCertFingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(tlsCertFingerprint),
      trusted: Value(trusted),
      identityStatus: Value(identityStatus),
      lastSeen: lastSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeen),
      manual: Value(manual),
      stale: Value(stale),
    );
  }

  factory Peer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Peer(
      id: serializer.fromJson<String>(json['id']),
      nick: serializer.fromJson<String>(json['nick']),
      host: serializer.fromJson<String>(json['host']),
      port: serializer.fromJson<int>(json['port']),
      scheme: serializer.fromJson<String>(json['scheme']),
      fingerprint: serializer.fromJson<String?>(json['fingerprint']),
      tlsCertFingerprint: serializer.fromJson<String?>(
        json['tlsCertFingerprint'],
      ),
      trusted: serializer.fromJson<bool>(json['trusted']),
      identityStatus: serializer.fromJson<String>(json['identityStatus']),
      lastSeen: serializer.fromJson<DateTime?>(json['lastSeen']),
      manual: serializer.fromJson<bool>(json['manual']),
      stale: serializer.fromJson<bool>(json['stale']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'nick': serializer.toJson<String>(nick),
      'host': serializer.toJson<String>(host),
      'port': serializer.toJson<int>(port),
      'scheme': serializer.toJson<String>(scheme),
      'fingerprint': serializer.toJson<String?>(fingerprint),
      'tlsCertFingerprint': serializer.toJson<String?>(tlsCertFingerprint),
      'trusted': serializer.toJson<bool>(trusted),
      'identityStatus': serializer.toJson<String>(identityStatus),
      'lastSeen': serializer.toJson<DateTime?>(lastSeen),
      'manual': serializer.toJson<bool>(manual),
      'stale': serializer.toJson<bool>(stale),
    };
  }

  Peer copyWith({
    String? id,
    String? nick,
    String? host,
    int? port,
    String? scheme,
    Value<String?> fingerprint = const Value.absent(),
    Value<String?> tlsCertFingerprint = const Value.absent(),
    bool? trusted,
    String? identityStatus,
    Value<DateTime?> lastSeen = const Value.absent(),
    bool? manual,
    bool? stale,
  }) => Peer(
    id: id ?? this.id,
    nick: nick ?? this.nick,
    host: host ?? this.host,
    port: port ?? this.port,
    scheme: scheme ?? this.scheme,
    fingerprint: fingerprint.present ? fingerprint.value : this.fingerprint,
    tlsCertFingerprint: tlsCertFingerprint.present
        ? tlsCertFingerprint.value
        : this.tlsCertFingerprint,
    trusted: trusted ?? this.trusted,
    identityStatus: identityStatus ?? this.identityStatus,
    lastSeen: lastSeen.present ? lastSeen.value : this.lastSeen,
    manual: manual ?? this.manual,
    stale: stale ?? this.stale,
  );
  Peer copyWithCompanion(PeersCompanion data) {
    return Peer(
      id: data.id.present ? data.id.value : this.id,
      nick: data.nick.present ? data.nick.value : this.nick,
      host: data.host.present ? data.host.value : this.host,
      port: data.port.present ? data.port.value : this.port,
      scheme: data.scheme.present ? data.scheme.value : this.scheme,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      tlsCertFingerprint: data.tlsCertFingerprint.present
          ? data.tlsCertFingerprint.value
          : this.tlsCertFingerprint,
      trusted: data.trusted.present ? data.trusted.value : this.trusted,
      identityStatus: data.identityStatus.present
          ? data.identityStatus.value
          : this.identityStatus,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      manual: data.manual.present ? data.manual.value : this.manual,
      stale: data.stale.present ? data.stale.value : this.stale,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Peer(')
          ..write('id: $id, ')
          ..write('nick: $nick, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('scheme: $scheme, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('tlsCertFingerprint: $tlsCertFingerprint, ')
          ..write('trusted: $trusted, ')
          ..write('identityStatus: $identityStatus, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('manual: $manual, ')
          ..write('stale: $stale')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    nick,
    host,
    port,
    scheme,
    fingerprint,
    tlsCertFingerprint,
    trusted,
    identityStatus,
    lastSeen,
    manual,
    stale,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Peer &&
          other.id == this.id &&
          other.nick == this.nick &&
          other.host == this.host &&
          other.port == this.port &&
          other.scheme == this.scheme &&
          other.fingerprint == this.fingerprint &&
          other.tlsCertFingerprint == this.tlsCertFingerprint &&
          other.trusted == this.trusted &&
          other.identityStatus == this.identityStatus &&
          other.lastSeen == this.lastSeen &&
          other.manual == this.manual &&
          other.stale == this.stale);
}

class PeersCompanion extends UpdateCompanion<Peer> {
  final Value<String> id;
  final Value<String> nick;
  final Value<String> host;
  final Value<int> port;
  final Value<String> scheme;
  final Value<String?> fingerprint;
  final Value<String?> tlsCertFingerprint;
  final Value<bool> trusted;
  final Value<String> identityStatus;
  final Value<DateTime?> lastSeen;
  final Value<bool> manual;
  final Value<bool> stale;
  final Value<int> rowid;
  const PeersCompanion({
    this.id = const Value.absent(),
    this.nick = const Value.absent(),
    this.host = const Value.absent(),
    this.port = const Value.absent(),
    this.scheme = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.tlsCertFingerprint = const Value.absent(),
    this.trusted = const Value.absent(),
    this.identityStatus = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.manual = const Value.absent(),
    this.stale = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeersCompanion.insert({
    required String id,
    required String nick,
    required String host,
    required int port,
    this.scheme = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.tlsCertFingerprint = const Value.absent(),
    this.trusted = const Value.absent(),
    this.identityStatus = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.manual = const Value.absent(),
    this.stale = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       nick = Value(nick),
       host = Value(host),
       port = Value(port);
  static Insertable<Peer> custom({
    Expression<String>? id,
    Expression<String>? nick,
    Expression<String>? host,
    Expression<int>? port,
    Expression<String>? scheme,
    Expression<String>? fingerprint,
    Expression<String>? tlsCertFingerprint,
    Expression<bool>? trusted,
    Expression<String>? identityStatus,
    Expression<DateTime>? lastSeen,
    Expression<bool>? manual,
    Expression<bool>? stale,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nick != null) 'nick': nick,
      if (host != null) 'host': host,
      if (port != null) 'port': port,
      if (scheme != null) 'scheme': scheme,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (tlsCertFingerprint != null)
        'tls_cert_fingerprint': tlsCertFingerprint,
      if (trusted != null) 'trusted': trusted,
      if (identityStatus != null) 'identity_status': identityStatus,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (manual != null) 'manual': manual,
      if (stale != null) 'stale': stale,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeersCompanion copyWith({
    Value<String>? id,
    Value<String>? nick,
    Value<String>? host,
    Value<int>? port,
    Value<String>? scheme,
    Value<String?>? fingerprint,
    Value<String?>? tlsCertFingerprint,
    Value<bool>? trusted,
    Value<String>? identityStatus,
    Value<DateTime?>? lastSeen,
    Value<bool>? manual,
    Value<bool>? stale,
    Value<int>? rowid,
  }) {
    return PeersCompanion(
      id: id ?? this.id,
      nick: nick ?? this.nick,
      host: host ?? this.host,
      port: port ?? this.port,
      scheme: scheme ?? this.scheme,
      fingerprint: fingerprint ?? this.fingerprint,
      tlsCertFingerprint: tlsCertFingerprint ?? this.tlsCertFingerprint,
      trusted: trusted ?? this.trusted,
      identityStatus: identityStatus ?? this.identityStatus,
      lastSeen: lastSeen ?? this.lastSeen,
      manual: manual ?? this.manual,
      stale: stale ?? this.stale,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (nick.present) {
      map['nick'] = Variable<String>(nick.value);
    }
    if (host.present) {
      map['host'] = Variable<String>(host.value);
    }
    if (port.present) {
      map['port'] = Variable<int>(port.value);
    }
    if (scheme.present) {
      map['scheme'] = Variable<String>(scheme.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (tlsCertFingerprint.present) {
      map['tls_cert_fingerprint'] = Variable<String>(tlsCertFingerprint.value);
    }
    if (trusted.present) {
      map['trusted'] = Variable<bool>(trusted.value);
    }
    if (identityStatus.present) {
      map['identity_status'] = Variable<String>(identityStatus.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (manual.present) {
      map['manual'] = Variable<bool>(manual.value);
    }
    if (stale.present) {
      map['stale'] = Variable<bool>(stale.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeersCompanion(')
          ..write('id: $id, ')
          ..write('nick: $nick, ')
          ..write('host: $host, ')
          ..write('port: $port, ')
          ..write('scheme: $scheme, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('tlsCertFingerprint: $tlsCertFingerprint, ')
          ..write('trusted: $trusted, ')
          ..write('identityStatus: $identityStatus, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('manual: $manual, ')
          ..write('stale: $stale, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemoteEntriesCacheTable extends RemoteEntriesCache
    with TableInfo<$RemoteEntriesCacheTable, RemoteEntriesCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemoteEntriesCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES peers (id)',
    ),
  );
  static const VerificationMeta _shareIdMeta = const VerificationMeta(
    'shareId',
  );
  @override
  late final GeneratedColumn<String> shareId = GeneratedColumn<String>(
    'share_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    peerId,
    shareId,
    relativePath,
    payloadJson,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'remote_entries_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<RemoteEntriesCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('share_id')) {
      context.handle(
        _shareIdMeta,
        shareId.isAcceptableOrUnknown(data['share_id']!, _shareIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shareIdMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RemoteEntriesCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RemoteEntriesCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      shareId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}share_id'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $RemoteEntriesCacheTable createAlias(String alias) {
    return $RemoteEntriesCacheTable(attachedDatabase, alias);
  }
}

class RemoteEntriesCacheData extends DataClass
    implements Insertable<RemoteEntriesCacheData> {
  final int id;
  final String peerId;
  final String shareId;
  final String relativePath;
  final String payloadJson;
  final DateTime cachedAt;
  const RemoteEntriesCacheData({
    required this.id,
    required this.peerId,
    required this.shareId,
    required this.relativePath,
    required this.payloadJson,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['peer_id'] = Variable<String>(peerId);
    map['share_id'] = Variable<String>(shareId);
    map['relative_path'] = Variable<String>(relativePath);
    map['payload_json'] = Variable<String>(payloadJson);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  RemoteEntriesCacheCompanion toCompanion(bool nullToAbsent) {
    return RemoteEntriesCacheCompanion(
      id: Value(id),
      peerId: Value(peerId),
      shareId: Value(shareId),
      relativePath: Value(relativePath),
      payloadJson: Value(payloadJson),
      cachedAt: Value(cachedAt),
    );
  }

  factory RemoteEntriesCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RemoteEntriesCacheData(
      id: serializer.fromJson<int>(json['id']),
      peerId: serializer.fromJson<String>(json['peerId']),
      shareId: serializer.fromJson<String>(json['shareId']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'peerId': serializer.toJson<String>(peerId),
      'shareId': serializer.toJson<String>(shareId),
      'relativePath': serializer.toJson<String>(relativePath),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  RemoteEntriesCacheData copyWith({
    int? id,
    String? peerId,
    String? shareId,
    String? relativePath,
    String? payloadJson,
    DateTime? cachedAt,
  }) => RemoteEntriesCacheData(
    id: id ?? this.id,
    peerId: peerId ?? this.peerId,
    shareId: shareId ?? this.shareId,
    relativePath: relativePath ?? this.relativePath,
    payloadJson: payloadJson ?? this.payloadJson,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  RemoteEntriesCacheData copyWithCompanion(RemoteEntriesCacheCompanion data) {
    return RemoteEntriesCacheData(
      id: data.id.present ? data.id.value : this.id,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      shareId: data.shareId.present ? data.shareId.value : this.shareId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RemoteEntriesCacheData(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('shareId: $shareId, ')
          ..write('relativePath: $relativePath, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, peerId, shareId, relativePath, payloadJson, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteEntriesCacheData &&
          other.id == this.id &&
          other.peerId == this.peerId &&
          other.shareId == this.shareId &&
          other.relativePath == this.relativePath &&
          other.payloadJson == this.payloadJson &&
          other.cachedAt == this.cachedAt);
}

class RemoteEntriesCacheCompanion
    extends UpdateCompanion<RemoteEntriesCacheData> {
  final Value<int> id;
  final Value<String> peerId;
  final Value<String> shareId;
  final Value<String> relativePath;
  final Value<String> payloadJson;
  final Value<DateTime> cachedAt;
  const RemoteEntriesCacheCompanion({
    this.id = const Value.absent(),
    this.peerId = const Value.absent(),
    this.shareId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
  });
  RemoteEntriesCacheCompanion.insert({
    this.id = const Value.absent(),
    required String peerId,
    required String shareId,
    required String relativePath,
    required String payloadJson,
    this.cachedAt = const Value.absent(),
  }) : peerId = Value(peerId),
       shareId = Value(shareId),
       relativePath = Value(relativePath),
       payloadJson = Value(payloadJson);
  static Insertable<RemoteEntriesCacheData> custom({
    Expression<int>? id,
    Expression<String>? peerId,
    Expression<String>? shareId,
    Expression<String>? relativePath,
    Expression<String>? payloadJson,
    Expression<DateTime>? cachedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (peerId != null) 'peer_id': peerId,
      if (shareId != null) 'share_id': shareId,
      if (relativePath != null) 'relative_path': relativePath,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (cachedAt != null) 'cached_at': cachedAt,
    });
  }

  RemoteEntriesCacheCompanion copyWith({
    Value<int>? id,
    Value<String>? peerId,
    Value<String>? shareId,
    Value<String>? relativePath,
    Value<String>? payloadJson,
    Value<DateTime>? cachedAt,
  }) {
    return RemoteEntriesCacheCompanion(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      shareId: shareId ?? this.shareId,
      relativePath: relativePath ?? this.relativePath,
      payloadJson: payloadJson ?? this.payloadJson,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (shareId.present) {
      map['share_id'] = Variable<String>(shareId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemoteEntriesCacheCompanion(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('shareId: $shareId, ')
          ..write('relativePath: $relativePath, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }
}

class $RemoteFilesTable extends RemoteFiles
    with TableInfo<$RemoteFilesTable, RemoteFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemoteFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES peers (id)',
    ),
  );
  static const VerificationMeta _shareIdMeta = const VerificationMeta(
    'shareId',
  );
  @override
  late final GeneratedColumn<String> shareId = GeneratedColumn<String>(
    'share_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDirectoryMeta = const VerificationMeta(
    'isDirectory',
  );
  @override
  late final GeneratedColumn<bool> isDirectory = GeneratedColumn<bool>(
    'is_directory',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_directory" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _mtimeMsMeta = const VerificationMeta(
    'mtimeMs',
  );
  @override
  late final GeneratedColumn<int> mtimeMs = GeneratedColumn<int>(
    'mtime_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hashReadyMeta = const VerificationMeta(
    'hashReady',
  );
  @override
  late final GeneratedColumn<bool> hashReady = GeneratedColumn<bool>(
    'hash_ready',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("hash_ready" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _contentSignatureMeta = const VerificationMeta(
    'contentSignature',
  );
  @override
  late final GeneratedColumn<String> contentSignature = GeneratedColumn<String>(
    'content_signature',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manifestJsonMeta = const VerificationMeta(
    'manifestJson',
  );
  @override
  late final GeneratedColumn<String> manifestJson = GeneratedColumn<String>(
    'manifest_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cachedAtMeta = const VerificationMeta(
    'cachedAt',
  );
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
    'cached_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    peerId,
    shareId,
    entryId,
    relativePath,
    name,
    isDirectory,
    size,
    mtimeMs,
    hashReady,
    contentSignature,
    manifestJson,
    cachedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'remote_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<RemoteFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('share_id')) {
      context.handle(
        _shareIdMeta,
        shareId.isAcceptableOrUnknown(data['share_id']!, _shareIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shareIdMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('is_directory')) {
      context.handle(
        _isDirectoryMeta,
        isDirectory.isAcceptableOrUnknown(
          data['is_directory']!,
          _isDirectoryMeta,
        ),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('mtime_ms')) {
      context.handle(
        _mtimeMsMeta,
        mtimeMs.isAcceptableOrUnknown(data['mtime_ms']!, _mtimeMsMeta),
      );
    }
    if (data.containsKey('hash_ready')) {
      context.handle(
        _hashReadyMeta,
        hashReady.isAcceptableOrUnknown(data['hash_ready']!, _hashReadyMeta),
      );
    }
    if (data.containsKey('content_signature')) {
      context.handle(
        _contentSignatureMeta,
        contentSignature.isAcceptableOrUnknown(
          data['content_signature']!,
          _contentSignatureMeta,
        ),
      );
    }
    if (data.containsKey('manifest_json')) {
      context.handle(
        _manifestJsonMeta,
        manifestJson.isAcceptableOrUnknown(
          data['manifest_json']!,
          _manifestJsonMeta,
        ),
      );
    }
    if (data.containsKey('cached_at')) {
      context.handle(
        _cachedAtMeta,
        cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RemoteFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RemoteFile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      shareId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}share_id'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      isDirectory: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_directory'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      mtimeMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mtime_ms'],
      )!,
      hashReady: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}hash_ready'],
      )!,
      contentSignature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_signature'],
      ),
      manifestJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}manifest_json'],
      ),
      cachedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cached_at'],
      )!,
    );
  }

  @override
  $RemoteFilesTable createAlias(String alias) {
    return $RemoteFilesTable(attachedDatabase, alias);
  }
}

class RemoteFile extends DataClass implements Insertable<RemoteFile> {
  final String id;
  final String peerId;
  final String shareId;
  final String entryId;
  final String relativePath;
  final String name;
  final bool isDirectory;
  final int size;
  final int mtimeMs;
  final bool hashReady;
  final String? contentSignature;
  final String? manifestJson;
  final DateTime cachedAt;
  const RemoteFile({
    required this.id,
    required this.peerId,
    required this.shareId,
    required this.entryId,
    required this.relativePath,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.mtimeMs,
    required this.hashReady,
    this.contentSignature,
    this.manifestJson,
    required this.cachedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['peer_id'] = Variable<String>(peerId);
    map['share_id'] = Variable<String>(shareId);
    map['entry_id'] = Variable<String>(entryId);
    map['relative_path'] = Variable<String>(relativePath);
    map['name'] = Variable<String>(name);
    map['is_directory'] = Variable<bool>(isDirectory);
    map['size'] = Variable<int>(size);
    map['mtime_ms'] = Variable<int>(mtimeMs);
    map['hash_ready'] = Variable<bool>(hashReady);
    if (!nullToAbsent || contentSignature != null) {
      map['content_signature'] = Variable<String>(contentSignature);
    }
    if (!nullToAbsent || manifestJson != null) {
      map['manifest_json'] = Variable<String>(manifestJson);
    }
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  RemoteFilesCompanion toCompanion(bool nullToAbsent) {
    return RemoteFilesCompanion(
      id: Value(id),
      peerId: Value(peerId),
      shareId: Value(shareId),
      entryId: Value(entryId),
      relativePath: Value(relativePath),
      name: Value(name),
      isDirectory: Value(isDirectory),
      size: Value(size),
      mtimeMs: Value(mtimeMs),
      hashReady: Value(hashReady),
      contentSignature: contentSignature == null && nullToAbsent
          ? const Value.absent()
          : Value(contentSignature),
      manifestJson: manifestJson == null && nullToAbsent
          ? const Value.absent()
          : Value(manifestJson),
      cachedAt: Value(cachedAt),
    );
  }

  factory RemoteFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RemoteFile(
      id: serializer.fromJson<String>(json['id']),
      peerId: serializer.fromJson<String>(json['peerId']),
      shareId: serializer.fromJson<String>(json['shareId']),
      entryId: serializer.fromJson<String>(json['entryId']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      name: serializer.fromJson<String>(json['name']),
      isDirectory: serializer.fromJson<bool>(json['isDirectory']),
      size: serializer.fromJson<int>(json['size']),
      mtimeMs: serializer.fromJson<int>(json['mtimeMs']),
      hashReady: serializer.fromJson<bool>(json['hashReady']),
      contentSignature: serializer.fromJson<String?>(json['contentSignature']),
      manifestJson: serializer.fromJson<String?>(json['manifestJson']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'peerId': serializer.toJson<String>(peerId),
      'shareId': serializer.toJson<String>(shareId),
      'entryId': serializer.toJson<String>(entryId),
      'relativePath': serializer.toJson<String>(relativePath),
      'name': serializer.toJson<String>(name),
      'isDirectory': serializer.toJson<bool>(isDirectory),
      'size': serializer.toJson<int>(size),
      'mtimeMs': serializer.toJson<int>(mtimeMs),
      'hashReady': serializer.toJson<bool>(hashReady),
      'contentSignature': serializer.toJson<String?>(contentSignature),
      'manifestJson': serializer.toJson<String?>(manifestJson),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  RemoteFile copyWith({
    String? id,
    String? peerId,
    String? shareId,
    String? entryId,
    String? relativePath,
    String? name,
    bool? isDirectory,
    int? size,
    int? mtimeMs,
    bool? hashReady,
    Value<String?> contentSignature = const Value.absent(),
    Value<String?> manifestJson = const Value.absent(),
    DateTime? cachedAt,
  }) => RemoteFile(
    id: id ?? this.id,
    peerId: peerId ?? this.peerId,
    shareId: shareId ?? this.shareId,
    entryId: entryId ?? this.entryId,
    relativePath: relativePath ?? this.relativePath,
    name: name ?? this.name,
    isDirectory: isDirectory ?? this.isDirectory,
    size: size ?? this.size,
    mtimeMs: mtimeMs ?? this.mtimeMs,
    hashReady: hashReady ?? this.hashReady,
    contentSignature: contentSignature.present
        ? contentSignature.value
        : this.contentSignature,
    manifestJson: manifestJson.present ? manifestJson.value : this.manifestJson,
    cachedAt: cachedAt ?? this.cachedAt,
  );
  RemoteFile copyWithCompanion(RemoteFilesCompanion data) {
    return RemoteFile(
      id: data.id.present ? data.id.value : this.id,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      shareId: data.shareId.present ? data.shareId.value : this.shareId,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      name: data.name.present ? data.name.value : this.name,
      isDirectory: data.isDirectory.present
          ? data.isDirectory.value
          : this.isDirectory,
      size: data.size.present ? data.size.value : this.size,
      mtimeMs: data.mtimeMs.present ? data.mtimeMs.value : this.mtimeMs,
      hashReady: data.hashReady.present ? data.hashReady.value : this.hashReady,
      contentSignature: data.contentSignature.present
          ? data.contentSignature.value
          : this.contentSignature,
      manifestJson: data.manifestJson.present
          ? data.manifestJson.value
          : this.manifestJson,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RemoteFile(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('shareId: $shareId, ')
          ..write('entryId: $entryId, ')
          ..write('relativePath: $relativePath, ')
          ..write('name: $name, ')
          ..write('isDirectory: $isDirectory, ')
          ..write('size: $size, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('hashReady: $hashReady, ')
          ..write('contentSignature: $contentSignature, ')
          ..write('manifestJson: $manifestJson, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    peerId,
    shareId,
    entryId,
    relativePath,
    name,
    isDirectory,
    size,
    mtimeMs,
    hashReady,
    contentSignature,
    manifestJson,
    cachedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteFile &&
          other.id == this.id &&
          other.peerId == this.peerId &&
          other.shareId == this.shareId &&
          other.entryId == this.entryId &&
          other.relativePath == this.relativePath &&
          other.name == this.name &&
          other.isDirectory == this.isDirectory &&
          other.size == this.size &&
          other.mtimeMs == this.mtimeMs &&
          other.hashReady == this.hashReady &&
          other.contentSignature == this.contentSignature &&
          other.manifestJson == this.manifestJson &&
          other.cachedAt == this.cachedAt);
}

class RemoteFilesCompanion extends UpdateCompanion<RemoteFile> {
  final Value<String> id;
  final Value<String> peerId;
  final Value<String> shareId;
  final Value<String> entryId;
  final Value<String> relativePath;
  final Value<String> name;
  final Value<bool> isDirectory;
  final Value<int> size;
  final Value<int> mtimeMs;
  final Value<bool> hashReady;
  final Value<String?> contentSignature;
  final Value<String?> manifestJson;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const RemoteFilesCompanion({
    this.id = const Value.absent(),
    this.peerId = const Value.absent(),
    this.shareId = const Value.absent(),
    this.entryId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.name = const Value.absent(),
    this.isDirectory = const Value.absent(),
    this.size = const Value.absent(),
    this.mtimeMs = const Value.absent(),
    this.hashReady = const Value.absent(),
    this.contentSignature = const Value.absent(),
    this.manifestJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemoteFilesCompanion.insert({
    required String id,
    required String peerId,
    required String shareId,
    required String entryId,
    required String relativePath,
    required String name,
    this.isDirectory = const Value.absent(),
    this.size = const Value.absent(),
    this.mtimeMs = const Value.absent(),
    this.hashReady = const Value.absent(),
    this.contentSignature = const Value.absent(),
    this.manifestJson = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       peerId = Value(peerId),
       shareId = Value(shareId),
       entryId = Value(entryId),
       relativePath = Value(relativePath),
       name = Value(name);
  static Insertable<RemoteFile> custom({
    Expression<String>? id,
    Expression<String>? peerId,
    Expression<String>? shareId,
    Expression<String>? entryId,
    Expression<String>? relativePath,
    Expression<String>? name,
    Expression<bool>? isDirectory,
    Expression<int>? size,
    Expression<int>? mtimeMs,
    Expression<bool>? hashReady,
    Expression<String>? contentSignature,
    Expression<String>? manifestJson,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (peerId != null) 'peer_id': peerId,
      if (shareId != null) 'share_id': shareId,
      if (entryId != null) 'entry_id': entryId,
      if (relativePath != null) 'relative_path': relativePath,
      if (name != null) 'name': name,
      if (isDirectory != null) 'is_directory': isDirectory,
      if (size != null) 'size': size,
      if (mtimeMs != null) 'mtime_ms': mtimeMs,
      if (hashReady != null) 'hash_ready': hashReady,
      if (contentSignature != null) 'content_signature': contentSignature,
      if (manifestJson != null) 'manifest_json': manifestJson,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemoteFilesCompanion copyWith({
    Value<String>? id,
    Value<String>? peerId,
    Value<String>? shareId,
    Value<String>? entryId,
    Value<String>? relativePath,
    Value<String>? name,
    Value<bool>? isDirectory,
    Value<int>? size,
    Value<int>? mtimeMs,
    Value<bool>? hashReady,
    Value<String?>? contentSignature,
    Value<String?>? manifestJson,
    Value<DateTime>? cachedAt,
    Value<int>? rowid,
  }) {
    return RemoteFilesCompanion(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      shareId: shareId ?? this.shareId,
      entryId: entryId ?? this.entryId,
      relativePath: relativePath ?? this.relativePath,
      name: name ?? this.name,
      isDirectory: isDirectory ?? this.isDirectory,
      size: size ?? this.size,
      mtimeMs: mtimeMs ?? this.mtimeMs,
      hashReady: hashReady ?? this.hashReady,
      contentSignature: contentSignature ?? this.contentSignature,
      manifestJson: manifestJson ?? this.manifestJson,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (shareId.present) {
      map['share_id'] = Variable<String>(shareId.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (isDirectory.present) {
      map['is_directory'] = Variable<bool>(isDirectory.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (mtimeMs.present) {
      map['mtime_ms'] = Variable<int>(mtimeMs.value);
    }
    if (hashReady.present) {
      map['hash_ready'] = Variable<bool>(hashReady.value);
    }
    if (contentSignature.present) {
      map['content_signature'] = Variable<String>(contentSignature.value);
    }
    if (manifestJson.present) {
      map['manifest_json'] = Variable<String>(manifestJson.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemoteFilesCompanion(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('shareId: $shareId, ')
          ..write('entryId: $entryId, ')
          ..write('relativePath: $relativePath, ')
          ..write('name: $name, ')
          ..write('isDirectory: $isDirectory, ')
          ..write('size: $size, ')
          ..write('mtimeMs: $mtimeMs, ')
          ..write('hashReady: $hashReady, ')
          ..write('contentSignature: $contentSignature, ')
          ..write('manifestJson: $manifestJson, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EntrySearchTokensTable extends EntrySearchTokens
    with TableInfo<$EntrySearchTokensTable, EntrySearchToken> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntrySearchTokensTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES entries (id)',
    ),
  );
  static const VerificationMeta _shareIdMeta = const VerificationMeta(
    'shareId',
  );
  @override
  late final GeneratedColumn<String> shareId = GeneratedColumn<String>(
    'share_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  @override
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
    'token',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [entryId, shareId, token];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entry_search_tokens';
  @override
  VerificationContext validateIntegrity(
    Insertable<EntrySearchToken> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('share_id')) {
      context.handle(
        _shareIdMeta,
        shareId.isAcceptableOrUnknown(data['share_id']!, _shareIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shareIdMeta);
    }
    if (data.containsKey('token')) {
      context.handle(
        _tokenMeta,
        token.isAcceptableOrUnknown(data['token']!, _tokenMeta),
      );
    } else if (isInserting) {
      context.missing(_tokenMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entryId, token};
  @override
  EntrySearchToken map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EntrySearchToken(
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      shareId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}share_id'],
      )!,
      token: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}token'],
      )!,
    );
  }

  @override
  $EntrySearchTokensTable createAlias(String alias) {
    return $EntrySearchTokensTable(attachedDatabase, alias);
  }
}

class EntrySearchToken extends DataClass
    implements Insertable<EntrySearchToken> {
  final String entryId;
  final String shareId;
  final String token;
  const EntrySearchToken({
    required this.entryId,
    required this.shareId,
    required this.token,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entry_id'] = Variable<String>(entryId);
    map['share_id'] = Variable<String>(shareId);
    map['token'] = Variable<String>(token);
    return map;
  }

  EntrySearchTokensCompanion toCompanion(bool nullToAbsent) {
    return EntrySearchTokensCompanion(
      entryId: Value(entryId),
      shareId: Value(shareId),
      token: Value(token),
    );
  }

  factory EntrySearchToken.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EntrySearchToken(
      entryId: serializer.fromJson<String>(json['entryId']),
      shareId: serializer.fromJson<String>(json['shareId']),
      token: serializer.fromJson<String>(json['token']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entryId': serializer.toJson<String>(entryId),
      'shareId': serializer.toJson<String>(shareId),
      'token': serializer.toJson<String>(token),
    };
  }

  EntrySearchToken copyWith({
    String? entryId,
    String? shareId,
    String? token,
  }) => EntrySearchToken(
    entryId: entryId ?? this.entryId,
    shareId: shareId ?? this.shareId,
    token: token ?? this.token,
  );
  EntrySearchToken copyWithCompanion(EntrySearchTokensCompanion data) {
    return EntrySearchToken(
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      shareId: data.shareId.present ? data.shareId.value : this.shareId,
      token: data.token.present ? data.token.value : this.token,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EntrySearchToken(')
          ..write('entryId: $entryId, ')
          ..write('shareId: $shareId, ')
          ..write('token: $token')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(entryId, shareId, token);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntrySearchToken &&
          other.entryId == this.entryId &&
          other.shareId == this.shareId &&
          other.token == this.token);
}

class EntrySearchTokensCompanion extends UpdateCompanion<EntrySearchToken> {
  final Value<String> entryId;
  final Value<String> shareId;
  final Value<String> token;
  final Value<int> rowid;
  const EntrySearchTokensCompanion({
    this.entryId = const Value.absent(),
    this.shareId = const Value.absent(),
    this.token = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EntrySearchTokensCompanion.insert({
    required String entryId,
    required String shareId,
    required String token,
    this.rowid = const Value.absent(),
  }) : entryId = Value(entryId),
       shareId = Value(shareId),
       token = Value(token);
  static Insertable<EntrySearchToken> custom({
    Expression<String>? entryId,
    Expression<String>? shareId,
    Expression<String>? token,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entryId != null) 'entry_id': entryId,
      if (shareId != null) 'share_id': shareId,
      if (token != null) 'token': token,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EntrySearchTokensCompanion copyWith({
    Value<String>? entryId,
    Value<String>? shareId,
    Value<String>? token,
    Value<int>? rowid,
  }) {
    return EntrySearchTokensCompanion(
      entryId: entryId ?? this.entryId,
      shareId: shareId ?? this.shareId,
      token: token ?? this.token,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (shareId.present) {
      map['share_id'] = Variable<String>(shareId.value);
    }
    if (token.present) {
      map['token'] = Variable<String>(token.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntrySearchTokensCompanion(')
          ..write('entryId: $entryId, ')
          ..write('shareId: $shareId, ')
          ..write('token: $token, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemoteChunkSourcesTable extends RemoteChunkSources
    with TableInfo<$RemoteChunkSourcesTable, RemoteChunkSource> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemoteChunkSourcesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES peers (id)',
    ),
  );
  static const VerificationMeta _remoteFileIdMeta = const VerificationMeta(
    'remoteFileId',
  );
  @override
  late final GeneratedColumn<String> remoteFileId = GeneratedColumn<String>(
    'remote_file_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES remote_files (id)',
    ),
  );
  static const VerificationMeta _shareIdMeta = const VerificationMeta(
    'shareId',
  );
  @override
  late final GeneratedColumn<String> shareId = GeneratedColumn<String>(
    'share_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chunkIndexMeta = const VerificationMeta(
    'chunkIndex',
  );
  @override
  late final GeneratedColumn<int> chunkIndex = GeneratedColumn<int>(
    'chunk_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _offsetMeta = const VerificationMeta('offset');
  @override
  late final GeneratedColumn<int> offset = GeneratedColumn<int>(
    'offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lengthMeta = const VerificationMeta('length');
  @override
  late final GeneratedColumn<int> length = GeneratedColumn<int>(
    'length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
    'last_seen',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastSuccessAtMeta = const VerificationMeta(
    'lastSuccessAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSuccessAt =
      GeneratedColumn<DateTime>(
        'last_success_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _failureCountMeta = const VerificationMeta(
    'failureCount',
  );
  @override
  late final GeneratedColumn<int> failureCount = GeneratedColumn<int>(
    'failure_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _avgLatencyMsMeta = const VerificationMeta(
    'avgLatencyMs',
  );
  @override
  late final GeneratedColumn<int> avgLatencyMs = GeneratedColumn<int>(
    'avg_latency_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _avgBytesPerSecondMeta = const VerificationMeta(
    'avgBytesPerSecond',
  );
  @override
  late final GeneratedColumn<int> avgBytesPerSecond = GeneratedColumn<int>(
    'avg_bytes_per_second',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    hash,
    peerId,
    remoteFileId,
    shareId,
    entryId,
    chunkIndex,
    offset,
    length,
    lastSeen,
    lastSuccessAt,
    failureCount,
    avgLatencyMs,
    avgBytesPerSecond,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'remote_chunk_sources';
  @override
  VerificationContext validateIntegrity(
    Insertable<RemoteChunkSource> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('remote_file_id')) {
      context.handle(
        _remoteFileIdMeta,
        remoteFileId.isAcceptableOrUnknown(
          data['remote_file_id']!,
          _remoteFileIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteFileIdMeta);
    }
    if (data.containsKey('share_id')) {
      context.handle(
        _shareIdMeta,
        shareId.isAcceptableOrUnknown(data['share_id']!, _shareIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shareIdMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('chunk_index')) {
      context.handle(
        _chunkIndexMeta,
        chunkIndex.isAcceptableOrUnknown(data['chunk_index']!, _chunkIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_chunkIndexMeta);
    }
    if (data.containsKey('offset')) {
      context.handle(
        _offsetMeta,
        offset.isAcceptableOrUnknown(data['offset']!, _offsetMeta),
      );
    } else if (isInserting) {
      context.missing(_offsetMeta);
    }
    if (data.containsKey('length')) {
      context.handle(
        _lengthMeta,
        length.isAcceptableOrUnknown(data['length']!, _lengthMeta),
      );
    } else if (isInserting) {
      context.missing(_lengthMeta);
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    }
    if (data.containsKey('last_success_at')) {
      context.handle(
        _lastSuccessAtMeta,
        lastSuccessAt.isAcceptableOrUnknown(
          data['last_success_at']!,
          _lastSuccessAtMeta,
        ),
      );
    }
    if (data.containsKey('failure_count')) {
      context.handle(
        _failureCountMeta,
        failureCount.isAcceptableOrUnknown(
          data['failure_count']!,
          _failureCountMeta,
        ),
      );
    }
    if (data.containsKey('avg_latency_ms')) {
      context.handle(
        _avgLatencyMsMeta,
        avgLatencyMs.isAcceptableOrUnknown(
          data['avg_latency_ms']!,
          _avgLatencyMsMeta,
        ),
      );
    }
    if (data.containsKey('avg_bytes_per_second')) {
      context.handle(
        _avgBytesPerSecondMeta,
        avgBytesPerSecond.isAcceptableOrUnknown(
          data['avg_bytes_per_second']!,
          _avgBytesPerSecondMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RemoteChunkSource map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RemoteChunkSource(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      remoteFileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_file_id'],
      )!,
      shareId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}share_id'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      chunkIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk_index'],
      )!,
      offset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset'],
      )!,
      length: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}length'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen'],
      )!,
      lastSuccessAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_success_at'],
      ),
      failureCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}failure_count'],
      )!,
      avgLatencyMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avg_latency_ms'],
      ),
      avgBytesPerSecond: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avg_bytes_per_second'],
      ),
    );
  }

  @override
  $RemoteChunkSourcesTable createAlias(String alias) {
    return $RemoteChunkSourcesTable(attachedDatabase, alias);
  }
}

class RemoteChunkSource extends DataClass
    implements Insertable<RemoteChunkSource> {
  final int id;
  final String hash;
  final String peerId;
  final String remoteFileId;
  final String shareId;
  final String entryId;
  final int chunkIndex;
  final int offset;
  final int length;
  final DateTime lastSeen;
  final DateTime? lastSuccessAt;
  final int failureCount;
  final int? avgLatencyMs;
  final int? avgBytesPerSecond;
  const RemoteChunkSource({
    required this.id,
    required this.hash,
    required this.peerId,
    required this.remoteFileId,
    required this.shareId,
    required this.entryId,
    required this.chunkIndex,
    required this.offset,
    required this.length,
    required this.lastSeen,
    this.lastSuccessAt,
    required this.failureCount,
    this.avgLatencyMs,
    this.avgBytesPerSecond,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['hash'] = Variable<String>(hash);
    map['peer_id'] = Variable<String>(peerId);
    map['remote_file_id'] = Variable<String>(remoteFileId);
    map['share_id'] = Variable<String>(shareId);
    map['entry_id'] = Variable<String>(entryId);
    map['chunk_index'] = Variable<int>(chunkIndex);
    map['offset'] = Variable<int>(offset);
    map['length'] = Variable<int>(length);
    map['last_seen'] = Variable<DateTime>(lastSeen);
    if (!nullToAbsent || lastSuccessAt != null) {
      map['last_success_at'] = Variable<DateTime>(lastSuccessAt);
    }
    map['failure_count'] = Variable<int>(failureCount);
    if (!nullToAbsent || avgLatencyMs != null) {
      map['avg_latency_ms'] = Variable<int>(avgLatencyMs);
    }
    if (!nullToAbsent || avgBytesPerSecond != null) {
      map['avg_bytes_per_second'] = Variable<int>(avgBytesPerSecond);
    }
    return map;
  }

  RemoteChunkSourcesCompanion toCompanion(bool nullToAbsent) {
    return RemoteChunkSourcesCompanion(
      id: Value(id),
      hash: Value(hash),
      peerId: Value(peerId),
      remoteFileId: Value(remoteFileId),
      shareId: Value(shareId),
      entryId: Value(entryId),
      chunkIndex: Value(chunkIndex),
      offset: Value(offset),
      length: Value(length),
      lastSeen: Value(lastSeen),
      lastSuccessAt: lastSuccessAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessAt),
      failureCount: Value(failureCount),
      avgLatencyMs: avgLatencyMs == null && nullToAbsent
          ? const Value.absent()
          : Value(avgLatencyMs),
      avgBytesPerSecond: avgBytesPerSecond == null && nullToAbsent
          ? const Value.absent()
          : Value(avgBytesPerSecond),
    );
  }

  factory RemoteChunkSource.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RemoteChunkSource(
      id: serializer.fromJson<int>(json['id']),
      hash: serializer.fromJson<String>(json['hash']),
      peerId: serializer.fromJson<String>(json['peerId']),
      remoteFileId: serializer.fromJson<String>(json['remoteFileId']),
      shareId: serializer.fromJson<String>(json['shareId']),
      entryId: serializer.fromJson<String>(json['entryId']),
      chunkIndex: serializer.fromJson<int>(json['chunkIndex']),
      offset: serializer.fromJson<int>(json['offset']),
      length: serializer.fromJson<int>(json['length']),
      lastSeen: serializer.fromJson<DateTime>(json['lastSeen']),
      lastSuccessAt: serializer.fromJson<DateTime?>(json['lastSuccessAt']),
      failureCount: serializer.fromJson<int>(json['failureCount']),
      avgLatencyMs: serializer.fromJson<int?>(json['avgLatencyMs']),
      avgBytesPerSecond: serializer.fromJson<int?>(json['avgBytesPerSecond']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'hash': serializer.toJson<String>(hash),
      'peerId': serializer.toJson<String>(peerId),
      'remoteFileId': serializer.toJson<String>(remoteFileId),
      'shareId': serializer.toJson<String>(shareId),
      'entryId': serializer.toJson<String>(entryId),
      'chunkIndex': serializer.toJson<int>(chunkIndex),
      'offset': serializer.toJson<int>(offset),
      'length': serializer.toJson<int>(length),
      'lastSeen': serializer.toJson<DateTime>(lastSeen),
      'lastSuccessAt': serializer.toJson<DateTime?>(lastSuccessAt),
      'failureCount': serializer.toJson<int>(failureCount),
      'avgLatencyMs': serializer.toJson<int?>(avgLatencyMs),
      'avgBytesPerSecond': serializer.toJson<int?>(avgBytesPerSecond),
    };
  }

  RemoteChunkSource copyWith({
    int? id,
    String? hash,
    String? peerId,
    String? remoteFileId,
    String? shareId,
    String? entryId,
    int? chunkIndex,
    int? offset,
    int? length,
    DateTime? lastSeen,
    Value<DateTime?> lastSuccessAt = const Value.absent(),
    int? failureCount,
    Value<int?> avgLatencyMs = const Value.absent(),
    Value<int?> avgBytesPerSecond = const Value.absent(),
  }) => RemoteChunkSource(
    id: id ?? this.id,
    hash: hash ?? this.hash,
    peerId: peerId ?? this.peerId,
    remoteFileId: remoteFileId ?? this.remoteFileId,
    shareId: shareId ?? this.shareId,
    entryId: entryId ?? this.entryId,
    chunkIndex: chunkIndex ?? this.chunkIndex,
    offset: offset ?? this.offset,
    length: length ?? this.length,
    lastSeen: lastSeen ?? this.lastSeen,
    lastSuccessAt: lastSuccessAt.present
        ? lastSuccessAt.value
        : this.lastSuccessAt,
    failureCount: failureCount ?? this.failureCount,
    avgLatencyMs: avgLatencyMs.present ? avgLatencyMs.value : this.avgLatencyMs,
    avgBytesPerSecond: avgBytesPerSecond.present
        ? avgBytesPerSecond.value
        : this.avgBytesPerSecond,
  );
  RemoteChunkSource copyWithCompanion(RemoteChunkSourcesCompanion data) {
    return RemoteChunkSource(
      id: data.id.present ? data.id.value : this.id,
      hash: data.hash.present ? data.hash.value : this.hash,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      remoteFileId: data.remoteFileId.present
          ? data.remoteFileId.value
          : this.remoteFileId,
      shareId: data.shareId.present ? data.shareId.value : this.shareId,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      chunkIndex: data.chunkIndex.present
          ? data.chunkIndex.value
          : this.chunkIndex,
      offset: data.offset.present ? data.offset.value : this.offset,
      length: data.length.present ? data.length.value : this.length,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      lastSuccessAt: data.lastSuccessAt.present
          ? data.lastSuccessAt.value
          : this.lastSuccessAt,
      failureCount: data.failureCount.present
          ? data.failureCount.value
          : this.failureCount,
      avgLatencyMs: data.avgLatencyMs.present
          ? data.avgLatencyMs.value
          : this.avgLatencyMs,
      avgBytesPerSecond: data.avgBytesPerSecond.present
          ? data.avgBytesPerSecond.value
          : this.avgBytesPerSecond,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RemoteChunkSource(')
          ..write('id: $id, ')
          ..write('hash: $hash, ')
          ..write('peerId: $peerId, ')
          ..write('remoteFileId: $remoteFileId, ')
          ..write('shareId: $shareId, ')
          ..write('entryId: $entryId, ')
          ..write('chunkIndex: $chunkIndex, ')
          ..write('offset: $offset, ')
          ..write('length: $length, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('failureCount: $failureCount, ')
          ..write('avgLatencyMs: $avgLatencyMs, ')
          ..write('avgBytesPerSecond: $avgBytesPerSecond')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    hash,
    peerId,
    remoteFileId,
    shareId,
    entryId,
    chunkIndex,
    offset,
    length,
    lastSeen,
    lastSuccessAt,
    failureCount,
    avgLatencyMs,
    avgBytesPerSecond,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RemoteChunkSource &&
          other.id == this.id &&
          other.hash == this.hash &&
          other.peerId == this.peerId &&
          other.remoteFileId == this.remoteFileId &&
          other.shareId == this.shareId &&
          other.entryId == this.entryId &&
          other.chunkIndex == this.chunkIndex &&
          other.offset == this.offset &&
          other.length == this.length &&
          other.lastSeen == this.lastSeen &&
          other.lastSuccessAt == this.lastSuccessAt &&
          other.failureCount == this.failureCount &&
          other.avgLatencyMs == this.avgLatencyMs &&
          other.avgBytesPerSecond == this.avgBytesPerSecond);
}

class RemoteChunkSourcesCompanion extends UpdateCompanion<RemoteChunkSource> {
  final Value<int> id;
  final Value<String> hash;
  final Value<String> peerId;
  final Value<String> remoteFileId;
  final Value<String> shareId;
  final Value<String> entryId;
  final Value<int> chunkIndex;
  final Value<int> offset;
  final Value<int> length;
  final Value<DateTime> lastSeen;
  final Value<DateTime?> lastSuccessAt;
  final Value<int> failureCount;
  final Value<int?> avgLatencyMs;
  final Value<int?> avgBytesPerSecond;
  const RemoteChunkSourcesCompanion({
    this.id = const Value.absent(),
    this.hash = const Value.absent(),
    this.peerId = const Value.absent(),
    this.remoteFileId = const Value.absent(),
    this.shareId = const Value.absent(),
    this.entryId = const Value.absent(),
    this.chunkIndex = const Value.absent(),
    this.offset = const Value.absent(),
    this.length = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.failureCount = const Value.absent(),
    this.avgLatencyMs = const Value.absent(),
    this.avgBytesPerSecond = const Value.absent(),
  });
  RemoteChunkSourcesCompanion.insert({
    this.id = const Value.absent(),
    required String hash,
    required String peerId,
    required String remoteFileId,
    required String shareId,
    required String entryId,
    required int chunkIndex,
    required int offset,
    required int length,
    this.lastSeen = const Value.absent(),
    this.lastSuccessAt = const Value.absent(),
    this.failureCount = const Value.absent(),
    this.avgLatencyMs = const Value.absent(),
    this.avgBytesPerSecond = const Value.absent(),
  }) : hash = Value(hash),
       peerId = Value(peerId),
       remoteFileId = Value(remoteFileId),
       shareId = Value(shareId),
       entryId = Value(entryId),
       chunkIndex = Value(chunkIndex),
       offset = Value(offset),
       length = Value(length);
  static Insertable<RemoteChunkSource> custom({
    Expression<int>? id,
    Expression<String>? hash,
    Expression<String>? peerId,
    Expression<String>? remoteFileId,
    Expression<String>? shareId,
    Expression<String>? entryId,
    Expression<int>? chunkIndex,
    Expression<int>? offset,
    Expression<int>? length,
    Expression<DateTime>? lastSeen,
    Expression<DateTime>? lastSuccessAt,
    Expression<int>? failureCount,
    Expression<int>? avgLatencyMs,
    Expression<int>? avgBytesPerSecond,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hash != null) 'hash': hash,
      if (peerId != null) 'peer_id': peerId,
      if (remoteFileId != null) 'remote_file_id': remoteFileId,
      if (shareId != null) 'share_id': shareId,
      if (entryId != null) 'entry_id': entryId,
      if (chunkIndex != null) 'chunk_index': chunkIndex,
      if (offset != null) 'offset': offset,
      if (length != null) 'length': length,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (lastSuccessAt != null) 'last_success_at': lastSuccessAt,
      if (failureCount != null) 'failure_count': failureCount,
      if (avgLatencyMs != null) 'avg_latency_ms': avgLatencyMs,
      if (avgBytesPerSecond != null) 'avg_bytes_per_second': avgBytesPerSecond,
    });
  }

  RemoteChunkSourcesCompanion copyWith({
    Value<int>? id,
    Value<String>? hash,
    Value<String>? peerId,
    Value<String>? remoteFileId,
    Value<String>? shareId,
    Value<String>? entryId,
    Value<int>? chunkIndex,
    Value<int>? offset,
    Value<int>? length,
    Value<DateTime>? lastSeen,
    Value<DateTime?>? lastSuccessAt,
    Value<int>? failureCount,
    Value<int?>? avgLatencyMs,
    Value<int?>? avgBytesPerSecond,
  }) {
    return RemoteChunkSourcesCompanion(
      id: id ?? this.id,
      hash: hash ?? this.hash,
      peerId: peerId ?? this.peerId,
      remoteFileId: remoteFileId ?? this.remoteFileId,
      shareId: shareId ?? this.shareId,
      entryId: entryId ?? this.entryId,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      offset: offset ?? this.offset,
      length: length ?? this.length,
      lastSeen: lastSeen ?? this.lastSeen,
      lastSuccessAt: lastSuccessAt ?? this.lastSuccessAt,
      failureCount: failureCount ?? this.failureCount,
      avgLatencyMs: avgLatencyMs ?? this.avgLatencyMs,
      avgBytesPerSecond: avgBytesPerSecond ?? this.avgBytesPerSecond,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (remoteFileId.present) {
      map['remote_file_id'] = Variable<String>(remoteFileId.value);
    }
    if (shareId.present) {
      map['share_id'] = Variable<String>(shareId.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (chunkIndex.present) {
      map['chunk_index'] = Variable<int>(chunkIndex.value);
    }
    if (offset.present) {
      map['offset'] = Variable<int>(offset.value);
    }
    if (length.present) {
      map['length'] = Variable<int>(length.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (lastSuccessAt.present) {
      map['last_success_at'] = Variable<DateTime>(lastSuccessAt.value);
    }
    if (failureCount.present) {
      map['failure_count'] = Variable<int>(failureCount.value);
    }
    if (avgLatencyMs.present) {
      map['avg_latency_ms'] = Variable<int>(avgLatencyMs.value);
    }
    if (avgBytesPerSecond.present) {
      map['avg_bytes_per_second'] = Variable<int>(avgBytesPerSecond.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemoteChunkSourcesCompanion(')
          ..write('id: $id, ')
          ..write('hash: $hash, ')
          ..write('peerId: $peerId, ')
          ..write('remoteFileId: $remoteFileId, ')
          ..write('shareId: $shareId, ')
          ..write('entryId: $entryId, ')
          ..write('chunkIndex: $chunkIndex, ')
          ..write('offset: $offset, ')
          ..write('length: $length, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('lastSuccessAt: $lastSuccessAt, ')
          ..write('failureCount: $failureCount, ')
          ..write('avgLatencyMs: $avgLatencyMs, ')
          ..write('avgBytesPerSecond: $avgBytesPerSecond')
          ..write(')'))
        .toString();
  }
}

class $DownloadGroupsTable extends DownloadGroups
    with TableInfo<$DownloadGroupsTable, DownloadGroup> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadGroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rootPathMeta = const VerificationMeta(
    'rootPath',
  );
  @override
  late final GeneratedColumn<String> rootPath = GeneratedColumn<String>(
    'root_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetPathMeta = const VerificationMeta(
    'targetPath',
  );
  @override
  late final GeneratedColumn<String> targetPath = GeneratedColumn<String>(
    'target_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _totalFilesMeta = const VerificationMeta(
    'totalFiles',
  );
  @override
  late final GeneratedColumn<int> totalFiles = GeneratedColumn<int>(
    'total_files',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _completedFilesMeta = const VerificationMeta(
    'completedFiles',
  );
  @override
  late final GeneratedColumn<int> completedFiles = GeneratedColumn<int>(
    'completed_files',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _downloadedBytesMeta = const VerificationMeta(
    'downloadedBytes',
  );
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
    'downloaded_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    rootPath,
    targetPath,
    state,
    totalFiles,
    completedFiles,
    totalBytes,
    downloadedBytes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadGroup> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('root_path')) {
      context.handle(
        _rootPathMeta,
        rootPath.isAcceptableOrUnknown(data['root_path']!, _rootPathMeta),
      );
    } else if (isInserting) {
      context.missing(_rootPathMeta);
    }
    if (data.containsKey('target_path')) {
      context.handle(
        _targetPathMeta,
        targetPath.isAcceptableOrUnknown(data['target_path']!, _targetPathMeta),
      );
    } else if (isInserting) {
      context.missing(_targetPathMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('total_files')) {
      context.handle(
        _totalFilesMeta,
        totalFiles.isAcceptableOrUnknown(data['total_files']!, _totalFilesMeta),
      );
    }
    if (data.containsKey('completed_files')) {
      context.handle(
        _completedFilesMeta,
        completedFiles.isAcceptableOrUnknown(
          data['completed_files']!,
          _completedFilesMeta,
        ),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
        _downloadedBytesMeta,
        downloadedBytes.isAcceptableOrUnknown(
          data['downloaded_bytes']!,
          _downloadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadGroup map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadGroup(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      rootPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}root_path'],
      )!,
      targetPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_path'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      totalFiles: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_files'],
      )!,
      completedFiles: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_files'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      )!,
      downloadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bytes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DownloadGroupsTable createAlias(String alias) {
    return $DownloadGroupsTable(attachedDatabase, alias);
  }
}

class DownloadGroup extends DataClass implements Insertable<DownloadGroup> {
  final String id;
  final String label;
  final String rootPath;
  final String targetPath;
  final String state;
  final int totalFiles;
  final int completedFiles;
  final int totalBytes;
  final int downloadedBytes;
  final DateTime createdAt;
  const DownloadGroup({
    required this.id,
    required this.label,
    required this.rootPath,
    required this.targetPath,
    required this.state,
    required this.totalFiles,
    required this.completedFiles,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['label'] = Variable<String>(label);
    map['root_path'] = Variable<String>(rootPath);
    map['target_path'] = Variable<String>(targetPath);
    map['state'] = Variable<String>(state);
    map['total_files'] = Variable<int>(totalFiles);
    map['completed_files'] = Variable<int>(completedFiles);
    map['total_bytes'] = Variable<int>(totalBytes);
    map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DownloadGroupsCompanion toCompanion(bool nullToAbsent) {
    return DownloadGroupsCompanion(
      id: Value(id),
      label: Value(label),
      rootPath: Value(rootPath),
      targetPath: Value(targetPath),
      state: Value(state),
      totalFiles: Value(totalFiles),
      completedFiles: Value(completedFiles),
      totalBytes: Value(totalBytes),
      downloadedBytes: Value(downloadedBytes),
      createdAt: Value(createdAt),
    );
  }

  factory DownloadGroup.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadGroup(
      id: serializer.fromJson<String>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      rootPath: serializer.fromJson<String>(json['rootPath']),
      targetPath: serializer.fromJson<String>(json['targetPath']),
      state: serializer.fromJson<String>(json['state']),
      totalFiles: serializer.fromJson<int>(json['totalFiles']),
      completedFiles: serializer.fromJson<int>(json['completedFiles']),
      totalBytes: serializer.fromJson<int>(json['totalBytes']),
      downloadedBytes: serializer.fromJson<int>(json['downloadedBytes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'label': serializer.toJson<String>(label),
      'rootPath': serializer.toJson<String>(rootPath),
      'targetPath': serializer.toJson<String>(targetPath),
      'state': serializer.toJson<String>(state),
      'totalFiles': serializer.toJson<int>(totalFiles),
      'completedFiles': serializer.toJson<int>(completedFiles),
      'totalBytes': serializer.toJson<int>(totalBytes),
      'downloadedBytes': serializer.toJson<int>(downloadedBytes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DownloadGroup copyWith({
    String? id,
    String? label,
    String? rootPath,
    String? targetPath,
    String? state,
    int? totalFiles,
    int? completedFiles,
    int? totalBytes,
    int? downloadedBytes,
    DateTime? createdAt,
  }) => DownloadGroup(
    id: id ?? this.id,
    label: label ?? this.label,
    rootPath: rootPath ?? this.rootPath,
    targetPath: targetPath ?? this.targetPath,
    state: state ?? this.state,
    totalFiles: totalFiles ?? this.totalFiles,
    completedFiles: completedFiles ?? this.completedFiles,
    totalBytes: totalBytes ?? this.totalBytes,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    createdAt: createdAt ?? this.createdAt,
  );
  DownloadGroup copyWithCompanion(DownloadGroupsCompanion data) {
    return DownloadGroup(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      rootPath: data.rootPath.present ? data.rootPath.value : this.rootPath,
      targetPath: data.targetPath.present
          ? data.targetPath.value
          : this.targetPath,
      state: data.state.present ? data.state.value : this.state,
      totalFiles: data.totalFiles.present
          ? data.totalFiles.value
          : this.totalFiles,
      completedFiles: data.completedFiles.present
          ? data.completedFiles.value
          : this.completedFiles,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadGroup(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('rootPath: $rootPath, ')
          ..write('targetPath: $targetPath, ')
          ..write('state: $state, ')
          ..write('totalFiles: $totalFiles, ')
          ..write('completedFiles: $completedFiles, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    rootPath,
    targetPath,
    state,
    totalFiles,
    completedFiles,
    totalBytes,
    downloadedBytes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadGroup &&
          other.id == this.id &&
          other.label == this.label &&
          other.rootPath == this.rootPath &&
          other.targetPath == this.targetPath &&
          other.state == this.state &&
          other.totalFiles == this.totalFiles &&
          other.completedFiles == this.completedFiles &&
          other.totalBytes == this.totalBytes &&
          other.downloadedBytes == this.downloadedBytes &&
          other.createdAt == this.createdAt);
}

class DownloadGroupsCompanion extends UpdateCompanion<DownloadGroup> {
  final Value<String> id;
  final Value<String> label;
  final Value<String> rootPath;
  final Value<String> targetPath;
  final Value<String> state;
  final Value<int> totalFiles;
  final Value<int> completedFiles;
  final Value<int> totalBytes;
  final Value<int> downloadedBytes;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DownloadGroupsCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.rootPath = const Value.absent(),
    this.targetPath = const Value.absent(),
    this.state = const Value.absent(),
    this.totalFiles = const Value.absent(),
    this.completedFiles = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadGroupsCompanion.insert({
    required String id,
    required String label,
    required String rootPath,
    required String targetPath,
    this.state = const Value.absent(),
    this.totalFiles = const Value.absent(),
    this.completedFiles = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       label = Value(label),
       rootPath = Value(rootPath),
       targetPath = Value(targetPath);
  static Insertable<DownloadGroup> custom({
    Expression<String>? id,
    Expression<String>? label,
    Expression<String>? rootPath,
    Expression<String>? targetPath,
    Expression<String>? state,
    Expression<int>? totalFiles,
    Expression<int>? completedFiles,
    Expression<int>? totalBytes,
    Expression<int>? downloadedBytes,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (rootPath != null) 'root_path': rootPath,
      if (targetPath != null) 'target_path': targetPath,
      if (state != null) 'state': state,
      if (totalFiles != null) 'total_files': totalFiles,
      if (completedFiles != null) 'completed_files': completedFiles,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadGroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? label,
    Value<String>? rootPath,
    Value<String>? targetPath,
    Value<String>? state,
    Value<int>? totalFiles,
    Value<int>? completedFiles,
    Value<int>? totalBytes,
    Value<int>? downloadedBytes,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return DownloadGroupsCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      rootPath: rootPath ?? this.rootPath,
      targetPath: targetPath ?? this.targetPath,
      state: state ?? this.state,
      totalFiles: totalFiles ?? this.totalFiles,
      completedFiles: completedFiles ?? this.completedFiles,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
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
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (rootPath.present) {
      map['root_path'] = Variable<String>(rootPath.value);
    }
    if (targetPath.present) {
      map['target_path'] = Variable<String>(targetPath.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (totalFiles.present) {
      map['total_files'] = Variable<int>(totalFiles.value);
    }
    if (completedFiles.present) {
      map['completed_files'] = Variable<int>(completedFiles.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadGroupsCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('rootPath: $rootPath, ')
          ..write('targetPath: $targetPath, ')
          ..write('state: $state, ')
          ..write('totalFiles: $totalFiles, ')
          ..write('completedFiles: $completedFiles, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, Download> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES peers (id)',
    ),
  );
  static const VerificationMeta _shareIdMeta = const VerificationMeta(
    'shareId',
  );
  @override
  late final GeneratedColumn<String> shareId = GeneratedColumn<String>(
    'share_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relativePathMeta = const VerificationMeta(
    'relativePath',
  );
  @override
  late final GeneratedColumn<String> relativePath = GeneratedColumn<String>(
    'relative_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetPathMeta = const VerificationMeta(
    'targetPath',
  );
  @override
  late final GeneratedColumn<String> targetPath = GeneratedColumn<String>(
    'target_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES download_groups (id)',
    ),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pausedMeta = const VerificationMeta('paused');
  @override
  late final GeneratedColumn<bool> paused = GeneratedColumn<bool>(
    'paused',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("paused" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _totalBytesMeta = const VerificationMeta(
    'totalBytes',
  );
  @override
  late final GeneratedColumn<int> totalBytes = GeneratedColumn<int>(
    'total_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _downloadedBytesMeta = const VerificationMeta(
    'downloadedBytes',
  );
  @override
  late final GeneratedColumn<int> downloadedBytes = GeneratedColumn<int>(
    'downloaded_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _inFlightBytesMeta = const VerificationMeta(
    'inFlightBytes',
  );
  @override
  late final GeneratedColumn<int> inFlightBytes = GeneratedColumn<int>(
    'in_flight_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    peerId,
    shareId,
    entryId,
    relativePath,
    targetPath,
    state,
    groupId,
    priority,
    paused,
    totalBytes,
    downloadedBytes,
    inFlightBytes,
    errorMessage,
    createdAt,
    updatedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<Download> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_peerIdMeta);
    }
    if (data.containsKey('share_id')) {
      context.handle(
        _shareIdMeta,
        shareId.isAcceptableOrUnknown(data['share_id']!, _shareIdMeta),
      );
    } else if (isInserting) {
      context.missing(_shareIdMeta);
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('relative_path')) {
      context.handle(
        _relativePathMeta,
        relativePath.isAcceptableOrUnknown(
          data['relative_path']!,
          _relativePathMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_relativePathMeta);
    }
    if (data.containsKey('target_path')) {
      context.handle(
        _targetPathMeta,
        targetPath.isAcceptableOrUnknown(data['target_path']!, _targetPathMeta),
      );
    } else if (isInserting) {
      context.missing(_targetPathMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('paused')) {
      context.handle(
        _pausedMeta,
        paused.isAcceptableOrUnknown(data['paused']!, _pausedMeta),
      );
    }
    if (data.containsKey('total_bytes')) {
      context.handle(
        _totalBytesMeta,
        totalBytes.isAcceptableOrUnknown(data['total_bytes']!, _totalBytesMeta),
      );
    }
    if (data.containsKey('downloaded_bytes')) {
      context.handle(
        _downloadedBytesMeta,
        downloadedBytes.isAcceptableOrUnknown(
          data['downloaded_bytes']!,
          _downloadedBytesMeta,
        ),
      );
    }
    if (data.containsKey('in_flight_bytes')) {
      context.handle(
        _inFlightBytesMeta,
        inFlightBytes.isAcceptableOrUnknown(
          data['in_flight_bytes']!,
          _inFlightBytesMeta,
        ),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Download map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Download(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      )!,
      shareId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}share_id'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      relativePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relative_path'],
      )!,
      targetPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_path'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      paused: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}paused'],
      )!,
      totalBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_bytes'],
      )!,
      downloadedBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}downloaded_bytes'],
      )!,
      inFlightBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}in_flight_bytes'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }
}

class Download extends DataClass implements Insertable<Download> {
  final String id;
  final String peerId;
  final String shareId;
  final String entryId;
  final String relativePath;
  final String targetPath;
  final String state;
  final String? groupId;
  final int priority;
  final bool paused;
  final int totalBytes;
  final int downloadedBytes;
  final int inFlightBytes;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  const Download({
    required this.id,
    required this.peerId,
    required this.shareId,
    required this.entryId,
    required this.relativePath,
    required this.targetPath,
    required this.state,
    this.groupId,
    required this.priority,
    required this.paused,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.inFlightBytes,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['peer_id'] = Variable<String>(peerId);
    map['share_id'] = Variable<String>(shareId);
    map['entry_id'] = Variable<String>(entryId);
    map['relative_path'] = Variable<String>(relativePath);
    map['target_path'] = Variable<String>(targetPath);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    map['priority'] = Variable<int>(priority);
    map['paused'] = Variable<bool>(paused);
    map['total_bytes'] = Variable<int>(totalBytes);
    map['downloaded_bytes'] = Variable<int>(downloadedBytes);
    map['in_flight_bytes'] = Variable<int>(inFlightBytes);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      id: Value(id),
      peerId: Value(peerId),
      shareId: Value(shareId),
      entryId: Value(entryId),
      relativePath: Value(relativePath),
      targetPath: Value(targetPath),
      state: Value(state),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      priority: Value(priority),
      paused: Value(paused),
      totalBytes: Value(totalBytes),
      downloadedBytes: Value(downloadedBytes),
      inFlightBytes: Value(inFlightBytes),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory Download.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Download(
      id: serializer.fromJson<String>(json['id']),
      peerId: serializer.fromJson<String>(json['peerId']),
      shareId: serializer.fromJson<String>(json['shareId']),
      entryId: serializer.fromJson<String>(json['entryId']),
      relativePath: serializer.fromJson<String>(json['relativePath']),
      targetPath: serializer.fromJson<String>(json['targetPath']),
      state: serializer.fromJson<String>(json['state']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      priority: serializer.fromJson<int>(json['priority']),
      paused: serializer.fromJson<bool>(json['paused']),
      totalBytes: serializer.fromJson<int>(json['totalBytes']),
      downloadedBytes: serializer.fromJson<int>(json['downloadedBytes']),
      inFlightBytes: serializer.fromJson<int>(json['inFlightBytes']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'peerId': serializer.toJson<String>(peerId),
      'shareId': serializer.toJson<String>(shareId),
      'entryId': serializer.toJson<String>(entryId),
      'relativePath': serializer.toJson<String>(relativePath),
      'targetPath': serializer.toJson<String>(targetPath),
      'state': serializer.toJson<String>(state),
      'groupId': serializer.toJson<String?>(groupId),
      'priority': serializer.toJson<int>(priority),
      'paused': serializer.toJson<bool>(paused),
      'totalBytes': serializer.toJson<int>(totalBytes),
      'downloadedBytes': serializer.toJson<int>(downloadedBytes),
      'inFlightBytes': serializer.toJson<int>(inFlightBytes),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  Download copyWith({
    String? id,
    String? peerId,
    String? shareId,
    String? entryId,
    String? relativePath,
    String? targetPath,
    String? state,
    Value<String?> groupId = const Value.absent(),
    int? priority,
    bool? paused,
    int? totalBytes,
    int? downloadedBytes,
    int? inFlightBytes,
    Value<String?> errorMessage = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => Download(
    id: id ?? this.id,
    peerId: peerId ?? this.peerId,
    shareId: shareId ?? this.shareId,
    entryId: entryId ?? this.entryId,
    relativePath: relativePath ?? this.relativePath,
    targetPath: targetPath ?? this.targetPath,
    state: state ?? this.state,
    groupId: groupId.present ? groupId.value : this.groupId,
    priority: priority ?? this.priority,
    paused: paused ?? this.paused,
    totalBytes: totalBytes ?? this.totalBytes,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    inFlightBytes: inFlightBytes ?? this.inFlightBytes,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  Download copyWithCompanion(DownloadsCompanion data) {
    return Download(
      id: data.id.present ? data.id.value : this.id,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      shareId: data.shareId.present ? data.shareId.value : this.shareId,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      relativePath: data.relativePath.present
          ? data.relativePath.value
          : this.relativePath,
      targetPath: data.targetPath.present
          ? data.targetPath.value
          : this.targetPath,
      state: data.state.present ? data.state.value : this.state,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      priority: data.priority.present ? data.priority.value : this.priority,
      paused: data.paused.present ? data.paused.value : this.paused,
      totalBytes: data.totalBytes.present
          ? data.totalBytes.value
          : this.totalBytes,
      downloadedBytes: data.downloadedBytes.present
          ? data.downloadedBytes.value
          : this.downloadedBytes,
      inFlightBytes: data.inFlightBytes.present
          ? data.inFlightBytes.value
          : this.inFlightBytes,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Download(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('shareId: $shareId, ')
          ..write('entryId: $entryId, ')
          ..write('relativePath: $relativePath, ')
          ..write('targetPath: $targetPath, ')
          ..write('state: $state, ')
          ..write('groupId: $groupId, ')
          ..write('priority: $priority, ')
          ..write('paused: $paused, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('inFlightBytes: $inFlightBytes, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    peerId,
    shareId,
    entryId,
    relativePath,
    targetPath,
    state,
    groupId,
    priority,
    paused,
    totalBytes,
    downloadedBytes,
    inFlightBytes,
    errorMessage,
    createdAt,
    updatedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Download &&
          other.id == this.id &&
          other.peerId == this.peerId &&
          other.shareId == this.shareId &&
          other.entryId == this.entryId &&
          other.relativePath == this.relativePath &&
          other.targetPath == this.targetPath &&
          other.state == this.state &&
          other.groupId == this.groupId &&
          other.priority == this.priority &&
          other.paused == this.paused &&
          other.totalBytes == this.totalBytes &&
          other.downloadedBytes == this.downloadedBytes &&
          other.inFlightBytes == this.inFlightBytes &&
          other.errorMessage == this.errorMessage &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.completedAt == this.completedAt);
}

class DownloadsCompanion extends UpdateCompanion<Download> {
  final Value<String> id;
  final Value<String> peerId;
  final Value<String> shareId;
  final Value<String> entryId;
  final Value<String> relativePath;
  final Value<String> targetPath;
  final Value<String> state;
  final Value<String?> groupId;
  final Value<int> priority;
  final Value<bool> paused;
  final Value<int> totalBytes;
  final Value<int> downloadedBytes;
  final Value<int> inFlightBytes;
  final Value<String?> errorMessage;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const DownloadsCompanion({
    this.id = const Value.absent(),
    this.peerId = const Value.absent(),
    this.shareId = const Value.absent(),
    this.entryId = const Value.absent(),
    this.relativePath = const Value.absent(),
    this.targetPath = const Value.absent(),
    this.state = const Value.absent(),
    this.groupId = const Value.absent(),
    this.priority = const Value.absent(),
    this.paused = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.inFlightBytes = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadsCompanion.insert({
    required String id,
    required String peerId,
    required String shareId,
    required String entryId,
    required String relativePath,
    required String targetPath,
    this.state = const Value.absent(),
    this.groupId = const Value.absent(),
    this.priority = const Value.absent(),
    this.paused = const Value.absent(),
    this.totalBytes = const Value.absent(),
    this.downloadedBytes = const Value.absent(),
    this.inFlightBytes = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       peerId = Value(peerId),
       shareId = Value(shareId),
       entryId = Value(entryId),
       relativePath = Value(relativePath),
       targetPath = Value(targetPath);
  static Insertable<Download> custom({
    Expression<String>? id,
    Expression<String>? peerId,
    Expression<String>? shareId,
    Expression<String>? entryId,
    Expression<String>? relativePath,
    Expression<String>? targetPath,
    Expression<String>? state,
    Expression<String>? groupId,
    Expression<int>? priority,
    Expression<bool>? paused,
    Expression<int>? totalBytes,
    Expression<int>? downloadedBytes,
    Expression<int>? inFlightBytes,
    Expression<String>? errorMessage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (peerId != null) 'peer_id': peerId,
      if (shareId != null) 'share_id': shareId,
      if (entryId != null) 'entry_id': entryId,
      if (relativePath != null) 'relative_path': relativePath,
      if (targetPath != null) 'target_path': targetPath,
      if (state != null) 'state': state,
      if (groupId != null) 'group_id': groupId,
      if (priority != null) 'priority': priority,
      if (paused != null) 'paused': paused,
      if (totalBytes != null) 'total_bytes': totalBytes,
      if (downloadedBytes != null) 'downloaded_bytes': downloadedBytes,
      if (inFlightBytes != null) 'in_flight_bytes': inFlightBytes,
      if (errorMessage != null) 'error_message': errorMessage,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadsCompanion copyWith({
    Value<String>? id,
    Value<String>? peerId,
    Value<String>? shareId,
    Value<String>? entryId,
    Value<String>? relativePath,
    Value<String>? targetPath,
    Value<String>? state,
    Value<String?>? groupId,
    Value<int>? priority,
    Value<bool>? paused,
    Value<int>? totalBytes,
    Value<int>? downloadedBytes,
    Value<int>? inFlightBytes,
    Value<String?>? errorMessage,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return DownloadsCompanion(
      id: id ?? this.id,
      peerId: peerId ?? this.peerId,
      shareId: shareId ?? this.shareId,
      entryId: entryId ?? this.entryId,
      relativePath: relativePath ?? this.relativePath,
      targetPath: targetPath ?? this.targetPath,
      state: state ?? this.state,
      groupId: groupId ?? this.groupId,
      priority: priority ?? this.priority,
      paused: paused ?? this.paused,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      inFlightBytes: inFlightBytes ?? this.inFlightBytes,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (shareId.present) {
      map['share_id'] = Variable<String>(shareId.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (relativePath.present) {
      map['relative_path'] = Variable<String>(relativePath.value);
    }
    if (targetPath.present) {
      map['target_path'] = Variable<String>(targetPath.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (paused.present) {
      map['paused'] = Variable<bool>(paused.value);
    }
    if (totalBytes.present) {
      map['total_bytes'] = Variable<int>(totalBytes.value);
    }
    if (downloadedBytes.present) {
      map['downloaded_bytes'] = Variable<int>(downloadedBytes.value);
    }
    if (inFlightBytes.present) {
      map['in_flight_bytes'] = Variable<int>(inFlightBytes.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('id: $id, ')
          ..write('peerId: $peerId, ')
          ..write('shareId: $shareId, ')
          ..write('entryId: $entryId, ')
          ..write('relativePath: $relativePath, ')
          ..write('targetPath: $targetPath, ')
          ..write('state: $state, ')
          ..write('groupId: $groupId, ')
          ..write('priority: $priority, ')
          ..write('paused: $paused, ')
          ..write('totalBytes: $totalBytes, ')
          ..write('downloadedBytes: $downloadedBytes, ')
          ..write('inFlightBytes: $inFlightBytes, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DownloadChunksTable extends DownloadChunks
    with TableInfo<$DownloadChunksTable, DownloadChunk> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadChunksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _downloadIdMeta = const VerificationMeta(
    'downloadId',
  );
  @override
  late final GeneratedColumn<String> downloadId = GeneratedColumn<String>(
    'download_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES downloads (id)',
    ),
  );
  static const VerificationMeta _chunkIndexMeta = const VerificationMeta(
    'chunkIndex',
  );
  @override
  late final GeneratedColumn<int> chunkIndex = GeneratedColumn<int>(
    'chunk_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _offsetMeta = const VerificationMeta('offset');
  @override
  late final GeneratedColumn<int> offset = GeneratedColumn<int>(
    'offset',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lengthMeta = const VerificationMeta('length');
  @override
  late final GeneratedColumn<int> length = GeneratedColumn<int>(
    'length',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourcePeerIdMeta = const VerificationMeta(
    'sourcePeerId',
  );
  @override
  late final GeneratedColumn<String> sourcePeerId = GeneratedColumn<String>(
    'source_peer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    downloadId,
    chunkIndex,
    hash,
    offset,
    length,
    state,
    errorMessage,
    sourcePeerId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'download_chunks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DownloadChunk> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('download_id')) {
      context.handle(
        _downloadIdMeta,
        downloadId.isAcceptableOrUnknown(data['download_id']!, _downloadIdMeta),
      );
    } else if (isInserting) {
      context.missing(_downloadIdMeta);
    }
    if (data.containsKey('chunk_index')) {
      context.handle(
        _chunkIndexMeta,
        chunkIndex.isAcceptableOrUnknown(data['chunk_index']!, _chunkIndexMeta),
      );
    } else if (isInserting) {
      context.missing(_chunkIndexMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('offset')) {
      context.handle(
        _offsetMeta,
        offset.isAcceptableOrUnknown(data['offset']!, _offsetMeta),
      );
    } else if (isInserting) {
      context.missing(_offsetMeta);
    }
    if (data.containsKey('length')) {
      context.handle(
        _lengthMeta,
        length.isAcceptableOrUnknown(data['length']!, _lengthMeta),
      );
    } else if (isInserting) {
      context.missing(_lengthMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('source_peer_id')) {
      context.handle(
        _sourcePeerIdMeta,
        sourcePeerId.isAcceptableOrUnknown(
          data['source_peer_id']!,
          _sourcePeerIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DownloadChunk map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DownloadChunk(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      downloadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_id'],
      )!,
      chunkIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chunk_index'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      offset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset'],
      )!,
      length: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}length'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      sourcePeerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_peer_id'],
      ),
    );
  }

  @override
  $DownloadChunksTable createAlias(String alias) {
    return $DownloadChunksTable(attachedDatabase, alias);
  }
}

class DownloadChunk extends DataClass implements Insertable<DownloadChunk> {
  final int id;
  final String downloadId;
  final int chunkIndex;
  final String hash;
  final int offset;
  final int length;
  final String state;
  final String? errorMessage;
  final String? sourcePeerId;
  const DownloadChunk({
    required this.id,
    required this.downloadId,
    required this.chunkIndex,
    required this.hash,
    required this.offset,
    required this.length,
    required this.state,
    this.errorMessage,
    this.sourcePeerId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['download_id'] = Variable<String>(downloadId);
    map['chunk_index'] = Variable<int>(chunkIndex);
    map['hash'] = Variable<String>(hash);
    map['offset'] = Variable<int>(offset);
    map['length'] = Variable<int>(length);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || sourcePeerId != null) {
      map['source_peer_id'] = Variable<String>(sourcePeerId);
    }
    return map;
  }

  DownloadChunksCompanion toCompanion(bool nullToAbsent) {
    return DownloadChunksCompanion(
      id: Value(id),
      downloadId: Value(downloadId),
      chunkIndex: Value(chunkIndex),
      hash: Value(hash),
      offset: Value(offset),
      length: Value(length),
      state: Value(state),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      sourcePeerId: sourcePeerId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourcePeerId),
    );
  }

  factory DownloadChunk.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DownloadChunk(
      id: serializer.fromJson<int>(json['id']),
      downloadId: serializer.fromJson<String>(json['downloadId']),
      chunkIndex: serializer.fromJson<int>(json['chunkIndex']),
      hash: serializer.fromJson<String>(json['hash']),
      offset: serializer.fromJson<int>(json['offset']),
      length: serializer.fromJson<int>(json['length']),
      state: serializer.fromJson<String>(json['state']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      sourcePeerId: serializer.fromJson<String?>(json['sourcePeerId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'downloadId': serializer.toJson<String>(downloadId),
      'chunkIndex': serializer.toJson<int>(chunkIndex),
      'hash': serializer.toJson<String>(hash),
      'offset': serializer.toJson<int>(offset),
      'length': serializer.toJson<int>(length),
      'state': serializer.toJson<String>(state),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'sourcePeerId': serializer.toJson<String?>(sourcePeerId),
    };
  }

  DownloadChunk copyWith({
    int? id,
    String? downloadId,
    int? chunkIndex,
    String? hash,
    int? offset,
    int? length,
    String? state,
    Value<String?> errorMessage = const Value.absent(),
    Value<String?> sourcePeerId = const Value.absent(),
  }) => DownloadChunk(
    id: id ?? this.id,
    downloadId: downloadId ?? this.downloadId,
    chunkIndex: chunkIndex ?? this.chunkIndex,
    hash: hash ?? this.hash,
    offset: offset ?? this.offset,
    length: length ?? this.length,
    state: state ?? this.state,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    sourcePeerId: sourcePeerId.present ? sourcePeerId.value : this.sourcePeerId,
  );
  DownloadChunk copyWithCompanion(DownloadChunksCompanion data) {
    return DownloadChunk(
      id: data.id.present ? data.id.value : this.id,
      downloadId: data.downloadId.present
          ? data.downloadId.value
          : this.downloadId,
      chunkIndex: data.chunkIndex.present
          ? data.chunkIndex.value
          : this.chunkIndex,
      hash: data.hash.present ? data.hash.value : this.hash,
      offset: data.offset.present ? data.offset.value : this.offset,
      length: data.length.present ? data.length.value : this.length,
      state: data.state.present ? data.state.value : this.state,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      sourcePeerId: data.sourcePeerId.present
          ? data.sourcePeerId.value
          : this.sourcePeerId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DownloadChunk(')
          ..write('id: $id, ')
          ..write('downloadId: $downloadId, ')
          ..write('chunkIndex: $chunkIndex, ')
          ..write('hash: $hash, ')
          ..write('offset: $offset, ')
          ..write('length: $length, ')
          ..write('state: $state, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('sourcePeerId: $sourcePeerId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    downloadId,
    chunkIndex,
    hash,
    offset,
    length,
    state,
    errorMessage,
    sourcePeerId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DownloadChunk &&
          other.id == this.id &&
          other.downloadId == this.downloadId &&
          other.chunkIndex == this.chunkIndex &&
          other.hash == this.hash &&
          other.offset == this.offset &&
          other.length == this.length &&
          other.state == this.state &&
          other.errorMessage == this.errorMessage &&
          other.sourcePeerId == this.sourcePeerId);
}

class DownloadChunksCompanion extends UpdateCompanion<DownloadChunk> {
  final Value<int> id;
  final Value<String> downloadId;
  final Value<int> chunkIndex;
  final Value<String> hash;
  final Value<int> offset;
  final Value<int> length;
  final Value<String> state;
  final Value<String?> errorMessage;
  final Value<String?> sourcePeerId;
  const DownloadChunksCompanion({
    this.id = const Value.absent(),
    this.downloadId = const Value.absent(),
    this.chunkIndex = const Value.absent(),
    this.hash = const Value.absent(),
    this.offset = const Value.absent(),
    this.length = const Value.absent(),
    this.state = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.sourcePeerId = const Value.absent(),
  });
  DownloadChunksCompanion.insert({
    this.id = const Value.absent(),
    required String downloadId,
    required int chunkIndex,
    required String hash,
    required int offset,
    required int length,
    this.state = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.sourcePeerId = const Value.absent(),
  }) : downloadId = Value(downloadId),
       chunkIndex = Value(chunkIndex),
       hash = Value(hash),
       offset = Value(offset),
       length = Value(length);
  static Insertable<DownloadChunk> custom({
    Expression<int>? id,
    Expression<String>? downloadId,
    Expression<int>? chunkIndex,
    Expression<String>? hash,
    Expression<int>? offset,
    Expression<int>? length,
    Expression<String>? state,
    Expression<String>? errorMessage,
    Expression<String>? sourcePeerId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (downloadId != null) 'download_id': downloadId,
      if (chunkIndex != null) 'chunk_index': chunkIndex,
      if (hash != null) 'hash': hash,
      if (offset != null) 'offset': offset,
      if (length != null) 'length': length,
      if (state != null) 'state': state,
      if (errorMessage != null) 'error_message': errorMessage,
      if (sourcePeerId != null) 'source_peer_id': sourcePeerId,
    });
  }

  DownloadChunksCompanion copyWith({
    Value<int>? id,
    Value<String>? downloadId,
    Value<int>? chunkIndex,
    Value<String>? hash,
    Value<int>? offset,
    Value<int>? length,
    Value<String>? state,
    Value<String?>? errorMessage,
    Value<String?>? sourcePeerId,
  }) {
    return DownloadChunksCompanion(
      id: id ?? this.id,
      downloadId: downloadId ?? this.downloadId,
      chunkIndex: chunkIndex ?? this.chunkIndex,
      hash: hash ?? this.hash,
      offset: offset ?? this.offset,
      length: length ?? this.length,
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      sourcePeerId: sourcePeerId ?? this.sourcePeerId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (downloadId.present) {
      map['download_id'] = Variable<String>(downloadId.value);
    }
    if (chunkIndex.present) {
      map['chunk_index'] = Variable<int>(chunkIndex.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (offset.present) {
      map['offset'] = Variable<int>(offset.value);
    }
    if (length.present) {
      map['length'] = Variable<int>(length.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (sourcePeerId.present) {
      map['source_peer_id'] = Variable<String>(sourcePeerId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadChunksCompanion(')
          ..write('id: $id, ')
          ..write('downloadId: $downloadId, ')
          ..write('chunkIndex: $chunkIndex, ')
          ..write('hash: $hash, ')
          ..write('offset: $offset, ')
          ..write('length: $length, ')
          ..write('state: $state, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('sourcePeerId: $sourcePeerId')
          ..write(')'))
        .toString();
  }
}

class $TransfersTable extends Transfers
    with TableInfo<$TransfersTable, Transfer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransfersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _peerIdMeta = const VerificationMeta('peerId');
  @override
  late final GeneratedColumn<String> peerId = GeneratedColumn<String>(
    'peer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteAddressMeta = const VerificationMeta(
    'remoteAddress',
  );
  @override
  late final GeneratedColumn<String> remoteAddress = GeneratedColumn<String>(
    'remote_address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chunkHashMeta = const VerificationMeta(
    'chunkHash',
  );
  @override
  late final GeneratedColumn<String> chunkHash = GeneratedColumn<String>(
    'chunk_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _bytesTotalMeta = const VerificationMeta(
    'bytesTotal',
  );
  @override
  late final GeneratedColumn<int> bytesTotal = GeneratedColumn<int>(
    'bytes_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bytesTransferredMeta = const VerificationMeta(
    'bytesTransferred',
  );
  @override
  late final GeneratedColumn<int> bytesTransferred = GeneratedColumn<int>(
    'bytes_transferred',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _rateBytesPerSecondMeta =
      const VerificationMeta('rateBytesPerSecond');
  @override
  late final GeneratedColumn<int> rateBytesPerSecond = GeneratedColumn<int>(
    'rate_bytes_per_second',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    direction,
    peerId,
    remoteAddress,
    entryId,
    chunkHash,
    bytesTotal,
    bytesTransferred,
    rateBytesPerSecond,
    state,
    errorMessage,
    startedAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transfers';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transfer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('peer_id')) {
      context.handle(
        _peerIdMeta,
        peerId.isAcceptableOrUnknown(data['peer_id']!, _peerIdMeta),
      );
    }
    if (data.containsKey('remote_address')) {
      context.handle(
        _remoteAddressMeta,
        remoteAddress.isAcceptableOrUnknown(
          data['remote_address']!,
          _remoteAddressMeta,
        ),
      );
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    }
    if (data.containsKey('chunk_hash')) {
      context.handle(
        _chunkHashMeta,
        chunkHash.isAcceptableOrUnknown(data['chunk_hash']!, _chunkHashMeta),
      );
    }
    if (data.containsKey('bytes_total')) {
      context.handle(
        _bytesTotalMeta,
        bytesTotal.isAcceptableOrUnknown(data['bytes_total']!, _bytesTotalMeta),
      );
    }
    if (data.containsKey('bytes_transferred')) {
      context.handle(
        _bytesTransferredMeta,
        bytesTransferred.isAcceptableOrUnknown(
          data['bytes_transferred']!,
          _bytesTransferredMeta,
        ),
      );
    }
    if (data.containsKey('rate_bytes_per_second')) {
      context.handle(
        _rateBytesPerSecondMeta,
        rateBytesPerSecond.isAcceptableOrUnknown(
          data['rate_bytes_per_second']!,
          _rateBytesPerSecondMeta,
        ),
      );
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transfer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transfer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      peerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_id'],
      ),
      remoteAddress: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_address'],
      ),
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      ),
      chunkHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chunk_hash'],
      ),
      bytesTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_total'],
      )!,
      bytesTransferred: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_transferred'],
      )!,
      rateBytesPerSecond: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rate_bytes_per_second'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TransfersTable createAlias(String alias) {
    return $TransfersTable(attachedDatabase, alias);
  }
}

class Transfer extends DataClass implements Insertable<Transfer> {
  final int id;
  final String direction;
  final String? peerId;
  final String? remoteAddress;
  final String? entryId;
  final String? chunkHash;
  final int bytesTotal;
  final int bytesTransferred;
  final int rateBytesPerSecond;
  final String state;
  final String? errorMessage;
  final DateTime startedAt;
  final DateTime updatedAt;
  const Transfer({
    required this.id,
    required this.direction,
    this.peerId,
    this.remoteAddress,
    this.entryId,
    this.chunkHash,
    required this.bytesTotal,
    required this.bytesTransferred,
    required this.rateBytesPerSecond,
    required this.state,
    this.errorMessage,
    required this.startedAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['direction'] = Variable<String>(direction);
    if (!nullToAbsent || peerId != null) {
      map['peer_id'] = Variable<String>(peerId);
    }
    if (!nullToAbsent || remoteAddress != null) {
      map['remote_address'] = Variable<String>(remoteAddress);
    }
    if (!nullToAbsent || entryId != null) {
      map['entry_id'] = Variable<String>(entryId);
    }
    if (!nullToAbsent || chunkHash != null) {
      map['chunk_hash'] = Variable<String>(chunkHash);
    }
    map['bytes_total'] = Variable<int>(bytesTotal);
    map['bytes_transferred'] = Variable<int>(bytesTransferred);
    map['rate_bytes_per_second'] = Variable<int>(rateBytesPerSecond);
    map['state'] = Variable<String>(state);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TransfersCompanion toCompanion(bool nullToAbsent) {
    return TransfersCompanion(
      id: Value(id),
      direction: Value(direction),
      peerId: peerId == null && nullToAbsent
          ? const Value.absent()
          : Value(peerId),
      remoteAddress: remoteAddress == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteAddress),
      entryId: entryId == null && nullToAbsent
          ? const Value.absent()
          : Value(entryId),
      chunkHash: chunkHash == null && nullToAbsent
          ? const Value.absent()
          : Value(chunkHash),
      bytesTotal: Value(bytesTotal),
      bytesTransferred: Value(bytesTransferred),
      rateBytesPerSecond: Value(rateBytesPerSecond),
      state: Value(state),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      startedAt: Value(startedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Transfer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transfer(
      id: serializer.fromJson<int>(json['id']),
      direction: serializer.fromJson<String>(json['direction']),
      peerId: serializer.fromJson<String?>(json['peerId']),
      remoteAddress: serializer.fromJson<String?>(json['remoteAddress']),
      entryId: serializer.fromJson<String?>(json['entryId']),
      chunkHash: serializer.fromJson<String?>(json['chunkHash']),
      bytesTotal: serializer.fromJson<int>(json['bytesTotal']),
      bytesTransferred: serializer.fromJson<int>(json['bytesTransferred']),
      rateBytesPerSecond: serializer.fromJson<int>(json['rateBytesPerSecond']),
      state: serializer.fromJson<String>(json['state']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'direction': serializer.toJson<String>(direction),
      'peerId': serializer.toJson<String?>(peerId),
      'remoteAddress': serializer.toJson<String?>(remoteAddress),
      'entryId': serializer.toJson<String?>(entryId),
      'chunkHash': serializer.toJson<String?>(chunkHash),
      'bytesTotal': serializer.toJson<int>(bytesTotal),
      'bytesTransferred': serializer.toJson<int>(bytesTransferred),
      'rateBytesPerSecond': serializer.toJson<int>(rateBytesPerSecond),
      'state': serializer.toJson<String>(state),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Transfer copyWith({
    int? id,
    String? direction,
    Value<String?> peerId = const Value.absent(),
    Value<String?> remoteAddress = const Value.absent(),
    Value<String?> entryId = const Value.absent(),
    Value<String?> chunkHash = const Value.absent(),
    int? bytesTotal,
    int? bytesTransferred,
    int? rateBytesPerSecond,
    String? state,
    Value<String?> errorMessage = const Value.absent(),
    DateTime? startedAt,
    DateTime? updatedAt,
  }) => Transfer(
    id: id ?? this.id,
    direction: direction ?? this.direction,
    peerId: peerId.present ? peerId.value : this.peerId,
    remoteAddress: remoteAddress.present
        ? remoteAddress.value
        : this.remoteAddress,
    entryId: entryId.present ? entryId.value : this.entryId,
    chunkHash: chunkHash.present ? chunkHash.value : this.chunkHash,
    bytesTotal: bytesTotal ?? this.bytesTotal,
    bytesTransferred: bytesTransferred ?? this.bytesTransferred,
    rateBytesPerSecond: rateBytesPerSecond ?? this.rateBytesPerSecond,
    state: state ?? this.state,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    startedAt: startedAt ?? this.startedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Transfer copyWithCompanion(TransfersCompanion data) {
    return Transfer(
      id: data.id.present ? data.id.value : this.id,
      direction: data.direction.present ? data.direction.value : this.direction,
      peerId: data.peerId.present ? data.peerId.value : this.peerId,
      remoteAddress: data.remoteAddress.present
          ? data.remoteAddress.value
          : this.remoteAddress,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      chunkHash: data.chunkHash.present ? data.chunkHash.value : this.chunkHash,
      bytesTotal: data.bytesTotal.present
          ? data.bytesTotal.value
          : this.bytesTotal,
      bytesTransferred: data.bytesTransferred.present
          ? data.bytesTransferred.value
          : this.bytesTransferred,
      rateBytesPerSecond: data.rateBytesPerSecond.present
          ? data.rateBytesPerSecond.value
          : this.rateBytesPerSecond,
      state: data.state.present ? data.state.value : this.state,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transfer(')
          ..write('id: $id, ')
          ..write('direction: $direction, ')
          ..write('peerId: $peerId, ')
          ..write('remoteAddress: $remoteAddress, ')
          ..write('entryId: $entryId, ')
          ..write('chunkHash: $chunkHash, ')
          ..write('bytesTotal: $bytesTotal, ')
          ..write('bytesTransferred: $bytesTransferred, ')
          ..write('rateBytesPerSecond: $rateBytesPerSecond, ')
          ..write('state: $state, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('startedAt: $startedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    direction,
    peerId,
    remoteAddress,
    entryId,
    chunkHash,
    bytesTotal,
    bytesTransferred,
    rateBytesPerSecond,
    state,
    errorMessage,
    startedAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transfer &&
          other.id == this.id &&
          other.direction == this.direction &&
          other.peerId == this.peerId &&
          other.remoteAddress == this.remoteAddress &&
          other.entryId == this.entryId &&
          other.chunkHash == this.chunkHash &&
          other.bytesTotal == this.bytesTotal &&
          other.bytesTransferred == this.bytesTransferred &&
          other.rateBytesPerSecond == this.rateBytesPerSecond &&
          other.state == this.state &&
          other.errorMessage == this.errorMessage &&
          other.startedAt == this.startedAt &&
          other.updatedAt == this.updatedAt);
}

class TransfersCompanion extends UpdateCompanion<Transfer> {
  final Value<int> id;
  final Value<String> direction;
  final Value<String?> peerId;
  final Value<String?> remoteAddress;
  final Value<String?> entryId;
  final Value<String?> chunkHash;
  final Value<int> bytesTotal;
  final Value<int> bytesTransferred;
  final Value<int> rateBytesPerSecond;
  final Value<String> state;
  final Value<String?> errorMessage;
  final Value<DateTime> startedAt;
  final Value<DateTime> updatedAt;
  const TransfersCompanion({
    this.id = const Value.absent(),
    this.direction = const Value.absent(),
    this.peerId = const Value.absent(),
    this.remoteAddress = const Value.absent(),
    this.entryId = const Value.absent(),
    this.chunkHash = const Value.absent(),
    this.bytesTotal = const Value.absent(),
    this.bytesTransferred = const Value.absent(),
    this.rateBytesPerSecond = const Value.absent(),
    this.state = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TransfersCompanion.insert({
    this.id = const Value.absent(),
    required String direction,
    this.peerId = const Value.absent(),
    this.remoteAddress = const Value.absent(),
    this.entryId = const Value.absent(),
    this.chunkHash = const Value.absent(),
    this.bytesTotal = const Value.absent(),
    this.bytesTransferred = const Value.absent(),
    this.rateBytesPerSecond = const Value.absent(),
    this.state = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : direction = Value(direction);
  static Insertable<Transfer> custom({
    Expression<int>? id,
    Expression<String>? direction,
    Expression<String>? peerId,
    Expression<String>? remoteAddress,
    Expression<String>? entryId,
    Expression<String>? chunkHash,
    Expression<int>? bytesTotal,
    Expression<int>? bytesTransferred,
    Expression<int>? rateBytesPerSecond,
    Expression<String>? state,
    Expression<String>? errorMessage,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (direction != null) 'direction': direction,
      if (peerId != null) 'peer_id': peerId,
      if (remoteAddress != null) 'remote_address': remoteAddress,
      if (entryId != null) 'entry_id': entryId,
      if (chunkHash != null) 'chunk_hash': chunkHash,
      if (bytesTotal != null) 'bytes_total': bytesTotal,
      if (bytesTransferred != null) 'bytes_transferred': bytesTransferred,
      if (rateBytesPerSecond != null)
        'rate_bytes_per_second': rateBytesPerSecond,
      if (state != null) 'state': state,
      if (errorMessage != null) 'error_message': errorMessage,
      if (startedAt != null) 'started_at': startedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TransfersCompanion copyWith({
    Value<int>? id,
    Value<String>? direction,
    Value<String?>? peerId,
    Value<String?>? remoteAddress,
    Value<String?>? entryId,
    Value<String?>? chunkHash,
    Value<int>? bytesTotal,
    Value<int>? bytesTransferred,
    Value<int>? rateBytesPerSecond,
    Value<String>? state,
    Value<String?>? errorMessage,
    Value<DateTime>? startedAt,
    Value<DateTime>? updatedAt,
  }) {
    return TransfersCompanion(
      id: id ?? this.id,
      direction: direction ?? this.direction,
      peerId: peerId ?? this.peerId,
      remoteAddress: remoteAddress ?? this.remoteAddress,
      entryId: entryId ?? this.entryId,
      chunkHash: chunkHash ?? this.chunkHash,
      bytesTotal: bytesTotal ?? this.bytesTotal,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      rateBytesPerSecond: rateBytesPerSecond ?? this.rateBytesPerSecond,
      state: state ?? this.state,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (peerId.present) {
      map['peer_id'] = Variable<String>(peerId.value);
    }
    if (remoteAddress.present) {
      map['remote_address'] = Variable<String>(remoteAddress.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (chunkHash.present) {
      map['chunk_hash'] = Variable<String>(chunkHash.value);
    }
    if (bytesTotal.present) {
      map['bytes_total'] = Variable<int>(bytesTotal.value);
    }
    if (bytesTransferred.present) {
      map['bytes_transferred'] = Variable<int>(bytesTransferred.value);
    }
    if (rateBytesPerSecond.present) {
      map['rate_bytes_per_second'] = Variable<int>(rateBytesPerSecond.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransfersCompanion(')
          ..write('id: $id, ')
          ..write('direction: $direction, ')
          ..write('peerId: $peerId, ')
          ..write('remoteAddress: $remoteAddress, ')
          ..write('entryId: $entryId, ')
          ..write('chunkHash: $chunkHash, ')
          ..write('bytesTotal: $bytesTotal, ')
          ..write('bytesTransferred: $bytesTransferred, ')
          ..write('rateBytesPerSecond: $rateBytesPerSecond, ')
          ..write('state: $state, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('startedAt: $startedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $SharesTable shares = $SharesTable(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $ChunksTable chunks = $ChunksTable(this);
  late final $PeersTable peers = $PeersTable(this);
  late final $RemoteEntriesCacheTable remoteEntriesCache =
      $RemoteEntriesCacheTable(this);
  late final $RemoteFilesTable remoteFiles = $RemoteFilesTable(this);
  late final $EntrySearchTokensTable entrySearchTokens =
      $EntrySearchTokensTable(this);
  late final $RemoteChunkSourcesTable remoteChunkSources =
      $RemoteChunkSourcesTable(this);
  late final $DownloadGroupsTable downloadGroups = $DownloadGroupsTable(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final $DownloadChunksTable downloadChunks = $DownloadChunksTable(this);
  late final $TransfersTable transfers = $TransfersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settings,
    shares,
    entries,
    chunks,
    peers,
    remoteEntriesCache,
    remoteFiles,
    entrySearchTokens,
    remoteChunkSources,
    downloadGroups,
    downloads,
    downloadChunks,
    transfers,
  ];
}

typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      required String key,
      required String value,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<int> id,
      Value<String> key,
      Value<String> value,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          Setting,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
          Setting,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
              }) => SettingsCompanion(id: id, key: key, value: value),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String key,
                required String value,
              }) => SettingsCompanion.insert(id: id, key: key, value: value),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      Setting,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (Setting, BaseReferences<_$AppDatabase, $SettingsTable, Setting>),
      Setting,
      PrefetchHooks Function()
    >;
typedef $$SharesTableCreateCompanionBuilder =
    SharesCompanion Function({
      required String id,
      required String displayName,
      required String localPath,
      Value<bool> enabled,
      Value<String> scanStatus,
      Value<String> storageType,
      Value<int> totalFiles,
      Value<int> hashedFiles,
      Value<int> totalHashBytes,
      Value<int> hashedBytes,
      Value<String?> currentFile,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$SharesTableUpdateCompanionBuilder =
    SharesCompanion Function({
      Value<String> id,
      Value<String> displayName,
      Value<String> localPath,
      Value<bool> enabled,
      Value<String> scanStatus,
      Value<String> storageType,
      Value<int> totalFiles,
      Value<int> hashedFiles,
      Value<int> totalHashBytes,
      Value<int> hashedBytes,
      Value<String?> currentFile,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$SharesTableReferences
    extends BaseReferences<_$AppDatabase, $SharesTable, Share> {
  $$SharesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EntriesTable, List<Entry>> _entriesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.entries,
    aliasName: 'shares__id__entries__share_id',
  );

  $$EntriesTableProcessedTableManager get entriesRefs {
    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.shareId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_entriesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SharesTableFilterComposer
    extends Composer<_$AppDatabase, $SharesTable> {
  $$SharesTableFilterComposer({
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

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanStatus => $composableBuilder(
    column: $table.scanStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get storageType => $composableBuilder(
    column: $table.storageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalFiles => $composableBuilder(
    column: $table.totalFiles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hashedFiles => $composableBuilder(
    column: $table.hashedFiles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalHashBytes => $composableBuilder(
    column: $table.totalHashBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hashedBytes => $composableBuilder(
    column: $table.hashedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentFile => $composableBuilder(
    column: $table.currentFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> entriesRefs(
    Expression<bool> Function($$EntriesTableFilterComposer f) f,
  ) {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.shareId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SharesTableOrderingComposer
    extends Composer<_$AppDatabase, $SharesTable> {
  $$SharesTableOrderingComposer({
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

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanStatus => $composableBuilder(
    column: $table.scanStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get storageType => $composableBuilder(
    column: $table.storageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalFiles => $composableBuilder(
    column: $table.totalFiles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hashedFiles => $composableBuilder(
    column: $table.hashedFiles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalHashBytes => $composableBuilder(
    column: $table.totalHashBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hashedBytes => $composableBuilder(
    column: $table.hashedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentFile => $composableBuilder(
    column: $table.currentFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SharesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SharesTable> {
  $$SharesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<String> get scanStatus => $composableBuilder(
    column: $table.scanStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get storageType => $composableBuilder(
    column: $table.storageType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalFiles => $composableBuilder(
    column: $table.totalFiles,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hashedFiles => $composableBuilder(
    column: $table.hashedFiles,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalHashBytes => $composableBuilder(
    column: $table.totalHashBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get hashedBytes => $composableBuilder(
    column: $table.hashedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentFile => $composableBuilder(
    column: $table.currentFile,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> entriesRefs<T extends Object>(
    Expression<T> Function($$EntriesTableAnnotationComposer a) f,
  ) {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.shareId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SharesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SharesTable,
          Share,
          $$SharesTableFilterComposer,
          $$SharesTableOrderingComposer,
          $$SharesTableAnnotationComposer,
          $$SharesTableCreateCompanionBuilder,
          $$SharesTableUpdateCompanionBuilder,
          (Share, $$SharesTableReferences),
          Share,
          PrefetchHooks Function({bool entriesRefs})
        > {
  $$SharesTableTableManager(_$AppDatabase db, $SharesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SharesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SharesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SharesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<String> scanStatus = const Value.absent(),
                Value<String> storageType = const Value.absent(),
                Value<int> totalFiles = const Value.absent(),
                Value<int> hashedFiles = const Value.absent(),
                Value<int> totalHashBytes = const Value.absent(),
                Value<int> hashedBytes = const Value.absent(),
                Value<String?> currentFile = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharesCompanion(
                id: id,
                displayName: displayName,
                localPath: localPath,
                enabled: enabled,
                scanStatus: scanStatus,
                storageType: storageType,
                totalFiles: totalFiles,
                hashedFiles: hashedFiles,
                totalHashBytes: totalHashBytes,
                hashedBytes: hashedBytes,
                currentFile: currentFile,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String displayName,
                required String localPath,
                Value<bool> enabled = const Value.absent(),
                Value<String> scanStatus = const Value.absent(),
                Value<String> storageType = const Value.absent(),
                Value<int> totalFiles = const Value.absent(),
                Value<int> hashedFiles = const Value.absent(),
                Value<int> totalHashBytes = const Value.absent(),
                Value<int> hashedBytes = const Value.absent(),
                Value<String?> currentFile = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SharesCompanion.insert(
                id: id,
                displayName: displayName,
                localPath: localPath,
                enabled: enabled,
                scanStatus: scanStatus,
                storageType: storageType,
                totalFiles: totalFiles,
                hashedFiles: hashedFiles,
                totalHashBytes: totalHashBytes,
                hashedBytes: hashedBytes,
                currentFile: currentFile,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$SharesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({entriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (entriesRefs) db.entries],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (entriesRefs)
                    await $_getPrefetchedData<Share, $SharesTable, Entry>(
                      currentTable: table,
                      referencedTable: $$SharesTableReferences
                          ._entriesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SharesTableReferences(db, table, p0).entriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.shareId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SharesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SharesTable,
      Share,
      $$SharesTableFilterComposer,
      $$SharesTableOrderingComposer,
      $$SharesTableAnnotationComposer,
      $$SharesTableCreateCompanionBuilder,
      $$SharesTableUpdateCompanionBuilder,
      (Share, $$SharesTableReferences),
      Share,
      PrefetchHooks Function({bool entriesRefs})
    >;
typedef $$EntriesTableCreateCompanionBuilder =
    EntriesCompanion Function({
      required String id,
      required String shareId,
      required String relativePath,
      required String name,
      Value<bool> isDirectory,
      Value<int> size,
      Value<int> mtimeMs,
      Value<String> hashStatus,
      Value<int?> chunkSize,
      Value<String?> localUri,
      Value<int> rowid,
    });
typedef $$EntriesTableUpdateCompanionBuilder =
    EntriesCompanion Function({
      Value<String> id,
      Value<String> shareId,
      Value<String> relativePath,
      Value<String> name,
      Value<bool> isDirectory,
      Value<int> size,
      Value<int> mtimeMs,
      Value<String> hashStatus,
      Value<int?> chunkSize,
      Value<String?> localUri,
      Value<int> rowid,
    });

final class $$EntriesTableReferences
    extends BaseReferences<_$AppDatabase, $EntriesTable, Entry> {
  $$EntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SharesTable _shareIdTable(_$AppDatabase db) =>
      db.shares.createAlias('entries__share_id__shares__id');

  $$SharesTableProcessedTableManager get shareId {
    final $_column = $_itemColumn<String>('share_id')!;

    final manager = $$SharesTableTableManager(
      $_db,
      $_db.shares,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_shareIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$ChunksTable, List<Chunk>> _chunksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.chunks,
    aliasName: 'entries__id__chunks__entry_id',
  );

  $$ChunksTableProcessedTableManager get chunksRefs {
    final manager = $$ChunksTableTableManager(
      $_db,
      $_db.chunks,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_chunksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$EntrySearchTokensTable, List<EntrySearchToken>>
  _entrySearchTokensRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.entrySearchTokens,
        aliasName: 'entries__id__entry_search_tokens__entry_id',
      );

  $$EntrySearchTokensTableProcessedTableManager get entrySearchTokensRefs {
    final manager = $$EntrySearchTokensTableTableManager(
      $_db,
      $_db.entrySearchTokens,
    ).filter((f) => f.entryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _entrySearchTokensRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EntriesTableFilterComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
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

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDirectory => $composableBuilder(
    column: $table.isDirectory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hashStatus => $composableBuilder(
    column: $table.hashStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunkSize => $composableBuilder(
    column: $table.chunkSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localUri => $composableBuilder(
    column: $table.localUri,
    builder: (column) => ColumnFilters(column),
  );

  $$SharesTableFilterComposer get shareId {
    final $$SharesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shareId,
      referencedTable: $db.shares,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SharesTableFilterComposer(
            $db: $db,
            $table: $db.shares,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> chunksRefs(
    Expression<bool> Function($$ChunksTableFilterComposer f) f,
  ) {
    final $$ChunksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chunks,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChunksTableFilterComposer(
            $db: $db,
            $table: $db.chunks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> entrySearchTokensRefs(
    Expression<bool> Function($$EntrySearchTokensTableFilterComposer f) f,
  ) {
    final $$EntrySearchTokensTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entrySearchTokens,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntrySearchTokensTableFilterComposer(
            $db: $db,
            $table: $db.entrySearchTokens,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
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

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDirectory => $composableBuilder(
    column: $table.isDirectory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hashStatus => $composableBuilder(
    column: $table.hashStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunkSize => $composableBuilder(
    column: $table.chunkSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localUri => $composableBuilder(
    column: $table.localUri,
    builder: (column) => ColumnOrderings(column),
  );

  $$SharesTableOrderingComposer get shareId {
    final $$SharesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shareId,
      referencedTable: $db.shares,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SharesTableOrderingComposer(
            $db: $db,
            $table: $db.shares,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isDirectory => $composableBuilder(
    column: $table.isDirectory,
    builder: (column) => column,
  );

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get mtimeMs =>
      $composableBuilder(column: $table.mtimeMs, builder: (column) => column);

  GeneratedColumn<String> get hashStatus => $composableBuilder(
    column: $table.hashStatus,
    builder: (column) => column,
  );

  GeneratedColumn<int> get chunkSize =>
      $composableBuilder(column: $table.chunkSize, builder: (column) => column);

  GeneratedColumn<String> get localUri =>
      $composableBuilder(column: $table.localUri, builder: (column) => column);

  $$SharesTableAnnotationComposer get shareId {
    final $$SharesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.shareId,
      referencedTable: $db.shares,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SharesTableAnnotationComposer(
            $db: $db,
            $table: $db.shares,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> chunksRefs<T extends Object>(
    Expression<T> Function($$ChunksTableAnnotationComposer a) f,
  ) {
    final $$ChunksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.chunks,
      getReferencedColumn: (t) => t.entryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ChunksTableAnnotationComposer(
            $db: $db,
            $table: $db.chunks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> entrySearchTokensRefs<T extends Object>(
    Expression<T> Function($$EntrySearchTokensTableAnnotationComposer a) f,
  ) {
    final $$EntrySearchTokensTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.entrySearchTokens,
          getReferencedColumn: (t) => t.entryId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$EntrySearchTokensTableAnnotationComposer(
                $db: $db,
                $table: $db.entrySearchTokens,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntriesTable,
          Entry,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (Entry, $$EntriesTableReferences),
          Entry,
          PrefetchHooks Function({
            bool shareId,
            bool chunksRefs,
            bool entrySearchTokensRefs,
          })
        > {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> shareId = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isDirectory = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> mtimeMs = const Value.absent(),
                Value<String> hashStatus = const Value.absent(),
                Value<int?> chunkSize = const Value.absent(),
                Value<String?> localUri = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                shareId: shareId,
                relativePath: relativePath,
                name: name,
                isDirectory: isDirectory,
                size: size,
                mtimeMs: mtimeMs,
                hashStatus: hashStatus,
                chunkSize: chunkSize,
                localUri: localUri,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String shareId,
                required String relativePath,
                required String name,
                Value<bool> isDirectory = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> mtimeMs = const Value.absent(),
                Value<String> hashStatus = const Value.absent(),
                Value<int?> chunkSize = const Value.absent(),
                Value<String?> localUri = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                shareId: shareId,
                relativePath: relativePath,
                name: name,
                isDirectory: isDirectory,
                size: size,
                mtimeMs: mtimeMs,
                hashStatus: hashStatus,
                chunkSize: chunkSize,
                localUri: localUri,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                shareId = false,
                chunksRefs = false,
                entrySearchTokensRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (chunksRefs) db.chunks,
                    if (entrySearchTokensRefs) db.entrySearchTokens,
                  ],
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
                        if (shareId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.shareId,
                                    referencedTable: $$EntriesTableReferences
                                        ._shareIdTable(db),
                                    referencedColumn: $$EntriesTableReferences
                                        ._shareIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (chunksRefs)
                        await $_getPrefetchedData<Entry, $EntriesTable, Chunk>(
                          currentTable: table,
                          referencedTable: $$EntriesTableReferences
                              ._chunksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).chunksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.entryId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (entrySearchTokensRefs)
                        await $_getPrefetchedData<
                          Entry,
                          $EntriesTable,
                          EntrySearchToken
                        >(
                          currentTable: table,
                          referencedTable: $$EntriesTableReferences
                              ._entrySearchTokensRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$EntriesTableReferences(
                                db,
                                table,
                                p0,
                              ).entrySearchTokensRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.entryId == item.id,
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

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntriesTable,
      Entry,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (Entry, $$EntriesTableReferences),
      Entry,
      PrefetchHooks Function({
        bool shareId,
        bool chunksRefs,
        bool entrySearchTokensRefs,
      })
    >;
typedef $$ChunksTableCreateCompanionBuilder =
    ChunksCompanion Function({
      Value<int> id,
      required String entryId,
      required int chunkIndex,
      required int offset,
      required int length,
      required String hash,
      Value<String> hashAlgorithm,
      Value<String> status,
    });
typedef $$ChunksTableUpdateCompanionBuilder =
    ChunksCompanion Function({
      Value<int> id,
      Value<String> entryId,
      Value<int> chunkIndex,
      Value<int> offset,
      Value<int> length,
      Value<String> hash,
      Value<String> hashAlgorithm,
      Value<String> status,
    });

final class $$ChunksTableReferences
    extends BaseReferences<_$AppDatabase, $ChunksTable, Chunk> {
  $$ChunksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EntriesTable _entryIdTable(_$AppDatabase db) =>
      db.entries.createAlias('chunks__entry_id__entries__id');

  $$EntriesTableProcessedTableManager get entryId {
    final $_column = $_itemColumn<String>('entry_id')!;

    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ChunksTableFilterComposer
    extends Composer<_$AppDatabase, $ChunksTable> {
  $$ChunksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offset => $composableBuilder(
    column: $table.offset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hashAlgorithm => $composableBuilder(
    column: $table.hashAlgorithm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  $$EntriesTableFilterComposer get entryId {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChunksTableOrderingComposer
    extends Composer<_$AppDatabase, $ChunksTable> {
  $$ChunksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offset => $composableBuilder(
    column: $table.offset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hashAlgorithm => $composableBuilder(
    column: $table.hashAlgorithm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  $$EntriesTableOrderingComposer get entryId {
    final $$EntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableOrderingComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChunksTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChunksTable> {
  $$ChunksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get offset =>
      $composableBuilder(column: $table.offset, builder: (column) => column);

  GeneratedColumn<int> get length =>
      $composableBuilder(column: $table.length, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<String> get hashAlgorithm => $composableBuilder(
    column: $table.hashAlgorithm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  $$EntriesTableAnnotationComposer get entryId {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ChunksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChunksTable,
          Chunk,
          $$ChunksTableFilterComposer,
          $$ChunksTableOrderingComposer,
          $$ChunksTableAnnotationComposer,
          $$ChunksTableCreateCompanionBuilder,
          $$ChunksTableUpdateCompanionBuilder,
          (Chunk, $$ChunksTableReferences),
          Chunk,
          PrefetchHooks Function({bool entryId})
        > {
  $$ChunksTableTableManager(_$AppDatabase db, $ChunksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChunksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChunksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChunksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<int> chunkIndex = const Value.absent(),
                Value<int> offset = const Value.absent(),
                Value<int> length = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<String> hashAlgorithm = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => ChunksCompanion(
                id: id,
                entryId: entryId,
                chunkIndex: chunkIndex,
                offset: offset,
                length: length,
                hash: hash,
                hashAlgorithm: hashAlgorithm,
                status: status,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entryId,
                required int chunkIndex,
                required int offset,
                required int length,
                required String hash,
                Value<String> hashAlgorithm = const Value.absent(),
                Value<String> status = const Value.absent(),
              }) => ChunksCompanion.insert(
                id: id,
                entryId: entryId,
                chunkIndex: chunkIndex,
                offset: offset,
                length: length,
                hash: hash,
                hashAlgorithm: hashAlgorithm,
                status: status,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$ChunksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({entryId = false}) {
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
                    if (entryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.entryId,
                                referencedTable: $$ChunksTableReferences
                                    ._entryIdTable(db),
                                referencedColumn: $$ChunksTableReferences
                                    ._entryIdTable(db)
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

typedef $$ChunksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChunksTable,
      Chunk,
      $$ChunksTableFilterComposer,
      $$ChunksTableOrderingComposer,
      $$ChunksTableAnnotationComposer,
      $$ChunksTableCreateCompanionBuilder,
      $$ChunksTableUpdateCompanionBuilder,
      (Chunk, $$ChunksTableReferences),
      Chunk,
      PrefetchHooks Function({bool entryId})
    >;
typedef $$PeersTableCreateCompanionBuilder =
    PeersCompanion Function({
      required String id,
      required String nick,
      required String host,
      required int port,
      Value<String> scheme,
      Value<String?> fingerprint,
      Value<String?> tlsCertFingerprint,
      Value<bool> trusted,
      Value<String> identityStatus,
      Value<DateTime?> lastSeen,
      Value<bool> manual,
      Value<bool> stale,
      Value<int> rowid,
    });
typedef $$PeersTableUpdateCompanionBuilder =
    PeersCompanion Function({
      Value<String> id,
      Value<String> nick,
      Value<String> host,
      Value<int> port,
      Value<String> scheme,
      Value<String?> fingerprint,
      Value<String?> tlsCertFingerprint,
      Value<bool> trusted,
      Value<String> identityStatus,
      Value<DateTime?> lastSeen,
      Value<bool> manual,
      Value<bool> stale,
      Value<int> rowid,
    });

final class $$PeersTableReferences
    extends BaseReferences<_$AppDatabase, $PeersTable, Peer> {
  $$PeersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $RemoteEntriesCacheTable,
    List<RemoteEntriesCacheData>
  >
  _remoteEntriesCacheRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.remoteEntriesCache,
        aliasName: 'peers__id__remote_entries_cache__peer_id',
      );

  $$RemoteEntriesCacheTableProcessedTableManager get remoteEntriesCacheRefs {
    final manager = $$RemoteEntriesCacheTableTableManager(
      $_db,
      $_db.remoteEntriesCache,
    ).filter((f) => f.peerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _remoteEntriesCacheRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RemoteFilesTable, List<RemoteFile>>
  _remoteFilesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.remoteFiles,
    aliasName: 'peers__id__remote_files__peer_id',
  );

  $$RemoteFilesTableProcessedTableManager get remoteFilesRefs {
    final manager = $$RemoteFilesTableTableManager(
      $_db,
      $_db.remoteFiles,
    ).filter((f) => f.peerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_remoteFilesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RemoteChunkSourcesTable, List<RemoteChunkSource>>
  _remoteChunkSourcesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.remoteChunkSources,
        aliasName: 'peers__id__remote_chunk_sources__peer_id',
      );

  $$RemoteChunkSourcesTableProcessedTableManager get remoteChunkSourcesRefs {
    final manager = $$RemoteChunkSourcesTableTableManager(
      $_db,
      $_db.remoteChunkSources,
    ).filter((f) => f.peerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _remoteChunkSourcesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DownloadsTable, List<Download>>
  _downloadsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.downloads,
    aliasName: 'peers__id__downloads__peer_id',
  );

  $$DownloadsTableProcessedTableManager get downloadsRefs {
    final manager = $$DownloadsTableTableManager(
      $_db,
      $_db.downloads,
    ).filter((f) => f.peerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_downloadsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PeersTableFilterComposer extends Composer<_$AppDatabase, $PeersTable> {
  $$PeersTableFilterComposer({
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

  ColumnFilters<String> get nick => $composableBuilder(
    column: $table.nick,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheme => $composableBuilder(
    column: $table.scheme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tlsCertFingerprint => $composableBuilder(
    column: $table.tlsCertFingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get trusted => $composableBuilder(
    column: $table.trusted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get identityStatus => $composableBuilder(
    column: $table.identityStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get manual => $composableBuilder(
    column: $table.manual,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get stale => $composableBuilder(
    column: $table.stale,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> remoteEntriesCacheRefs(
    Expression<bool> Function($$RemoteEntriesCacheTableFilterComposer f) f,
  ) {
    final $$RemoteEntriesCacheTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.remoteEntriesCache,
      getReferencedColumn: (t) => t.peerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemoteEntriesCacheTableFilterComposer(
            $db: $db,
            $table: $db.remoteEntriesCache,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> remoteFilesRefs(
    Expression<bool> Function($$RemoteFilesTableFilterComposer f) f,
  ) {
    final $$RemoteFilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.remoteFiles,
      getReferencedColumn: (t) => t.peerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemoteFilesTableFilterComposer(
            $db: $db,
            $table: $db.remoteFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> remoteChunkSourcesRefs(
    Expression<bool> Function($$RemoteChunkSourcesTableFilterComposer f) f,
  ) {
    final $$RemoteChunkSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.remoteChunkSources,
      getReferencedColumn: (t) => t.peerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemoteChunkSourcesTableFilterComposer(
            $db: $db,
            $table: $db.remoteChunkSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> downloadsRefs(
    Expression<bool> Function($$DownloadsTableFilterComposer f) f,
  ) {
    final $$DownloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.peerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableFilterComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeersTableOrderingComposer
    extends Composer<_$AppDatabase, $PeersTable> {
  $$PeersTableOrderingComposer({
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

  ColumnOrderings<String> get nick => $composableBuilder(
    column: $table.nick,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get host => $composableBuilder(
    column: $table.host,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get port => $composableBuilder(
    column: $table.port,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheme => $composableBuilder(
    column: $table.scheme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tlsCertFingerprint => $composableBuilder(
    column: $table.tlsCertFingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get trusted => $composableBuilder(
    column: $table.trusted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get identityStatus => $composableBuilder(
    column: $table.identityStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get manual => $composableBuilder(
    column: $table.manual,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get stale => $composableBuilder(
    column: $table.stale,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeersTable> {
  $$PeersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get nick =>
      $composableBuilder(column: $table.nick, builder: (column) => column);

  GeneratedColumn<String> get host =>
      $composableBuilder(column: $table.host, builder: (column) => column);

  GeneratedColumn<int> get port =>
      $composableBuilder(column: $table.port, builder: (column) => column);

  GeneratedColumn<String> get scheme =>
      $composableBuilder(column: $table.scheme, builder: (column) => column);

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<String> get tlsCertFingerprint => $composableBuilder(
    column: $table.tlsCertFingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get trusted =>
      $composableBuilder(column: $table.trusted, builder: (column) => column);

  GeneratedColumn<String> get identityStatus => $composableBuilder(
    column: $table.identityStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<bool> get manual =>
      $composableBuilder(column: $table.manual, builder: (column) => column);

  GeneratedColumn<bool> get stale =>
      $composableBuilder(column: $table.stale, builder: (column) => column);

  Expression<T> remoteEntriesCacheRefs<T extends Object>(
    Expression<T> Function($$RemoteEntriesCacheTableAnnotationComposer a) f,
  ) {
    final $$RemoteEntriesCacheTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.remoteEntriesCache,
          getReferencedColumn: (t) => t.peerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RemoteEntriesCacheTableAnnotationComposer(
                $db: $db,
                $table: $db.remoteEntriesCache,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> remoteFilesRefs<T extends Object>(
    Expression<T> Function($$RemoteFilesTableAnnotationComposer a) f,
  ) {
    final $$RemoteFilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.remoteFiles,
      getReferencedColumn: (t) => t.peerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemoteFilesTableAnnotationComposer(
            $db: $db,
            $table: $db.remoteFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> remoteChunkSourcesRefs<T extends Object>(
    Expression<T> Function($$RemoteChunkSourcesTableAnnotationComposer a) f,
  ) {
    final $$RemoteChunkSourcesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.remoteChunkSources,
          getReferencedColumn: (t) => t.peerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RemoteChunkSourcesTableAnnotationComposer(
                $db: $db,
                $table: $db.remoteChunkSources,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> downloadsRefs<T extends Object>(
    Expression<T> Function($$DownloadsTableAnnotationComposer a) f,
  ) {
    final $$DownloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.peerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PeersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeersTable,
          Peer,
          $$PeersTableFilterComposer,
          $$PeersTableOrderingComposer,
          $$PeersTableAnnotationComposer,
          $$PeersTableCreateCompanionBuilder,
          $$PeersTableUpdateCompanionBuilder,
          (Peer, $$PeersTableReferences),
          Peer,
          PrefetchHooks Function({
            bool remoteEntriesCacheRefs,
            bool remoteFilesRefs,
            bool remoteChunkSourcesRefs,
            bool downloadsRefs,
          })
        > {
  $$PeersTableTableManager(_$AppDatabase db, $PeersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> nick = const Value.absent(),
                Value<String> host = const Value.absent(),
                Value<int> port = const Value.absent(),
                Value<String> scheme = const Value.absent(),
                Value<String?> fingerprint = const Value.absent(),
                Value<String?> tlsCertFingerprint = const Value.absent(),
                Value<bool> trusted = const Value.absent(),
                Value<String> identityStatus = const Value.absent(),
                Value<DateTime?> lastSeen = const Value.absent(),
                Value<bool> manual = const Value.absent(),
                Value<bool> stale = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeersCompanion(
                id: id,
                nick: nick,
                host: host,
                port: port,
                scheme: scheme,
                fingerprint: fingerprint,
                tlsCertFingerprint: tlsCertFingerprint,
                trusted: trusted,
                identityStatus: identityStatus,
                lastSeen: lastSeen,
                manual: manual,
                stale: stale,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String nick,
                required String host,
                required int port,
                Value<String> scheme = const Value.absent(),
                Value<String?> fingerprint = const Value.absent(),
                Value<String?> tlsCertFingerprint = const Value.absent(),
                Value<bool> trusted = const Value.absent(),
                Value<String> identityStatus = const Value.absent(),
                Value<DateTime?> lastSeen = const Value.absent(),
                Value<bool> manual = const Value.absent(),
                Value<bool> stale = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeersCompanion.insert(
                id: id,
                nick: nick,
                host: host,
                port: port,
                scheme: scheme,
                fingerprint: fingerprint,
                tlsCertFingerprint: tlsCertFingerprint,
                trusted: trusted,
                identityStatus: identityStatus,
                lastSeen: lastSeen,
                manual: manual,
                stale: stale,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$PeersTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                remoteEntriesCacheRefs = false,
                remoteFilesRefs = false,
                remoteChunkSourcesRefs = false,
                downloadsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (remoteEntriesCacheRefs) db.remoteEntriesCache,
                    if (remoteFilesRefs) db.remoteFiles,
                    if (remoteChunkSourcesRefs) db.remoteChunkSources,
                    if (downloadsRefs) db.downloads,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (remoteEntriesCacheRefs)
                        await $_getPrefetchedData<
                          Peer,
                          $PeersTable,
                          RemoteEntriesCacheData
                        >(
                          currentTable: table,
                          referencedTable: $$PeersTableReferences
                              ._remoteEntriesCacheRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeersTableReferences(
                                db,
                                table,
                                p0,
                              ).remoteEntriesCacheRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.peerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (remoteFilesRefs)
                        await $_getPrefetchedData<
                          Peer,
                          $PeersTable,
                          RemoteFile
                        >(
                          currentTable: table,
                          referencedTable: $$PeersTableReferences
                              ._remoteFilesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeersTableReferences(
                                db,
                                table,
                                p0,
                              ).remoteFilesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.peerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (remoteChunkSourcesRefs)
                        await $_getPrefetchedData<
                          Peer,
                          $PeersTable,
                          RemoteChunkSource
                        >(
                          currentTable: table,
                          referencedTable: $$PeersTableReferences
                              ._remoteChunkSourcesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeersTableReferences(
                                db,
                                table,
                                p0,
                              ).remoteChunkSourcesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.peerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (downloadsRefs)
                        await $_getPrefetchedData<Peer, $PeersTable, Download>(
                          currentTable: table,
                          referencedTable: $$PeersTableReferences
                              ._downloadsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PeersTableReferences(
                                db,
                                table,
                                p0,
                              ).downloadsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.peerId == item.id,
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

typedef $$PeersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeersTable,
      Peer,
      $$PeersTableFilterComposer,
      $$PeersTableOrderingComposer,
      $$PeersTableAnnotationComposer,
      $$PeersTableCreateCompanionBuilder,
      $$PeersTableUpdateCompanionBuilder,
      (Peer, $$PeersTableReferences),
      Peer,
      PrefetchHooks Function({
        bool remoteEntriesCacheRefs,
        bool remoteFilesRefs,
        bool remoteChunkSourcesRefs,
        bool downloadsRefs,
      })
    >;
typedef $$RemoteEntriesCacheTableCreateCompanionBuilder =
    RemoteEntriesCacheCompanion Function({
      Value<int> id,
      required String peerId,
      required String shareId,
      required String relativePath,
      required String payloadJson,
      Value<DateTime> cachedAt,
    });
typedef $$RemoteEntriesCacheTableUpdateCompanionBuilder =
    RemoteEntriesCacheCompanion Function({
      Value<int> id,
      Value<String> peerId,
      Value<String> shareId,
      Value<String> relativePath,
      Value<String> payloadJson,
      Value<DateTime> cachedAt,
    });

final class $$RemoteEntriesCacheTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RemoteEntriesCacheTable,
          RemoteEntriesCacheData
        > {
  $$RemoteEntriesCacheTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PeersTable _peerIdTable(_$AppDatabase db) =>
      db.peers.createAlias('remote_entries_cache__peer_id__peers__id');

  $$PeersTableProcessedTableManager get peerId {
    final $_column = $_itemColumn<String>('peer_id')!;

    final manager = $$PeersTableTableManager(
      $_db,
      $_db.peers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_peerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RemoteEntriesCacheTableFilterComposer
    extends Composer<_$AppDatabase, $RemoteEntriesCacheTable> {
  $$RemoteEntriesCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shareId => $composableBuilder(
    column: $table.shareId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PeersTableFilterComposer get peerId {
    final $$PeersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.peerId,
      referencedTable: $db.peers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeersTableFilterComposer(
            $db: $db,
            $table: $db.peers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemoteEntriesCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $RemoteEntriesCacheTable> {
  $$RemoteEntriesCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shareId => $composableBuilder(
    column: $table.shareId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PeersTableOrderingComposer get peerId {
    final $$PeersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.peerId,
      referencedTable: $db.peers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeersTableOrderingComposer(
            $db: $db,
            $table: $db.peers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemoteEntriesCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemoteEntriesCacheTable> {
  $$RemoteEntriesCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shareId =>
      $composableBuilder(column: $table.shareId, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  $$PeersTableAnnotationComposer get peerId {
    final $$PeersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.peerId,
      referencedTable: $db.peers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeersTableAnnotationComposer(
            $db: $db,
            $table: $db.peers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemoteEntriesCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemoteEntriesCacheTable,
          RemoteEntriesCacheData,
          $$RemoteEntriesCacheTableFilterComposer,
          $$RemoteEntriesCacheTableOrderingComposer,
          $$RemoteEntriesCacheTableAnnotationComposer,
          $$RemoteEntriesCacheTableCreateCompanionBuilder,
          $$RemoteEntriesCacheTableUpdateCompanionBuilder,
          (RemoteEntriesCacheData, $$RemoteEntriesCacheTableReferences),
          RemoteEntriesCacheData,
          PrefetchHooks Function({bool peerId})
        > {
  $$RemoteEntriesCacheTableTableManager(
    _$AppDatabase db,
    $RemoteEntriesCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemoteEntriesCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemoteEntriesCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemoteEntriesCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<String> shareId = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
              }) => RemoteEntriesCacheCompanion(
                id: id,
                peerId: peerId,
                shareId: shareId,
                relativePath: relativePath,
                payloadJson: payloadJson,
                cachedAt: cachedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String peerId,
                required String shareId,
                required String relativePath,
                required String payloadJson,
                Value<DateTime> cachedAt = const Value.absent(),
              }) => RemoteEntriesCacheCompanion.insert(
                id: id,
                peerId: peerId,
                shareId: shareId,
                relativePath: relativePath,
                payloadJson: payloadJson,
                cachedAt: cachedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RemoteEntriesCacheTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({peerId = false}) {
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
                    if (peerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.peerId,
                                referencedTable:
                                    $$RemoteEntriesCacheTableReferences
                                        ._peerIdTable(db),
                                referencedColumn:
                                    $$RemoteEntriesCacheTableReferences
                                        ._peerIdTable(db)
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

typedef $$RemoteEntriesCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemoteEntriesCacheTable,
      RemoteEntriesCacheData,
      $$RemoteEntriesCacheTableFilterComposer,
      $$RemoteEntriesCacheTableOrderingComposer,
      $$RemoteEntriesCacheTableAnnotationComposer,
      $$RemoteEntriesCacheTableCreateCompanionBuilder,
      $$RemoteEntriesCacheTableUpdateCompanionBuilder,
      (RemoteEntriesCacheData, $$RemoteEntriesCacheTableReferences),
      RemoteEntriesCacheData,
      PrefetchHooks Function({bool peerId})
    >;
typedef $$RemoteFilesTableCreateCompanionBuilder =
    RemoteFilesCompanion Function({
      required String id,
      required String peerId,
      required String shareId,
      required String entryId,
      required String relativePath,
      required String name,
      Value<bool> isDirectory,
      Value<int> size,
      Value<int> mtimeMs,
      Value<bool> hashReady,
      Value<String?> contentSignature,
      Value<String?> manifestJson,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });
typedef $$RemoteFilesTableUpdateCompanionBuilder =
    RemoteFilesCompanion Function({
      Value<String> id,
      Value<String> peerId,
      Value<String> shareId,
      Value<String> entryId,
      Value<String> relativePath,
      Value<String> name,
      Value<bool> isDirectory,
      Value<int> size,
      Value<int> mtimeMs,
      Value<bool> hashReady,
      Value<String?> contentSignature,
      Value<String?> manifestJson,
      Value<DateTime> cachedAt,
      Value<int> rowid,
    });

final class $$RemoteFilesTableReferences
    extends BaseReferences<_$AppDatabase, $RemoteFilesTable, RemoteFile> {
  $$RemoteFilesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PeersTable _peerIdTable(_$AppDatabase db) =>
      db.peers.createAlias('remote_files__peer_id__peers__id');

  $$PeersTableProcessedTableManager get peerId {
    final $_column = $_itemColumn<String>('peer_id')!;

    final manager = $$PeersTableTableManager(
      $_db,
      $_db.peers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_peerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RemoteChunkSourcesTable, List<RemoteChunkSource>>
  _remoteChunkSourcesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.remoteChunkSources,
        aliasName: 'remote_files__id__remote_chunk_sources__remote_file_id',
      );

  $$RemoteChunkSourcesTableProcessedTableManager get remoteChunkSourcesRefs {
    final manager = $$RemoteChunkSourcesTableTableManager(
      $_db,
      $_db.remoteChunkSources,
    ).filter((f) => f.remoteFileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _remoteChunkSourcesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RemoteFilesTableFilterComposer
    extends Composer<_$AppDatabase, $RemoteFilesTable> {
  $$RemoteFilesTableFilterComposer({
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

  ColumnFilters<String> get shareId => $composableBuilder(
    column: $table.shareId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDirectory => $composableBuilder(
    column: $table.isDirectory,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hashReady => $composableBuilder(
    column: $table.hashReady,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentSignature => $composableBuilder(
    column: $table.contentSignature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PeersTableFilterComposer get peerId {
    final $$PeersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.peerId,
      referencedTable: $db.peers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeersTableFilterComposer(
            $db: $db,
            $table: $db.peers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> remoteChunkSourcesRefs(
    Expression<bool> Function($$RemoteChunkSourcesTableFilterComposer f) f,
  ) {
    final $$RemoteChunkSourcesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.remoteChunkSources,
      getReferencedColumn: (t) => t.remoteFileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemoteChunkSourcesTableFilterComposer(
            $db: $db,
            $table: $db.remoteChunkSources,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RemoteFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $RemoteFilesTable> {
  $$RemoteFilesTableOrderingComposer({
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

  ColumnOrderings<String> get shareId => $composableBuilder(
    column: $table.shareId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDirectory => $composableBuilder(
    column: $table.isDirectory,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mtimeMs => $composableBuilder(
    column: $table.mtimeMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hashReady => $composableBuilder(
    column: $table.hashReady,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentSignature => $composableBuilder(
    column: $table.contentSignature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
    column: $table.cachedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PeersTableOrderingComposer get peerId {
    final $$PeersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.peerId,
      referencedTable: $db.peers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeersTableOrderingComposer(
            $db: $db,
            $table: $db.peers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemoteFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemoteFilesTable> {
  $$RemoteFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shareId =>
      $composableBuilder(column: $table.shareId, builder: (column) => column);

  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get isDirectory => $composableBuilder(
    column: $table.isDirectory,
    builder: (column) => column,
  );

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get mtimeMs =>
      $composableBuilder(column: $table.mtimeMs, builder: (column) => column);

  GeneratedColumn<bool> get hashReady =>
      $composableBuilder(column: $table.hashReady, builder: (column) => column);

  GeneratedColumn<String> get contentSignature => $composableBuilder(
    column: $table.contentSignature,
    builder: (column) => column,
  );

  GeneratedColumn<String> get manifestJson => $composableBuilder(
    column: $table.manifestJson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);

  $$PeersTableAnnotationComposer get peerId {
    final $$PeersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.peerId,
      referencedTable: $db.peers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeersTableAnnotationComposer(
            $db: $db,
            $table: $db.peers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> remoteChunkSourcesRefs<T extends Object>(
    Expression<T> Function($$RemoteChunkSourcesTableAnnotationComposer a) f,
  ) {
    final $$RemoteChunkSourcesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.remoteChunkSources,
          getReferencedColumn: (t) => t.remoteFileId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RemoteChunkSourcesTableAnnotationComposer(
                $db: $db,
                $table: $db.remoteChunkSources,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$RemoteFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemoteFilesTable,
          RemoteFile,
          $$RemoteFilesTableFilterComposer,
          $$RemoteFilesTableOrderingComposer,
          $$RemoteFilesTableAnnotationComposer,
          $$RemoteFilesTableCreateCompanionBuilder,
          $$RemoteFilesTableUpdateCompanionBuilder,
          (RemoteFile, $$RemoteFilesTableReferences),
          RemoteFile,
          PrefetchHooks Function({bool peerId, bool remoteChunkSourcesRefs})
        > {
  $$RemoteFilesTableTableManager(_$AppDatabase db, $RemoteFilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemoteFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemoteFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemoteFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<String> shareId = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<bool> isDirectory = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> mtimeMs = const Value.absent(),
                Value<bool> hashReady = const Value.absent(),
                Value<String?> contentSignature = const Value.absent(),
                Value<String?> manifestJson = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemoteFilesCompanion(
                id: id,
                peerId: peerId,
                shareId: shareId,
                entryId: entryId,
                relativePath: relativePath,
                name: name,
                isDirectory: isDirectory,
                size: size,
                mtimeMs: mtimeMs,
                hashReady: hashReady,
                contentSignature: contentSignature,
                manifestJson: manifestJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String peerId,
                required String shareId,
                required String entryId,
                required String relativePath,
                required String name,
                Value<bool> isDirectory = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> mtimeMs = const Value.absent(),
                Value<bool> hashReady = const Value.absent(),
                Value<String?> contentSignature = const Value.absent(),
                Value<String?> manifestJson = const Value.absent(),
                Value<DateTime> cachedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemoteFilesCompanion.insert(
                id: id,
                peerId: peerId,
                shareId: shareId,
                entryId: entryId,
                relativePath: relativePath,
                name: name,
                isDirectory: isDirectory,
                size: size,
                mtimeMs: mtimeMs,
                hashReady: hashReady,
                contentSignature: contentSignature,
                manifestJson: manifestJson,
                cachedAt: cachedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RemoteFilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({peerId = false, remoteChunkSourcesRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (remoteChunkSourcesRefs) db.remoteChunkSources,
                  ],
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
                        if (peerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.peerId,
                                    referencedTable:
                                        $$RemoteFilesTableReferences
                                            ._peerIdTable(db),
                                    referencedColumn:
                                        $$RemoteFilesTableReferences
                                            ._peerIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (remoteChunkSourcesRefs)
                        await $_getPrefetchedData<
                          RemoteFile,
                          $RemoteFilesTable,
                          RemoteChunkSource
                        >(
                          currentTable: table,
                          referencedTable: $$RemoteFilesTableReferences
                              ._remoteChunkSourcesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RemoteFilesTableReferences(
                                db,
                                table,
                                p0,
                              ).remoteChunkSourcesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.remoteFileId == item.id,
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

typedef $$RemoteFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemoteFilesTable,
      RemoteFile,
      $$RemoteFilesTableFilterComposer,
      $$RemoteFilesTableOrderingComposer,
      $$RemoteFilesTableAnnotationComposer,
      $$RemoteFilesTableCreateCompanionBuilder,
      $$RemoteFilesTableUpdateCompanionBuilder,
      (RemoteFile, $$RemoteFilesTableReferences),
      RemoteFile,
      PrefetchHooks Function({bool peerId, bool remoteChunkSourcesRefs})
    >;
typedef $$EntrySearchTokensTableCreateCompanionBuilder =
    EntrySearchTokensCompanion Function({
      required String entryId,
      required String shareId,
      required String token,
      Value<int> rowid,
    });
typedef $$EntrySearchTokensTableUpdateCompanionBuilder =
    EntrySearchTokensCompanion Function({
      Value<String> entryId,
      Value<String> shareId,
      Value<String> token,
      Value<int> rowid,
    });

final class $$EntrySearchTokensTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $EntrySearchTokensTable,
          EntrySearchToken
        > {
  $$EntrySearchTokensTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EntriesTable _entryIdTable(_$AppDatabase db) =>
      db.entries.createAlias('entry_search_tokens__entry_id__entries__id');

  $$EntriesTableProcessedTableManager get entryId {
    final $_column = $_itemColumn<String>('entry_id')!;

    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_entryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$EntrySearchTokensTableFilterComposer
    extends Composer<_$AppDatabase, $EntrySearchTokensTable> {
  $$EntrySearchTokensTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get shareId => $composableBuilder(
    column: $table.shareId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnFilters(column),
  );

  $$EntriesTableFilterComposer get entryId {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntrySearchTokensTableOrderingComposer
    extends Composer<_$AppDatabase, $EntrySearchTokensTable> {
  $$EntrySearchTokensTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get shareId => $composableBuilder(
    column: $table.shareId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get token => $composableBuilder(
    column: $table.token,
    builder: (column) => ColumnOrderings(column),
  );

  $$EntriesTableOrderingComposer get entryId {
    final $$EntriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableOrderingComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntrySearchTokensTableAnnotationComposer
    extends Composer<_$AppDatabase, $EntrySearchTokensTable> {
  $$EntrySearchTokensTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get shareId =>
      $composableBuilder(column: $table.shareId, builder: (column) => column);

  GeneratedColumn<String> get token =>
      $composableBuilder(column: $table.token, builder: (column) => column);

  $$EntriesTableAnnotationComposer get entryId {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.entryId,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntrySearchTokensTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntrySearchTokensTable,
          EntrySearchToken,
          $$EntrySearchTokensTableFilterComposer,
          $$EntrySearchTokensTableOrderingComposer,
          $$EntrySearchTokensTableAnnotationComposer,
          $$EntrySearchTokensTableCreateCompanionBuilder,
          $$EntrySearchTokensTableUpdateCompanionBuilder,
          (EntrySearchToken, $$EntrySearchTokensTableReferences),
          EntrySearchToken,
          PrefetchHooks Function({bool entryId})
        > {
  $$EntrySearchTokensTableTableManager(
    _$AppDatabase db,
    $EntrySearchTokensTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EntrySearchTokensTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EntrySearchTokensTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EntrySearchTokensTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> entryId = const Value.absent(),
                Value<String> shareId = const Value.absent(),
                Value<String> token = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EntrySearchTokensCompanion(
                entryId: entryId,
                shareId: shareId,
                token: token,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entryId,
                required String shareId,
                required String token,
                Value<int> rowid = const Value.absent(),
              }) => EntrySearchTokensCompanion.insert(
                entryId: entryId,
                shareId: shareId,
                token: token,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EntrySearchTokensTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({entryId = false}) {
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
                    if (entryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.entryId,
                                referencedTable:
                                    $$EntrySearchTokensTableReferences
                                        ._entryIdTable(db),
                                referencedColumn:
                                    $$EntrySearchTokensTableReferences
                                        ._entryIdTable(db)
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

typedef $$EntrySearchTokensTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntrySearchTokensTable,
      EntrySearchToken,
      $$EntrySearchTokensTableFilterComposer,
      $$EntrySearchTokensTableOrderingComposer,
      $$EntrySearchTokensTableAnnotationComposer,
      $$EntrySearchTokensTableCreateCompanionBuilder,
      $$EntrySearchTokensTableUpdateCompanionBuilder,
      (EntrySearchToken, $$EntrySearchTokensTableReferences),
      EntrySearchToken,
      PrefetchHooks Function({bool entryId})
    >;
typedef $$RemoteChunkSourcesTableCreateCompanionBuilder =
    RemoteChunkSourcesCompanion Function({
      Value<int> id,
      required String hash,
      required String peerId,
      required String remoteFileId,
      required String shareId,
      required String entryId,
      required int chunkIndex,
      required int offset,
      required int length,
      Value<DateTime> lastSeen,
      Value<DateTime?> lastSuccessAt,
      Value<int> failureCount,
      Value<int?> avgLatencyMs,
      Value<int?> avgBytesPerSecond,
    });
typedef $$RemoteChunkSourcesTableUpdateCompanionBuilder =
    RemoteChunkSourcesCompanion Function({
      Value<int> id,
      Value<String> hash,
      Value<String> peerId,
      Value<String> remoteFileId,
      Value<String> shareId,
      Value<String> entryId,
      Value<int> chunkIndex,
      Value<int> offset,
      Value<int> length,
      Value<DateTime> lastSeen,
      Value<DateTime?> lastSuccessAt,
      Value<int> failureCount,
      Value<int?> avgLatencyMs,
      Value<int?> avgBytesPerSecond,
    });

final class $$RemoteChunkSourcesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RemoteChunkSourcesTable,
          RemoteChunkSource
        > {
  $$RemoteChunkSourcesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PeersTable _peerIdTable(_$AppDatabase db) =>
      db.peers.createAlias('remote_chunk_sources__peer_id__peers__id');

  $$PeersTableProcessedTableManager get peerId {
    final $_column = $_itemColumn<String>('peer_id')!;

    final manager = $$PeersTableTableManager(
      $_db,
      $_db.peers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_peerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RemoteFilesTable _remoteFileIdTable(_$AppDatabase db) => db
      .remoteFiles
      .createAlias('remote_chunk_sources__remote_file_id__remote_files__id');

  $$RemoteFilesTableProcessedTableManager get remoteFileId {
    final $_column = $_itemColumn<String>('remote_file_id')!;

    final manager = $$RemoteFilesTableTableManager(
      $_db,
      $_db.remoteFiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_remoteFileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RemoteChunkSourcesTableFilterComposer
    extends Composer<_$AppDatabase, $RemoteChunkSourcesTable> {
  $$RemoteChunkSourcesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shareId => $composableBuilder(
    column: $table.shareId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offset => $composableBuilder(
    column: $table.offset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get failureCount => $composableBuilder(
    column: $table.failureCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avgLatencyMs => $composableBuilder(
    column: $table.avgLatencyMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avgBytesPerSecond => $composableBuilder(
    column: $table.avgBytesPerSecond,
    builder: (column) => ColumnFilters(column),
  );

  $$PeersTableFilterComposer get peerId {
    final $$PeersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.peerId,
      referencedTable: $db.peers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeersTableFilterComposer(
            $db: $db,
            $table: $db.peers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RemoteFilesTableFilterComposer get remoteFileId {
    final $$RemoteFilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.remoteFileId,
      referencedTable: $db.remoteFiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemoteFilesTableFilterComposer(
            $db: $db,
            $table: $db.remoteFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemoteChunkSourcesTableOrderingComposer
    extends Composer<_$AppDatabase, $RemoteChunkSourcesTable> {
  $$RemoteChunkSourcesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shareId => $composableBuilder(
    column: $table.shareId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offset => $composableBuilder(
    column: $table.offset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get failureCount => $composableBuilder(
    column: $table.failureCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avgLatencyMs => $composableBuilder(
    column: $table.avgLatencyMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avgBytesPerSecond => $composableBuilder(
    column: $table.avgBytesPerSecond,
    builder: (column) => ColumnOrderings(column),
  );

  $$PeersTableOrderingComposer get peerId {
    final $$PeersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.peerId,
      referencedTable: $db.peers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeersTableOrderingComposer(
            $db: $db,
            $table: $db.peers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RemoteFilesTableOrderingComposer get remoteFileId {
    final $$RemoteFilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.remoteFileId,
      referencedTable: $db.remoteFiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemoteFilesTableOrderingComposer(
            $db: $db,
            $table: $db.remoteFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemoteChunkSourcesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RemoteChunkSourcesTable> {
  $$RemoteChunkSourcesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<String> get shareId =>
      $composableBuilder(column: $table.shareId, builder: (column) => column);

  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get offset =>
      $composableBuilder(column: $table.offset, builder: (column) => column);

  GeneratedColumn<int> get length =>
      $composableBuilder(column: $table.length, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSuccessAt => $composableBuilder(
    column: $table.lastSuccessAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get failureCount => $composableBuilder(
    column: $table.failureCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get avgLatencyMs => $composableBuilder(
    column: $table.avgLatencyMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get avgBytesPerSecond => $composableBuilder(
    column: $table.avgBytesPerSecond,
    builder: (column) => column,
  );

  $$PeersTableAnnotationComposer get peerId {
    final $$PeersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.peerId,
      referencedTable: $db.peers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeersTableAnnotationComposer(
            $db: $db,
            $table: $db.peers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RemoteFilesTableAnnotationComposer get remoteFileId {
    final $$RemoteFilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.remoteFileId,
      referencedTable: $db.remoteFiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemoteFilesTableAnnotationComposer(
            $db: $db,
            $table: $db.remoteFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemoteChunkSourcesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RemoteChunkSourcesTable,
          RemoteChunkSource,
          $$RemoteChunkSourcesTableFilterComposer,
          $$RemoteChunkSourcesTableOrderingComposer,
          $$RemoteChunkSourcesTableAnnotationComposer,
          $$RemoteChunkSourcesTableCreateCompanionBuilder,
          $$RemoteChunkSourcesTableUpdateCompanionBuilder,
          (RemoteChunkSource, $$RemoteChunkSourcesTableReferences),
          RemoteChunkSource,
          PrefetchHooks Function({bool peerId, bool remoteFileId})
        > {
  $$RemoteChunkSourcesTableTableManager(
    _$AppDatabase db,
    $RemoteChunkSourcesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemoteChunkSourcesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemoteChunkSourcesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemoteChunkSourcesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<String> remoteFileId = const Value.absent(),
                Value<String> shareId = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<int> chunkIndex = const Value.absent(),
                Value<int> offset = const Value.absent(),
                Value<int> length = const Value.absent(),
                Value<DateTime> lastSeen = const Value.absent(),
                Value<DateTime?> lastSuccessAt = const Value.absent(),
                Value<int> failureCount = const Value.absent(),
                Value<int?> avgLatencyMs = const Value.absent(),
                Value<int?> avgBytesPerSecond = const Value.absent(),
              }) => RemoteChunkSourcesCompanion(
                id: id,
                hash: hash,
                peerId: peerId,
                remoteFileId: remoteFileId,
                shareId: shareId,
                entryId: entryId,
                chunkIndex: chunkIndex,
                offset: offset,
                length: length,
                lastSeen: lastSeen,
                lastSuccessAt: lastSuccessAt,
                failureCount: failureCount,
                avgLatencyMs: avgLatencyMs,
                avgBytesPerSecond: avgBytesPerSecond,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String hash,
                required String peerId,
                required String remoteFileId,
                required String shareId,
                required String entryId,
                required int chunkIndex,
                required int offset,
                required int length,
                Value<DateTime> lastSeen = const Value.absent(),
                Value<DateTime?> lastSuccessAt = const Value.absent(),
                Value<int> failureCount = const Value.absent(),
                Value<int?> avgLatencyMs = const Value.absent(),
                Value<int?> avgBytesPerSecond = const Value.absent(),
              }) => RemoteChunkSourcesCompanion.insert(
                id: id,
                hash: hash,
                peerId: peerId,
                remoteFileId: remoteFileId,
                shareId: shareId,
                entryId: entryId,
                chunkIndex: chunkIndex,
                offset: offset,
                length: length,
                lastSeen: lastSeen,
                lastSuccessAt: lastSuccessAt,
                failureCount: failureCount,
                avgLatencyMs: avgLatencyMs,
                avgBytesPerSecond: avgBytesPerSecond,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RemoteChunkSourcesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({peerId = false, remoteFileId = false}) {
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
                    if (peerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.peerId,
                                referencedTable:
                                    $$RemoteChunkSourcesTableReferences
                                        ._peerIdTable(db),
                                referencedColumn:
                                    $$RemoteChunkSourcesTableReferences
                                        ._peerIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (remoteFileId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.remoteFileId,
                                referencedTable:
                                    $$RemoteChunkSourcesTableReferences
                                        ._remoteFileIdTable(db),
                                referencedColumn:
                                    $$RemoteChunkSourcesTableReferences
                                        ._remoteFileIdTable(db)
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

typedef $$RemoteChunkSourcesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RemoteChunkSourcesTable,
      RemoteChunkSource,
      $$RemoteChunkSourcesTableFilterComposer,
      $$RemoteChunkSourcesTableOrderingComposer,
      $$RemoteChunkSourcesTableAnnotationComposer,
      $$RemoteChunkSourcesTableCreateCompanionBuilder,
      $$RemoteChunkSourcesTableUpdateCompanionBuilder,
      (RemoteChunkSource, $$RemoteChunkSourcesTableReferences),
      RemoteChunkSource,
      PrefetchHooks Function({bool peerId, bool remoteFileId})
    >;
typedef $$DownloadGroupsTableCreateCompanionBuilder =
    DownloadGroupsCompanion Function({
      required String id,
      required String label,
      required String rootPath,
      required String targetPath,
      Value<String> state,
      Value<int> totalFiles,
      Value<int> completedFiles,
      Value<int> totalBytes,
      Value<int> downloadedBytes,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$DownloadGroupsTableUpdateCompanionBuilder =
    DownloadGroupsCompanion Function({
      Value<String> id,
      Value<String> label,
      Value<String> rootPath,
      Value<String> targetPath,
      Value<String> state,
      Value<int> totalFiles,
      Value<int> completedFiles,
      Value<int> totalBytes,
      Value<int> downloadedBytes,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$DownloadGroupsTableReferences
    extends BaseReferences<_$AppDatabase, $DownloadGroupsTable, DownloadGroup> {
  $$DownloadGroupsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$DownloadsTable, List<Download>>
  _downloadsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.downloads,
    aliasName: 'download_groups__id__downloads__group_id',
  );

  $$DownloadsTableProcessedTableManager get downloadsRefs {
    final manager = $$DownloadsTableTableManager(
      $_db,
      $_db.downloads,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_downloadsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DownloadGroupsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadGroupsTable> {
  $$DownloadGroupsTableFilterComposer({
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

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rootPath => $composableBuilder(
    column: $table.rootPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalFiles => $composableBuilder(
    column: $table.totalFiles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedFiles => $composableBuilder(
    column: $table.completedFiles,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> downloadsRefs(
    Expression<bool> Function($$DownloadsTableFilterComposer f) f,
  ) {
    final $$DownloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableFilterComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DownloadGroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadGroupsTable> {
  $$DownloadGroupsTableOrderingComposer({
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

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rootPath => $composableBuilder(
    column: $table.rootPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalFiles => $composableBuilder(
    column: $table.totalFiles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedFiles => $composableBuilder(
    column: $table.completedFiles,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DownloadGroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadGroupsTable> {
  $$DownloadGroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get rootPath =>
      $composableBuilder(column: $table.rootPath, builder: (column) => column);

  GeneratedColumn<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get totalFiles => $composableBuilder(
    column: $table.totalFiles,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedFiles => $composableBuilder(
    column: $table.completedFiles,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> downloadsRefs<T extends Object>(
    Expression<T> Function($$DownloadsTableAnnotationComposer a) f,
  ) {
    final $$DownloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DownloadGroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadGroupsTable,
          DownloadGroup,
          $$DownloadGroupsTableFilterComposer,
          $$DownloadGroupsTableOrderingComposer,
          $$DownloadGroupsTableAnnotationComposer,
          $$DownloadGroupsTableCreateCompanionBuilder,
          $$DownloadGroupsTableUpdateCompanionBuilder,
          (DownloadGroup, $$DownloadGroupsTableReferences),
          DownloadGroup,
          PrefetchHooks Function({bool downloadsRefs})
        > {
  $$DownloadGroupsTableTableManager(
    _$AppDatabase db,
    $DownloadGroupsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadGroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadGroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadGroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> rootPath = const Value.absent(),
                Value<String> targetPath = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> totalFiles = const Value.absent(),
                Value<int> completedFiles = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadGroupsCompanion(
                id: id,
                label: label,
                rootPath: rootPath,
                targetPath: targetPath,
                state: state,
                totalFiles: totalFiles,
                completedFiles: completedFiles,
                totalBytes: totalBytes,
                downloadedBytes: downloadedBytes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String label,
                required String rootPath,
                required String targetPath,
                Value<String> state = const Value.absent(),
                Value<int> totalFiles = const Value.absent(),
                Value<int> completedFiles = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadGroupsCompanion.insert(
                id: id,
                label: label,
                rootPath: rootPath,
                targetPath: targetPath,
                state: state,
                totalFiles: totalFiles,
                completedFiles: completedFiles,
                totalBytes: totalBytes,
                downloadedBytes: downloadedBytes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadGroupsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({downloadsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (downloadsRefs) db.downloads],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (downloadsRefs)
                    await $_getPrefetchedData<
                      DownloadGroup,
                      $DownloadGroupsTable,
                      Download
                    >(
                      currentTable: table,
                      referencedTable: $$DownloadGroupsTableReferences
                          ._downloadsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$DownloadGroupsTableReferences(
                            db,
                            table,
                            p0,
                          ).downloadsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.groupId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DownloadGroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadGroupsTable,
      DownloadGroup,
      $$DownloadGroupsTableFilterComposer,
      $$DownloadGroupsTableOrderingComposer,
      $$DownloadGroupsTableAnnotationComposer,
      $$DownloadGroupsTableCreateCompanionBuilder,
      $$DownloadGroupsTableUpdateCompanionBuilder,
      (DownloadGroup, $$DownloadGroupsTableReferences),
      DownloadGroup,
      PrefetchHooks Function({bool downloadsRefs})
    >;
typedef $$DownloadsTableCreateCompanionBuilder =
    DownloadsCompanion Function({
      required String id,
      required String peerId,
      required String shareId,
      required String entryId,
      required String relativePath,
      required String targetPath,
      Value<String> state,
      Value<String?> groupId,
      Value<int> priority,
      Value<bool> paused,
      Value<int> totalBytes,
      Value<int> downloadedBytes,
      Value<int> inFlightBytes,
      Value<String?> errorMessage,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$DownloadsTableUpdateCompanionBuilder =
    DownloadsCompanion Function({
      Value<String> id,
      Value<String> peerId,
      Value<String> shareId,
      Value<String> entryId,
      Value<String> relativePath,
      Value<String> targetPath,
      Value<String> state,
      Value<String?> groupId,
      Value<int> priority,
      Value<bool> paused,
      Value<int> totalBytes,
      Value<int> downloadedBytes,
      Value<int> inFlightBytes,
      Value<String?> errorMessage,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

final class $$DownloadsTableReferences
    extends BaseReferences<_$AppDatabase, $DownloadsTable, Download> {
  $$DownloadsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $PeersTable _peerIdTable(_$AppDatabase db) =>
      db.peers.createAlias('downloads__peer_id__peers__id');

  $$PeersTableProcessedTableManager get peerId {
    final $_column = $_itemColumn<String>('peer_id')!;

    final manager = $$PeersTableTableManager(
      $_db,
      $_db.peers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_peerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DownloadGroupsTable _groupIdTable(_$AppDatabase db) =>
      db.downloadGroups.createAlias('downloads__group_id__download_groups__id');

  $$DownloadGroupsTableProcessedTableManager? get groupId {
    final $_column = $_itemColumn<String>('group_id');
    if ($_column == null) return null;
    final manager = $$DownloadGroupsTableTableManager(
      $_db,
      $_db.downloadGroups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$DownloadChunksTable, List<DownloadChunk>>
  _downloadChunksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.downloadChunks,
    aliasName: 'downloads__id__download_chunks__download_id',
  );

  $$DownloadChunksTableProcessedTableManager get downloadChunksRefs {
    final manager = $$DownloadChunksTableTableManager(
      $_db,
      $_db.downloadChunks,
    ).filter((f) => f.downloadId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_downloadChunksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DownloadsTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
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

  ColumnFilters<String> get shareId => $composableBuilder(
    column: $table.shareId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get paused => $composableBuilder(
    column: $table.paused,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get inFlightBytes => $composableBuilder(
    column: $table.inFlightBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$PeersTableFilterComposer get peerId {
    final $$PeersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.peerId,
      referencedTable: $db.peers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeersTableFilterComposer(
            $db: $db,
            $table: $db.peers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DownloadGroupsTableFilterComposer get groupId {
    final $$DownloadGroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.downloadGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadGroupsTableFilterComposer(
            $db: $db,
            $table: $db.downloadGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> downloadChunksRefs(
    Expression<bool> Function($$DownloadChunksTableFilterComposer f) f,
  ) {
    final $$DownloadChunksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloadChunks,
      getReferencedColumn: (t) => t.downloadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadChunksTableFilterComposer(
            $db: $db,
            $table: $db.downloadChunks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
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

  ColumnOrderings<String> get shareId => $composableBuilder(
    column: $table.shareId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get paused => $composableBuilder(
    column: $table.paused,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get inFlightBytes => $composableBuilder(
    column: $table.inFlightBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$PeersTableOrderingComposer get peerId {
    final $$PeersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.peerId,
      referencedTable: $db.peers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeersTableOrderingComposer(
            $db: $db,
            $table: $db.peers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DownloadGroupsTableOrderingComposer get groupId {
    final $$DownloadGroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.downloadGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadGroupsTableOrderingComposer(
            $db: $db,
            $table: $db.downloadGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get shareId =>
      $composableBuilder(column: $table.shareId, builder: (column) => column);

  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get relativePath => $composableBuilder(
    column: $table.relativePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetPath => $composableBuilder(
    column: $table.targetPath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<bool> get paused =>
      $composableBuilder(column: $table.paused, builder: (column) => column);

  GeneratedColumn<int> get totalBytes => $composableBuilder(
    column: $table.totalBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get downloadedBytes => $composableBuilder(
    column: $table.downloadedBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get inFlightBytes => $composableBuilder(
    column: $table.inFlightBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  $$PeersTableAnnotationComposer get peerId {
    final $$PeersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.peerId,
      referencedTable: $db.peers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PeersTableAnnotationComposer(
            $db: $db,
            $table: $db.peers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DownloadGroupsTableAnnotationComposer get groupId {
    final $$DownloadGroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.downloadGroups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadGroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloadGroups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> downloadChunksRefs<T extends Object>(
    Expression<T> Function($$DownloadChunksTableAnnotationComposer a) f,
  ) {
    final $$DownloadChunksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.downloadChunks,
      getReferencedColumn: (t) => t.downloadId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadChunksTableAnnotationComposer(
            $db: $db,
            $table: $db.downloadChunks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DownloadsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadsTable,
          Download,
          $$DownloadsTableFilterComposer,
          $$DownloadsTableOrderingComposer,
          $$DownloadsTableAnnotationComposer,
          $$DownloadsTableCreateCompanionBuilder,
          $$DownloadsTableUpdateCompanionBuilder,
          (Download, $$DownloadsTableReferences),
          Download,
          PrefetchHooks Function({
            bool peerId,
            bool groupId,
            bool downloadChunksRefs,
          })
        > {
  $$DownloadsTableTableManager(_$AppDatabase db, $DownloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> peerId = const Value.absent(),
                Value<String> shareId = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<String> relativePath = const Value.absent(),
                Value<String> targetPath = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> paused = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<int> inFlightBytes = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion(
                id: id,
                peerId: peerId,
                shareId: shareId,
                entryId: entryId,
                relativePath: relativePath,
                targetPath: targetPath,
                state: state,
                groupId: groupId,
                priority: priority,
                paused: paused,
                totalBytes: totalBytes,
                downloadedBytes: downloadedBytes,
                inFlightBytes: inFlightBytes,
                errorMessage: errorMessage,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String peerId,
                required String shareId,
                required String entryId,
                required String relativePath,
                required String targetPath,
                Value<String> state = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<bool> paused = const Value.absent(),
                Value<int> totalBytes = const Value.absent(),
                Value<int> downloadedBytes = const Value.absent(),
                Value<int> inFlightBytes = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DownloadsCompanion.insert(
                id: id,
                peerId: peerId,
                shareId: shareId,
                entryId: entryId,
                relativePath: relativePath,
                targetPath: targetPath,
                state: state,
                groupId: groupId,
                priority: priority,
                paused: paused,
                totalBytes: totalBytes,
                downloadedBytes: downloadedBytes,
                inFlightBytes: inFlightBytes,
                errorMessage: errorMessage,
                createdAt: createdAt,
                updatedAt: updatedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({peerId = false, groupId = false, downloadChunksRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (downloadChunksRefs) db.downloadChunks,
                  ],
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
                        if (peerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.peerId,
                                    referencedTable: $$DownloadsTableReferences
                                        ._peerIdTable(db),
                                    referencedColumn: $$DownloadsTableReferences
                                        ._peerIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (groupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.groupId,
                                    referencedTable: $$DownloadsTableReferences
                                        ._groupIdTable(db),
                                    referencedColumn: $$DownloadsTableReferences
                                        ._groupIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (downloadChunksRefs)
                        await $_getPrefetchedData<
                          Download,
                          $DownloadsTable,
                          DownloadChunk
                        >(
                          currentTable: table,
                          referencedTable: $$DownloadsTableReferences
                              ._downloadChunksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DownloadsTableReferences(
                                db,
                                table,
                                p0,
                              ).downloadChunksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.downloadId == item.id,
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

typedef $$DownloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadsTable,
      Download,
      $$DownloadsTableFilterComposer,
      $$DownloadsTableOrderingComposer,
      $$DownloadsTableAnnotationComposer,
      $$DownloadsTableCreateCompanionBuilder,
      $$DownloadsTableUpdateCompanionBuilder,
      (Download, $$DownloadsTableReferences),
      Download,
      PrefetchHooks Function({
        bool peerId,
        bool groupId,
        bool downloadChunksRefs,
      })
    >;
typedef $$DownloadChunksTableCreateCompanionBuilder =
    DownloadChunksCompanion Function({
      Value<int> id,
      required String downloadId,
      required int chunkIndex,
      required String hash,
      required int offset,
      required int length,
      Value<String> state,
      Value<String?> errorMessage,
      Value<String?> sourcePeerId,
    });
typedef $$DownloadChunksTableUpdateCompanionBuilder =
    DownloadChunksCompanion Function({
      Value<int> id,
      Value<String> downloadId,
      Value<int> chunkIndex,
      Value<String> hash,
      Value<int> offset,
      Value<int> length,
      Value<String> state,
      Value<String?> errorMessage,
      Value<String?> sourcePeerId,
    });

final class $$DownloadChunksTableReferences
    extends BaseReferences<_$AppDatabase, $DownloadChunksTable, DownloadChunk> {
  $$DownloadChunksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DownloadsTable _downloadIdTable(_$AppDatabase db) =>
      db.downloads.createAlias('download_chunks__download_id__downloads__id');

  $$DownloadsTableProcessedTableManager get downloadId {
    final $_column = $_itemColumn<String>('download_id')!;

    final manager = $$DownloadsTableTableManager(
      $_db,
      $_db.downloads,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_downloadIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DownloadChunksTableFilterComposer
    extends Composer<_$AppDatabase, $DownloadChunksTable> {
  $$DownloadChunksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offset => $composableBuilder(
    column: $table.offset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourcePeerId => $composableBuilder(
    column: $table.sourcePeerId,
    builder: (column) => ColumnFilters(column),
  );

  $$DownloadsTableFilterComposer get downloadId {
    final $$DownloadsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.downloadId,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableFilterComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadChunksTableOrderingComposer
    extends Composer<_$AppDatabase, $DownloadChunksTable> {
  $$DownloadChunksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offset => $composableBuilder(
    column: $table.offset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get length => $composableBuilder(
    column: $table.length,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourcePeerId => $composableBuilder(
    column: $table.sourcePeerId,
    builder: (column) => ColumnOrderings(column),
  );

  $$DownloadsTableOrderingComposer get downloadId {
    final $$DownloadsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.downloadId,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableOrderingComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadChunksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DownloadChunksTable> {
  $$DownloadChunksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get chunkIndex => $composableBuilder(
    column: $table.chunkIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<int> get offset =>
      $composableBuilder(column: $table.offset, builder: (column) => column);

  GeneratedColumn<int> get length =>
      $composableBuilder(column: $table.length, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourcePeerId => $composableBuilder(
    column: $table.sourcePeerId,
    builder: (column) => column,
  );

  $$DownloadsTableAnnotationComposer get downloadId {
    final $$DownloadsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.downloadId,
      referencedTable: $db.downloads,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DownloadsTableAnnotationComposer(
            $db: $db,
            $table: $db.downloads,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DownloadChunksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DownloadChunksTable,
          DownloadChunk,
          $$DownloadChunksTableFilterComposer,
          $$DownloadChunksTableOrderingComposer,
          $$DownloadChunksTableAnnotationComposer,
          $$DownloadChunksTableCreateCompanionBuilder,
          $$DownloadChunksTableUpdateCompanionBuilder,
          (DownloadChunk, $$DownloadChunksTableReferences),
          DownloadChunk,
          PrefetchHooks Function({bool downloadId})
        > {
  $$DownloadChunksTableTableManager(
    _$AppDatabase db,
    $DownloadChunksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadChunksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadChunksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadChunksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> downloadId = const Value.absent(),
                Value<int> chunkIndex = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<int> offset = const Value.absent(),
                Value<int> length = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> sourcePeerId = const Value.absent(),
              }) => DownloadChunksCompanion(
                id: id,
                downloadId: downloadId,
                chunkIndex: chunkIndex,
                hash: hash,
                offset: offset,
                length: length,
                state: state,
                errorMessage: errorMessage,
                sourcePeerId: sourcePeerId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String downloadId,
                required int chunkIndex,
                required String hash,
                required int offset,
                required int length,
                Value<String> state = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> sourcePeerId = const Value.absent(),
              }) => DownloadChunksCompanion.insert(
                id: id,
                downloadId: downloadId,
                chunkIndex: chunkIndex,
                hash: hash,
                offset: offset,
                length: length,
                state: state,
                errorMessage: errorMessage,
                sourcePeerId: sourcePeerId,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DownloadChunksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({downloadId = false}) {
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
                    if (downloadId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.downloadId,
                                referencedTable: $$DownloadChunksTableReferences
                                    ._downloadIdTable(db),
                                referencedColumn:
                                    $$DownloadChunksTableReferences
                                        ._downloadIdTable(db)
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

typedef $$DownloadChunksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DownloadChunksTable,
      DownloadChunk,
      $$DownloadChunksTableFilterComposer,
      $$DownloadChunksTableOrderingComposer,
      $$DownloadChunksTableAnnotationComposer,
      $$DownloadChunksTableCreateCompanionBuilder,
      $$DownloadChunksTableUpdateCompanionBuilder,
      (DownloadChunk, $$DownloadChunksTableReferences),
      DownloadChunk,
      PrefetchHooks Function({bool downloadId})
    >;
typedef $$TransfersTableCreateCompanionBuilder =
    TransfersCompanion Function({
      Value<int> id,
      required String direction,
      Value<String?> peerId,
      Value<String?> remoteAddress,
      Value<String?> entryId,
      Value<String?> chunkHash,
      Value<int> bytesTotal,
      Value<int> bytesTransferred,
      Value<int> rateBytesPerSecond,
      Value<String> state,
      Value<String?> errorMessage,
      Value<DateTime> startedAt,
      Value<DateTime> updatedAt,
    });
typedef $$TransfersTableUpdateCompanionBuilder =
    TransfersCompanion Function({
      Value<int> id,
      Value<String> direction,
      Value<String?> peerId,
      Value<String?> remoteAddress,
      Value<String?> entryId,
      Value<String?> chunkHash,
      Value<int> bytesTotal,
      Value<int> bytesTransferred,
      Value<int> rateBytesPerSecond,
      Value<String> state,
      Value<String?> errorMessage,
      Value<DateTime> startedAt,
      Value<DateTime> updatedAt,
    });

class $$TransfersTableFilterComposer
    extends Composer<_$AppDatabase, $TransfersTable> {
  $$TransfersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteAddress => $composableBuilder(
    column: $table.remoteAddress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chunkHash => $composableBuilder(
    column: $table.chunkHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytesTotal => $composableBuilder(
    column: $table.bytesTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytesTransferred => $composableBuilder(
    column: $table.bytesTransferred,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rateBytesPerSecond => $composableBuilder(
    column: $table.rateBytesPerSecond,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransfersTableOrderingComposer
    extends Composer<_$AppDatabase, $TransfersTable> {
  $$TransfersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerId => $composableBuilder(
    column: $table.peerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteAddress => $composableBuilder(
    column: $table.remoteAddress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chunkHash => $composableBuilder(
    column: $table.chunkHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesTotal => $composableBuilder(
    column: $table.bytesTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesTransferred => $composableBuilder(
    column: $table.bytesTransferred,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rateBytesPerSecond => $composableBuilder(
    column: $table.rateBytesPerSecond,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransfersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransfersTable> {
  $$TransfersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get peerId =>
      $composableBuilder(column: $table.peerId, builder: (column) => column);

  GeneratedColumn<String> get remoteAddress => $composableBuilder(
    column: $table.remoteAddress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<String> get chunkHash =>
      $composableBuilder(column: $table.chunkHash, builder: (column) => column);

  GeneratedColumn<int> get bytesTotal => $composableBuilder(
    column: $table.bytesTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bytesTransferred => $composableBuilder(
    column: $table.bytesTransferred,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rateBytesPerSecond => $composableBuilder(
    column: $table.rateBytesPerSecond,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TransfersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransfersTable,
          Transfer,
          $$TransfersTableFilterComposer,
          $$TransfersTableOrderingComposer,
          $$TransfersTableAnnotationComposer,
          $$TransfersTableCreateCompanionBuilder,
          $$TransfersTableUpdateCompanionBuilder,
          (Transfer, BaseReferences<_$AppDatabase, $TransfersTable, Transfer>),
          Transfer,
          PrefetchHooks Function()
        > {
  $$TransfersTableTableManager(_$AppDatabase db, $TransfersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransfersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransfersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransfersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String?> peerId = const Value.absent(),
                Value<String?> remoteAddress = const Value.absent(),
                Value<String?> entryId = const Value.absent(),
                Value<String?> chunkHash = const Value.absent(),
                Value<int> bytesTotal = const Value.absent(),
                Value<int> bytesTransferred = const Value.absent(),
                Value<int> rateBytesPerSecond = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TransfersCompanion(
                id: id,
                direction: direction,
                peerId: peerId,
                remoteAddress: remoteAddress,
                entryId: entryId,
                chunkHash: chunkHash,
                bytesTotal: bytesTotal,
                bytesTransferred: bytesTransferred,
                rateBytesPerSecond: rateBytesPerSecond,
                state: state,
                errorMessage: errorMessage,
                startedAt: startedAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String direction,
                Value<String?> peerId = const Value.absent(),
                Value<String?> remoteAddress = const Value.absent(),
                Value<String?> entryId = const Value.absent(),
                Value<String?> chunkHash = const Value.absent(),
                Value<int> bytesTotal = const Value.absent(),
                Value<int> bytesTransferred = const Value.absent(),
                Value<int> rateBytesPerSecond = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TransfersCompanion.insert(
                id: id,
                direction: direction,
                peerId: peerId,
                remoteAddress: remoteAddress,
                entryId: entryId,
                chunkHash: chunkHash,
                bytesTotal: bytesTotal,
                bytesTransferred: bytesTransferred,
                rateBytesPerSecond: rateBytesPerSecond,
                state: state,
                errorMessage: errorMessage,
                startedAt: startedAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransfersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransfersTable,
      Transfer,
      $$TransfersTableFilterComposer,
      $$TransfersTableOrderingComposer,
      $$TransfersTableAnnotationComposer,
      $$TransfersTableCreateCompanionBuilder,
      $$TransfersTableUpdateCompanionBuilder,
      (Transfer, BaseReferences<_$AppDatabase, $TransfersTable, Transfer>),
      Transfer,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$SharesTableTableManager get shares =>
      $$SharesTableTableManager(_db, _db.shares);
  $$EntriesTableTableManager get entries =>
      $$EntriesTableTableManager(_db, _db.entries);
  $$ChunksTableTableManager get chunks =>
      $$ChunksTableTableManager(_db, _db.chunks);
  $$PeersTableTableManager get peers =>
      $$PeersTableTableManager(_db, _db.peers);
  $$RemoteEntriesCacheTableTableManager get remoteEntriesCache =>
      $$RemoteEntriesCacheTableTableManager(_db, _db.remoteEntriesCache);
  $$RemoteFilesTableTableManager get remoteFiles =>
      $$RemoteFilesTableTableManager(_db, _db.remoteFiles);
  $$EntrySearchTokensTableTableManager get entrySearchTokens =>
      $$EntrySearchTokensTableTableManager(_db, _db.entrySearchTokens);
  $$RemoteChunkSourcesTableTableManager get remoteChunkSources =>
      $$RemoteChunkSourcesTableTableManager(_db, _db.remoteChunkSources);
  $$DownloadGroupsTableTableManager get downloadGroups =>
      $$DownloadGroupsTableTableManager(_db, _db.downloadGroups);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
  $$DownloadChunksTableTableManager get downloadChunks =>
      $$DownloadChunksTableTableManager(_db, _db.downloadChunks);
  $$TransfersTableTableManager get transfers =>
      $$TransfersTableTableManager(_db, _db.transfers);
}
