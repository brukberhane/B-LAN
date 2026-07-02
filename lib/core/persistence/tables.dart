import 'package:drift/drift.dart';

class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
}

class Shares extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text()();
  TextColumn get localPath => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get scanStatus =>
      text().withDefault(const Constant('idle'))();
  TextColumn get storageType =>
      text().withDefault(const Constant('filesystem'))();
  IntColumn get totalFiles => integer().withDefault(const Constant(0))();
  IntColumn get hashedFiles => integer().withDefault(const Constant(0))();
  IntColumn get totalHashBytes => integer().withDefault(const Constant(0))();
  IntColumn get hashedBytes => integer().withDefault(const Constant(0))();
  TextColumn get currentFile => text().nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Entries extends Table {
  TextColumn get id => text()();
  TextColumn get shareId => text().references(Shares, #id)();
  TextColumn get relativePath => text()();
  TextColumn get name => text()();
  BoolColumn get isDirectory =>
      boolean().withDefault(const Constant(false))();
  IntColumn get size => integer().withDefault(const Constant(0))();
  IntColumn get mtimeMs => integer().withDefault(const Constant(0))();
  TextColumn get hashStatus =>
      text().withDefault(const Constant('pending'))();
  IntColumn get chunkSize => integer().nullable()();
  TextColumn get localUri => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Chunks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entryId => text().references(Entries, #id)();
  IntColumn get chunkIndex => integer()();
  IntColumn get offset => integer()();
  IntColumn get length => integer()();
  TextColumn get hash => text()();
  TextColumn get hashAlgorithm =>
      text().withDefault(const Constant('sha256'))();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))();
}

class Peers extends Table {
  TextColumn get id => text()();
  TextColumn get nick => text()();
  TextColumn get host => text()();
  IntColumn get port => integer()();
  TextColumn get fingerprint => text().nullable()();
  BoolColumn get trusted => boolean().withDefault(const Constant(false))();
  TextColumn get identityStatus =>
      text().withDefault(const Constant('normal'))();
  DateTimeColumn get lastSeen => dateTime().nullable()();
  BoolColumn get manual => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class RemoteEntriesCache extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get peerId => text().references(Peers, #id)();
  TextColumn get shareId => text()();
  TextColumn get relativePath => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get cachedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class DownloadGroups extends Table {
  TextColumn get id => text()();
  TextColumn get label => text()();
  TextColumn get rootPath => text()();
  TextColumn get targetPath => text()();
  TextColumn get state =>
      text().withDefault(const Constant('queued'))();
  IntColumn get totalFiles => integer().withDefault(const Constant(0))();
  IntColumn get completedFiles => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  IntColumn get downloadedBytes =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Downloads extends Table {
  TextColumn get id => text()();
  TextColumn get peerId => text().references(Peers, #id)();
  TextColumn get shareId => text()();
  TextColumn get entryId => text()();
  TextColumn get relativePath => text()();
  TextColumn get targetPath => text()();
  TextColumn get state =>
      text().withDefault(const Constant('queued'))();
  TextColumn get groupId => text().nullable().references(DownloadGroups, #id)();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  BoolColumn get paused => boolean().withDefault(const Constant(false))();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  IntColumn get downloadedBytes =>
      integer().withDefault(const Constant(0))();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DownloadChunks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get downloadId => text().references(Downloads, #id)();
  IntColumn get chunkIndex => integer()();
  TextColumn get hash => text()();
  IntColumn get offset => integer()();
  IntColumn get length => integer()();
  TextColumn get state =>
      text().withDefault(const Constant('pending'))();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get sourcePeerId => text().nullable()();
}

class Transfers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get direction => text()();
  TextColumn get peerId => text().nullable()();
  TextColumn get entryId => text().nullable()();
  IntColumn get bytesTransferred =>
      integer().withDefault(const Constant(0))();
  TextColumn get state =>
      text().withDefault(const Constant('active'))();
  DateTimeColumn get startedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
