import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class FolderListItem extends StatelessWidget {
  final AssetPathEntity album;
  final bool isSelected;
  final VoidCallback onTap;

  const FolderListItem({
    Key? key,
    required this.album,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: FutureBuilder<List<AssetEntity>>(
        future: album.getAssetListRange(start: 0, end: 1),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data != null &&
              snapshot.data!.isNotEmpty) {
            return Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: AssetEntityImage(
                snapshot.data!.first,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize(56, 56),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(
                      Icons.folder,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            );
          }
          return Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.folder,
              color: Colors.grey,
            ),
          );
        },
      ),
      title: Text(album.name),
      subtitle: FutureBuilder<int>(
        future: album.assetCountAsync,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              snapshot.data != null) {
            return Text('${snapshot.data} items');
          }
          return const Text('Loading...');
        },
      ),
      trailing: isSelected
          ? const Icon(
              Icons.check_circle,
              color: Colors.blue,
            )
          : null,
      onTap: onTap,
    );
  }
}
