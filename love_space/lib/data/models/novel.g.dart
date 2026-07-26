// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'novel.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetNovelCollection on Isar {
  IsarCollection<Novel> get novels => this.collection();
}

const NovelSchema = CollectionSchema(
  name: r'Novel',
  id: 5475403121629904191,
  properties: {
    r'author': PropertySchema(
      id: 0,
      name: r'author',
      type: IsarType.string,
    ),
    r'chapterCount': PropertySchema(
      id: 1,
      name: r'chapterCount',
      type: IsarType.long,
    ),
    r'coverColorValue': PropertySchema(
      id: 2,
      name: r'coverColorValue',
      type: IsarType.long,
    ),
    r'createdAt': PropertySchema(
      id: 3,
      name: r'createdAt',
      type: IsarType.dateTime,
    ),
    r'intro': PropertySchema(
      id: 4,
      name: r'intro',
      type: IsarType.string,
    ),
    r'isBuiltin': PropertySchema(
      id: 5,
      name: r'isBuiltin',
      type: IsarType.bool,
    ),
    r'lastChapterIndex': PropertySchema(
      id: 6,
      name: r'lastChapterIndex',
      type: IsarType.long,
    ),
    r'lastPosition': PropertySchema(
      id: 7,
      name: r'lastPosition',
      type: IsarType.double,
    ),
    r'lastReadAt': PropertySchema(
      id: 8,
      name: r'lastReadAt',
      type: IsarType.dateTime,
    ),
    r'tags': PropertySchema(
      id: 9,
      name: r'tags',
      type: IsarType.stringList,
    ),
    r'title': PropertySchema(
      id: 10,
      name: r'title',
      type: IsarType.string,
    )
  },
  estimateSize: _novelEstimateSize,
  serialize: _novelSerialize,
  deserialize: _novelDeserialize,
  deserializeProp: _novelDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _novelGetId,
  getLinks: _novelGetLinks,
  attach: _novelAttach,
  version: '3.1.0+1',
);

int _novelEstimateSize(
  Novel object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.author.length * 3;
  bytesCount += 3 + object.intro.length * 3;
  bytesCount += 3 + object.tags.length * 3;
  {
    for (var i = 0; i < object.tags.length; i++) {
      final value = object.tags[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.title.length * 3;
  return bytesCount;
}

void _novelSerialize(
  Novel object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.author);
  writer.writeLong(offsets[1], object.chapterCount);
  writer.writeLong(offsets[2], object.coverColorValue);
  writer.writeDateTime(offsets[3], object.createdAt);
  writer.writeString(offsets[4], object.intro);
  writer.writeBool(offsets[5], object.isBuiltin);
  writer.writeLong(offsets[6], object.lastChapterIndex);
  writer.writeDouble(offsets[7], object.lastPosition);
  writer.writeDateTime(offsets[8], object.lastReadAt);
  writer.writeStringList(offsets[9], object.tags);
  writer.writeString(offsets[10], object.title);
}

Novel _novelDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Novel();
  object.author = reader.readString(offsets[0]);
  object.chapterCount = reader.readLong(offsets[1]);
  object.coverColorValue = reader.readLong(offsets[2]);
  object.createdAt = reader.readDateTime(offsets[3]);
  object.id = id;
  object.intro = reader.readString(offsets[4]);
  object.isBuiltin = reader.readBool(offsets[5]);
  object.lastChapterIndex = reader.readLong(offsets[6]);
  object.lastPosition = reader.readDouble(offsets[7]);
  object.lastReadAt = reader.readDateTimeOrNull(offsets[8]);
  object.tags = reader.readStringList(offsets[9]) ?? [];
  object.title = reader.readString(offsets[10]);
  return object;
}

P _novelDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readLong(offset)) as P;
    case 7:
      return (reader.readDouble(offset)) as P;
    case 8:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 9:
      return (reader.readStringList(offset) ?? []) as P;
    case 10:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _novelGetId(Novel object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _novelGetLinks(Novel object) {
  return [];
}

void _novelAttach(IsarCollection<dynamic> col, Id id, Novel object) {
  object.id = id;
}

extension NovelQueryWhereSort on QueryBuilder<Novel, Novel, QWhere> {
  QueryBuilder<Novel, Novel, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension NovelQueryWhere on QueryBuilder<Novel, Novel, QWhereClause> {
  QueryBuilder<Novel, Novel, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Novel, Novel, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Novel, Novel, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Novel, Novel, QAfterWhereClause> idBetween(
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

extension NovelQueryFilter on QueryBuilder<Novel, Novel, QFilterCondition> {
  QueryBuilder<Novel, Novel, QAfterFilterCondition> authorEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'author',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> authorGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'author',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> authorLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'author',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> authorBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'author',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> authorStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'author',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> authorEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'author',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> authorContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'author',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> authorMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'author',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> authorIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'author',
        value: '',
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> authorIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'author',
        value: '',
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> chapterCountEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'chapterCount',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> chapterCountGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'chapterCount',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> chapterCountLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'chapterCount',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> chapterCountBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'chapterCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> coverColorValueEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'coverColorValue',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> coverColorValueGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'coverColorValue',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> coverColorValueLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'coverColorValue',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> coverColorValueBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'coverColorValue',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> createdAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> createdAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> createdAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'createdAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> createdAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'createdAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Novel, Novel, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Novel, Novel, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Novel, Novel, QAfterFilterCondition> introEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'intro',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> introGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'intro',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> introLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'intro',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> introBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'intro',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> introStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'intro',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> introEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'intro',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> introContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'intro',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> introMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'intro',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> introIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'intro',
        value: '',
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> introIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'intro',
        value: '',
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> isBuiltinEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isBuiltin',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> lastChapterIndexEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastChapterIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> lastChapterIndexGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastChapterIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> lastChapterIndexLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastChapterIndex',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> lastChapterIndexBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastChapterIndex',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> lastPositionEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastPosition',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> lastPositionGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastPosition',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> lastPositionLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastPosition',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> lastPositionBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastPosition',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> lastReadAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastReadAt',
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> lastReadAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastReadAt',
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> lastReadAtEqualTo(
      DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastReadAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> lastReadAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastReadAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> lastReadAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastReadAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> lastReadAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastReadAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tags',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsElementContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsElementMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'tags',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tags',
        value: '',
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'tags',
        value: '',
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsLengthEqualTo(
      int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> tagsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> titleGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> titleLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'title',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> titleContains(String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'title',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> titleMatches(String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'title',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> titleIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'title',
        value: '',
      ));
    });
  }

  QueryBuilder<Novel, Novel, QAfterFilterCondition> titleIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'title',
        value: '',
      ));
    });
  }
}

