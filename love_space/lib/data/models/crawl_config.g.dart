// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crawl_config.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCrawlConfigCollection on Isar {
  IsarCollection<CrawlConfig> get crawlConfigs => this.collection();
}

const CrawlConfigSchema = CollectionSchema(
  name: r'CrawlConfig',
  id: -6427415421874314832,
  properties: {
    r'adKeywords': PropertySchema(
      id: 0,
      name: r'adKeywords',
      type: IsarType.stringList,
    ),
    r'maxRetries': PropertySchema(
      id: 1,
      name: r'maxRetries',
      type: IsarType.long,
    ),
    r'prefetchChapters': PropertySchema(
      id: 2,
      name: r'prefetchChapters',
      type: IsarType.long,
    ),
    r'requestIntervalMs': PropertySchema(
      id: 3,
      name: r'requestIntervalMs',
      type: IsarType.long,
    ),
    r'rotateUserAgent': PropertySchema(
      id: 4,
      name: r'rotateUserAgent',
      type: IsarType.bool,
    ),
    r'timeoutMs': PropertySchema(
      id: 5,
      name: r'timeoutMs',
      type: IsarType.long,
    )
  },
  estimateSize: _crawlConfigEstimateSize,
  serialize: _crawlConfigSerialize,
  deserialize: _crawlConfigDeserialize,
  deserializeProp: _crawlConfigDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _crawlConfigGetId,
  getLinks: _crawlConfigGetLinks,
  attach: _crawlConfigAttach,
  version: '3.1.0+1',
);

int _crawlConfigEstimateSize(
  CrawlConfig object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.adKeywords.length * 3;
  {
    for (var i = 0; i < object.adKeywords.length; i++) {
      final value = object.adKeywords[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _crawlConfigSerialize(
  CrawlConfig object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeStringList(offsets[0], object.adKeywords);
  writer.writeLong(offsets[1], object.maxRetries);
  writer.writeLong(offsets[2], object.prefetchChapters);
  writer.writeLong(offsets[3], object.requestIntervalMs);
  writer.writeBool(offsets[4], object.rotateUserAgent);
  writer.writeLong(offsets[5], object.timeoutMs);
}

CrawlConfig _crawlConfigDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CrawlConfig();
  object.adKeywords = reader.readStringList(offsets[0]) ?? [];
  object.id = id;
  object.maxRetries = reader.readLong(offsets[1]);
  object.prefetchChapters = reader.readLong(offsets[2]);
  object.requestIntervalMs = reader.readLong(offsets[3]);
  object.rotateUserAgent = reader.readBool(offsets[4]);
  object.timeoutMs = reader.readLong(offsets[5]);
  return object;
}

P _crawlConfigDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readStringList(offset) ?? []) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _crawlConfigGetId(CrawlConfig object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _crawlConfigGetLinks(CrawlConfig object) {
  return [];
}

void _crawlConfigAttach(
    IsarCollection<dynamic> col, Id id, CrawlConfig object) {
  object.id = id;
}

extension CrawlConfigQueryWhereSort
    on QueryBuilder<CrawlConfig, CrawlConfig, QWhere> {
  QueryBuilder<CrawlConfig, CrawlConfig, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension CrawlConfigQueryWhere
    on QueryBuilder<CrawlConfig, CrawlConfig, QWhereClause> {
  QueryBuilder<CrawlConfig, CrawlConfig, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterWhereClause> idBetween(
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

extension CrawlConfigQueryFilter
    on QueryBuilder<CrawlConfig, CrawlConfig, QFilterCondition> {
  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'adKeywords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'adKeywords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'adKeywords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'adKeywords',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'adKeywords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'adKeywords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'adKeywords',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'adKeywords',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'adKeywords',
        value: '',
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'adKeywords',
        value: '',
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'adKeywords',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'adKeywords',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'adKeywords',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'adKeywords',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'adKeywords',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      adKeywordsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'adKeywords',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition> idBetween(
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

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      maxRetriesEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'maxRetries',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      maxRetriesGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'maxRetries',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      maxRetriesLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'maxRetries',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      maxRetriesBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'maxRetries',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      prefetchChaptersEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'prefetchChapters',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      prefetchChaptersGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'prefetchChapters',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      prefetchChaptersLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'prefetchChapters',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      prefetchChaptersBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'prefetchChapters',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      requestIntervalMsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'requestIntervalMs',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      requestIntervalMsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'requestIntervalMs',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      requestIntervalMsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'requestIntervalMs',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      requestIntervalMsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'requestIntervalMs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      rotateUserAgentEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rotateUserAgent',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      timeoutMsEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'timeoutMs',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      timeoutMsGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'timeoutMs',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      timeoutMsLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'timeoutMs',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterFilterCondition>
      timeoutMsBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'timeoutMs',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension CrawlConfigQueryObject
    on QueryBuilder<CrawlConfig, CrawlConfig, QFilterCondition> {}

extension CrawlConfigQueryLinks
    on QueryBuilder<CrawlConfig, CrawlConfig, QFilterCondition> {}

extension CrawlConfigQuerySortBy
    on QueryBuilder<CrawlConfig, CrawlConfig, QSortBy> {
  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy> sortByMaxRetries() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxRetries', Sort.asc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy> sortByMaxRetriesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxRetries', Sort.desc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy>
      sortByPrefetchChapters() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prefetchChapters', Sort.asc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy>
      sortByPrefetchChaptersDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prefetchChapters', Sort.desc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy>
      sortByRequestIntervalMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestIntervalMs', Sort.asc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy>
      sortByRequestIntervalMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestIntervalMs', Sort.desc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy> sortByRotateUserAgent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rotateUserAgent', Sort.asc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy>
      sortByRotateUserAgentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rotateUserAgent', Sort.desc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy> sortByTimeoutMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timeoutMs', Sort.asc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy> sortByTimeoutMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timeoutMs', Sort.desc);
    });
  }
}

extension CrawlConfigQuerySortThenBy
    on QueryBuilder<CrawlConfig, CrawlConfig, QSortThenBy> {
  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy> thenByMaxRetries() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxRetries', Sort.asc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy> thenByMaxRetriesDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'maxRetries', Sort.desc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy>
      thenByPrefetchChapters() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prefetchChapters', Sort.asc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy>
      thenByPrefetchChaptersDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'prefetchChapters', Sort.desc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy>
      thenByRequestIntervalMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestIntervalMs', Sort.asc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy>
      thenByRequestIntervalMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'requestIntervalMs', Sort.desc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy> thenByRotateUserAgent() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rotateUserAgent', Sort.asc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy>
      thenByRotateUserAgentDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rotateUserAgent', Sort.desc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy> thenByTimeoutMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timeoutMs', Sort.asc);
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QAfterSortBy> thenByTimeoutMsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'timeoutMs', Sort.desc);
    });
  }
}

