/// A photo entry stored in `data/gallery.yml`.
class GalleryItem {
  /// Either an absolute `http(s)` URL or a repo-relative path (`/images/...`).
  final String url;
  final String caption;

  /// Capture date, used by the "on this day" memory picker. Optional: entries
  /// written before dates were recorded have none.
  final DateTime? date;

  const GalleryItem({required this.url, required this.caption, this.date});

  factory GalleryItem.fromMap(Map<dynamic, dynamic> map) {
    final rawDate = map['date'];
    return GalleryItem(
      url: map['url']?.toString() ?? '',
      caption: map['caption']?.toString() ?? '',
      date: rawDate is DateTime
          ? rawDate
          : (rawDate == null ? null : DateTime.tryParse(rawDate.toString())),
    );
  }

  GalleryItem copyWith({String? url, String? caption, DateTime? date}) =>
      GalleryItem(
        url: url ?? this.url,
        caption: caption ?? this.caption,
        date: date ?? this.date,
      );
}
