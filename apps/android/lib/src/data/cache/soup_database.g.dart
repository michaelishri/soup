// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'soup_database.dart';

// ignore_for_file: type=lint
class $MediaItemsTable extends MediaItems
    with TableInfo<$MediaItemsTable, MediaItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MediaItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
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
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _collectionTypeMeta = const VerificationMeta(
    'collectionType',
  );
  @override
  late final GeneratedColumn<String> collectionType = GeneratedColumn<String>(
    'collection_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _overviewMeta = const VerificationMeta(
    'overview',
  );
  @override
  late final GeneratedColumn<String> overview = GeneratedColumn<String>(
    'overview',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productionYearMeta = const VerificationMeta(
    'productionYear',
  );
  @override
  late final GeneratedColumn<int> productionYear = GeneratedColumn<int>(
    'production_year',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _officialRatingMeta = const VerificationMeta(
    'officialRating',
  );
  @override
  late final GeneratedColumn<String> officialRating = GeneratedColumn<String>(
    'official_rating',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _communityRatingMeta = const VerificationMeta(
    'communityRating',
  );
  @override
  late final GeneratedColumn<double> communityRating = GeneratedColumn<double>(
    'community_rating',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _runTimeTicksMeta = const VerificationMeta(
    'runTimeTicks',
  );
  @override
  late final GeneratedColumn<int> runTimeTicks = GeneratedColumn<int>(
    'run_time_ticks',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seriesNameMeta = const VerificationMeta(
    'seriesName',
  );
  @override
  late final GeneratedColumn<String> seriesName = GeneratedColumn<String>(
    'series_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _seasonNameMeta = const VerificationMeta(
    'seasonName',
  );
  @override
  late final GeneratedColumn<String> seasonName = GeneratedColumn<String>(
    'season_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _indexNumberMeta = const VerificationMeta(
    'indexNumber',
  );
  @override
  late final GeneratedColumn<int> indexNumber = GeneratedColumn<int>(
    'index_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentIndexNumberMeta = const VerificationMeta(
    'parentIndexNumber',
  );
  @override
  late final GeneratedColumn<int> parentIndexNumber = GeneratedColumn<int>(
    'parent_index_number',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _primaryImageTagMeta = const VerificationMeta(
    'primaryImageTag',
  );
  @override
  late final GeneratedColumn<String> primaryImageTag = GeneratedColumn<String>(
    'primary_image_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backdropImageTagMeta = const VerificationMeta(
    'backdropImageTag',
  );
  @override
  late final GeneratedColumn<String> backdropImageTag = GeneratedColumn<String>(
    'backdrop_image_tag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _primaryBlurHashMeta = const VerificationMeta(
    'primaryBlurHash',
  );
  @override
  late final GeneratedColumn<String> primaryBlurHash = GeneratedColumn<String>(
    'primary_blur_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _backdropBlurHashMeta = const VerificationMeta(
    'backdropBlurHash',
  );
  @override
  late final GeneratedColumn<String> backdropBlurHash = GeneratedColumn<String>(
    'backdrop_blur_hash',
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    itemId,
    name,
    type,
    collectionType,
    overview,
    productionYear,
    officialRating,
    communityRating,
    runTimeTicks,
    seriesName,
    seasonName,
    indexNumber,
    parentIndexNumber,
    primaryImageTag,
    backdropImageTag,
    primaryBlurHash,
    backdropBlurHash,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'media_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<MediaItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('collection_type')) {
      context.handle(
        _collectionTypeMeta,
        collectionType.isAcceptableOrUnknown(
          data['collection_type']!,
          _collectionTypeMeta,
        ),
      );
    }
    if (data.containsKey('overview')) {
      context.handle(
        _overviewMeta,
        overview.isAcceptableOrUnknown(data['overview']!, _overviewMeta),
      );
    }
    if (data.containsKey('production_year')) {
      context.handle(
        _productionYearMeta,
        productionYear.isAcceptableOrUnknown(
          data['production_year']!,
          _productionYearMeta,
        ),
      );
    }
    if (data.containsKey('official_rating')) {
      context.handle(
        _officialRatingMeta,
        officialRating.isAcceptableOrUnknown(
          data['official_rating']!,
          _officialRatingMeta,
        ),
      );
    }
    if (data.containsKey('community_rating')) {
      context.handle(
        _communityRatingMeta,
        communityRating.isAcceptableOrUnknown(
          data['community_rating']!,
          _communityRatingMeta,
        ),
      );
    }
    if (data.containsKey('run_time_ticks')) {
      context.handle(
        _runTimeTicksMeta,
        runTimeTicks.isAcceptableOrUnknown(
          data['run_time_ticks']!,
          _runTimeTicksMeta,
        ),
      );
    }
    if (data.containsKey('series_name')) {
      context.handle(
        _seriesNameMeta,
        seriesName.isAcceptableOrUnknown(data['series_name']!, _seriesNameMeta),
      );
    }
    if (data.containsKey('season_name')) {
      context.handle(
        _seasonNameMeta,
        seasonName.isAcceptableOrUnknown(data['season_name']!, _seasonNameMeta),
      );
    }
    if (data.containsKey('index_number')) {
      context.handle(
        _indexNumberMeta,
        indexNumber.isAcceptableOrUnknown(
          data['index_number']!,
          _indexNumberMeta,
        ),
      );
    }
    if (data.containsKey('parent_index_number')) {
      context.handle(
        _parentIndexNumberMeta,
        parentIndexNumber.isAcceptableOrUnknown(
          data['parent_index_number']!,
          _parentIndexNumberMeta,
        ),
      );
    }
    if (data.containsKey('primary_image_tag')) {
      context.handle(
        _primaryImageTagMeta,
        primaryImageTag.isAcceptableOrUnknown(
          data['primary_image_tag']!,
          _primaryImageTagMeta,
        ),
      );
    }
    if (data.containsKey('backdrop_image_tag')) {
      context.handle(
        _backdropImageTagMeta,
        backdropImageTag.isAcceptableOrUnknown(
          data['backdrop_image_tag']!,
          _backdropImageTagMeta,
        ),
      );
    }
    if (data.containsKey('primary_blur_hash')) {
      context.handle(
        _primaryBlurHashMeta,
        primaryBlurHash.isAcceptableOrUnknown(
          data['primary_blur_hash']!,
          _primaryBlurHashMeta,
        ),
      );
    }
    if (data.containsKey('backdrop_blur_hash')) {
      context.handle(
        _backdropBlurHashMeta,
        backdropBlurHash.isAcceptableOrUnknown(
          data['backdrop_blur_hash']!,
          _backdropBlurHashMeta,
        ),
      );
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
  Set<GeneratedColumn> get $primaryKey => {serverId, itemId};
  @override
  MediaItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MediaItem(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      collectionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_type'],
      ),
      overview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}overview'],
      ),
      productionYear: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}production_year'],
      ),
      officialRating: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}official_rating'],
      ),
      communityRating: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}community_rating'],
      ),
      runTimeTicks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}run_time_ticks'],
      ),
      seriesName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}series_name'],
      ),
      seasonName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}season_name'],
      ),
      indexNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}index_number'],
      ),
      parentIndexNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_index_number'],
      ),
      primaryImageTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_image_tag'],
      ),
      backdropImageTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backdrop_image_tag'],
      ),
      primaryBlurHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}primary_blur_hash'],
      ),
      backdropBlurHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}backdrop_blur_hash'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $MediaItemsTable createAlias(String alias) {
    return $MediaItemsTable(attachedDatabase, alias);
  }
}

