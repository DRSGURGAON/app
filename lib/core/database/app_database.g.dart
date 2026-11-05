// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
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
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _customNameMeta = const VerificationMeta(
    'customName',
  );
  @override
  late final GeneratedColumn<String> customName = GeneratedColumn<String>(
    'custom_name',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 80),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    key,
    customName,
    sortOrder,
    isDefault,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
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
    }
    if (data.containsKey('custom_name')) {
      context.handle(
        _customNameMeta,
        customName.isAcceptableOrUnknown(data['custom_name']!, _customNameMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      ),
      customName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_name'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final int id;
  final String? key;
  final String? customName;
  final int sortOrder;
  final bool isDefault;
  final DateTime createdAt;
  const Category({
    required this.id,
    this.key,
    this.customName,
    required this.sortOrder,
    required this.isDefault,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || key != null) {
      map['key'] = Variable<String>(key);
    }
    if (!nullToAbsent || customName != null) {
      map['custom_name'] = Variable<String>(customName);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_default'] = Variable<bool>(isDefault);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      key: key == null && nullToAbsent ? const Value.absent() : Value(key),
      customName: customName == null && nullToAbsent
          ? const Value.absent()
          : Value(customName),
      sortOrder: Value(sortOrder),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      key: serializer.fromJson<String?>(json['key']),
      customName: serializer.fromJson<String?>(json['customName']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'key': serializer.toJson<String?>(key),
      'customName': serializer.toJson<String?>(customName),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isDefault': serializer.toJson<bool>(isDefault),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Category copyWith({
    int? id,
    Value<String?> key = const Value.absent(),
    Value<String?> customName = const Value.absent(),
    int? sortOrder,
    bool? isDefault,
    DateTime? createdAt,
  }) => Category(
    id: id ?? this.id,
    key: key.present ? key.value : this.key,
    customName: customName.present ? customName.value : this.customName,
    sortOrder: sortOrder ?? this.sortOrder,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      key: data.key.present ? data.key.value : this.key,
      customName: data.customName.present
          ? data.customName.value
          : this.customName,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('customName: $customName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, key, customName, sortOrder, isDefault, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.key == this.key &&
          other.customName == this.customName &&
          other.sortOrder == this.sortOrder &&
          other.isDefault == this.isDefault &&
          other.createdAt == this.createdAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String?> key;
  final Value<String?> customName;
  final Value<int> sortOrder;
  final Value<bool> isDefault;
  final Value<DateTime> createdAt;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.key = const Value.absent(),
    this.customName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    this.key = const Value.absent(),
    this.customName = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isDefault = const Value.absent(),
    required DateTime createdAt,
  }) : createdAt = Value(createdAt);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? key,
    Expression<String>? customName,
    Expression<int>? sortOrder,
    Expression<bool>? isDefault,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (key != null) 'key': key,
      if (customName != null) 'custom_name': customName,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isDefault != null) 'is_default': isDefault,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  CategoriesCompanion copyWith({
    Value<int>? id,
    Value<String?>? key,
    Value<String?>? customName,
    Value<int>? sortOrder,
    Value<bool>? isDefault,
    Value<DateTime>? createdAt,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      key: key ?? this.key,
      customName: customName ?? this.customName,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
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
    if (customName.present) {
      map['custom_name'] = Variable<String>(customName.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('key: $key, ')
          ..write('customName: $customName, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $EncryptedFilesTable extends EncryptedFiles
    with TableInfo<$EncryptedFilesTable, EncryptedFile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EncryptedFilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 32,
      maxTextLength: 32,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatVersionMeta = const VerificationMeta(
    'formatVersion',
  );
  @override
  late final GeneratedColumn<int> formatVersion = GeneratedColumn<int>(
    'format_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plaintextBytesMeta = const VerificationMeta(
    'plaintextBytes',
  );
  @override
  late final GeneratedColumn<int> plaintextBytes = GeneratedColumn<int>(
    'plaintext_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ciphertextBytesMeta = const VerificationMeta(
    'ciphertextBytes',
  );
  @override
  late final GeneratedColumn<int> ciphertextBytes = GeneratedColumn<int>(
    'ciphertext_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    formatVersion,
    plaintextBytes,
    ciphertextBytes,
    fingerprint,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'encrypted_files';
  @override
  VerificationContext validateIntegrity(
    Insertable<EncryptedFile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('format_version')) {
      context.handle(
        _formatVersionMeta,
        formatVersion.isAcceptableOrUnknown(
          data['format_version']!,
          _formatVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_formatVersionMeta);
    }
    if (data.containsKey('plaintext_bytes')) {
      context.handle(
        _plaintextBytesMeta,
        plaintextBytes.isAcceptableOrUnknown(
          data['plaintext_bytes']!,
          _plaintextBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_plaintextBytesMeta);
    }
    if (data.containsKey('ciphertext_bytes')) {
      context.handle(
        _ciphertextBytesMeta,
        ciphertextBytes.isAcceptableOrUnknown(
          data['ciphertext_bytes']!,
          _ciphertextBytesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ciphertextBytesMeta);
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
  EncryptedFile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EncryptedFile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      formatVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}format_version'],
      )!,
      plaintextBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}plaintext_bytes'],
      )!,
      ciphertextBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ciphertext_bytes'],
      )!,
      fingerprint: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fingerprint'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $EncryptedFilesTable createAlias(String alias) {
    return $EncryptedFilesTable(attachedDatabase, alias);
  }
}

class EncryptedFile extends DataClass implements Insertable<EncryptedFile> {
  /// 32 lowercase hex chars; also the container's file name and header id.
  final String id;
  final int formatVersion;
  final int plaintextBytes;
  final int ciphertextBytes;

  /// Device-keyed HMAC of the plaintext, for duplicate detection only.
  final String? fingerprint;
  final DateTime createdAt;
  const EncryptedFile({
    required this.id,
    required this.formatVersion,
    required this.plaintextBytes,
    required this.ciphertextBytes,
    this.fingerprint,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['format_version'] = Variable<int>(formatVersion);
    map['plaintext_bytes'] = Variable<int>(plaintextBytes);
    map['ciphertext_bytes'] = Variable<int>(ciphertextBytes);
    if (!nullToAbsent || fingerprint != null) {
      map['fingerprint'] = Variable<String>(fingerprint);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  EncryptedFilesCompanion toCompanion(bool nullToAbsent) {
    return EncryptedFilesCompanion(
      id: Value(id),
      formatVersion: Value(formatVersion),
      plaintextBytes: Value(plaintextBytes),
      ciphertextBytes: Value(ciphertextBytes),
      fingerprint: fingerprint == null && nullToAbsent
          ? const Value.absent()
          : Value(fingerprint),
      createdAt: Value(createdAt),
    );
  }

  factory EncryptedFile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EncryptedFile(
      id: serializer.fromJson<String>(json['id']),
      formatVersion: serializer.fromJson<int>(json['formatVersion']),
      plaintextBytes: serializer.fromJson<int>(json['plaintextBytes']),
      ciphertextBytes: serializer.fromJson<int>(json['ciphertextBytes']),
      fingerprint: serializer.fromJson<String?>(json['fingerprint']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'formatVersion': serializer.toJson<int>(formatVersion),
      'plaintextBytes': serializer.toJson<int>(plaintextBytes),
      'ciphertextBytes': serializer.toJson<int>(ciphertextBytes),
      'fingerprint': serializer.toJson<String?>(fingerprint),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  EncryptedFile copyWith({
    String? id,
    int? formatVersion,
    int? plaintextBytes,
    int? ciphertextBytes,
    Value<String?> fingerprint = const Value.absent(),
    DateTime? createdAt,
  }) => EncryptedFile(
    id: id ?? this.id,
    formatVersion: formatVersion ?? this.formatVersion,
    plaintextBytes: plaintextBytes ?? this.plaintextBytes,
    ciphertextBytes: ciphertextBytes ?? this.ciphertextBytes,
    fingerprint: fingerprint.present ? fingerprint.value : this.fingerprint,
    createdAt: createdAt ?? this.createdAt,
  );
  EncryptedFile copyWithCompanion(EncryptedFilesCompanion data) {
    return EncryptedFile(
      id: data.id.present ? data.id.value : this.id,
      formatVersion: data.formatVersion.present
          ? data.formatVersion.value
          : this.formatVersion,
      plaintextBytes: data.plaintextBytes.present
          ? data.plaintextBytes.value
          : this.plaintextBytes,
      ciphertextBytes: data.ciphertextBytes.present
          ? data.ciphertextBytes.value
          : this.ciphertextBytes,
      fingerprint: data.fingerprint.present
          ? data.fingerprint.value
          : this.fingerprint,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EncryptedFile(')
          ..write('id: $id, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('plaintextBytes: $plaintextBytes, ')
          ..write('ciphertextBytes: $ciphertextBytes, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    formatVersion,
    plaintextBytes,
    ciphertextBytes,
    fingerprint,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EncryptedFile &&
          other.id == this.id &&
          other.formatVersion == this.formatVersion &&
          other.plaintextBytes == this.plaintextBytes &&
          other.ciphertextBytes == this.ciphertextBytes &&
          other.fingerprint == this.fingerprint &&
          other.createdAt == this.createdAt);
}

class EncryptedFilesCompanion extends UpdateCompanion<EncryptedFile> {
  final Value<String> id;
  final Value<int> formatVersion;
  final Value<int> plaintextBytes;
  final Value<int> ciphertextBytes;
  final Value<String?> fingerprint;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const EncryptedFilesCompanion({
    this.id = const Value.absent(),
    this.formatVersion = const Value.absent(),
    this.plaintextBytes = const Value.absent(),
    this.ciphertextBytes = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EncryptedFilesCompanion.insert({
    required String id,
    required int formatVersion,
    required int plaintextBytes,
    required int ciphertextBytes,
    this.fingerprint = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       formatVersion = Value(formatVersion),
       plaintextBytes = Value(plaintextBytes),
       ciphertextBytes = Value(ciphertextBytes),
       createdAt = Value(createdAt);
  static Insertable<EncryptedFile> custom({
    Expression<String>? id,
    Expression<int>? formatVersion,
    Expression<int>? plaintextBytes,
    Expression<int>? ciphertextBytes,
    Expression<String>? fingerprint,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (formatVersion != null) 'format_version': formatVersion,
      if (plaintextBytes != null) 'plaintext_bytes': plaintextBytes,
      if (ciphertextBytes != null) 'ciphertext_bytes': ciphertextBytes,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EncryptedFilesCompanion copyWith({
    Value<String>? id,
    Value<int>? formatVersion,
    Value<int>? plaintextBytes,
    Value<int>? ciphertextBytes,
    Value<String?>? fingerprint,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return EncryptedFilesCompanion(
      id: id ?? this.id,
      formatVersion: formatVersion ?? this.formatVersion,
      plaintextBytes: plaintextBytes ?? this.plaintextBytes,
      ciphertextBytes: ciphertextBytes ?? this.ciphertextBytes,
      fingerprint: fingerprint ?? this.fingerprint,
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
    if (formatVersion.present) {
      map['format_version'] = Variable<int>(formatVersion.value);
    }
    if (plaintextBytes.present) {
      map['plaintext_bytes'] = Variable<int>(plaintextBytes.value);
    }
    if (ciphertextBytes.present) {
      map['ciphertext_bytes'] = Variable<int>(ciphertextBytes.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
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
    return (StringBuffer('EncryptedFilesCompanion(')
          ..write('id: $id, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('plaintextBytes: $plaintextBytes, ')
          ..write('ciphertextBytes: $ciphertextBytes, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentsTable extends Documents
    with TableInfo<$DocumentsTable, Document> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeTypeMeta = const VerificationMeta(
    'mimeType',
  );
  @override
  late final GeneratedColumn<String> mimeType = GeneratedColumn<String>(
    'mime_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileIdMeta = const VerificationMeta('fileId');
  @override
  late final GeneratedColumn<String> fileId = GeneratedColumn<String>(
    'file_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES encrypted_files (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES categories (id) ON DELETE SET NULL',
    ),
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
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    mimeType,
    fileId,
    categoryId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<Document> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('file_id')) {
      context.handle(
        _fileIdMeta,
        fileId.isAcceptableOrUnknown(data['file_id']!, _fileIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fileIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
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
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Document map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Document(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      fileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_id'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DocumentsTable createAlias(String alias) {
    return $DocumentsTable(attachedDatabase, alias);
  }
}

class Document extends DataClass implements Insertable<Document> {
  final int id;
  final String title;
  final String mimeType;
  final String fileId;
  final int? categoryId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Document({
    required this.id,
    required this.title,
    required this.mimeType,
    required this.fileId,
    this.categoryId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['mime_type'] = Variable<String>(mimeType);
    map['file_id'] = Variable<String>(fileId);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      id: Value(id),
      title: Value(title),
      mimeType: Value(mimeType),
      fileId: Value(fileId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Document.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Document(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      fileId: serializer.fromJson<String>(json['fileId']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'mimeType': serializer.toJson<String>(mimeType),
      'fileId': serializer.toJson<String>(fileId),
      'categoryId': serializer.toJson<int?>(categoryId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Document copyWith({
    int? id,
    String? title,
    String? mimeType,
    String? fileId,
    Value<int?> categoryId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Document(
    id: id ?? this.id,
    title: title ?? this.title,
    mimeType: mimeType ?? this.mimeType,
    fileId: fileId ?? this.fileId,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Document copyWithCompanion(DocumentsCompanion data) {
    return Document(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      fileId: data.fileId.present ? data.fileId.value : this.fileId,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Document(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('mimeType: $mimeType, ')
          ..write('fileId: $fileId, ')
          ..write('categoryId: $categoryId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    mimeType,
    fileId,
    categoryId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Document &&
          other.id == this.id &&
          other.title == this.title &&
          other.mimeType == this.mimeType &&
          other.fileId == this.fileId &&
          other.categoryId == this.categoryId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DocumentsCompanion extends UpdateCompanion<Document> {
  final Value<int> id;
  final Value<String> title;
  final Value<String> mimeType;
  final Value<String> fileId;
  final Value<int?> categoryId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const DocumentsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.fileId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DocumentsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required String mimeType,
    required String fileId,
    this.categoryId = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : title = Value(title),
       mimeType = Value(mimeType),
       fileId = Value(fileId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Document> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? mimeType,
    Expression<String>? fileId,
    Expression<int>? categoryId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (mimeType != null) 'mime_type': mimeType,
      if (fileId != null) 'file_id': fileId,
      if (categoryId != null) 'category_id': categoryId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DocumentsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String>? mimeType,
    Value<String>? fileId,
    Value<int?>? categoryId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return DocumentsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      mimeType: mimeType ?? this.mimeType,
      fileId: fileId ?? this.fileId,
      categoryId: categoryId ?? this.categoryId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (fileId.present) {
      map['file_id'] = Variable<String>(fileId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('mimeType: $mimeType, ')
          ..write('fileId: $fileId, ')
          ..write('categoryId: $categoryId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
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
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
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
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $EncryptedFilesTable encryptedFiles = $EncryptedFilesTable(this);
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final Index idxCategoriesSort = Index(
    'idx_categories_sort',
    'CREATE INDEX idx_categories_sort ON categories (sort_order)',
  );
  late final Index idxEncryptedFilesFingerprint = Index(
    'idx_encrypted_files_fingerprint',
    'CREATE INDEX idx_encrypted_files_fingerprint ON encrypted_files (fingerprint)',
  );
  late final Index idxDocumentsCreated = Index(
    'idx_documents_created',
    'CREATE INDEX idx_documents_created ON documents (created_at)',
  );
  late final Index idxDocumentsCategory = Index(
    'idx_documents_category',
    'CREATE INDEX idx_documents_category ON documents (category_id)',
  );
  late final Index idxDocumentsFile = Index(
    'idx_documents_file',
    'CREATE UNIQUE INDEX idx_documents_file ON documents (file_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    categories,
    encryptedFiles,
    documents,
    appSettings,
    idxCategoriesSort,
    idxEncryptedFilesFingerprint,
    idxDocumentsCreated,
    idxDocumentsCategory,
    idxDocumentsFile,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'categories',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('documents', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  Value<String?> key,
  Value<String?> customName,
  Value<int> sortOrder,
  Value<bool> isDefault,
  required DateTime createdAt,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  Value<String?> key,
  Value<String?> customName,
  Value<int> sortOrder,
  Value<bool> isDefault,
  Value<DateTime> createdAt,
});

final class $$CategoriesTableReferences
    extends BaseReferences<_$AppDatabase, $CategoriesTable, Category> {
  $$CategoriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DocumentsTable, List<Document>>
  _documentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.documents,
    aliasName: 'categories__id__documents__category_id',
  );

  $$DocumentsTableProcessedTableManager get documentsRefs {
    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_documentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
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

  ColumnFilters<String> get customName => $composableBuilder(
    column: $table.customName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> documentsRefs(
    Expression<bool> Function($$DocumentsTableFilterComposer f) f,
  ) {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
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

  ColumnOrderings<String> get customName => $composableBuilder(
    column: $table.customName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
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

  GeneratedColumn<String> get customName => $composableBuilder(
    column: $table.customName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> documentsRefs<T extends Object>(
    Expression<T> Function($$DocumentsTableAnnotationComposer a) f,
  ) {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, $$CategoriesTableReferences),
          Category,
          PrefetchHooks Function({bool documentsRefs})
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> key = const Value.absent(),
                Value<String?> customName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                key: key,
                customName: customName,
                sortOrder: sortOrder,
                isDefault: isDefault,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> key = const Value.absent(),
                Value<String?> customName = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                required DateTime createdAt,
              }) => CategoriesCompanion.insert(
                id: id,
                key: key,
                customName: customName,
                sortOrder: sortOrder,
                isDefault: isDefault,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CategoriesTable, Category>(table),
                  $$CategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (documentsRefs) db.documents],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (documentsRefs)
                    await $_getPrefetchedDataByColumns<
                      Category,
                      $CategoriesTable,
                      Document,
                      $DocumentsTable
                    >(
                      currentTable: table,
                      referencedTable: $$CategoriesTableReferences
                          ._documentsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CategoriesTableReferences(
                            db,
                            table,
                            p0,
                          ).documentsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'category_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, $$CategoriesTableReferences),
      Category,
      PrefetchHooks Function({bool documentsRefs})
    >;
typedef $$EncryptedFilesTableCreateCompanionBuilder =
    EncryptedFilesCompanion Function({
      required String id,
      required int formatVersion,
      required int plaintextBytes,
      required int ciphertextBytes,
      Value<String?> fingerprint,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$EncryptedFilesTableUpdateCompanionBuilder =
    EncryptedFilesCompanion Function({
      Value<String> id,
      Value<int> formatVersion,
      Value<int> plaintextBytes,
      Value<int> ciphertextBytes,
      Value<String?> fingerprint,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$EncryptedFilesTableReferences
    extends BaseReferences<_$AppDatabase, $EncryptedFilesTable, EncryptedFile> {
  $$EncryptedFilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$DocumentsTable, List<Document>>
  _documentsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.documents,
    aliasName: 'encrypted_files__id__documents__file_id',
  );

  $$DocumentsTableProcessedTableManager get documentsRefs {
    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.fileId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_documentsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EncryptedFilesTableFilterComposer
    extends Composer<_$AppDatabase, $EncryptedFilesTable> {
  $$EncryptedFilesTableFilterComposer({
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

  ColumnFilters<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plaintextBytes => $composableBuilder(
    column: $table.plaintextBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ciphertextBytes => $composableBuilder(
    column: $table.ciphertextBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> documentsRefs(
    Expression<bool> Function($$DocumentsTableFilterComposer f) f,
  ) {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.fileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EncryptedFilesTableOrderingComposer
    extends Composer<_$AppDatabase, $EncryptedFilesTable> {
  $$EncryptedFilesTableOrderingComposer({
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

  ColumnOrderings<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plaintextBytes => $composableBuilder(
    column: $table.plaintextBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ciphertextBytes => $composableBuilder(
    column: $table.ciphertextBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EncryptedFilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $EncryptedFilesTable> {
  $$EncryptedFilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get plaintextBytes => $composableBuilder(
    column: $table.plaintextBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ciphertextBytes => $composableBuilder(
    column: $table.ciphertextBytes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get fingerprint => $composableBuilder(
    column: $table.fingerprint,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> documentsRefs<T extends Object>(
    Expression<T> Function($$DocumentsTableAnnotationComposer a) f,
  ) {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.fileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EncryptedFilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EncryptedFilesTable,
          EncryptedFile,
          $$EncryptedFilesTableFilterComposer,
          $$EncryptedFilesTableOrderingComposer,
          $$EncryptedFilesTableAnnotationComposer,
          $$EncryptedFilesTableCreateCompanionBuilder,
          $$EncryptedFilesTableUpdateCompanionBuilder,
          (EncryptedFile, $$EncryptedFilesTableReferences),
          EncryptedFile,
          PrefetchHooks Function({bool documentsRefs})
        > {
  $$EncryptedFilesTableTableManager(
    _$AppDatabase db,
    $EncryptedFilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EncryptedFilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EncryptedFilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EncryptedFilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> formatVersion = const Value.absent(),
                Value<int> plaintextBytes = const Value.absent(),
                Value<int> ciphertextBytes = const Value.absent(),
                Value<String?> fingerprint = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EncryptedFilesCompanion(
                id: id,
                formatVersion: formatVersion,
                plaintextBytes: plaintextBytes,
                ciphertextBytes: ciphertextBytes,
                fingerprint: fingerprint,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int formatVersion,
                required int plaintextBytes,
                required int ciphertextBytes,
                Value<String?> fingerprint = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => EncryptedFilesCompanion.insert(
                id: id,
                formatVersion: formatVersion,
                plaintextBytes: plaintextBytes,
                ciphertextBytes: ciphertextBytes,
                fingerprint: fingerprint,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EncryptedFilesTable, EncryptedFile>(table),
                  $$EncryptedFilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (documentsRefs) db.documents],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (documentsRefs)
                    await $_getPrefetchedDataByColumns<
                      EncryptedFile,
                      $EncryptedFilesTable,
                      Document,
                      $DocumentsTable
                    >(
                      currentTable: table,
                      referencedTable: $$EncryptedFilesTableReferences
                          ._documentsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$EncryptedFilesTableReferences(
                            db,
                            table,
                            p0,
                          ).documentsRefs,
                      currentColumn: 'id',
                      referencedColumn: 'file_id',
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$EncryptedFilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EncryptedFilesTable,
      EncryptedFile,
      $$EncryptedFilesTableFilterComposer,
      $$EncryptedFilesTableOrderingComposer,
      $$EncryptedFilesTableAnnotationComposer,
      $$EncryptedFilesTableCreateCompanionBuilder,
      $$EncryptedFilesTableUpdateCompanionBuilder,
      (EncryptedFile, $$EncryptedFilesTableReferences),
      EncryptedFile,
      PrefetchHooks Function({bool documentsRefs})
    >;
typedef $$DocumentsTableCreateCompanionBuilder = DocumentsCompanion Function({
  Value<int> id,
  required String title,
  required String mimeType,
  required String fileId,
  Value<int?> categoryId,
  required DateTime createdAt,
  required DateTime updatedAt,
});
typedef $$DocumentsTableUpdateCompanionBuilder = DocumentsCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String> mimeType,
  Value<String> fileId,
  Value<int?> categoryId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
});

final class $$DocumentsTableReferences
    extends BaseReferences<_$AppDatabase, $DocumentsTable, Document> {
  $$DocumentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $EncryptedFilesTable _fileIdTable(_$AppDatabase db) =>
      db.encryptedFiles.createAlias('documents__file_id__encrypted_files__id');

  $$EncryptedFilesTableProcessedTableManager get fileId {
    final $_column = $_itemColumn<String>('file_id')!;

    final manager = $$EncryptedFilesTableTableManager(
      $_db,
      $_db.encryptedFiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_fileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.categories.createAlias('documents__category_id__categories__id');

  $$CategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<int>('category_id');
    if ($_column == null) return null;
    final manager = $$CategoriesTableTableManager(
      $_db,
      $_db.categories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DocumentsTableFilterComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableFilterComposer({
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

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
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

  $$EncryptedFilesTableFilterComposer get fileId {
    final $$EncryptedFilesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fileId,
      referencedTable: $db.encryptedFiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EncryptedFilesTableFilterComposer(
            $db: $db,
            $table: $db.encryptedFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableFilterComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentsTableOrderingComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableOrderingComposer({
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

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
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

  $$EncryptedFilesTableOrderingComposer get fileId {
    final $$EncryptedFilesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fileId,
      referencedTable: $db.encryptedFiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EncryptedFilesTableOrderingComposer(
            $db: $db,
            $table: $db.encryptedFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$EncryptedFilesTableAnnotationComposer get fileId {
    final $$EncryptedFilesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.fileId,
      referencedTable: $db.encryptedFiles,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EncryptedFilesTableAnnotationComposer(
            $db: $db,
            $table: $db.encryptedFiles,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CategoriesTableAnnotationComposer get categoryId {
    final $$CategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.categories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.categories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentsTable,
          Document,
          $$DocumentsTableFilterComposer,
          $$DocumentsTableOrderingComposer,
          $$DocumentsTableAnnotationComposer,
          $$DocumentsTableCreateCompanionBuilder,
          $$DocumentsTableUpdateCompanionBuilder,
          (Document, $$DocumentsTableReferences),
          Document,
          PrefetchHooks Function({bool fileId, bool categoryId})
        > {
  $$DocumentsTableTableManager(_$AppDatabase db, $DocumentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<String> fileId = const Value.absent(),
                Value<int?> categoryId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DocumentsCompanion(
                id: id,
                title: title,
                mimeType: mimeType,
                fileId: fileId,
                categoryId: categoryId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required String mimeType,
                required String fileId,
                Value<int?> categoryId = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => DocumentsCompanion.insert(
                id: id,
                title: title,
                mimeType: mimeType,
                fileId: fileId,
                categoryId: categoryId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DocumentsTable, Document>(table),
                  $$DocumentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({fileId = false, categoryId = false}) {
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
                    if (fileId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.fileId,
                        referencedTable: $$DocumentsTableReferences
                            ._fileIdTable(db),
                        referencedColumn: $$DocumentsTableReferences
                            ._fileIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (categoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.categoryId,
                        referencedTable: $$DocumentsTableReferences
                            ._categoryIdTable(db),
                        referencedColumn: $$DocumentsTableReferences
                            ._categoryIdTable(db)
                            .id,
                      ) as T;
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

typedef $$DocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentsTable,
      Document,
      $$DocumentsTableFilterComposer,
      $$DocumentsTableOrderingComposer,
      $$DocumentsTableAnnotationComposer,
      $$DocumentsTableCreateCompanionBuilder,
      $$DocumentsTableUpdateCompanionBuilder,
      (Document, $$DocumentsTableReferences),
      Document,
      PrefetchHooks Function({bool fileId, bool categoryId})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AppSettingsTable, AppSetting>(table),
                  BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$EncryptedFilesTableTableManager get encryptedFiles =>
      $$EncryptedFilesTableTableManager(_db, _db.encryptedFiles);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db, _db.documents);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
