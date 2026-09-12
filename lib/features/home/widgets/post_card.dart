import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/post.dart';

final DateFormat _monthAbbr = DateFormat.MMM();

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const PostCard({super.key, required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = post.date.isEmpty ? null : DateTime.tryParse(post.date);
    final abstract = post.abstract;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF0F0F0)),
          boxShadow: [
            BoxShadow(
              color: theme.primaryColor.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Undated posts get no date rail at all, which reads cleaner than
              // an empty placeholder.
              if (date != null) _DateRail(date: date),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                          fontFamily: 'Source Han Serif CN',
                        ),
                      ),
                      if (abstract != null && abstract.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            abstract,
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

class _DateRail extends StatelessWidget {
  final DateTime date;

  const _DateRail({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const family = 'Source Han Serif CN';

    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: theme.primaryColor,
              fontFamily: family,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _monthAbbr.format(date).toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
              fontFamily: family,
            ),
          ),
          Text(
            '${date.year}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[400],
              fontFamily: family,
            ),
          ),
        ],
      ),
    );
  }
}