class MediaItem extends DataClass implements Insertable<MediaItem> {
  final String serverId;
  final String itemId;
  final String name;
  final String type;
  final String? collectionType;
  final String? overview;
  final int? productionYear;
  final String? officialRating;
  final double? communityRating;
  final int? runTimeTicks;
  final String? seriesName;
  final String? seasonName;
  final int? indexNumber;
  final int? parentIndexNumber;
  final String? primaryImageTag;
  final String? backdropImageTag;
  final String? primaryBlurHash;
  final String? backdropBlurHash;
  final DateTime updatedAt;
  const MediaItem({
    required this.serverId,
    required this.itemId,
    required this.name,
    required this.type,
    this.collectionType,
    this.overview,
    this.productionYear,
    this.officialRating,
    this.communityRating,
    this.runTimeTicks,
    this.seriesName,
    this.seasonName,
    this.indexNumber,
    this.parentIndexNumber,
    this.primaryImageTag,
    this.backdropImageTag,
    this.primaryBlurHash,
    this.backdropBlurHash,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['item_id'] = Variable<String>(itemId);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || collectionType != null) {
      map['collection_type'] = Variable<String>(collectionType);
    }
    if (!nullToAbsent || overview != null) {
      map['overview'] = Variable<String>(overview);
    }
    if (!nullToAbsent || productionYear != null) {
      map['production_year'] = Variable<int>(productionYear);
    }
    if (!nullToAbsent || officialRating != null) {
      map['official_rating'] = Variable<String>(officialRating);
    }
    if (!nullToAbsent || communityRating != null) {
      map['community_rating'] = Variable<double>(communityRating);
    }
    if (!nullToAbsent || runTimeTicks != null) {
      map['run_time_ticks'] = Variable<int>(runTimeTicks);
    }
    if (!nullToAbsent || seriesName != null) {
      map['series_name'] = Variable<String>(seriesName);
    }
    if (!nullToAbsent || seasonName != null) {
      map['season_name'] = Variable<String>(seasonName);
    }
    if (!nullToAbsent || indexNumber != null) {
      map['index_number'] = Variable<int>(indexNumber);
    }
    if (!nullToAbsent || parentIndexNumber != null) {
      map['parent_index_number'] = Variable<int>(parentIndexNumber);
    }
    if (!nullToAbsent || primaryImageTag != null) {
      map['primary_image_tag'] = Variable<String>(primaryImageTag);
    }
    if (!nullToAbsent || backdropImageTag != null) {
      map['backdrop_image_tag'] = Variable<String>(backdropImageTag);
    }
    if (!nullToAbsent || primaryBlurHash != null) {
      map['primary_blur_hash'] = Variable<String>(primaryBlurHash);
    }
    if (!nullToAbsent || backdropBlurHash != null) {
      map['backdrop_blur_hash'] = Variable<String>(backdropBlurHash);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  MediaItemsCompanion toCompanion(bool nullToAbsent) {
    return MediaItemsCompanion(
      serverId: Value(serverId),
      itemId: Value(itemId),
      name: Value(name),
      type: Value(type),
      collectionType: collectionType == null && nullToAbsent
          ? const Value.absent()
          : Value(collectionType),
      overview: overview == null && nullToAbsent
          ? const Value.absent()
          : Value(overview),
      productionYear: productionYear == null && nullToAbsent
          ? const Value.absent()
          : Value(productionYear),
      officialRating: officialRating == null && nullToAbsent
          ? const Value.absent()
          : Value(officialRating),
      communityRating: communityRating == null && nullToAbsent
          ? const Value.absent()
          : Value(communityRating),
      runTimeTicks: runTimeTicks == null && nullToAbsent
          ? const Value.absent()
          : Value(runTimeTicks),
      seriesName: seriesName == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesName),
      seasonName: seasonName == null && nullToAbsent
          ? const Value.absent()
          : Value(seasonName),
      indexNumber: indexNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(indexNumber),
      parentIndexNumber: parentIndexNumber == null && nullToAbsent
          ? const Value.absent()
          : Value(parentIndexNumber),
      primaryImageTag: primaryImageTag == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryImageTag),
      backdropImageTag: backdropImageTag == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropImageTag),
      primaryBlurHash: primaryBlurHash == null && nullToAbsent
          ? const Value.absent()
          : Value(primaryBlurHash),
      backdropBlurHash: backdropBlurHash == null && nullToAbsent
          ? const Value.absent()
          : Value(backdropBlurHash),
      updatedAt: Value(updatedAt),
    );
  }

  factory MediaItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MediaItem(
      serverId: serializer.fromJson<String>(json['serverId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      collectionType: serializer.fromJson<String?>(json['collectionType']),
      overview: serializer.fromJson<String?>(json['overview']),
      productionYear: serializer.fromJson<int?>(json['productionYear']),
      officialRating: serializer.fromJson<String?>(json['officialRating']),
      communityRating: serializer.fromJson<double?>(json['communityRating']),
      runTimeTicks: serializer.fromJson<int?>(json['runTimeTicks']),
      seriesName: serializer.fromJson<String?>(json['seriesName']),
      seasonName: serializer.fromJson<String?>(json['seasonName']),
      indexNumber: serializer.fromJson<int?>(json['indexNumber']),
      parentIndexNumber: serializer.fromJson<int?>(json['parentIndexNumber']),
      primaryImageTag: serializer.fromJson<String?>(json['primaryImageTag']),
      backdropImageTag: serializer.fromJson<String?>(json['backdropImageTag']),
      primaryBlurHash: serializer.fromJson<String?>(json['primaryBlurHash']),
      backdropBlurHash: serializer.fromJson<String?>(json['backdropBlurHash']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'itemId': serializer.toJson<String>(itemId),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'collectionType': serializer.toJson<String?>(collectionType),
      'overview': serializer.toJson<String?>(overview),
      'productionYear': serializer.toJson<int?>(productionYear),
      'officialRating': serializer.toJson<String?>(officialRating),
      'communityRating': serializer.toJson<double?>(communityRating),
      'runTimeTicks': serializer.toJson<int?>(runTimeTicks),
      'seriesName': serializer.toJson<String?>(seriesName),
      'seasonName': serializer.toJson<String?>(seasonName),
      'indexNumber': serializer.toJson<int?>(indexNumber),
      'parentIndexNumber': serializer.toJson<int?>(parentIndexNumber),
      'primaryImageTag': serializer.toJson<String?>(primaryImageTag),
      'backdropImageTag': serializer.toJson<String?>(backdropImageTag),
      'primaryBlurHash': serializer.toJson<String?>(primaryBlurHash),
      'backdropBlurHash': serializer.toJson<String?>(backdropBlurHash),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  MediaItem copyWith({
    String? serverId,
    String? itemId,
    String? name,
    String? type,
    Value<String?> collectionType = const Value.absent(),
    Value<String?> overview = const Value.absent(),
    Value<int?> productionYear = const Value.absent(),
    Value<String?> officialRating = const Value.absent(),
    Value<double?> communityRating = const Value.absent(),
    Value<int?> runTimeTicks = const Value.absent(),
    Value<String?> seriesName = const Value.absent(),
    Value<String?> seasonName = const Value.absent(),
    Value<int?> indexNumber = const Value.absent(),
    Value<int?> parentIndexNumber = const Value.absent(),
    Value<String?> primaryImageTag = const Value.absent(),
    Value<String?> backdropImageTag = const Value.absent(),
    Value<String?> primaryBlurHash = const Value.absent(),
    Value<String?> backdropBlurHash = const Value.absent(),
    DateTime? updatedAt,
  }) => MediaItem(
    serverId: serverId ?? this.serverId,
    itemId: itemId ?? this.itemId,
    name: name ?? this.name,
    type: type ?? this.type,
    collectionType: collectionType.present
        ? collectionType.value
        : this.collectionType,
    overview: overview.present ? overview.value : this.overview,
    productionYear: productionYear.present
        ? productionYear.value
        : this.productionYear,
    officialRating: officialRating.present
        ? officialRating.value
        : this.officialRating,
    communityRating: communityRating.present
        ? communityRating.value
        : this.communityRating,
    runTimeTicks: runTimeTicks.present ? runTimeTicks.value : this.runTimeTicks,
    seriesName: seriesName.present ? seriesName.value : this.seriesName,
    seasonName: seasonName.present ? seasonName.value : this.seasonName,
    indexNumber: indexNumber.present ? indexNumber.value : this.indexNumber,
    parentIndexNumber: parentIndexNumber.present
        ? parentIndexNumber.value
        : this.parentIndexNumber,
    primaryImageTag: primaryImageTag.present
        ? primaryImageTag.value
        : this.primaryImageTag,
    backdropImageTag: backdropImageTag.present
        ? backdropImageTag.value
        : this.backdropImageTag,
    primaryBlurHash: primaryBlurHash.present
        ? primaryBlurHash.value
        : this.primaryBlurHash,
    backdropBlurHash: backdropBlurHash.present
        ? backdropBlurHash.value
        : this.backdropBlurHash,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  MediaItem copyWithCompanion(MediaItemsCompanion data) {
    return MediaItem(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      collectionType: data.collectionType.present
          ? data.collectionType.value
          : this.collectionType,
      overview: data.overview.present ? data.overview.value : this.overview,
      productionYear: data.productionYear.present
          ? data.productionYear.value
          : this.productionYear,
      officialRating: data.officialRating.present
          ? data.officialRating.value
          : this.officialRating,
      communityRating: data.communityRating.present
          ? data.communityRating.value
          : this.communityRating,
      runTimeTicks: data.runTimeTicks.present
          ? data.runTimeTicks.value
          : this.runTimeTicks,
      seriesName: data.seriesName.present
          ? data.seriesName.value
          : this.seriesName,
      seasonName: data.seasonName.present
          ? data.seasonName.value
          : this.seasonName,
      indexNumber: data.indexNumber.present
          ? data.indexNumber.value
          : this.indexNumber,
      parentIndexNumber: data.parentIndexNumber.present
          ? data.parentIndexNumber.value
          : this.parentIndexNumber,
      primaryImageTag: data.primaryImageTag.present
          ? data.primaryImageTag.value
          : this.primaryImageTag,
      backdropImageTag: data.backdropImageTag.present
          ? data.backdropImageTag.value
          : this.backdropImageTag,
      primaryBlurHash: data.primaryBlurHash.present
          ? data.primaryBlurHash.value
          : this.primaryBlurHash,
      backdropBlurHash: data.backdropBlurHash.present
          ? data.backdropBlurHash.value
          : this.backdropBlurHash,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MediaItem(')
          ..write('serverId: $serverId, ')
          ..write('itemId: $itemId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('collectionType: $collectionType, ')
          ..write('overview: $overview, ')
          ..write('productionYear: $productionYear, ')
          ..write('officialRating: $officialRating, ')
          ..write('communityRating: $communityRating, ')
          ..write('runTimeTicks: $runTimeTicks, ')
          ..write('seriesName: $seriesName, ')
          ..write('seasonName: $seasonName, ')
          ..write('indexNumber: $indexNumber, ')
          ..write('parentIndexNumber: $parentIndexNumber, ')
          ..write('primaryImageTag: $primaryImageTag, ')
          ..write('backdropImageTag: $backdropImageTag, ')
          ..write('primaryBlurHash: $primaryBlurHash, ')
          ..write('backdropBlurHash: $backdropBlurHash, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serverId,
    itemId,
    name,
    type,
    collectionType,
    overview,
    productionYear,
    officialRating,
    communityRating,
    runTimeTicks,
    seriesName,
    seasonName,
    indexNumber,
    parentIndexNumber,
    primaryImageTag,
    backdropImageTag,
    primaryBlurHash,
    backdropBlurHash,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MediaItem &&
          other.serverId == this.serverId &&
          other.itemId == this.itemId &&
          other.name == this.name &&
          other.type == this.type &&
          other.collectionType == this.collectionType &&
          other.overview == this.overview &&
          other.productionYear == this.productionYear &&
          other.officialRating == this.officialRating &&
          other.communityRating == this.communityRating &&
          other.runTimeTicks == this.runTimeTicks &&
          other.seriesName == this.seriesName &&
          other.seasonName == this.seasonName &&
          other.indexNumber == this.indexNumber &&
          other.parentIndexNumber == this.parentIndexNumber &&
          other.primaryImageTag == this.primaryImageTag &&
          other.backdropImageTag == this.backdropImageTag &&
          other.primaryBlurHash == this.primaryBlurHash &&
          other.backdropBlurHash == this.backdropBlurHash &&
          other.updatedAt == this.updatedAt);
}

class MediaItemsCompanion extends UpdateCompanion<MediaItem> {
  final Value<String> serverId;
  final Value<String> itemId;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> collectionType;
  final Value<String?> overview;
  final Value<int?> productionYear;
  final Value<String?> officialRating;
  final Value<double?> communityRating;
  final Value<int?> runTimeTicks;
  final Value<String?> seriesName;
  final Value<String?> seasonName;
  final Value<int?> indexNumber;
  final Value<int?> parentIndexNumber;
  final Value<String?> primaryImageTag;
  final Value<String?> backdropImageTag;
  final Value<String?> primaryBlurHash;
  final Value<String?> backdropBlurHash;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const MediaItemsCompanion({
    this.serverId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.collectionType = const Value.absent(),
    this.overview = const Value.absent(),
    this.productionYear = const Value.absent(),
    this.officialRating = const Value.absent(),
    this.communityRating = const Value.absent(),
    this.runTimeTicks = const Value.absent(),
    this.seriesName = const Value.absent(),
    this.seasonName = const Value.absent(),
    this.indexNumber = const Value.absent(),
    this.parentIndexNumber = const Value.absent(),
    this.primaryImageTag = const Value.absent(),
    this.backdropImageTag = const Value.absent(),
    this.primaryBlurHash = const Value.absent(),
    this.backdropBlurHash = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MediaItemsCompanion.insert({
    required String serverId,
    required String itemId,
    required String name,
    required String type,
    this.collectionType = const Value.absent(),
    this.overview = const Value.absent(),
    this.productionYear = const Value.absent(),
    this.officialRating = const Value.absent(),
    this.communityRating = const Value.absent(),
    this.runTimeTicks = const Value.absent(),
    this.seriesName = const Value.absent(),
    this.seasonName = const Value.absent(),
    this.indexNumber = const Value.absent(),
    this.parentIndexNumber = const Value.absent(),
    this.primaryImageTag = const Value.absent(),
    this.backdropImageTag = const Value.absent(),
    this.primaryBlurHash = const Value.absent(),
    this.backdropBlurHash = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       itemId = Value(itemId),
       name = Value(name),
       type = Value(type),
       updatedAt = Value(updatedAt);
  static Insertable<MediaItem> custom({
    Expression<String>? serverId,
    Expression<String>? itemId,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? collectionType,
    Expression<String>? overview,
    Expression<int>? productionYear,
    Expression<String>? officialRating,
    Expression<double>? communityRating,
    Expression<int>? runTimeTicks,
    Expression<String>? seriesName,
    Expression<String>? seasonName,
    Expression<int>? indexNumber,
    Expression<int>? parentIndexNumber,
    Expression<String>? primaryImageTag,
    Expression<String>? backdropImageTag,
    Expression<String>? primaryBlurHash,
    Expression<String>? backdropBlurHash,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (itemId != null) 'item_id': itemId,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (collectionType != null) 'collection_type': collectionType,
      if (overview != null) 'overview': overview,
      if (productionYear != null) 'production_year': productionYear,
      if (officialRating != null) 'official_rating': officialRating,
      if (communityRating != null) 'community_rating': communityRating,
      if (runTimeTicks != null) 'run_time_ticks': runTimeTicks,
      if (seriesName != null) 'series_name': seriesName,
      if (seasonName != null) 'season_name': seasonName,
      if (indexNumber != null) 'index_number': indexNumber,
      if (parentIndexNumber != null) 'parent_index_number': parentIndexNumber,
      if (primaryImageTag != null) 'primary_image_tag': primaryImageTag,
      if (backdropImageTag != null) 'backdrop_image_tag': backdropImageTag,
      if (primaryBlurHash != null) 'primary_blur_hash': primaryBlurHash,
      if (backdropBlurHash != null) 'backdrop_blur_hash': backdropBlurHash,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MediaItemsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? itemId,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? collectionType,
    Value<String?>? overview,
    Value<int?>? productionYear,
    Value<String?>? officialRating,
    Value<double?>? communityRating,
    Value<int?>? runTimeTicks,
    Value<String?>? seriesName,
    Value<String?>? seasonName,
    Value<int?>? indexNumber,
    Value<int?>? parentIndexNumber,
    Value<String?>? primaryImageTag,
    Value<String?>? backdropImageTag,
    Value<String?>? primaryBlurHash,
    Value<String?>? backdropBlurHash,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return MediaItemsCompanion(
      serverId: serverId ?? this.serverId,
      itemId: itemId ?? this.itemId,
      name: name ?? this.name,
      type: type ?? this.type,
      collectionType: collectionType ?? this.collectionType,
      overview: overview ?? this.overview,
      productionYear: productionYear ?? this.productionYear,
      officialRating: officialRating ?? this.officialRating,
      communityRating: communityRating ?? this.communityRating,
      runTimeTicks: runTimeTicks ?? this.runTimeTicks,
      seriesName: seriesName ?? this.seriesName,
      seasonName: seasonName ?? this.seasonName,
      indexNumber: indexNumber ?? this.indexNumber,
      parentIndexNumber: parentIndexNumber ?? this.parentIndexNumber,
      primaryImageTag: primaryImageTag ?? this.primaryImageTag,
      backdropImageTag: backdropImageTag ?? this.backdropImageTag,
      primaryBlurHash: primaryBlurHash ?? this.primaryBlurHash,
      backdropBlurHash: backdropBlurHash ?? this.backdropBlurHash,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (collectionType.present) {
      map['collection_type'] = Variable<String>(collectionType.value);
    }
    if (overview.present) {
      map['overview'] = Variable<String>(overview.value);
    }
    if (productionYear.present) {
      map['production_year'] = Variable<int>(productionYear.value);
    }
    if (officialRating.present) {
      map['official_rating'] = Variable<String>(officialRating.value);
    }
    if (communityRating.present) {
      map['community_rating'] = Variable<double>(communityRating.value);
    }
    if (runTimeTicks.present) {
      map['run_time_ticks'] = Variable<int>(runTimeTicks.value);
    }
    if (seriesName.present) {
      map['series_name'] = Variable<String>(seriesName.value);
    }
    if (seasonName.present) {
      map['season_name'] = Variable<String>(seasonName.value);
    }
    if (indexNumber.present) {
      map['index_number'] = Variable<int>(indexNumber.value);
    }
    if (parentIndexNumber.present) {
      map['parent_index_number'] = Variable<int>(parentIndexNumber.value);
    }
    if (primaryImageTag.present) {
      map['primary_image_tag'] = Variable<String>(primaryImageTag.value);
    }
    if (backdropImageTag.present) {
      map['backdrop_image_tag'] = Variable<String>(backdropImageTag.value);
    }
    if (primaryBlurHash.present) {
      map['primary_blur_hash'] = Variable<String>(primaryBlurHash.value);
    }
    if (backdropBlurHash.present) {
      map['backdrop_blur_hash'] = Variable<String>(backdropBlurHash.value);
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
    return (StringBuffer('MediaItemsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('itemId: $itemId, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('collectionType: $collectionType, ')
          ..write('overview: $overview, ')
          ..write('productionYear: $productionYear, ')
          ..write('officialRating: $officialRating, ')
          ..write('communityRating: $communityRating, ')
          ..write('runTimeTicks: $runTimeTicks, ')
          ..write('seriesName: $seriesName, ')
          ..write('seasonName: $seasonName, ')
          ..write('indexNumber: $indexNumber, ')
          ..write('parentIndexNumber: $parentIndexNumber, ')
          ..write('primaryImageTag: $primaryImageTag, ')
          ..write('backdropImageTag: $backdropImageTag, ')
          ..write('primaryBlurHash: $primaryBlurHash, ')
          ..write('backdropBlurHash: $backdropBlurHash, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserItemStatesTable extends UserItemStates
    with TableInfo<$UserItemStatesTable, UserItemState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserItemStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playbackPositionTicksMeta =
      const VerificationMeta('playbackPositionTicks');
  @override
  late final GeneratedColumn<int> playbackPositionTicks = GeneratedColumn<int>(
    'playback_position_ticks',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _playedPercentageMeta = const VerificationMeta(
    'playedPercentage',
  );
  @override
  late final GeneratedColumn<double> playedPercentage = GeneratedColumn<double>(
    'played_percentage',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _playedMeta = const VerificationMeta('played');
  @override
  late final GeneratedColumn<bool> played = GeneratedColumn<bool>(
    'played',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("played" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    serverId,
    userId,
    itemId,
    playbackPositionTicks,
    playedPercentage,
    played,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_item_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserItemState> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('playback_position_ticks')) {
      context.handle(
        _playbackPositionTicksMeta,
        playbackPositionTicks.isAcceptableOrUnknown(
          data['playback_position_ticks']!,
          _playbackPositionTicksMeta,
        ),
      );
    }
    if (data.containsKey('played_percentage')) {
      context.handle(
        _playedPercentageMeta,
        playedPercentage.isAcceptableOrUnknown(
          data['played_percentage']!,
          _playedPercentageMeta,
        ),
      );
    }
    if (data.containsKey('played')) {
      context.handle(
        _playedMeta,
        played.isAcceptableOrUnknown(data['played']!, _playedMeta),
      );
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
  Set<GeneratedColumn> get $primaryKey => {serverId, userId, itemId};
  @override
  UserItemState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserItemState(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      playbackPositionTicks: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}playback_position_ticks'],
      )!,
      playedPercentage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}played_percentage'],
      ),
      played: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}played'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserItemStatesTable createAlias(String alias) {
    return $UserItemStatesTable(attachedDatabase, alias);
  }
}

class UserItemState extends DataClass implements Insertable<UserItemState> {
  final String serverId;
  final String userId;
  final String itemId;
  final int playbackPositionTicks;
  final double? playedPercentage;
  final bool played;
  final DateTime updatedAt;
  const UserItemState({
    required this.serverId,
    required this.userId,
    required this.itemId,
    required this.playbackPositionTicks,
    this.playedPercentage,
    required this.played,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['user_id'] = Variable<String>(userId);
    map['item_id'] = Variable<String>(itemId);
    map['playback_position_ticks'] = Variable<int>(playbackPositionTicks);
    if (!nullToAbsent || playedPercentage != null) {
      map['played_percentage'] = Variable<double>(playedPercentage);
    }
    map['played'] = Variable<bool>(played);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserItemStatesCompanion toCompanion(bool nullToAbsent) {
    return UserItemStatesCompanion(
      serverId: Value(serverId),
      userId: Value(userId),
      itemId: Value(itemId),
      playbackPositionTicks: Value(playbackPositionTicks),
      playedPercentage: playedPercentage == null && nullToAbsent
          ? const Value.absent()
          : Value(playedPercentage),
      played: Value(played),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserItemState.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserItemState(
      serverId: serializer.fromJson<String>(json['serverId']),
      userId: serializer.fromJson<String>(json['userId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      playbackPositionTicks: serializer.fromJson<int>(
        json['playbackPositionTicks'],
      ),
      playedPercentage: serializer.fromJson<double?>(json['playedPercentage']),
      played: serializer.fromJson<bool>(json['played']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'userId': serializer.toJson<String>(userId),
      'itemId': serializer.toJson<String>(itemId),
      'playbackPositionTicks': serializer.toJson<int>(playbackPositionTicks),
      'playedPercentage': serializer.toJson<double?>(playedPercentage),
      'played': serializer.toJson<bool>(played),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserItemState copyWith({
    String? serverId,
    String? userId,
    String? itemId,
    int? playbackPositionTicks,
    Value<double?> playedPercentage = const Value.absent(),
    bool? played,
    DateTime? updatedAt,
  }) => UserItemState(
    serverId: serverId ?? this.serverId,
    userId: userId ?? this.userId,
    itemId: itemId ?? this.itemId,
    playbackPositionTicks: playbackPositionTicks ?? this.playbackPositionTicks,
    playedPercentage: playedPercentage.present
        ? playedPercentage.value
        : this.playedPercentage,
    played: played ?? this.played,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserItemState copyWithCompanion(UserItemStatesCompanion data) {
    return UserItemState(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      userId: data.userId.present ? data.userId.value : this.userId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      playbackPositionTicks: data.playbackPositionTicks.present
          ? data.playbackPositionTicks.value
          : this.playbackPositionTicks,
      playedPercentage: data.playedPercentage.present
          ? data.playedPercentage.value
          : this.playedPercentage,
      played: data.played.present ? data.played.value : this.played,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserItemState(')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('itemId: $itemId, ')
          ..write('playbackPositionTicks: $playbackPositionTicks, ')
          ..write('playedPercentage: $playedPercentage, ')
          ..write('played: $played, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serverId,
    userId,
    itemId,
    playbackPositionTicks,
    playedPercentage,
    played,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserItemState &&
          other.serverId == this.serverId &&
          other.userId == this.userId &&
          other.itemId == this.itemId &&
          other.playbackPositionTicks == this.playbackPositionTicks &&
          other.playedPercentage == this.playedPercentage &&
          other.played == this.played &&
          other.updatedAt == this.updatedAt);
}

class UserItemStatesCompanion extends UpdateCompanion<UserItemState> {
  final Value<String> serverId;
  final Value<String> userId;
  final Value<String> itemId;
  final Value<int> playbackPositionTicks;
  final Value<double?> playedPercentage;
  final Value<bool> played;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserItemStatesCompanion({
    this.serverId = const Value.absent(),
    this.userId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.playbackPositionTicks = const Value.absent(),
    this.playedPercentage = const Value.absent(),
    this.played = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserItemStatesCompanion.insert({
    required String serverId,
    required String userId,
    required String itemId,
    this.playbackPositionTicks = const Value.absent(),
    this.playedPercentage = const Value.absent(),
    this.played = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       userId = Value(userId),
       itemId = Value(itemId),
       updatedAt = Value(updatedAt);
  static Insertable<UserItemState> custom({
    Expression<String>? serverId,
    Expression<String>? userId,
    Expression<String>? itemId,
    Expression<int>? playbackPositionTicks,
    Expression<double>? playedPercentage,
    Expression<bool>? played,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (userId != null) 'user_id': userId,
      if (itemId != null) 'item_id': itemId,
      if (playbackPositionTicks != null)
        'playback_position_ticks': playbackPositionTicks,
      if (playedPercentage != null) 'played_percentage': playedPercentage,
      if (played != null) 'played': played,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserItemStatesCompanion copyWith({
    Value<String>? serverId,
    Value<String>? userId,
    Value<String>? itemId,
    Value<int>? playbackPositionTicks,
    Value<double?>? playedPercentage,
    Value<bool>? played,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserItemStatesCompanion(
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      itemId: itemId ?? this.itemId,
      playbackPositionTicks:
          playbackPositionTicks ?? this.playbackPositionTicks,
      playedPercentage: playedPercentage ?? this.playedPercentage,
      played: played ?? this.played,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (playbackPositionTicks.present) {
      map['playback_position_ticks'] = Variable<int>(
        playbackPositionTicks.value,
      );
    }
    if (playedPercentage.present) {
      map['played_percentage'] = Variable<double>(playedPercentage.value);
    }
    if (played.present) {
      map['played'] = Variable<bool>(played.value);
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
    return (StringBuffer('UserItemStatesCompanion(')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('itemId: $itemId, ')
          ..write('playbackPositionTicks: $playbackPositionTicks, ')
          ..write('playedPercentage: $playedPercentage, ')
          ..write('played: $played, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScopeEntriesTable extends ScopeEntries
    with TableInfo<$ScopeEntriesTable, ScopeEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScopeEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeTypeMeta = const VerificationMeta(
    'scopeType',
  );
  @override
  late final GeneratedColumn<String> scopeType = GeneratedColumn<String>(
    'scope_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<String> scopeId = GeneratedColumn<String>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    userId,
    scopeType,
    scopeId,
    itemId,
    position,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scope_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScopeEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('scope_type')) {
      context.handle(
        _scopeTypeMeta,
        scopeType.isAcceptableOrUnknown(data['scope_type']!, _scopeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeTypeMeta);
    }
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    serverId,
    userId,
    scopeType,
    scopeId,
    itemId,
  };
  @override
  ScopeEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScopeEntry(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      scopeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_type'],
      )!,
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
    );
  }

  @override
  $ScopeEntriesTable createAlias(String alias) {
    return $ScopeEntriesTable(attachedDatabase, alias);
  }
}

class ScopeEntry extends DataClass implements Insertable<ScopeEntry> {
  final String serverId;
  final String userId;
  final String scopeType;
  final String scopeId;
  final String itemId;
  final int position;
  const ScopeEntry({
    required this.serverId,
    required this.userId,
    required this.scopeType,
    required this.scopeId,
    required this.itemId,
    required this.position,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['user_id'] = Variable<String>(userId);
    map['scope_type'] = Variable<String>(scopeType);
    map['scope_id'] = Variable<String>(scopeId);
    map['item_id'] = Variable<String>(itemId);
    map['position'] = Variable<int>(position);
    return map;
  }

  ScopeEntriesCompanion toCompanion(bool nullToAbsent) {
    return ScopeEntriesCompanion(
      serverId: Value(serverId),
      userId: Value(userId),
      scopeType: Value(scopeType),
      scopeId: Value(scopeId),
      itemId: Value(itemId),
      position: Value(position),
    );
  }

  factory ScopeEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScopeEntry(
      serverId: serializer.fromJson<String>(json['serverId']),
      userId: serializer.fromJson<String>(json['userId']),
      scopeType: serializer.fromJson<String>(json['scopeType']),
      scopeId: serializer.fromJson<String>(json['scopeId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'userId': serializer.toJson<String>(userId),
      'scopeType': serializer.toJson<String>(scopeType),
      'scopeId': serializer.toJson<String>(scopeId),
      'itemId': serializer.toJson<String>(itemId),
      'position': serializer.toJson<int>(position),
    };
  }

  ScopeEntry copyWith({
    String? serverId,
    String? userId,
    String? scopeType,
    String? scopeId,
    String? itemId,
    int? position,
  }) => ScopeEntry(
    serverId: serverId ?? this.serverId,
    userId: userId ?? this.userId,
    scopeType: scopeType ?? this.scopeType,
    scopeId: scopeId ?? this.scopeId,
    itemId: itemId ?? this.itemId,
    position: position ?? this.position,
  );
  ScopeEntry copyWithCompanion(ScopeEntriesCompanion data) {
    return ScopeEntry(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      userId: data.userId.present ? data.userId.value : this.userId,
      scopeType: data.scopeType.present ? data.scopeType.value : this.scopeType,
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScopeEntry(')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('scopeType: $scopeType, ')
          ..write('scopeId: $scopeId, ')
          ..write('itemId: $itemId, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(serverId, userId, scopeType, scopeId, itemId, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScopeEntry &&
          other.serverId == this.serverId &&
          other.userId == this.userId &&
          other.scopeType == this.scopeType &&
          other.scopeId == this.scopeId &&
          other.itemId == this.itemId &&
          other.position == this.position);
}

class ScopeEntriesCompanion extends UpdateCompanion<ScopeEntry> {
  final Value<String> serverId;
  final Value<String> userId;
  final Value<String> scopeType;
  final Value<String> scopeId;
  final Value<String> itemId;
  final Value<int> position;
  final Value<int> rowid;
  const ScopeEntriesCompanion({
    this.serverId = const Value.absent(),
    this.userId = const Value.absent(),
    this.scopeType = const Value.absent(),
    this.scopeId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScopeEntriesCompanion.insert({
    required String serverId,
    required String userId,
    required String scopeType,
    required String scopeId,
    required String itemId,
    required int position,
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       userId = Value(userId),
       scopeType = Value(scopeType),
       scopeId = Value(scopeId),
       itemId = Value(itemId),
       position = Value(position);
  static Insertable<ScopeEntry> custom({
    Expression<String>? serverId,
    Expression<String>? userId,
    Expression<String>? scopeType,
    Expression<String>? scopeId,
    Expression<String>? itemId,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (userId != null) 'user_id': userId,
      if (scopeType != null) 'scope_type': scopeType,
      if (scopeId != null) 'scope_id': scopeId,
      if (itemId != null) 'item_id': itemId,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScopeEntriesCompanion copyWith({
    Value<String>? serverId,
    Value<String>? userId,
    Value<String>? scopeType,
    Value<String>? scopeId,
    Value<String>? itemId,
    Value<int>? position,
    Value<int>? rowid,
  }) {
    return ScopeEntriesCompanion(
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      scopeType: scopeType ?? this.scopeType,
      scopeId: scopeId ?? this.scopeId,
      itemId: itemId ?? this.itemId,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (scopeType.present) {
      map['scope_type'] = Variable<String>(scopeType.value);
    }
    if (scopeId.present) {
      map['scope_id'] = Variable<String>(scopeId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScopeEntriesCompanion(')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('scopeType: $scopeType, ')
          ..write('scopeId: $scopeId, ')
          ..write('itemId: $itemId, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ScopeSyncsTable extends ScopeSyncs
    with TableInfo<$ScopeSyncsTable, ScopeSync> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScopeSyncsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeTypeMeta = const VerificationMeta(
    'scopeType',
  );
  @override
  late final GeneratedColumn<String> scopeType = GeneratedColumn<String>(
    'scope_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeIdMeta = const VerificationMeta(
    'scopeId',
  );
  @override
  late final GeneratedColumn<String> scopeId = GeneratedColumn<String>(
    'scope_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSuccessfulRefreshMeta =
      const VerificationMeta('lastSuccessfulRefresh');
  @override
  late final GeneratedColumn<DateTime> lastSuccessfulRefresh =
      GeneratedColumn<DateTime>(
        'last_successful_refresh',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    serverId,
    userId,
    scopeType,
    scopeId,
    lastSuccessfulRefresh,
    stale,
    errorMessage,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scope_syncs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ScopeSync> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('scope_type')) {
      context.handle(
        _scopeTypeMeta,
        scopeType.isAcceptableOrUnknown(data['scope_type']!, _scopeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeTypeMeta);
    }
    if (data.containsKey('scope_id')) {
      context.handle(
        _scopeIdMeta,
        scopeId.isAcceptableOrUnknown(data['scope_id']!, _scopeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeIdMeta);
    }
    if (data.containsKey('last_successful_refresh')) {
      context.handle(
        _lastSuccessfulRefreshMeta,
        lastSuccessfulRefresh.isAcceptableOrUnknown(
          data['last_successful_refresh']!,
          _lastSuccessfulRefreshMeta,
        ),
      );
    }
    if (data.containsKey('stale')) {
      context.handle(
        _staleMeta,
        stale.isAcceptableOrUnknown(data['stale']!, _staleMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    serverId,
    userId,
    scopeType,
    scopeId,
  };
  @override
  ScopeSync map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScopeSync(
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      scopeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_type'],
      )!,
      scopeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_id'],
      )!,
      lastSuccessfulRefresh: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_successful_refresh'],
      ),
      stale: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}stale'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
    );
  }

  @override
  $ScopeSyncsTable createAlias(String alias) {
    return $ScopeSyncsTable(attachedDatabase, alias);
  }
}

class ScopeSync extends DataClass implements Insertable<ScopeSync> {
  final String serverId;
  final String userId;
  final String scopeType;
  final String scopeId;
  final DateTime? lastSuccessfulRefresh;
  final bool stale;
  final String? errorMessage;
  const ScopeSync({
    required this.serverId,
    required this.userId,
    required this.scopeType,
    required this.scopeId,
    this.lastSuccessfulRefresh,
    required this.stale,
    this.errorMessage,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['user_id'] = Variable<String>(userId);
    map['scope_type'] = Variable<String>(scopeType);
    map['scope_id'] = Variable<String>(scopeId);
    if (!nullToAbsent || lastSuccessfulRefresh != null) {
      map['last_successful_refresh'] = Variable<DateTime>(
        lastSuccessfulRefresh,
      );
    }
    map['stale'] = Variable<bool>(stale);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    return map;
  }

  ScopeSyncsCompanion toCompanion(bool nullToAbsent) {
    return ScopeSyncsCompanion(
      serverId: Value(serverId),
      userId: Value(userId),
      scopeType: Value(scopeType),
      scopeId: Value(scopeId),
      lastSuccessfulRefresh: lastSuccessfulRefresh == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSuccessfulRefresh),
      stale: Value(stale),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
    );
  }

  factory ScopeSync.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScopeSync(
      serverId: serializer.fromJson<String>(json['serverId']),
      userId: serializer.fromJson<String>(json['userId']),
      scopeType: serializer.fromJson<String>(json['scopeType']),
      scopeId: serializer.fromJson<String>(json['scopeId']),
      lastSuccessfulRefresh: serializer.fromJson<DateTime?>(
        json['lastSuccessfulRefresh'],
      ),
      stale: serializer.fromJson<bool>(json['stale']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'userId': serializer.toJson<String>(userId),
      'scopeType': serializer.toJson<String>(scopeType),
      'scopeId': serializer.toJson<String>(scopeId),
      'lastSuccessfulRefresh': serializer.toJson<DateTime?>(
        lastSuccessfulRefresh,
      ),
      'stale': serializer.toJson<bool>(stale),
      'errorMessage': serializer.toJson<String?>(errorMessage),
    };
  }

  ScopeSync copyWith({
    String? serverId,
    String? userId,
    String? scopeType,
    String? scopeId,
    Value<DateTime?> lastSuccessfulRefresh = const Value.absent(),
    bool? stale,
    Value<String?> errorMessage = const Value.absent(),
  }) => ScopeSync(
    serverId: serverId ?? this.serverId,
    userId: userId ?? this.userId,
    scopeType: scopeType ?? this.scopeType,
    scopeId: scopeId ?? this.scopeId,
    lastSuccessfulRefresh: lastSuccessfulRefresh.present
        ? lastSuccessfulRefresh.value
        : this.lastSuccessfulRefresh,
    stale: stale ?? this.stale,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
  );
  ScopeSync copyWithCompanion(ScopeSyncsCompanion data) {
    return ScopeSync(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      userId: data.userId.present ? data.userId.value : this.userId,
      scopeType: data.scopeType.present ? data.scopeType.value : this.scopeType,
      scopeId: data.scopeId.present ? data.scopeId.value : this.scopeId,
      lastSuccessfulRefresh: data.lastSuccessfulRefresh.present
          ? data.lastSuccessfulRefresh.value
          : this.lastSuccessfulRefresh,
      stale: data.stale.present ? data.stale.value : this.stale,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScopeSync(')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('scopeType: $scopeType, ')
          ..write('scopeId: $scopeId, ')
          ..write('lastSuccessfulRefresh: $lastSuccessfulRefresh, ')
          ..write('stale: $stale, ')
          ..write('errorMessage: $errorMessage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    serverId,
    userId,
    scopeType,
    scopeId,
    lastSuccessfulRefresh,
    stale,
    errorMessage,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScopeSync &&
          other.serverId == this.serverId &&
          other.userId == this.userId &&
          other.scopeType == this.scopeType &&
          other.scopeId == this.scopeId &&
          other.lastSuccessfulRefresh == this.lastSuccessfulRefresh &&
          other.stale == this.stale &&
          other.errorMessage == this.errorMessage);
}

class ScopeSyncsCompanion extends UpdateCompanion<ScopeSync> {
  final Value<String> serverId;
  final Value<String> userId;
  final Value<String> scopeType;
  final Value<String> scopeId;
  final Value<DateTime?> lastSuccessfulRefresh;
  final Value<bool> stale;
  final Value<String?> errorMessage;
  final Value<int> rowid;
  const ScopeSyncsCompanion({
    this.serverId = const Value.absent(),
    this.userId = const Value.absent(),
    this.scopeType = const Value.absent(),
    this.scopeId = const Value.absent(),
    this.lastSuccessfulRefresh = const Value.absent(),
    this.stale = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScopeSyncsCompanion.insert({
    required String serverId,
    required String userId,
    required String scopeType,
    required String scopeId,
    this.lastSuccessfulRefresh = const Value.absent(),
    this.stale = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : serverId = Value(serverId),
       userId = Value(userId),
       scopeType = Value(scopeType),
       scopeId = Value(scopeId);
  static Insertable<ScopeSync> custom({
    Expression<String>? serverId,
    Expression<String>? userId,
    Expression<String>? scopeType,
    Expression<String>? scopeId,
    Expression<DateTime>? lastSuccessfulRefresh,
    Expression<bool>? stale,
    Expression<String>? errorMessage,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (userId != null) 'user_id': userId,
      if (scopeType != null) 'scope_type': scopeType,
      if (scopeId != null) 'scope_id': scopeId,
      if (lastSuccessfulRefresh != null)
        'last_successful_refresh': lastSuccessfulRefresh,
      if (stale != null) 'stale': stale,
      if (errorMessage != null) 'error_message': errorMessage,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScopeSyncsCompanion copyWith({
    Value<String>? serverId,
    Value<String>? userId,
    Value<String>? scopeType,
    Value<String>? scopeId,
    Value<DateTime?>? lastSuccessfulRefresh,
    Value<bool>? stale,
    Value<String?>? errorMessage,
    Value<int>? rowid,
  }) {
    return ScopeSyncsCompanion(
      serverId: serverId ?? this.serverId,
      userId: userId ?? this.userId,
      scopeType: scopeType ?? this.scopeType,
      scopeId: scopeId ?? this.scopeId,
      lastSuccessfulRefresh:
          lastSuccessfulRefresh ?? this.lastSuccessfulRefresh,
      stale: stale ?? this.stale,
      errorMessage: errorMessage ?? this.errorMessage,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (scopeType.present) {
      map['scope_type'] = Variable<String>(scopeType.value);
    }
    if (scopeId.present) {
      map['scope_id'] = Variable<String>(scopeId.value);
    }
    if (lastSuccessfulRefresh.present) {
      map['last_successful_refresh'] = Variable<DateTime>(
        lastSuccessfulRefresh.value,
      );
    }
    if (stale.present) {
      map['stale'] = Variable<bool>(stale.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScopeSyncsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('userId: $userId, ')
          ..write('scopeType: $scopeType, ')
          ..write('scopeId: $scopeId, ')
          ..write('lastSuccessfulRefresh: $lastSuccessfulRefresh, ')
          ..write('stale: $stale, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArtworkEntriesTable extends ArtworkEntries
    with TableInfo<$ArtworkEntriesTable, ArtworkEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArtworkEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _variantKeyMeta = const VerificationMeta(
    'variantKey',
  );
  @override
  late final GeneratedColumn<String> variantKey = GeneratedColumn<String>(
    'variant_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageTypeMeta = const VerificationMeta(
    'imageType',
  );
  @override
  late final GeneratedColumn<String> imageType = GeneratedColumn<String>(
    'image_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageIndexMeta = const VerificationMeta(
    'imageIndex',
  );
  @override
  late final GeneratedColumn<int> imageIndex = GeneratedColumn<int>(
    'image_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _imageTagMeta = const VerificationMeta(
    'imageTag',
  );
  @override
  late final GeneratedColumn<String> imageTag = GeneratedColumn<String>(
    'image_tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<int> quality = GeneratedColumn<int>(
    'quality',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatPolicyVersionMeta =
      const VerificationMeta('formatPolicyVersion');
  @override
  late final GeneratedColumn<int> formatPolicyVersion = GeneratedColumn<int>(
    'format_policy_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
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
  static const VerificationMeta _fileNameMeta = const VerificationMeta(
    'fileName',
  );
  @override
  late final GeneratedColumn<String> fileName = GeneratedColumn<String>(
    'file_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _byteSizeMeta = const VerificationMeta(
    'byteSize',
  );
  @override
  late final GeneratedColumn<int> byteSize = GeneratedColumn<int>(
    'byte_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAccessMeta = const VerificationMeta(
    'lastAccess',
  );
  @override
  late final GeneratedColumn<DateTime> lastAccess = GeneratedColumn<DateTime>(
    'last_access',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    variantKey,
    serverId,
    itemId,
    imageType,
    imageIndex,
    imageTag,
    width,
    quality,
    formatPolicyVersion,
    mimeType,
    fileName,
    byteSize,
    lastAccess,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'artwork_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArtworkEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('variant_key')) {
      context.handle(
        _variantKeyMeta,
        variantKey.isAcceptableOrUnknown(data['variant_key']!, _variantKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_variantKeyMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('image_type')) {
      context.handle(
        _imageTypeMeta,
        imageType.isAcceptableOrUnknown(data['image_type']!, _imageTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_imageTypeMeta);
    }
    if (data.containsKey('image_index')) {
      context.handle(
        _imageIndexMeta,
        imageIndex.isAcceptableOrUnknown(data['image_index']!, _imageIndexMeta),
      );
    }
    if (data.containsKey('image_tag')) {
      context.handle(
        _imageTagMeta,
        imageTag.isAcceptableOrUnknown(data['image_tag']!, _imageTagMeta),
      );
    } else if (isInserting) {
      context.missing(_imageTagMeta);
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    } else if (isInserting) {
      context.missing(_qualityMeta);
    }
    if (data.containsKey('format_policy_version')) {
      context.handle(
        _formatPolicyVersionMeta,
        formatPolicyVersion.isAcceptableOrUnknown(
          data['format_policy_version']!,
          _formatPolicyVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_formatPolicyVersionMeta);
    }
    if (data.containsKey('mime_type')) {
      context.handle(
        _mimeTypeMeta,
        mimeType.isAcceptableOrUnknown(data['mime_type']!, _mimeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mimeTypeMeta);
    }
    if (data.containsKey('file_name')) {
      context.handle(
        _fileNameMeta,
        fileName.isAcceptableOrUnknown(data['file_name']!, _fileNameMeta),
      );
    } else if (isInserting) {
      context.missing(_fileNameMeta);
    }
    if (data.containsKey('byte_size')) {
      context.handle(
        _byteSizeMeta,
        byteSize.isAcceptableOrUnknown(data['byte_size']!, _byteSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_byteSizeMeta);
    }
    if (data.containsKey('last_access')) {
      context.handle(
        _lastAccessMeta,
        lastAccess.isAcceptableOrUnknown(data['last_access']!, _lastAccessMeta),
      );
    } else if (isInserting) {
      context.missing(_lastAccessMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {variantKey};
  @override
  ArtworkEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArtworkEntry(
      variantKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant_key'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      imageType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_type'],
      )!,
      imageIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}image_index'],
      )!,
      imageTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_tag'],
      )!,
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quality'],
      )!,
      formatPolicyVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}format_policy_version'],
      )!,
      mimeType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime_type'],
      )!,
      fileName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_name'],
      )!,
      byteSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_size'],
      )!,
      lastAccess: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_access'],
      )!,
    );
  }

  @override
  $ArtworkEntriesTable createAlias(String alias) {
    return $ArtworkEntriesTable(attachedDatabase, alias);
  }
}

class ArtworkEntry extends DataClass implements Insertable<ArtworkEntry> {
  final String variantKey;
  final String serverId;
  final String itemId;
  final String imageType;
  final int imageIndex;
  final String imageTag;
  final int width;
  final int quality;
  final int formatPolicyVersion;
  final String mimeType;
  final String fileName;
  final int byteSize;
  final DateTime lastAccess;
  const ArtworkEntry({
    required this.variantKey,
    required this.serverId,
    required this.itemId,
    required this.imageType,
    required this.imageIndex,
    required this.imageTag,
    required this.width,
    required this.quality,
    required this.formatPolicyVersion,
    required this.mimeType,
    required this.fileName,
    required this.byteSize,
    required this.lastAccess,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['variant_key'] = Variable<String>(variantKey);
    map['server_id'] = Variable<String>(serverId);
    map['item_id'] = Variable<String>(itemId);
    map['image_type'] = Variable<String>(imageType);
    map['image_index'] = Variable<int>(imageIndex);
    map['image_tag'] = Variable<String>(imageTag);
    map['width'] = Variable<int>(width);
    map['quality'] = Variable<int>(quality);
    map['format_policy_version'] = Variable<int>(formatPolicyVersion);
    map['mime_type'] = Variable<String>(mimeType);
    map['file_name'] = Variable<String>(fileName);
    map['byte_size'] = Variable<int>(byteSize);
    map['last_access'] = Variable<DateTime>(lastAccess);
    return map;
  }

  ArtworkEntriesCompanion toCompanion(bool nullToAbsent) {
    return ArtworkEntriesCompanion(
      variantKey: Value(variantKey),
      serverId: Value(serverId),
      itemId: Value(itemId),
      imageType: Value(imageType),
      imageIndex: Value(imageIndex),
      imageTag: Value(imageTag),
      width: Value(width),
      quality: Value(quality),
      formatPolicyVersion: Value(formatPolicyVersion),
      mimeType: Value(mimeType),
      fileName: Value(fileName),
      byteSize: Value(byteSize),
      lastAccess: Value(lastAccess),
    );
  }

  factory ArtworkEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArtworkEntry(
      variantKey: serializer.fromJson<String>(json['variantKey']),
      serverId: serializer.fromJson<String>(json['serverId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      imageType: serializer.fromJson<String>(json['imageType']),
      imageIndex: serializer.fromJson<int>(json['imageIndex']),
      imageTag: serializer.fromJson<String>(json['imageTag']),
      width: serializer.fromJson<int>(json['width']),
      quality: serializer.fromJson<int>(json['quality']),
      formatPolicyVersion: serializer.fromJson<int>(
        json['formatPolicyVersion'],
      ),
      mimeType: serializer.fromJson<String>(json['mimeType']),
      fileName: serializer.fromJson<String>(json['fileName']),
      byteSize: serializer.fromJson<int>(json['byteSize']),
      lastAccess: serializer.fromJson<DateTime>(json['lastAccess']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'variantKey': serializer.toJson<String>(variantKey),
      'serverId': serializer.toJson<String>(serverId),
      'itemId': serializer.toJson<String>(itemId),
      'imageType': serializer.toJson<String>(imageType),
      'imageIndex': serializer.toJson<int>(imageIndex),
      'imageTag': serializer.toJson<String>(imageTag),
      'width': serializer.toJson<int>(width),
      'quality': serializer.toJson<int>(quality),
      'formatPolicyVersion': serializer.toJson<int>(formatPolicyVersion),
      'mimeType': serializer.toJson<String>(mimeType),
      'fileName': serializer.toJson<String>(fileName),
      'byteSize': serializer.toJson<int>(byteSize),
      'lastAccess': serializer.toJson<DateTime>(lastAccess),
    };
  }

  ArtworkEntry copyWith({
    String? variantKey,
    String? serverId,
    String? itemId,
    String? imageType,
    int? imageIndex,
    String? imageTag,
    int? width,
    int? quality,
    int? formatPolicyVersion,
    String? mimeType,
    String? fileName,
    int? byteSize,
    DateTime? lastAccess,
  }) => ArtworkEntry(
    variantKey: variantKey ?? this.variantKey,
    serverId: serverId ?? this.serverId,
    itemId: itemId ?? this.itemId,
    imageType: imageType ?? this.imageType,
    imageIndex: imageIndex ?? this.imageIndex,
    imageTag: imageTag ?? this.imageTag,
    width: width ?? this.width,
    quality: quality ?? this.quality,
    formatPolicyVersion: formatPolicyVersion ?? this.formatPolicyVersion,
    mimeType: mimeType ?? this.mimeType,
    fileName: fileName ?? this.fileName,
    byteSize: byteSize ?? this.byteSize,
    lastAccess: lastAccess ?? this.lastAccess,
  );
  ArtworkEntry copyWithCompanion(ArtworkEntriesCompanion data) {
    return ArtworkEntry(
      variantKey: data.variantKey.present
          ? data.variantKey.value
          : this.variantKey,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      imageType: data.imageType.present ? data.imageType.value : this.imageType,
      imageIndex: data.imageIndex.present
          ? data.imageIndex.value
          : this.imageIndex,
      imageTag: data.imageTag.present ? data.imageTag.value : this.imageTag,
      width: data.width.present ? data.width.value : this.width,
      quality: data.quality.present ? data.quality.value : this.quality,
      formatPolicyVersion: data.formatPolicyVersion.present
          ? data.formatPolicyVersion.value
          : this.formatPolicyVersion,
      mimeType: data.mimeType.present ? data.mimeType.value : this.mimeType,
      fileName: data.fileName.present ? data.fileName.value : this.fileName,
      byteSize: data.byteSize.present ? data.byteSize.value : this.byteSize,
      lastAccess: data.lastAccess.present
          ? data.lastAccess.value
          : this.lastAccess,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArtworkEntry(')
          ..write('variantKey: $variantKey, ')
          ..write('serverId: $serverId, ')
          ..write('itemId: $itemId, ')
          ..write('imageType: $imageType, ')
          ..write('imageIndex: $imageIndex, ')
          ..write('imageTag: $imageTag, ')
          ..write('width: $width, ')
          ..write('quality: $quality, ')
          ..write('formatPolicyVersion: $formatPolicyVersion, ')
          ..write('mimeType: $mimeType, ')
          ..write('fileName: $fileName, ')
          ..write('byteSize: $byteSize, ')
          ..write('lastAccess: $lastAccess')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    variantKey,
    serverId,
    itemId,
    imageType,
    imageIndex,
    imageTag,
    width,
    quality,
    formatPolicyVersion,
    mimeType,
    fileName,
    byteSize,
    lastAccess,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArtworkEntry &&
          other.variantKey == this.variantKey &&
          other.serverId == this.serverId &&
          other.itemId == this.itemId &&
          other.imageType == this.imageType &&
          other.imageIndex == this.imageIndex &&
          other.imageTag == this.imageTag &&
          other.width == this.width &&
          other.quality == this.quality &&
          other.formatPolicyVersion == this.formatPolicyVersion &&
          other.mimeType == this.mimeType &&
          other.fileName == this.fileName &&
          other.byteSize == this.byteSize &&
          other.lastAccess == this.lastAccess);
}

class ArtworkEntriesCompanion extends UpdateCompanion<ArtworkEntry> {
  final Value<String> variantKey;
  final Value<String> serverId;
  final Value<String> itemId;
  final Value<String> imageType;
  final Value<int> imageIndex;
  final Value<String> imageTag;
  final Value<int> width;
  final Value<int> quality;
  final Value<int> formatPolicyVersion;
  final Value<String> mimeType;
  final Value<String> fileName;
  final Value<int> byteSize;
  final Value<DateTime> lastAccess;
  final Value<int> rowid;
  const ArtworkEntriesCompanion({
    this.variantKey = const Value.absent(),
    this.serverId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.imageType = const Value.absent(),
    this.imageIndex = const Value.absent(),
    this.imageTag = const Value.absent(),
    this.width = const Value.absent(),
    this.quality = const Value.absent(),
    this.formatPolicyVersion = const Value.absent(),
    this.mimeType = const Value.absent(),
    this.fileName = const Value.absent(),
    this.byteSize = const Value.absent(),
    this.lastAccess = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArtworkEntriesCompanion.insert({
    required String variantKey,
    required String serverId,
    required String itemId,
    required String imageType,
    this.imageIndex = const Value.absent(),
    required String imageTag,
    required int width,
    required int quality,
    required int formatPolicyVersion,
    required String mimeType,
    required String fileName,
    required int byteSize,
    required DateTime lastAccess,
    this.rowid = const Value.absent(),
  }) : variantKey = Value(variantKey),
       serverId = Value(serverId),
       itemId = Value(itemId),
       imageType = Value(imageType),
       imageTag = Value(imageTag),
       width = Value(width),
       quality = Value(quality),
       formatPolicyVersion = Value(formatPolicyVersion),
       mimeType = Value(mimeType),
       fileName = Value(fileName),
       byteSize = Value(byteSize),
       lastAccess = Value(lastAccess);
  static Insertable<ArtworkEntry> custom({
    Expression<String>? variantKey,
    Expression<String>? serverId,
    Expression<String>? itemId,
    Expression<String>? imageType,
    Expression<int>? imageIndex,
    Expression<String>? imageTag,
    Expression<int>? width,
    Expression<int>? quality,
    Expression<int>? formatPolicyVersion,
    Expression<String>? mimeType,
    Expression<String>? fileName,
    Expression<int>? byteSize,
    Expression<DateTime>? lastAccess,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (variantKey != null) 'variant_key': variantKey,
      if (serverId != null) 'server_id': serverId,
      if (itemId != null) 'item_id': itemId,
      if (imageType != null) 'image_type': imageType,
      if (imageIndex != null) 'image_index': imageIndex,
      if (imageTag != null) 'image_tag': imageTag,
      if (width != null) 'width': width,
      if (quality != null) 'quality': quality,
      if (formatPolicyVersion != null)
        'format_policy_version': formatPolicyVersion,
      if (mimeType != null) 'mime_type': mimeType,
      if (fileName != null) 'file_name': fileName,
      if (byteSize != null) 'byte_size': byteSize,
      if (lastAccess != null) 'last_access': lastAccess,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArtworkEntriesCompanion copyWith({
    Value<String>? variantKey,
    Value<String>? serverId,
    Value<String>? itemId,
    Value<String>? imageType,
    Value<int>? imageIndex,
    Value<String>? imageTag,
    Value<int>? width,
    Value<int>? quality,
    Value<int>? formatPolicyVersion,
    Value<String>? mimeType,
    Value<String>? fileName,
    Value<int>? byteSize,
    Value<DateTime>? lastAccess,
    Value<int>? rowid,
  }) {
    return ArtworkEntriesCompanion(
      variantKey: variantKey ?? this.variantKey,
      serverId: serverId ?? this.serverId,
      itemId: itemId ?? this.itemId,
      imageType: imageType ?? this.imageType,
      imageIndex: imageIndex ?? this.imageIndex,
      imageTag: imageTag ?? this.imageTag,
      width: width ?? this.width,
      quality: quality ?? this.quality,
      formatPolicyVersion: formatPolicyVersion ?? this.formatPolicyVersion,
      mimeType: mimeType ?? this.mimeType,
      fileName: fileName ?? this.fileName,
      byteSize: byteSize ?? this.byteSize,
      lastAccess: lastAccess ?? this.lastAccess,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (variantKey.present) {
      map['variant_key'] = Variable<String>(variantKey.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (imageType.present) {
      map['image_type'] = Variable<String>(imageType.value);
    }
    if (imageIndex.present) {
      map['image_index'] = Variable<int>(imageIndex.value);
    }
    if (imageTag.present) {
      map['image_tag'] = Variable<String>(imageTag.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (quality.present) {
      map['quality'] = Variable<int>(quality.value);
    }
    if (formatPolicyVersion.present) {
      map['format_policy_version'] = Variable<int>(formatPolicyVersion.value);
    }
    if (mimeType.present) {
      map['mime_type'] = Variable<String>(mimeType.value);
    }
    if (fileName.present) {
      map['file_name'] = Variable<String>(fileName.value);
    }
    if (byteSize.present) {
      map['byte_size'] = Variable<int>(byteSize.value);
    }
    if (lastAccess.present) {
      map['last_access'] = Variable<DateTime>(lastAccess.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArtworkEntriesCompanion(')
          ..write('variantKey: $variantKey, ')
          ..write('serverId: $serverId, ')
          ..write('itemId: $itemId, ')
          ..write('imageType: $imageType, ')
          ..write('imageIndex: $imageIndex, ')
          ..write('imageTag: $imageTag, ')
          ..write('width: $width, ')
          ..write('quality: $quality, ')
          ..write('formatPolicyVersion: $formatPolicyVersion, ')
          ..write('mimeType: $mimeType, ')
          ..write('fileName: $fileName, ')
          ..write('byteSize: $byteSize, ')
          ..write('lastAccess: $lastAccess, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$SoupDatabase extends GeneratedDatabase {
  _$SoupDatabase(QueryExecutor e) : super(e);
  $SoupDatabaseManager get managers => $SoupDatabaseManager(this);
  late final $MediaItemsTable mediaItems = $MediaItemsTable(this);
  late final $UserItemStatesTable userItemStates = $UserItemStatesTable(this);
  late final $ScopeEntriesTable scopeEntries = $ScopeEntriesTable(this);
  late final $ScopeSyncsTable scopeSyncs = $ScopeSyncsTable(this);
  late final $ArtworkEntriesTable artworkEntries = $ArtworkEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    mediaItems,
    userItemStates,
    scopeEntries,
    scopeSyncs,
    artworkEntries,
  ];
}

typedef $$MediaItemsTableCreateCompanionBuilder =
    MediaItemsCompanion Function({
      required String serverId,
      required String itemId,
      required String name,
      required String type,
      Value<String?> collectionType,
      Value<String?> overview,
      Value<int?> productionYear,
      Value<String?> officialRating,
      Value<double?> communityRating,
      Value<int?> runTimeTicks,
      Value<String?> seriesName,
      Value<String?> seasonName,
      Value<int?> indexNumber,
      Value<int?> parentIndexNumber,
      Value<String?> primaryImageTag,
      Value<String?> backdropImageTag,
      Value<String?> primaryBlurHash,
      Value<String?> backdropBlurHash,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$MediaItemsTableUpdateCompanionBuilder =
    MediaItemsCompanion Function({
      Value<String> serverId,
      Value<String> itemId,
      Value<String> name,
      Value<String> type,
      Value<String?> collectionType,
      Value<String?> overview,
      Value<int?> productionYear,
      Value<String?> officialRating,
      Value<double?> communityRating,
      Value<int?> runTimeTicks,
      Value<String?> seriesName,
      Value<String?> seasonName,
      Value<int?> indexNumber,
      Value<int?> parentIndexNumber,
      Value<String?> primaryImageTag,
      Value<String?> backdropImageTag,
      Value<String?> primaryBlurHash,
      Value<String?> backdropBlurHash,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$MediaItemsTableFilterComposer
    extends Composer<_$SoupDatabase, $MediaItemsTable> {
  $$MediaItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overview => $composableBuilder(
    column: $table.overview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get productionYear => $composableBuilder(
    column: $table.productionYear,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get officialRating => $composableBuilder(
    column: $table.officialRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get communityRating => $composableBuilder(
    column: $table.communityRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get runTimeTicks => $composableBuilder(
    column: $table.runTimeTicks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seriesName => $composableBuilder(
    column: $table.seriesName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get seasonName => $composableBuilder(
    column: $table.seasonName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get indexNumber => $composableBuilder(
    column: $table.indexNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get parentIndexNumber => $composableBuilder(
    column: $table.parentIndexNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryImageTag => $composableBuilder(
    column: $table.primaryImageTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backdropImageTag => $composableBuilder(
    column: $table.backdropImageTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get primaryBlurHash => $composableBuilder(
    column: $table.primaryBlurHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get backdropBlurHash => $composableBuilder(
    column: $table.backdropBlurHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MediaItemsTableOrderingComposer
    extends Composer<_$SoupDatabase, $MediaItemsTable> {
  $$MediaItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overview => $composableBuilder(
    column: $table.overview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get productionYear => $composableBuilder(
    column: $table.productionYear,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get officialRating => $composableBuilder(
    column: $table.officialRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get communityRating => $composableBuilder(
    column: $table.communityRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get runTimeTicks => $composableBuilder(
    column: $table.runTimeTicks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seriesName => $composableBuilder(
    column: $table.seriesName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get seasonName => $composableBuilder(
    column: $table.seasonName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get indexNumber => $composableBuilder(
    column: $table.indexNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get parentIndexNumber => $composableBuilder(
    column: $table.parentIndexNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryImageTag => $composableBuilder(
    column: $table.primaryImageTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backdropImageTag => $composableBuilder(
    column: $table.backdropImageTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get primaryBlurHash => $composableBuilder(
    column: $table.primaryBlurHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get backdropBlurHash => $composableBuilder(
    column: $table.backdropBlurHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MediaItemsTableAnnotationComposer
    extends Composer<_$SoupDatabase, $MediaItemsTable> {
  $$MediaItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get collectionType => $composableBuilder(
    column: $table.collectionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get overview =>
      $composableBuilder(column: $table.overview, builder: (column) => column);

  GeneratedColumn<int> get productionYear => $composableBuilder(
    column: $table.productionYear,
    builder: (column) => column,
  );

  GeneratedColumn<String> get officialRating => $composableBuilder(
    column: $table.officialRating,
    builder: (column) => column,
  );

  GeneratedColumn<double> get communityRating => $composableBuilder(
    column: $table.communityRating,
    builder: (column) => column,
  );

  GeneratedColumn<int> get runTimeTicks => $composableBuilder(
    column: $table.runTimeTicks,
    builder: (column) => column,
  );

  GeneratedColumn<String> get seriesName => $composableBuilder(
    column: $table.seriesName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get seasonName => $composableBuilder(
    column: $table.seasonName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get indexNumber => $composableBuilder(
    column: $table.indexNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get parentIndexNumber => $composableBuilder(
    column: $table.parentIndexNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get primaryImageTag => $composableBuilder(
    column: $table.primaryImageTag,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backdropImageTag => $composableBuilder(
    column: $table.backdropImageTag,
    builder: (column) => column,
  );

  GeneratedColumn<String> get primaryBlurHash => $composableBuilder(
    column: $table.primaryBlurHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get backdropBlurHash => $composableBuilder(
    column: $table.backdropBlurHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$MediaItemsTableTableManager
    extends
        RootTableManager<
          _$SoupDatabase,
          $MediaItemsTable,
          MediaItem,
          $$MediaItemsTableFilterComposer,
          $$MediaItemsTableOrderingComposer,
          $$MediaItemsTableAnnotationComposer,
          $$MediaItemsTableCreateCompanionBuilder,
          $$MediaItemsTableUpdateCompanionBuilder,
          (
            MediaItem,
            BaseReferences<_$SoupDatabase, $MediaItemsTable, MediaItem>,
          ),
          MediaItem,
          PrefetchHooks Function()
        > {
  $$MediaItemsTableTableManager(_$SoupDatabase db, $MediaItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MediaItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MediaItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MediaItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> collectionType = const Value.absent(),
                Value<String?> overview = const Value.absent(),
                Value<int?> productionYear = const Value.absent(),
                Value<String?> officialRating = const Value.absent(),
                Value<double?> communityRating = const Value.absent(),
                Value<int?> runTimeTicks = const Value.absent(),
                Value<String?> seriesName = const Value.absent(),
                Value<String?> seasonName = const Value.absent(),
                Value<int?> indexNumber = const Value.absent(),
                Value<int?> parentIndexNumber = const Value.absent(),
                Value<String?> primaryImageTag = const Value.absent(),
                Value<String?> backdropImageTag = const Value.absent(),
                Value<String?> primaryBlurHash = const Value.absent(),
                Value<String?> backdropBlurHash = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MediaItemsCompanion(
                serverId: serverId,
                itemId: itemId,
                name: name,
                type: type,
                collectionType: collectionType,
                overview: overview,
                productionYear: productionYear,
                officialRating: officialRating,
                communityRating: communityRating,
                runTimeTicks: runTimeTicks,
                seriesName: seriesName,
                seasonName: seasonName,
                indexNumber: indexNumber,
                parentIndexNumber: parentIndexNumber,
                primaryImageTag: primaryImageTag,
                backdropImageTag: backdropImageTag,
                primaryBlurHash: primaryBlurHash,
                backdropBlurHash: backdropBlurHash,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String itemId,
                required String name,
                required String type,
                Value<String?> collectionType = const Value.absent(),
                Value<String?> overview = const Value.absent(),
                Value<int?> productionYear = const Value.absent(),
                Value<String?> officialRating = const Value.absent(),
                Value<double?> communityRating = const Value.absent(),
                Value<int?> runTimeTicks = const Value.absent(),
                Value<String?> seriesName = const Value.absent(),
                Value<String?> seasonName = const Value.absent(),
                Value<int?> indexNumber = const Value.absent(),
                Value<int?> parentIndexNumber = const Value.absent(),
                Value<String?> primaryImageTag = const Value.absent(),
                Value<String?> backdropImageTag = const Value.absent(),
                Value<String?> primaryBlurHash = const Value.absent(),
                Value<String?> backdropBlurHash = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => MediaItemsCompanion.insert(
                serverId: serverId,
                itemId: itemId,
                name: name,
                type: type,
                collectionType: collectionType,
                overview: overview,
                productionYear: productionYear,
                officialRating: officialRating,
                communityRating: communityRating,
                runTimeTicks: runTimeTicks,
                seriesName: seriesName,
                seasonName: seasonName,
                indexNumber: indexNumber,
                parentIndexNumber: parentIndexNumber,
                primaryImageTag: primaryImageTag,
                backdropImageTag: backdropImageTag,
                primaryBlurHash: primaryBlurHash,
                backdropBlurHash: backdropBlurHash,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MediaItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$SoupDatabase,
      $MediaItemsTable,
      MediaItem,
      $$MediaItemsTableFilterComposer,
      $$MediaItemsTableOrderingComposer,
      $$MediaItemsTableAnnotationComposer,
      $$MediaItemsTableCreateCompanionBuilder,
      $$MediaItemsTableUpdateCompanionBuilder,
      (MediaItem, BaseReferences<_$SoupDatabase, $MediaItemsTable, MediaItem>),
      MediaItem,
      PrefetchHooks Function()
    >;
typedef $$UserItemStatesTableCreateCompanionBuilder =
    UserItemStatesCompanion Function({
      required String serverId,
      required String userId,
      required String itemId,
      Value<int> playbackPositionTicks,
      Value<double?> playedPercentage,
      Value<bool> played,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$UserItemStatesTableUpdateCompanionBuilder =
    UserItemStatesCompanion Function({
      Value<String> serverId,
      Value<String> userId,
      Value<String> itemId,
      Value<int> playbackPositionTicks,
      Value<double?> playedPercentage,
      Value<bool> played,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UserItemStatesTableFilterComposer
    extends Composer<_$SoupDatabase, $UserItemStatesTable> {
  $$UserItemStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playbackPositionTicks => $composableBuilder(
    column: $table.playbackPositionTicks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get playedPercentage => $composableBuilder(
    column: $table.playedPercentage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get played => $composableBuilder(
    column: $table.played,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserItemStatesTableOrderingComposer
    extends Composer<_$SoupDatabase, $UserItemStatesTable> {
  $$UserItemStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playbackPositionTicks => $composableBuilder(
    column: $table.playbackPositionTicks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get playedPercentage => $composableBuilder(
    column: $table.playedPercentage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get played => $composableBuilder(
    column: $table.played,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserItemStatesTableAnnotationComposer
    extends Composer<_$SoupDatabase, $UserItemStatesTable> {
  $$UserItemStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get playbackPositionTicks => $composableBuilder(
    column: $table.playbackPositionTicks,
    builder: (column) => column,
  );

  GeneratedColumn<double> get playedPercentage => $composableBuilder(
    column: $table.playedPercentage,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get played =>
      $composableBuilder(column: $table.played, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserItemStatesTableTableManager
    extends
        RootTableManager<
          _$SoupDatabase,
          $UserItemStatesTable,
          UserItemState,
          $$UserItemStatesTableFilterComposer,
          $$UserItemStatesTableOrderingComposer,
          $$UserItemStatesTableAnnotationComposer,
          $$UserItemStatesTableCreateCompanionBuilder,
          $$UserItemStatesTableUpdateCompanionBuilder,
          (
            UserItemState,
            BaseReferences<_$SoupDatabase, $UserItemStatesTable, UserItemState>,
          ),
          UserItemState,
          PrefetchHooks Function()
        > {
  $$UserItemStatesTableTableManager(
    _$SoupDatabase db,
    $UserItemStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserItemStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserItemStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserItemStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<int> playbackPositionTicks = const Value.absent(),
                Value<double?> playedPercentage = const Value.absent(),
                Value<bool> played = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserItemStatesCompanion(
                serverId: serverId,
                userId: userId,
                itemId: itemId,
                playbackPositionTicks: playbackPositionTicks,
                playedPercentage: playedPercentage,
                played: played,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String userId,
                required String itemId,
                Value<int> playbackPositionTicks = const Value.absent(),
                Value<double?> playedPercentage = const Value.absent(),
                Value<bool> played = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => UserItemStatesCompanion.insert(
                serverId: serverId,
                userId: userId,
                itemId: itemId,
                playbackPositionTicks: playbackPositionTicks,
                playedPercentage: playedPercentage,
                played: played,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserItemStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$SoupDatabase,
      $UserItemStatesTable,
      UserItemState,
      $$UserItemStatesTableFilterComposer,
      $$UserItemStatesTableOrderingComposer,
      $$UserItemStatesTableAnnotationComposer,
      $$UserItemStatesTableCreateCompanionBuilder,
      $$UserItemStatesTableUpdateCompanionBuilder,
      (
        UserItemState,
        BaseReferences<_$SoupDatabase, $UserItemStatesTable, UserItemState>,
      ),
      UserItemState,
      PrefetchHooks Function()
    >;
typedef $$ScopeEntriesTableCreateCompanionBuilder =
    ScopeEntriesCompanion Function({
      required String serverId,
      required String userId,
      required String scopeType,
      required String scopeId,
      required String itemId,
      required int position,
      Value<int> rowid,
    });
typedef $$ScopeEntriesTableUpdateCompanionBuilder =
    ScopeEntriesCompanion Function({
      Value<String> serverId,
      Value<String> userId,
      Value<String> scopeType,
      Value<String> scopeId,
      Value<String> itemId,
      Value<int> position,
      Value<int> rowid,
    });

class $$ScopeEntriesTableFilterComposer
    extends Composer<_$SoupDatabase, $ScopeEntriesTable> {
  $$ScopeEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeType => $composableBuilder(
    column: $table.scopeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScopeEntriesTableOrderingComposer
    extends Composer<_$SoupDatabase, $ScopeEntriesTable> {
  $$ScopeEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeType => $composableBuilder(
    column: $table.scopeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScopeEntriesTableAnnotationComposer
    extends Composer<_$SoupDatabase, $ScopeEntriesTable> {
  $$ScopeEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get scopeType =>
      $composableBuilder(column: $table.scopeType, builder: (column) => column);

  GeneratedColumn<String> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);
}

class $$ScopeEntriesTableTableManager
    extends
        RootTableManager<
          _$SoupDatabase,
          $ScopeEntriesTable,
          ScopeEntry,
          $$ScopeEntriesTableFilterComposer,
          $$ScopeEntriesTableOrderingComposer,
          $$ScopeEntriesTableAnnotationComposer,
          $$ScopeEntriesTableCreateCompanionBuilder,
          $$ScopeEntriesTableUpdateCompanionBuilder,
          (
            ScopeEntry,
            BaseReferences<_$SoupDatabase, $ScopeEntriesTable, ScopeEntry>,
          ),
          ScopeEntry,
          PrefetchHooks Function()
        > {
  $$ScopeEntriesTableTableManager(_$SoupDatabase db, $ScopeEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScopeEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScopeEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScopeEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> scopeType = const Value.absent(),
                Value<String> scopeId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScopeEntriesCompanion(
                serverId: serverId,
                userId: userId,
                scopeType: scopeType,
                scopeId: scopeId,
                itemId: itemId,
                position: position,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String userId,
                required String scopeType,
                required String scopeId,
                required String itemId,
                required int position,
                Value<int> rowid = const Value.absent(),
              }) => ScopeEntriesCompanion.insert(
                serverId: serverId,
                userId: userId,
                scopeType: scopeType,
                scopeId: scopeId,
                itemId: itemId,
                position: position,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScopeEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$SoupDatabase,
      $ScopeEntriesTable,
      ScopeEntry,
      $$ScopeEntriesTableFilterComposer,
      $$ScopeEntriesTableOrderingComposer,
      $$ScopeEntriesTableAnnotationComposer,
      $$ScopeEntriesTableCreateCompanionBuilder,
      $$ScopeEntriesTableUpdateCompanionBuilder,
      (
        ScopeEntry,
        BaseReferences<_$SoupDatabase, $ScopeEntriesTable, ScopeEntry>,
      ),
      ScopeEntry,
      PrefetchHooks Function()
    >;
typedef $$ScopeSyncsTableCreateCompanionBuilder =
    ScopeSyncsCompanion Function({
      required String serverId,
      required String userId,
      required String scopeType,
      required String scopeId,
      Value<DateTime?> lastSuccessfulRefresh,
      Value<bool> stale,
      Value<String?> errorMessage,
      Value<int> rowid,
    });
typedef $$ScopeSyncsTableUpdateCompanionBuilder =
    ScopeSyncsCompanion Function({
      Value<String> serverId,
      Value<String> userId,
      Value<String> scopeType,
      Value<String> scopeId,
      Value<DateTime?> lastSuccessfulRefresh,
      Value<bool> stale,
      Value<String?> errorMessage,
      Value<int> rowid,
    });

class $$ScopeSyncsTableFilterComposer
    extends Composer<_$SoupDatabase, $ScopeSyncsTable> {
  $$ScopeSyncsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeType => $composableBuilder(
    column: $table.scopeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSuccessfulRefresh => $composableBuilder(
    column: $table.lastSuccessfulRefresh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get stale => $composableBuilder(
    column: $table.stale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ScopeSyncsTableOrderingComposer
    extends Composer<_$SoupDatabase, $ScopeSyncsTable> {
  $$ScopeSyncsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeType => $composableBuilder(
    column: $table.scopeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeId => $composableBuilder(
    column: $table.scopeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSuccessfulRefresh => $composableBuilder(
    column: $table.lastSuccessfulRefresh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get stale => $composableBuilder(
    column: $table.stale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ScopeSyncsTableAnnotationComposer
    extends Composer<_$SoupDatabase, $ScopeSyncsTable> {
  $$ScopeSyncsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get scopeType =>
      $composableBuilder(column: $table.scopeType, builder: (column) => column);

  GeneratedColumn<String> get scopeId =>
      $composableBuilder(column: $table.scopeId, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSuccessfulRefresh => $composableBuilder(
    column: $table.lastSuccessfulRefresh,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get stale =>
      $composableBuilder(column: $table.stale, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );
}

class $$ScopeSyncsTableTableManager
    extends
        RootTableManager<
          _$SoupDatabase,
          $ScopeSyncsTable,
          ScopeSync,
          $$ScopeSyncsTableFilterComposer,
          $$ScopeSyncsTableOrderingComposer,
          $$ScopeSyncsTableAnnotationComposer,
          $$ScopeSyncsTableCreateCompanionBuilder,
          $$ScopeSyncsTableUpdateCompanionBuilder,
          (
            ScopeSync,
            BaseReferences<_$SoupDatabase, $ScopeSyncsTable, ScopeSync>,
          ),
          ScopeSync,
          PrefetchHooks Function()
        > {
  $$ScopeSyncsTableTableManager(_$SoupDatabase db, $ScopeSyncsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScopeSyncsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScopeSyncsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScopeSyncsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> serverId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> scopeType = const Value.absent(),
                Value<String> scopeId = const Value.absent(),
                Value<DateTime?> lastSuccessfulRefresh = const Value.absent(),
                Value<bool> stale = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScopeSyncsCompanion(
                serverId: serverId,
                userId: userId,
                scopeType: scopeType,
                scopeId: scopeId,
                lastSuccessfulRefresh: lastSuccessfulRefresh,
                stale: stale,
                errorMessage: errorMessage,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String serverId,
                required String userId,
                required String scopeType,
                required String scopeId,
                Value<DateTime?> lastSuccessfulRefresh = const Value.absent(),
                Value<bool> stale = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ScopeSyncsCompanion.insert(
                serverId: serverId,
                userId: userId,
                scopeType: scopeType,
                scopeId: scopeId,
                lastSuccessfulRefresh: lastSuccessfulRefresh,
                stale: stale,
                errorMessage: errorMessage,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ScopeSyncsTableProcessedTableManager =
    ProcessedTableManager<
      _$SoupDatabase,
      $ScopeSyncsTable,
      ScopeSync,
      $$ScopeSyncsTableFilterComposer,
      $$ScopeSyncsTableOrderingComposer,
      $$ScopeSyncsTableAnnotationComposer,
      $$ScopeSyncsTableCreateCompanionBuilder,
      $$ScopeSyncsTableUpdateCompanionBuilder,
      (ScopeSync, BaseReferences<_$SoupDatabase, $ScopeSyncsTable, ScopeSync>),
      ScopeSync,
      PrefetchHooks Function()
    >;
typedef $$ArtworkEntriesTableCreateCompanionBuilder =
    ArtworkEntriesCompanion Function({
      required String variantKey,
      required String serverId,
      required String itemId,
      required String imageType,
      Value<int> imageIndex,
      required String imageTag,
      required int width,
      required int quality,
      required int formatPolicyVersion,
      required String mimeType,
      required String fileName,
      required int byteSize,
      required DateTime lastAccess,
      Value<int> rowid,
    });
typedef $$ArtworkEntriesTableUpdateCompanionBuilder =
    ArtworkEntriesCompanion Function({
      Value<String> variantKey,
      Value<String> serverId,
      Value<String> itemId,
      Value<String> imageType,
      Value<int> imageIndex,
      Value<String> imageTag,
      Value<int> width,
      Value<int> quality,
      Value<int> formatPolicyVersion,
      Value<String> mimeType,
      Value<String> fileName,
      Value<int> byteSize,
      Value<DateTime> lastAccess,
      Value<int> rowid,
    });

class $$ArtworkEntriesTableFilterComposer
    extends Composer<_$SoupDatabase, $ArtworkEntriesTable> {
  $$ArtworkEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get variantKey => $composableBuilder(
    column: $table.variantKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageType => $composableBuilder(
    column: $table.imageType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get imageIndex => $composableBuilder(
    column: $table.imageIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageTag => $composableBuilder(
    column: $table.imageTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get formatPolicyVersion => $composableBuilder(
    column: $table.formatPolicyVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastAccess => $composableBuilder(
    column: $table.lastAccess,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ArtworkEntriesTableOrderingComposer
    extends Composer<_$SoupDatabase, $ArtworkEntriesTable> {
  $$ArtworkEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get variantKey => $composableBuilder(
    column: $table.variantKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageType => $composableBuilder(
    column: $table.imageType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get imageIndex => $composableBuilder(
    column: $table.imageIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageTag => $composableBuilder(
    column: $table.imageTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get formatPolicyVersion => $composableBuilder(
    column: $table.formatPolicyVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mimeType => $composableBuilder(
    column: $table.mimeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fileName => $composableBuilder(
    column: $table.fileName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteSize => $composableBuilder(
    column: $table.byteSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastAccess => $composableBuilder(
    column: $table.lastAccess,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArtworkEntriesTableAnnotationComposer
    extends Composer<_$SoupDatabase, $ArtworkEntriesTable> {
  $$ArtworkEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get variantKey => $composableBuilder(
    column: $table.variantKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get imageType =>
      $composableBuilder(column: $table.imageType, builder: (column) => column);

  GeneratedColumn<int> get imageIndex => $composableBuilder(
    column: $table.imageIndex,
    builder: (column) => column,
  );

  GeneratedColumn<String> get imageTag =>
      $composableBuilder(column: $table.imageTag, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<int> get formatPolicyVersion => $composableBuilder(
    column: $table.formatPolicyVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mimeType =>
      $composableBuilder(column: $table.mimeType, builder: (column) => column);

  GeneratedColumn<String> get fileName =>
      $composableBuilder(column: $table.fileName, builder: (column) => column);

  GeneratedColumn<int> get byteSize =>
      $composableBuilder(column: $table.byteSize, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAccess => $composableBuilder(
    column: $table.lastAccess,
    builder: (column) => column,
  );
}

class $$ArtworkEntriesTableTableManager
    extends
        RootTableManager<
          _$SoupDatabase,
          $ArtworkEntriesTable,
          ArtworkEntry,
          $$ArtworkEntriesTableFilterComposer,
          $$ArtworkEntriesTableOrderingComposer,
          $$ArtworkEntriesTableAnnotationComposer,
          $$ArtworkEntriesTableCreateCompanionBuilder,
          $$ArtworkEntriesTableUpdateCompanionBuilder,
          (
            ArtworkEntry,
            BaseReferences<_$SoupDatabase, $ArtworkEntriesTable, ArtworkEntry>,
          ),
          ArtworkEntry,
          PrefetchHooks Function()
        > {
  $$ArtworkEntriesTableTableManager(
    _$SoupDatabase db,
    $ArtworkEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArtworkEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArtworkEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArtworkEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> variantKey = const Value.absent(),
                Value<String> serverId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String> imageType = const Value.absent(),
                Value<int> imageIndex = const Value.absent(),
                Value<String> imageTag = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> quality = const Value.absent(),
                Value<int> formatPolicyVersion = const Value.absent(),
                Value<String> mimeType = const Value.absent(),
                Value<String> fileName = const Value.absent(),
                Value<int> byteSize = const Value.absent(),
                Value<DateTime> lastAccess = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArtworkEntriesCompanion(
                variantKey: variantKey,
                serverId: serverId,
                itemId: itemId,
                imageType: imageType,
                imageIndex: imageIndex,
                imageTag: imageTag,
                width: width,
                quality: quality,
                formatPolicyVersion: formatPolicyVersion,
                mimeType: mimeType,
                fileName: fileName,
                byteSize: byteSize,
                lastAccess: lastAccess,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String variantKey,
                required String serverId,
                required String itemId,
                required String imageType,
                Value<int> imageIndex = const Value.absent(),
                required String imageTag,
                required int width,
                required int quality,
                required int formatPolicyVersion,
                required String mimeType,
                required String fileName,
                required int byteSize,
                required DateTime lastAccess,
                Value<int> rowid = const Value.absent(),
              }) => ArtworkEntriesCompanion.insert(
                variantKey: variantKey,
                serverId: serverId,
                itemId: itemId,
                imageType: imageType,
                imageIndex: imageIndex,
                imageTag: imageTag,
                width: width,
                quality: quality,
                formatPolicyVersion: formatPolicyVersion,
                mimeType: mimeType,
                fileName: fileName,
                byteSize: byteSize,
                lastAccess: lastAccess,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ArtworkEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$SoupDatabase,
      $ArtworkEntriesTable,
      ArtworkEntry,
      $$ArtworkEntriesTableFilterComposer,
      $$ArtworkEntriesTableOrderingComposer,
      $$ArtworkEntriesTableAnnotationComposer,
      $$ArtworkEntriesTableCreateCompanionBuilder,
      $$ArtworkEntriesTableUpdateCompanionBuilder,
      (
        ArtworkEntry,
        BaseReferences<_$SoupDatabase, $ArtworkEntriesTable, ArtworkEntry>,
      ),
      ArtworkEntry,
      PrefetchHooks Function()
    >;

class $SoupDatabaseManager {
  final _$SoupDatabase _db;
  $SoupDatabaseManager(this._db);
  $$MediaItemsTableTableManager get mediaItems =>
      $$MediaItemsTableTableManager(_db, _db.mediaItems);
  $$UserItemStatesTableTableManager get userItemStates =>
      $$UserItemStatesTableTableManager(_db, _db.userItemStates);
  $$ScopeEntriesTableTableManager get scopeEntries =>
      $$ScopeEntriesTableTableManager(_db, _db.scopeEntries);
  $$ScopeSyncsTableTableManager get scopeSyncs =>
      $$ScopeSyncsTableTableManager(_db, _db.scopeSyncs);
  $$ArtworkEntriesTableTableManager get artworkEntries =>
      $$ArtworkEntriesTableTableManager(_db, _db.artworkEntries);
}
