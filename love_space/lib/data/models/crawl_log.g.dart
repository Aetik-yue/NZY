// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crawl_log.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCrawlLogCollection on Isar {
  IsarCollection<CrawlLog> get crawlLogs => this.collection();
}

const CrawlLogSchema = CollectionSchema(
  name: r'CrawlLog',
  id: -6859112841007197336,
  properties: {
    r'crawledAt': PropertySchema(
      id: 0,
      name: r'crawledAt',
      type: IsarType.dateTime,
    ),
    r'message': PropertySchema(
      id: 1,
      name: r'message',
      type: IsarType.string,
    ),
    r'newChapters': PropertySchema(
      id: 2,
      name: r'newChapters',
      type: IsarType.long,
    ),
    r'novelId': PropertySchema(
      id: 3,
      name: r'novelId',
      type: IsarType.long,
    ),
    r'status': PropertySchema(
      id: 4,
      name: r'status',
      type: IsarType.string,
    )
  },
  estimateSize: _crawlLogEstimateSize,
  serialize: _crawlLogSerialize,
  deserialize: _crawlLogDeserialize,
  deserializeProp: _crawlLogDeserializeProp,
  idName: r'id',
  indexes: {
    r'novelId': IndexSchema(
      id: 5691757736292369527,
      name: r'novelId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'novelId',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _crawlLogGetId,
  getLinks: _crawlLogGetLinks,
  attach: _crawlLogAttach,
  version: '3.1.0+1',
);

int _crawlLogEstimateSize(
  CrawlLog object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.message;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.status.length * 3;
  return bytesCount;
}

void _crawlLogSerialize(
  CrawlLog object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.crawledAt);
  writer.writeString(offsets[1], object.message);
  writer.writeLong(offsets[2], object.newChapters);
  writer.writeLong(offsets[3], object.novelId);
  writer.writeString(offsets[4], object.status);
}

CrawlLog _crawlLogDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CrawlLog();
  object.crawledAt = reader.readDateTime(offsets[0]);
  object.id = id;
  object.message = reader.readStringOrNull(offsets[1]);
  object.newChapters = reader.readLongOrNull(offsets[2]);
  object.novelId = reader.readLong(offsets[3]);
  object.status = reader.readString(offsets[4]);
  return object;
}

P _crawlLogDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTime(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _crawlLogGetId(CrawlLog object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _crawlLogGetLinks(CrawlLog object) {
  return [];
}

void _crawlLogAttach(IsarCollection<dynamic> col, Id id, CrawlLog object) {
  object.id = id;
}

extension CrawlLogQueryWhereSort on QueryBuilder<CrawlLog, CrawlLog, QWhere> {
  QueryBuilder<CrawlLog, CrawlLog, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterWhere> anyNovelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'novelId'),
      );
    });
  }
}

