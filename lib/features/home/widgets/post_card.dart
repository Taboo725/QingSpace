import 'package:flutter/material.dart';
import '../../../../models/post.dart';
import 'package:intl/intl.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const PostCard({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Try to parse '2023-01-01'
    DateTime? date;
    try {
      if (post.date.isNotEmpty) {
        date = DateTime.parse(post.date);
      }
    } catch (_) {}

    final day = date != null ? date.day.toString() : '';
    final month = date != null
        ? DateFormat.MMM().format(date).toUpperCase()
        : '';
    final year = date != null ? date.year.toString() : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F0F0)), // Subtle border
          boxShadow: [
            BoxShadow(
              color: Theme.of(
                context,
              ).primaryColor.withValues(alpha: 0.04), // Tinted shadow
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date Box (Dynamic)
              if (date != null)
                Container(
                  width: 72,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        day,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).primaryColor,
                          fontFamily: 'Source Han Serif CN',
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        month,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.secondary, // Accent Color
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          fontFamily: 'Source Han Serif CN',
                        ),
                      ),
                      Text(
                        year,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[400],
                          fontFamily: 'Source Han Serif CN',
                        ),
                      ),
                    ],
                  ),
                ),
              // NO fallback strip here - clean look for undated items

              // Content Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        post.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                          color: Color(0xFF333333),
                          fontFamily:
                              'Source Han Serif CN', // Corrected Family Name (spaces matter based on pubspec)
                        ),
                      ),

                      // Abstract (if available)
                      if (post.abstract != null && post.abstract!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            post.abstract!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              height: 1.4,
                              fontFamily: 'Source Han Serif CN',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Arrow
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[300],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
