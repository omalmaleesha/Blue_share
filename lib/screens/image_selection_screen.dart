import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../widgets/asset_thumbnail.dart';
import '../widgets/folder_list_item.dart';

class ImageSelectionScreen extends StatefulWidget {
  final Function(List<AssetEntity>) onImagesSelected;

  const ImageSelectionScreen({
    Key? key,
    required this.onImagesSelected,
  }) : super(key: key);

  @override
  State<ImageSelectionScreen> createState() => _ImageSelectionScreenState();
}

class _ImageSelectionScreenState extends State<ImageSelectionScreen> {
  List<AssetPathEntity> _albums = [];
  List<AssetEntity> _assets = [];
  List<AssetEntity> _selectedAssets = [];
  AssetPathEntity? _currentAlbum;
  bool _isLoading = true;
  int _currentPage = 0;
  final int _pageSize = 80;
  bool _hasMoreToLoad = true;
  bool _isGridView = true;
  SortOrder _sortOrder = SortOrder.desc;

  @override
  void initState() {
    super.initState();
    _fetchAlbums();
  }

  Future<void> _fetchAlbums() async {
    final permitted = await _checkAndRequestPermission();
    if (!permitted) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    // Get all albums
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
    );

    if (albums.isNotEmpty) {
      setState(() {
        _albums = albums;
        _currentAlbum = albums.first; // Usually the "All" album
      });
      _fetchAssets();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAssets() async {
    if (_currentAlbum == null) return;

    final assets = await _currentAlbum!.getAssetListPaged(
      page: _currentPage,
      size: _pageSize,
    );

    // Sort assets based on creation date
    final sortedAssets = List<AssetEntity>.from(assets)
      ..sort((a, b) => _sortOrder == SortOrder.desc
          ? b.createDateTime.compareTo(a.createDateTime)
          : a.createDateTime.compareTo(b.createDateTime));

    setState(() {
      if (_currentPage == 0) {
        _assets = sortedAssets;
      } else {
        _assets.addAll(sortedAssets);
      }
      _hasMoreToLoad = assets.length >= _pageSize;
      _isLoading = false;
    });
  }

  Future<bool> _checkAndRequestPermission() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth;
  }

  void _loadMore() {
    if (_hasMoreToLoad && !_isLoading) {
      setState(() {
        _currentPage++;
        _isLoading = true;
      });
      _fetchAssets();
    }
  }

  void _changeAlbum(AssetPathEntity album) {
    setState(() {
      _currentAlbum = album;
      _currentPage = 0;
      _assets = [];
      _isLoading = true;
    });
    _fetchAssets();
    Navigator.pop(context);
  }

  void _toggleSortOrder() {
    setState(() {
      _sortOrder = _sortOrder == SortOrder.desc ? SortOrder.asc : SortOrder.desc;
      _currentPage = 0;
      _assets = [];
      _isLoading = true;
    });
    _fetchAssets();
  }

  void _toggleViewMode() {
    setState(() {
      _isGridView = !_isGridView;
    });
  }

  void _toggleAssetSelection(AssetEntity asset) {
    setState(() {
      if (_selectedAssets.contains(asset)) {
        _selectedAssets.remove(asset);
      } else {
        _selectedAssets.add(asset);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedAssets.length == _assets.length) {
        // If all are selected, deselect all
        _selectedAssets.clear();
      } else {
        // Otherwise, select all
        _selectedAssets = List.from(_assets);
      }
    });
  }

  void _confirmSelection() {
    widget.onImagesSelected(_selectedAssets);
    Navigator.pop(context);
  }

  void _showAlbumPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Text(
                    'Select Album',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: _albums.length,
                itemBuilder: (context, index) {
                  final album = _albums[index];
                  return FolderListItem(
                    album: album,
                    isSelected: album.id == _currentAlbum?.id,
                    onTap: () => _changeAlbum(album),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewAsset(AssetEntity asset) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssetViewerScreen(
          asset: asset,
          isSelected: _selectedAssets.contains(asset),
          onToggleSelection: () => _toggleAssetSelection(asset),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showAlbumPicker,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_currentAlbum?.name ?? 'Photos'),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(_sortOrder == SortOrder.desc
                ? Icons.arrow_downward
                : Icons.arrow_upward),
            onPressed: _toggleSortOrder,
            tooltip: 'Change sort order',
          ),
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: _toggleViewMode,
            tooltip: 'Change view mode',
          ),
          if (_assets.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _selectAll,
              tooltip: _selectedAssets.length == _assets.length
                  ? 'Deselect all'
                  : 'Select all',
            ),
        ],
      ),
      body: _isLoading && _assets.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _assets.isEmpty
          ? const Center(child: Text('No photos found'))
          : _isGridView
          ? _buildGridView()
          : _buildListView(),
      bottomNavigationBar: _selectedAssets.isNotEmpty
          ? BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Text(
                '${_selectedAssets.length} selected',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _confirmSelection,
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      )
          : null,
    );
  }

  Widget _buildGridView() {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200 &&
            _hasMoreToLoad &&
            !_isLoading) {
          _loadMore();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(1),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 1,
          crossAxisSpacing: 1,
        ),
        itemCount: _assets.length + (_hasMoreToLoad ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _assets.length) {
            return const Center(child: CircularProgressIndicator());
          }

          final asset = _assets[index];
          final isSelected = _selectedAssets.contains(asset);

          return AssetThumbnail(
            asset: asset,
            isSelected: isSelected,
            onTap: () => _viewAsset(asset),
            onLongPress: () => _toggleAssetSelection(asset),
            selectionMode: true,
          );
        },
      ),
    );
  }

  Widget _buildListView() {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200 &&
            _hasMoreToLoad &&
            !_isLoading) {
          _loadMore();
        }
        return false;
      },
      child: ListView.builder(
        itemCount: _assets.length + (_hasMoreToLoad ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _assets.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final asset = _assets[index];
          final isSelected = _selectedAssets.contains(asset);

          return ListTile(
            leading: AssetThumbnail(
              asset: asset,
              isSelected: isSelected,
              selectionMode: false,
              size: 56,
            ),
            title: FutureBuilder<File?>(
              future: asset.file,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                  return Text(path.basename(snapshot.data!.path));
                }
                return const Text('Loading...');
              },
            ),
            subtitle: Text(
              '${asset.width}x${asset.height} • ${_formatDate(asset.createDateTime)}',
            ),
            trailing: Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleAssetSelection(asset),
            ),
            onTap: () => _viewAsset(asset),
            onLongPress: () => _toggleAssetSelection(asset),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class AssetViewerScreen extends StatelessWidget {
  final AssetEntity asset;
  final bool isSelected;
  final VoidCallback onToggleSelection;

  const AssetViewerScreen({
    Key? key,
    required this.asset,
    required this.isSelected,
    required this.onToggleSelection,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? Colors.blue : Colors.white,
            ),
            onPressed: onToggleSelection,
          ),
        ],
      ),
      body: Center(
        child: AssetEntityImage(
          asset,
          isOriginal: true,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.white,
                size: 64,
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${asset.width}x${asset.height}',
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                _formatDate(asset.createDateTime),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

enum SortOrder { asc, desc }