extension CrawlConfigQueryWhereDistinct
    on QueryBuilder<CrawlConfig, CrawlConfig, QDistinct> {
  QueryBuilder<CrawlConfig, CrawlConfig, QDistinct> distinctByAdKeywords() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'adKeywords');
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QDistinct> distinctByMaxRetries() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'maxRetries');
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QDistinct>
      distinctByPrefetchChapters() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'prefetchChapters');
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QDistinct>
      distinctByRequestIntervalMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'requestIntervalMs');
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QDistinct>
      distinctByRotateUserAgent() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rotateUserAgent');
    });
  }

  QueryBuilder<CrawlConfig, CrawlConfig, QDistinct> distinctByTimeoutMs() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'timeoutMs');
    });
  }
}

extension CrawlConfigQueryProperty
    on QueryBuilder<CrawlConfig, CrawlConfig, QQueryProperty> {
  QueryBuilder<CrawlConfig, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CrawlConfig, List<String>, QQueryOperations>
      adKeywordsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'adKeywords');
    });
  }

  QueryBuilder<CrawlConfig, int, QQueryOperations> maxRetriesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'maxRetries');
    });
  }

  QueryBuilder<CrawlConfig, int, QQueryOperations> prefetchChaptersProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'prefetchChapters');
    });
  }

  QueryBuilder<CrawlConfig, int, QQueryOperations> requestIntervalMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'requestIntervalMs');
    });
  }

  QueryBuilder<CrawlConfig, bool, QQueryOperations> rotateUserAgentProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rotateUserAgent');
    });
  }

  QueryBuilder<CrawlConfig, int, QQueryOperations> timeoutMsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'timeoutMs');
    });
  }
}
