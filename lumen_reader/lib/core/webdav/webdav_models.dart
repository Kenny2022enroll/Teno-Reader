import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';

@HiveType(typeId: 20)
class WebDAVSettings extends Equatable {
  @HiveField(0)
  final String url;
  @HiveField(1)
  final String username;
  @HiveField(2)
  final String password;
  @HiveField(3)
  final String rootFolder;
  @HiveField(4)
  final bool autoSync;

  const WebDAVSettings({
    required this.url,
    required this.username,
    required this.password,
    this.rootFolder = '/LumenReader',
    this.autoSync = true,
  });

  WebDAVSettings copyWith({
    String? url,
    String? username,
    String? password,
    String? rootFolder,
    bool? autoSync,
  }) {
    return WebDAVSettings(
      url: url ?? this.url,
      username: username ?? this.username,
      password: password ?? this.password,
      rootFolder: rootFolder ?? this.rootFolder,
      autoSync: autoSync ?? this.autoSync,
    );
  }

  bool get isConfigured =>
      url.isNotEmpty && username.isNotEmpty && password.isNotEmpty;

  @override
  List<Object?> get props => [url, username, password, rootFolder, autoSync];
}

class WebDAVSyncResult {
  final bool ok;
  final String? message;
  final int? uploaded;
  final int? downloaded;

  const WebDAVSyncResult.success({this.uploaded, this.downloaded})
    : ok = true,
      message = null;

  const WebDAVSyncResult.failed(this.message)
    : ok = false,
      uploaded = null,
      downloaded = null;
}
