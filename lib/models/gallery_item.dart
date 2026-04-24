class GalleryItem {
  final String url;
  final String caption;
  final DateTime? date;

  GalleryItem({required this.url, required this.caption, this.date});

  factory GalleryItem.fromMap(Map<String, dynamic> map) {
    // Try to parse date if available
    DateTime? parsedDate;
    if (map['date'] != null) {
      if (map['date'] is DateTime) {
        parsedDate = map['date'];
      } else {
        parsedDate = DateTime.tryParse(map['date'].toString());
      }
    }

    return GalleryItem(
      url: map['url'] ?? '',
      caption: map['caption'] ?? '',
      date: parsedDate,
    );
  }
}
