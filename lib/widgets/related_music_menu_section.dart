import 'package:flutter/material.dart';

import '../models/song_relations.dart';

class RelatedMusicMenuSection extends StatelessWidget {
  const RelatedMusicMenuSection({
    super.key,
    required this.relations,
    required this.isLoading,
    required this.onSelected,
  });

  final SongRelations relations;
  final bool isLoading;
  final ValueChanged<SongRelationTarget> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildAction(
          context,
          key: const Key('related_artist_action'),
          label: 'Go to Artist',
          pickerTitle: 'Choose Artist',
          icon: Icons.person_outline_rounded,
          targets: relations.artists,
        ),
        _buildAction(
          context,
          key: const Key('related_circle_action'),
          label: 'Go to Circle',
          pickerTitle: 'Choose Circle',
          icon: Icons.groups_outlined,
          targets: relations.circles,
        ),
        _buildAction(
          context,
          key: const Key('related_album_action'),
          label: 'Go to Album',
          pickerTitle: 'Choose Album',
          icon: Icons.album_outlined,
          targets: relations.albums,
        ),
      ],
    );
  }

  Widget _buildAction(
    BuildContext context, {
    required Key key,
    required String label,
    required String pickerTitle,
    required IconData icon,
    required List<SongRelationTarget> targets,
  }) {
    final enabled = !isLoading && targets.isNotEmpty;
    final foreground = enabled ? Colors.white : Colors.white54;

    return ListTile(
      key: key,
      enabled: enabled,
      leading: Icon(icon, color: foreground),
      title: Text(label, style: TextStyle(color: foreground)),
      trailing: isLoading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            )
          : targets.length > 1
          ? const Icon(Icons.chevron_right_rounded, color: Colors.white54)
          : null,
      onTap: enabled
          ? () {
              if (targets.length == 1) {
                onSelected(targets.single);
                return;
              }
              _showTargetPicker(context, pickerTitle, targets);
            }
          : null,
    );
  }

  Future<void> _showTargetPicker(
    BuildContext context,
    String title,
    List<SongRelationTarget> targets,
  ) async {
    final selected = await showModalBottomSheet<SongRelationTarget>(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      showDragHandle: true,
      isScrollControlled: true,
      builder: (pickerContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(pickerContext).height * 0.72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Text(
                  title,
                  style: Theme.of(pickerContext).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: targets.length,
                  itemBuilder: (context, index) {
                    final target = targets[index];
                    return ListTile(
                      key: Key(
                        'related_target_${target.kind.name}_${target.id}',
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white70,
                        child: Icon(_iconFor(target.kind)),
                      ),
                      title: Text(
                        target.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: target.subtitle.isEmpty
                          ? null
                          : Text(
                              target.subtitle,
                              style: const TextStyle(color: Colors.white54),
                            ),
                      onTap: () {
                        Navigator.of(pickerContext).pop(target);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) onSelected(selected);
  }

  IconData _iconFor(SongRelationKind kind) {
    return switch (kind) {
      SongRelationKind.artist => Icons.person_outline_rounded,
      SongRelationKind.circle => Icons.groups_outlined,
      SongRelationKind.album => Icons.album_outlined,
    };
  }
}
