import 'package:drift/drift.dart';

import '../protocol/constants.dart';

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
  TextColumn get scheme =>
      text().withDefault(const Constant(peerSchemeHttps))();
  TextColumn get fingerprint => text().nullable()();
  TextColumn get tlsCertFingerprint => text().nullable()();
  BoolColumn get trusted => boolean().withDefault(const Constant(false))();
  TextColumn get identityStatus =>
      text().withDefault(const Constant('normal'))();
  DateTimeColumn get lastSeen => dateTime().nullable()();
  BoolColumn get manual => boolean().withDefault(const Constant(false))();
  BoolColumn get stale => boolean().withDefault(const Constant(false))();

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
  IntColumn get inFlightBytes =>
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

class RemoteFiles extends Table {
  TextColumn get id => text()();
  TextColumn get peerId => text().references(Peers, #id)();
  TextColumn get shareId => text()();
  TextColumn get entryId => text()();
  TextColumn get relativePath => text()();
  TextColumn get name => text()();
  BoolColumn get isDirectory =>
      boolean().withDefault(const Constant(false))();
  IntColumn get size => integer().withDefault(const Constant(0))();
  IntColumn get mtimeMs => integer().withDefault(const Constant(0))();
  BoolColumn get hashReady => boolean().withDefault(const Constant(false))();
  TextColumn get contentSignature => text().nullable()();
  TextColumn get manifestJson => text().nullable()();
  DateTimeColumn get cachedAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class EntrySearchTokens extends Table {
  TextColumn get entryId => text().references(Entries, #id)();
  TextColumn get shareId => text()();
  TextColumn get token => text()();

  @override
  Set<Column<Object>> get primaryKey => {entryId, token};
}

class RemoteChunkSources extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get hash => text()();
  TextColumn get peerId => text().references(Peers, #id)();
  TextColumn get remoteFileId => text().references(RemoteFiles, #id)();
  TextColumn get shareId => text()();
  TextColumn get entryId => text()();
  IntColumn get chunkIndex => integer()();
  IntColumn get offset => integer()();
  IntColumn get length => integer()();
  DateTimeColumn get lastSeen =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastSuccessAt => dateTime().nullable()();
  IntColumn get failureCount => integer().withDefault(const Constant(0))();
  IntColumn get avgLatencyMs => integer().nullable()();
  IntColumn get avgBytesPerSecond => integer().nullable()();
}

class Transfers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get direction => text()();
  TextColumn get peerId => text().nullable()();
  TextColumn get remoteAddress => text().nullable()();
  TextColumn get entryId => text().nullable()();
  TextColumn get chunkHash => text().nullable()();
  IntColumn get bytesTotal => integer().withDefault(const Constant(0))();
  IntColumn get bytesTransferred =>
      integer().withDefault(const Constant(0))();
  IntColumn get rateBytesPerSecond =>
      integer().withDefault(const Constant(0))();
  TextColumn get state =>
      text().withDefault(const Constant('active'))();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get startedAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
