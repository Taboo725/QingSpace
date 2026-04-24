class AppVersion {
  static const String currentVersion = '1.0.3';

  static const List<Map<String, String>> changelog = [
    {
      'version': '1.0.3',
      'date': '2026-03-02',
      'changes': '''
- Fixed loading issues of GitHub content (jsDelivr)
- Added Settings page
- Added Theme setting
- Added Debug Mode toggle
- Added Version info and Changelog display
''',
    },
    {
      'version': '1.0.1',
      'date': '2026-02-15',
      'changes': '''
- Added date modifier for Moments
''',
    },
    {
      'version': '1.0.0',
      'date': '2025-02-15',
      'changes': '''
- Initial Release
''',
    },
  ];
}
