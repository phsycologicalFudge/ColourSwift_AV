import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:open_filex/open_filex.dart';

enum CleanerSort { newest, oldest, largest, smallest }

class CleanerDetailScreen extends StatefulWidget {
  final String title;
  final List<File> files;
  const CleanerDetailScreen({super.key, required this.title, required this.files});

  @override
  State<CleanerDetailScreen> createState() => _CleanerDetailScreenState();
}

class _CleanerDetailScreenState extends State<CleanerDetailScreen> {
  final Set<File> _selected = {};
  CleanerSort _sort = CleanerSort.newest;

  bool _isImage(File f) {
    final e = p.extension(f.path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'].contains(e);
  }

  bool _isVideo(File f) {
    final e = p.extension(f.path).toLowerCase();
    return ['.mp4', '.mov', '.mkv', '.avi', '.webm'].contains(e);
  }

  bool get _isLargeFilesCategory => widget.title.toLowerCase().contains('large');

  List<File> get _sortedFiles {
    final list = List<File>.from(widget.files);
    int sizeOf(File f) { try { return f.lengthSync(); } catch (_) { return 0; } }
    DateTime mtime(File f) { try { return f.statSync().modified; } catch (_) { return DateTime.fromMillisecondsSinceEpoch(0); } }
    switch (_sort) {
      case CleanerSort.newest:
        list.sort((a, b) => mtime(b).compareTo(mtime(a)));
        break;
      case CleanerSort.oldest:
        list.sort((a, b) => mtime(a).compareTo(mtime(b)));
        break;
      case CleanerSort.largest:
        list.sort((a, b) => sizeOf(b).compareTo(sizeOf(a)));
        break;
      case CleanerSort.smallest:
        list.sort((a, b) => sizeOf(a).compareTo(sizeOf(b)));
        break;
    }
    return list;
  }

  void _toggleSelection(File f) {
    setState(() => _selected.contains(f) ? _selected.remove(f) : _selected.add(f));
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Files'),
        content: Text('Delete ${_selected.length} files permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    for (final f in _selected) { try { await f.delete(); } catch (_) {} }
    setState(() {
      widget.files.removeWhere(_selected.contains);
      _selected.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected files deleted')));
    }
  }

  Future<void> _deleteAll() async {
    if (widget.files.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete All Files'),
        content: Text('Delete all ${widget.files.length} files permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete All')),
        ],
      ),
    );
    if (ok != true) return;
    for (final f in widget.files) { try { await f.delete(); } catch (_) {} }
    setState(() {
      widget.files.clear();
      _selected.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All files deleted')));
    }
  }

  void _openPreview(File f) {
    if (_isImage(f)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ImagePreviewScreen(file: f)));
    } else if (_isVideo(f)) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VideoPreviewScreen(file: f)));
    }
  }

  String _fmtBytes(int bytes) {
    const u = ['B','KB','MB','GB','TB'];
    var v = bytes.toDouble();
    var i = 0;
    while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
    return '${v.toStringAsFixed(v >= 10 || i == 0 ? 0 : 1)} ${u[i]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final files = _sortedFiles;

    final hasMedia = !_isLargeFilesCategory && files.any((f) => _isImage(f) || _isVideo(f));
    final width = MediaQuery.of(context).size.width;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final crossAxis = (isLandscape || width >= 720) ? 4 : 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(_selected.isEmpty ? widget.title : '${_selected.length} selected'),
        actions: [
          PopupMenuButton<CleanerSort>(
            initialValue: _sort,
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: CleanerSort.newest, child: Text('Newest first')),
              PopupMenuItem(value: CleanerSort.oldest, child: Text('Oldest first')),
              PopupMenuItem(value: CleanerSort.largest, child: Text('Largest first')),
              PopupMenuItem(value: CleanerSort.smallest, child: Text('Smallest first')),
            ],
            icon: const Icon(Icons.sort_rounded),
          ),
          if (widget.files.isNotEmpty && _selected.isEmpty)
            IconButton(icon: const Icon(Icons.delete_sweep_rounded), onPressed: _deleteAll),
          if (_selected.isNotEmpty)
            IconButton(icon: const Icon(Icons.delete_forever_rounded), onPressed: _deleteSelected),
        ],
      ),
      body: files.isEmpty
          ? const Center(child: Text('No files found'))
          : hasMedia
          ? GridView.builder(
        padding: const EdgeInsets.all(8),
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxis,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
        itemCount: files.length,
        itemBuilder: (context, i) {
          final f = files[i];
          final isVid = _isVideo(f);
          final selected = _selected.contains(f);
          return GestureDetector(
            onTap: () => _openPreview(f),
            onLongPress: () => _toggleSelection(f),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: isVid
                      ? FutureBuilder<String?>(
                    future: VideoThumbnail.thumbnailFile(
                      video: f.path,
                      imageFormat: ImageFormat.JPEG,
                      maxWidth: 256,
                      quality: 40,
                    ),
                    builder: (context, snap) {
                      if (snap.hasData && snap.data != null) {
                        return Image.file(
                          File(snap.data!),
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        );
                      }
                      return Container(color: Colors.black12);
                    },
                  )
                      : Image.file(
                    f,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.black12),
                  ),
                ),
                if (isVid) const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 32),
                if (selected)
                  Container(
                    decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.check_circle, color: Colors.white, size: 28),
                  ),
              ],
            ),
          );
        },
      )
          : _isLargeFilesCategory
          ? ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: files.length,
        itemBuilder: (context, i) {
          final f = files[i];
          final selected = _selected.contains(f);
          int size; try { size = f.lengthSync(); } catch (_) { size = 0; }
          return ListTile(
            onTap: () => OpenFilex.open(f.path),
            onLongPress: () => _toggleSelection(f),
            title: Text(p.basename(f.path)),
            subtitle: Text(_fmtBytes(size)),
            trailing: selected ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary) : null,
          );
        },
      )
          : ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: files.length,
        itemBuilder: (context, i) {
          final f = files[i];
          final selected = _selected.contains(f);
          return ListTile(
            onLongPress: () => _toggleSelection(f),
            title: Text(p.basename(f.path)),
            subtitle: Text(f.path, overflow: TextOverflow.ellipsis),
            trailing: selected ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary) : null,
          );
        },
      ),
    );
  }
}

class ImagePreviewScreen extends StatelessWidget {
  final File file;
  const ImagePreviewScreen({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(p.basename(file.path))),
      body: PhotoView(
        imageProvider: FileImage(file),
        backgroundDecoration: const BoxDecoration(color: Colors.black),
      ),
    );
  }
}

class VideoPreviewScreen extends StatefulWidget {
  final File file;
  const VideoPreviewScreen({super.key, required this.file});

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, title: Text(p.basename(widget.file.path))),
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              VideoPlayer(_controller),
              VideoProgressIndicator(_controller, allowScrubbing: true),
              Positioned(
                bottom: 40,
                child: IconButton(
                  icon: Icon(
                    _controller.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 64,
                  ),
                  onPressed: () {
                    setState(() {
                      _controller.value.isPlaying ? _controller.pause() : _controller.play();
                    });
                  },
                ),
              ),
            ],
          ),
        )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
