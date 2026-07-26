// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reader_settings.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetReaderSettingsCollection on Isar {
  IsarCollection<ReaderSettings> get readerSettings => this.collection();
}

const ReaderSettingsSchema = CollectionSchema(
  name: r'ReaderSettings',
  id: -7089826136440672203,
  properties: {
    r'bgTheme': PropertySchema(
      id: 0,
      name: r'bgTheme',
      type: IsarType.long,
    ),
    r'fontSize': PropertySchema(
      id: 1,
      name: r'fontSize',
      type: IsarType.double,
    ),
    r'keepScreenOn': PropertySchema(
      id: 2,
      name: r'keepScreenOn',
      type: IsarType.bool,
    ),
    r'lineHeight': PropertySchema(
      id: 3,
      name: r'lineHeight',
      type: IsarType.double,
    ),
    r'pageMode': PropertySchema(
      id: 4,
      name: r'pageMode',
      type: IsarType.long,
    )
  },
  estimateSize: _readerSettingsEstimateSize,
  serialize: _readerSettingsSerialize,
  deserialize: _readerSettingsDeserialize,
  deserializeProp: _readerSettingsDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _readerSettingsGetId,
  getLinks: _readerSettingsGetLinks,
  attach: _readerSettingsAttach,
  version: '3.1.0+1',
);

int _readerSettingsEstimateSize(
  ReaderSettings object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _readerSettingsSerialize(
  ReaderSettings object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.bgTheme);
  writer.writeDouble(offsets[1], object.fontSize);
  writer.writeBool(offsets[2], object.keepScreenOn);
  writer.writeDouble(offsets[3], object.lineHeight);
  writer.writeLong(offsets[4], object.pageMode);
}

ReaderSettings _readerSettingsDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ReaderSettings();
  object.bgTheme = reader.readLong(offsets[0]);
  object.fontSize = reader.readDouble(offsets[1]);
  object.id = id;
  object.keepScreenOn = reader.readBool(offsets[2]);
  object.lineHeight = reader.readDouble(offsets[3]);
  object.pageMode = reader.readLong(offsets[4]);
  return object;
}

P _readerSettingsDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    case 2:
      return (reader.readBool(offset)) as P;
    case 3:
      return (reader.readDouble(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _readerSettingsGetId(ReaderSettings object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _readerSettingsGetLinks(ReaderSettings object) {
  return [];
}

void _readerSettingsAttach(
    IsarCollection<dynamic> col, Id id, ReaderSettings object) {
  object.id = id;
}

extension ReaderSettingsQueryWhereSort
    on QueryBuilder<ReaderSettings, ReaderSettings, QWhere> {
  QueryBuilder<ReaderSettings, ReaderSettings, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ReaderSettingsQueryWhere
    on QueryBuilder<ReaderSettings, ReaderSettings, QWhereClause> {
  QueryBuilder<ReaderSettings, ReaderSettings, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ReaderSettingsQueryFilter
    on QueryBuilder<ReaderSettings, ReaderSettings, QFilterCondition> {
  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      bgThemeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'bgTheme',
        value: value,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      bgThemeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'bgTheme',
        value: value,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      bgThemeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'bgTheme',
        value: value,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      bgThemeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'bgTheme',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      fontSizeEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'fontSize',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      fontSizeGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'fontSize',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      fontSizeLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'fontSize',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      fontSizeBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'fontSize',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      keepScreenOnEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'keepScreenOn',
        value: value,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      lineHeightEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lineHeight',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      lineHeightGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lineHeight',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      lineHeightLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lineHeight',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      lineHeightBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lineHeight',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      pageModeEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pageMode',
        value: value,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      pageModeGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pageMode',
        value: value,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      pageModeLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pageMode',
        value: value,
      ));
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterFilterCondition>
      pageModeBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pageMode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ReaderSettingsQueryObject
    on QueryBuilder<ReaderSettings, ReaderSettings, QFilterCondition> {}

extension ReaderSettingsQueryLinks
    on QueryBuilder<ReaderSettings, ReaderSettings, QFilterCondition> {}

extension ReaderSettingsQuerySortBy
    on QueryBuilder<ReaderSettings, ReaderSettings, QSortBy> {
  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy> sortByBgTheme() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bgTheme', Sort.asc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy>
      sortByBgThemeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bgTheme', Sort.desc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy> sortByFontSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontSize', Sort.asc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy>
      sortByFontSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontSize', Sort.desc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy>
      sortByKeepScreenOn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keepScreenOn', Sort.asc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy>
      sortByKeepScreenOnDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keepScreenOn', Sort.desc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy>
      sortByLineHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lineHeight', Sort.asc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy>
      sortByLineHeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lineHeight', Sort.desc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy> sortByPageMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageMode', Sort.asc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy>
      sortByPageModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageMode', Sort.desc);
    });
  }
}

extension ReaderSettingsQuerySortThenBy
    on QueryBuilder<ReaderSettings, ReaderSettings, QSortThenBy> {
  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy> thenByBgTheme() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bgTheme', Sort.asc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy>
      thenByBgThemeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'bgTheme', Sort.desc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy> thenByFontSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontSize', Sort.asc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy>
      thenByFontSizeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'fontSize', Sort.desc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy>
      thenByKeepScreenOn() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keepScreenOn', Sort.asc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy>
      thenByKeepScreenOnDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keepScreenOn', Sort.desc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy>
      thenByLineHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lineHeight', Sort.asc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy>
      thenByLineHeightDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lineHeight', Sort.desc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy> thenByPageMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageMode', Sort.asc);
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QAfterSortBy>
      thenByPageModeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'pageMode', Sort.desc);
    });
  }
}

extension ReaderSettingsQueryWhereDistinct
    on QueryBuilder<ReaderSettings, ReaderSettings, QDistinct> {
  QueryBuilder<ReaderSettings, ReaderSettings, QDistinct> distinctByBgTheme() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'bgTheme');
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QDistinct> distinctByFontSize() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'fontSize');
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QDistinct>
      distinctByKeepScreenOn() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'keepScreenOn');
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QDistinct>
      distinctByLineHeight() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lineHeight');
    });
  }

  QueryBuilder<ReaderSettings, ReaderSettings, QDistinct> distinctByPageMode() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'pageMode');
    });
  }
}

extension ReaderSettingsQueryProperty
    on QueryBuilder<ReaderSettings, ReaderSettings, QQueryProperty> {
  QueryBuilder<ReaderSettings, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ReaderSettings, int, QQueryOperations> bgThemeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'bgTheme');
    });
  }

  QueryBuilder<ReaderSettings, double, QQueryOperations> fontSizeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'fontSize');
    });
  }

  QueryBuilder<ReaderSettings, bool, QQueryOperations> keepScreenOnProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'keepScreenOn');
    });
  }

  QueryBuilder<ReaderSettings, double, QQueryOperations> lineHeightProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lineHeight');
    });
  }

  QueryBuilder<ReaderSettings, int, QQueryOperations> pageModeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'pageMode');
    });
  }
}