extension CrawlLogQueryWhere on QueryBuilder<CrawlLog, CrawlLog, QWhereClause> {
  QueryBuilder<CrawlLog, CrawlLog, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<CrawlLog, CrawlLog, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterWhereClause> idBetween(
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

  QueryBuilder<CrawlLog, CrawlLog, QAfterWhereClause> novelIdEqualTo(
      int novelId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'novelId',
        value: [novelId],
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterWhereClause> novelIdNotEqualTo(
      int novelId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'novelId',
              lower: [],
              upper: [novelId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'novelId',
              lower: [novelId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'novelId',
              lower: [novelId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'novelId',
              lower: [],
              upper: [novelId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterWhereClause> novelIdGreaterThan(
    int novelId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'novelId',
        lower: [novelId],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterWhereClause> novelIdLessThan(
    int novelId, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'novelId',
        lower: [],
        upper: [novelId],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterWhereClause> novelIdBetween(
    int lowerNovelId,
    int upperNovelId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'novelId',
        lower: [lowerNovelId],
        includeLower: includeLower,
        upper: [upperNovelId],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension CrawlLogQueryFilter
    on QueryBuilder<CrawlLog, CrawlLog, QFilterCondition> {
  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> crawledAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'crawledAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> crawledAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'crawledAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> crawledAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'crawledAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> crawledAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'crawledAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> idBetween(
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

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> messageIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'message',
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> messageIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'message',
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> messageEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'message',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> messageGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'message',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> messageLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'message',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> messageBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'message',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> messageStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'message',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> messageEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'message',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> messageContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'message',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> messageMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'message',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> messageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'message',
        value: '',
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> messageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'message',
        value: '',
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> newChaptersIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'newChapters',
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition>
      newChaptersIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'newChapters',
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> newChaptersEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'newChapters',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition>
      newChaptersGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'newChapters',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> newChaptersLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'newChapters',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> newChaptersBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'newChapters',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> novelIdEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'novelId',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> novelIdGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'novelId',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> novelIdLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'novelId',
        value: value,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> novelIdBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'novelId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> statusEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> statusGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> statusLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> statusBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'status',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> statusContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'status',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> statusMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'status',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> statusIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'status',
        value: '',
      ));
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterFilterCondition> statusIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'status',
        value: '',
      ));
    });
  }
}

extension CrawlLogQueryObject
    on QueryBuilder<CrawlLog, CrawlLog, QFilterCondition> {}

extension CrawlLogQueryLinks
    on QueryBuilder<CrawlLog, CrawlLog, QFilterCondition> {}

extension CrawlLogQuerySortBy on QueryBuilder<CrawlLog, CrawlLog, QSortBy> {
  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> sortByCrawledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'crawledAt', Sort.asc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> sortByCrawledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'crawledAt', Sort.desc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> sortByMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message', Sort.asc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> sortByMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message', Sort.desc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> sortByNewChapters() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newChapters', Sort.asc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> sortByNewChaptersDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newChapters', Sort.desc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> sortByNovelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'novelId', Sort.asc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> sortByNovelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'novelId', Sort.desc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> sortByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> sortByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension CrawlLogQuerySortThenBy
    on QueryBuilder<CrawlLog, CrawlLog, QSortThenBy> {
  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> thenByCrawledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'crawledAt', Sort.asc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> thenByCrawledAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'crawledAt', Sort.desc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> thenByMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message', Sort.asc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> thenByMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'message', Sort.desc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> thenByNewChapters() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newChapters', Sort.asc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> thenByNewChaptersDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'newChapters', Sort.desc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> thenByNovelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'novelId', Sort.asc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> thenByNovelIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'novelId', Sort.desc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> thenByStatus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.asc);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QAfterSortBy> thenByStatusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'status', Sort.desc);
    });
  }
}

extension CrawlLogQueryWhereDistinct
    on QueryBuilder<CrawlLog, CrawlLog, QDistinct> {
  QueryBuilder<CrawlLog, CrawlLog, QDistinct> distinctByCrawledAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'crawledAt');
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QDistinct> distinctByMessage(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'message', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QDistinct> distinctByNewChapters() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'newChapters');
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QDistinct> distinctByNovelId() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'novelId');
    });
  }

  QueryBuilder<CrawlLog, CrawlLog, QDistinct> distinctByStatus(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'status', caseSensitive: caseSensitive);
    });
  }
}

extension CrawlLogQueryProperty
    on QueryBuilder<CrawlLog, CrawlLog, QQueryProperty> {
  QueryBuilder<CrawlLog, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CrawlLog, DateTime, QQueryOperations> crawledAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'crawledAt');
    });
  }

  QueryBuilder<CrawlLog, String?, QQueryOperations> messageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'message');
    });
  }

  QueryBuilder<CrawlLog, int?, QQueryOperations> newChaptersProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'newChapters');
    });
  }

  QueryBuilder<CrawlLog, int, QQueryOperations> novelIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'novelId');
    });
  }

  QueryBuilder<CrawlLog, String, QQueryOperations> statusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'status');
    });
  }
}
