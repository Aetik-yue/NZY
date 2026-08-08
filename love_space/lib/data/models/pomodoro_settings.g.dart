// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pomodoro_settings.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPomodoroSettingsCollection on Isar {
  IsarCollection<PomodoroSettings> get pomodoroSettings => this.collection();
}

const PomodoroSettingsSchema = CollectionSchema(
  name: r'PomodoroSettings',
  id: 6140716566819135039,
  properties: {
    r'autoStartBreak': PropertySchema(
      id: 0,
      name: r'autoStartBreak',
      type: IsarType.bool,
    ),
    r'autoStartFocus': PropertySchema(
      id: 1,
      name: r'autoStartFocus',
      type: IsarType.bool,
    ),
    r'focusMin': PropertySchema(
      id: 2,
      name: r'focusMin',
      type: IsarType.long,
    ),
    r'longBreakInterval': PropertySchema(
      id: 3,
      name: r'longBreakInterval',
      type: IsarType.long,
    ),
    r'longBreakMin': PropertySchema(
      id: 4,
      name: r'longBreakMin',
      type: IsarType.long,
    ),
    r'shortBreakMin': PropertySchema(
      id: 5,
      name: r'shortBreakMin',
      type: IsarType.long,
    )
  },
  estimateSize: _pomodoroSettingsEstimateSize,
  serialize: _pomodoroSettingsSerialize,
  deserialize: _pomodoroSettingsDeserialize,
  deserializeProp: _pomodoroSettingsDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _pomodoroSettingsGetId,
  getLinks: _pomodoroSettingsGetLinks,
  attach: _pomodoroSettingsAttach,
  version: '3.1.0+1',
);

int _pomodoroSettingsEstimateSize(
  PomodoroSettings object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _pomodoroSettingsSerialize(
  PomodoroSettings object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.autoStartBreak);
  writer.writeBool(offsets[1], object.autoStartFocus);
  writer.writeLong(offsets[2], object.focusMin);
  writer.writeLong(offsets[3], object.longBreakInterval);
  writer.writeLong(offsets[4], object.longBreakMin);
  writer.writeLong(offsets[5], object.shortBreakMin);
}

PomodoroSettings _pomodoroSettingsDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PomodoroSettings();
  object.autoStartBreak = reader.readBool(offsets[0]);
  object.autoStartFocus = reader.readBool(offsets[1]);
  object.focusMin = reader.readLong(offsets[2]);
  object.id = id;
  object.longBreakInterval = reader.readLong(offsets[3]);
  object.longBreakMin = reader.readLong(offsets[4]);
  object.shortBreakMin = reader.readLong(offsets[5]);
  return object;
}

