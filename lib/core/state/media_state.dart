import 'package:flutter/foundation.dart';

import '../../models/media_item.dart';

enum MediaStatus {
  initial,
  loading,
  success,
  refreshFailed,
  error,
}

@immutable
class MediaState {
  const MediaState({
    this.status = MediaStatus.initial,
    this.items = const <MediaItem>[],
    this.selectedItem,
    this.errorMessage,
    this.errorCode,
    this.isOffline = false,
    this.isBackgroundRefreshing = false,
  });

  final MediaStatus status;
  final List<MediaItem> items;
  final MediaItem? selectedItem;
  final String? errorMessage;
  final String? errorCode;
  final bool isOffline;
  final bool isBackgroundRefreshing;

  MediaState copyWith({
    MediaStatus? status,
    List<MediaItem>? items,
    MediaItem? selectedItem,
    String? errorMessage,
    String? errorCode,
    bool? isOffline,
    bool? isBackgroundRefreshing,
    bool clearSelectedItem = false,
    bool clearError = false,
    bool clearErrorCode = false,
  }) {
    return MediaState(
      status: status ?? this.status,
      items: items ?? this.items,
      selectedItem:
          clearSelectedItem ? null : (selectedItem ?? this.selectedItem),
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
      errorCode:
          clearErrorCode ? null : (errorCode ?? this.errorCode),
      isOffline: isOffline ?? this.isOffline,
      isBackgroundRefreshing:
          isBackgroundRefreshing ?? this.isBackgroundRefreshing,
    );
  }

  bool get hasData => items.isNotEmpty || selectedItem != null;

  bool get hasError =>
      status == MediaStatus.error ||
      status == MediaStatus.refreshFailed;

  bool get isLoading => status == MediaStatus.loading;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MediaState &&
        other.status == status &&
        listEquals(other.items, items) &&
        other.selectedItem == selectedItem &&
        other.errorMessage == errorMessage &&
        other.errorCode == errorCode &&
        other.isOffline == isOffline &&
        other.isBackgroundRefreshing == isBackgroundRefreshing;
  }

  @override
  int get hashCode => Object.hash(
        status,
        Object.hashAll(items),
        selectedItem,
        errorMessage,
        errorCode,
        isOffline,
        isBackgroundRefreshing,
      );
}