extension NovelQueryObject on QueryBuilder<Novel, Novel, QFilterCondition> {}

extension NovelQueryLinks on QueryBuilder<Novel, Novel, QFilterCondition> {}

extension NovelQuerySortBy on QueryBuilder<Novel, Novel, QSortBy> {
  QueryBuilder<Novel, Novel, QAfterSortBy> sortByAuthor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'author', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByAuthorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'author', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByChapterCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterCount', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByChapterCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterCount', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByCoverColorValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverColorValue', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByCoverColorValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverColorValue', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByIntro() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intro', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByIntroDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intro', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByIsBuiltin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBuiltin', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByIsBuiltinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBuiltin', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByLastChapterIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastChapterIndex', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByLastChapterIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastChapterIndex', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByLastPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPosition', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByLastPositionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPosition', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByLastReadAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadAt', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByLastReadAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadAt', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> sortByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension NovelQuerySortThenBy on QueryBuilder<Novel, Novel, QSortThenBy> {
  QueryBuilder<Novel, Novel, QAfterSortBy> thenByAuthor() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'author', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByAuthorDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'author', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByChapterCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterCount', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByChapterCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'chapterCount', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByCoverColorValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverColorValue', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByCoverColorValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'coverColorValue', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByCreatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'createdAt', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByIntro() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intro', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByIntroDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'intro', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByIsBuiltin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBuiltin', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByIsBuiltinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isBuiltin', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByLastChapterIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastChapterIndex', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByLastChapterIndexDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastChapterIndex', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByLastPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPosition', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByLastPositionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPosition', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByLastReadAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadAt', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByLastReadAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastReadAt', Sort.desc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByTitle() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.asc);
    });
  }

  QueryBuilder<Novel, Novel, QAfterSortBy> thenByTitleDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'title', Sort.desc);
    });
  }
}

extension NovelQueryWhereDistinct on QueryBuilder<Novel, Novel, QDistinct> {
  QueryBuilder<Novel, Novel, QDistinct> distinctByAuthor(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'author', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Novel, Novel, QDistinct> distinctByChapterCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'chapterCount');
    });
  }

  QueryBuilder<Novel, Novel, QDistinct> distinctByCoverColorValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'coverColorValue');
    });
  }

  QueryBuilder<Novel, Novel, QDistinct> distinctByCreatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'createdAt');
    });
  }

  QueryBuilder<Novel, Novel, QDistinct> distinctByIntro(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'intro', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Novel, Novel, QDistinct> distinctByIsBuiltin() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isBuiltin');
    });
  }

  QueryBuilder<Novel, Novel, QDistinct> distinctByLastChapterIndex() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastChapterIndex');
    });
  }

  QueryBuilder<Novel, Novel, QDistinct> distinctByLastPosition() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastPosition');
    });
  }

  QueryBuilder<Novel, Novel, QDistinct> distinctByLastReadAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastReadAt');
    });
  }

  QueryBuilder<Novel, Novel, QDistinct> distinctByTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tags');
    });
  }

  QueryBuilder<Novel, Novel, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'title', caseSensitive: caseSensitive);
    });
  }
}

extension NovelQueryProperty on QueryBuilder<Novel, Novel, QQueryProperty> {
  QueryBuilder<Novel, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Novel, String, QQueryOperations> authorProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'author');
    });
  }

  QueryBuilder<Novel, int, QQueryOperations> chapterCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'chapterCount');
    });
  }

  QueryBuilder<Novel, int, QQueryOperations> coverColorValueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'coverColorValue');
    });
  }

  QueryBuilder<Novel, DateTime, QQueryOperations> createdAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'createdAt');
    });
  }

  QueryBuilder<Novel, String, QQueryOperations> introProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'intro');
    });
  }

  QueryBuilder<Novel, bool, QQueryOperations> isBuiltinProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isBuiltin');
    });
  }

  QueryBuilder<Novel, int, QQueryOperations> lastChapterIndexProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastChapterIndex');
    });
  }

  QueryBuilder<Novel, double, QQueryOperations> lastPositionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastPosition');
    });
  }

  QueryBuilder<Novel, DateTime?, QQueryOperations> lastReadAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastReadAt');
    });
  }

  QueryBuilder<Novel, List<String>, QQueryOperations> tagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tags');
    });
  }

  QueryBuilder<Novel, String, QQueryOperations> titleProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'title');
    });
  }
}