P _pomodoroSettingsDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readBool(offset)) as P;
    case 2:
      return (reader.readLong(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _pomodoroSettingsGetId(PomodoroSettings object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _pomodoroSettingsGetLinks(PomodoroSettings object) {
  return [];
}

void _pomodoroSettingsAttach(
    IsarCollection<dynamic> col, Id id, PomodoroSettings object) {
  object.id = id;
}

extension PomodoroSettingsQueryWhereSort
    on QueryBuilder<PomodoroSettings, PomodoroSettings, QWhere> {
  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension PomodoroSettingsQueryWhere
    on QueryBuilder<PomodoroSettings, PomodoroSettings, QWhereClause> {
  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterWhereClause>
      idNotEqualTo(Id id) {
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

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterWhereClause> idBetween(
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

extension PomodoroSettingsQueryFilter
    on QueryBuilder<PomodoroSettings, PomodoroSettings, QFilterCondition> {
  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      autoStartBreakEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'autoStartBreak',
        value: value,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      autoStartFocusEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'autoStartFocus',
        value: value,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      focusMinEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'focusMin',
        value: value,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      focusMinGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'focusMin',
        value: value,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      focusMinLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'focusMin',
        value: value,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      focusMinBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'focusMin',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
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

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
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

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      idBetween(
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

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      longBreakIntervalEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'longBreakInterval',
        value: value,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      longBreakIntervalGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'longBreakInterval',
        value: value,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      longBreakIntervalLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'longBreakInterval',
        value: value,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      longBreakIntervalBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'longBreakInterval',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      longBreakMinEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'longBreakMin',
        value: value,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      longBreakMinGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'longBreakMin',
        value: value,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      longBreakMinLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'longBreakMin',
        value: value,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      longBreakMinBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'longBreakMin',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      shortBreakMinEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'shortBreakMin',
        value: value,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      shortBreakMinGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'shortBreakMin',
        value: value,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      shortBreakMinLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'shortBreakMin',
        value: value,
      ));
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterFilterCondition>
      shortBreakMinBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'shortBreakMin',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension PomodoroSettingsQueryObject
    on QueryBuilder<PomodoroSettings, PomodoroSettings, QFilterCondition> {}

extension PomodoroSettingsQueryLinks
    on QueryBuilder<PomodoroSettings, PomodoroSettings, QFilterCondition> {}

extension PomodoroSettingsQuerySortBy
    on QueryBuilder<PomodoroSettings, PomodoroSettings, QSortBy> {
  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      sortByAutoStartBreak() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartBreak', Sort.asc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      sortByAutoStartBreakDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartBreak', Sort.desc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      sortByAutoStartFocus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartFocus', Sort.asc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      sortByAutoStartFocusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartFocus', Sort.desc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      sortByFocusMin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'focusMin', Sort.asc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      sortByFocusMinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'focusMin', Sort.desc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      sortByLongBreakInterval() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longBreakInterval', Sort.asc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      sortByLongBreakIntervalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longBreakInterval', Sort.desc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      sortByLongBreakMin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longBreakMin', Sort.asc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      sortByLongBreakMinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longBreakMin', Sort.desc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      sortByShortBreakMin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shortBreakMin', Sort.asc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      sortByShortBreakMinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shortBreakMin', Sort.desc);
    });
  }
}

extension PomodoroSettingsQuerySortThenBy
    on QueryBuilder<PomodoroSettings, PomodoroSettings, QSortThenBy> {
  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      thenByAutoStartBreak() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartBreak', Sort.asc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      thenByAutoStartBreakDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartBreak', Sort.desc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      thenByAutoStartFocus() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartFocus', Sort.asc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      thenByAutoStartFocusDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'autoStartFocus', Sort.desc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      thenByFocusMin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'focusMin', Sort.asc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      thenByFocusMinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'focusMin', Sort.desc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      thenByLongBreakInterval() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longBreakInterval', Sort.asc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      thenByLongBreakIntervalDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longBreakInterval', Sort.desc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      thenByLongBreakMin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longBreakMin', Sort.asc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      thenByLongBreakMinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'longBreakMin', Sort.desc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      thenByShortBreakMin() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shortBreakMin', Sort.asc);
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QAfterSortBy>
      thenByShortBreakMinDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'shortBreakMin', Sort.desc);
    });
  }
}

extension PomodoroSettingsQueryWhereDistinct
    on QueryBuilder<PomodoroSettings, PomodoroSettings, QDistinct> {
  QueryBuilder<PomodoroSettings, PomodoroSettings, QDistinct>
      distinctByAutoStartBreak() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'autoStartBreak');
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QDistinct>
      distinctByAutoStartFocus() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'autoStartFocus');
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QDistinct>
      distinctByFocusMin() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'focusMin');
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QDistinct>
      distinctByLongBreakInterval() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'longBreakInterval');
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QDistinct>
      distinctByLongBreakMin() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'longBreakMin');
    });
  }

  QueryBuilder<PomodoroSettings, PomodoroSettings, QDistinct>
      distinctByShortBreakMin() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'shortBreakMin');
    });
  }
}

extension PomodoroSettingsQueryProperty
    on QueryBuilder<PomodoroSettings, PomodoroSettings, QQueryProperty> {
  QueryBuilder<PomodoroSettings, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PomodoroSettings, bool, QQueryOperations>
      autoStartBreakProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'autoStartBreak');
    });
  }

  QueryBuilder<PomodoroSettings, bool, QQueryOperations>
      autoStartFocusProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'autoStartFocus');
    });
  }

  QueryBuilder<PomodoroSettings, int, QQueryOperations> focusMinProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'focusMin');
    });
  }

  QueryBuilder<PomodoroSettings, int, QQueryOperations>
      longBreakIntervalProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'longBreakInterval');
    });
  }

  QueryBuilder<PomodoroSettings, int, QQueryOperations> longBreakMinProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'longBreakMin');
    });
  }

  QueryBuilder<PomodoroSettings, int, QQueryOperations>
      shortBreakMinProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'shortBreakMin');
    });
  }
}
