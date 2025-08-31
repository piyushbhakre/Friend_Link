import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:http/http.dart' as http;

class ImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? fileName;

  const ImageViewer({
    super.key,
    required this.imageUrl,
    this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade200,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: GestureDetector(
          onTap: () => _showFullScreen(context),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Center(
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: Colors.blue.shade600,
                size: 30,
              ),
            ),
            errorWidget: (context, url, error) => const Icon(
              Icons.error,
              color: Colors.red,
            ),
          ),
        ),
      ),
    );
  }

  void _showFullScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          imageUrl: imageUrl,
          fileName: fileName,
        ),
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? fileName;

  const FullScreenImageViewer({
    super.key,
    required this.imageUrl,
    this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          fileName ?? 'Image',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _downloadImage(context),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (context, url) => Center(
              child: LoadingAnimationWidget.staggeredDotsWave(
                color: Colors.white,
                size: 50,
              ),
            ),
            errorWidget: (context, url, error) => const Icon(
              Icons.error,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadImage(BuildContext context) async {
    try {
      // Request storage permissions with proper explanation
      bool hasPermission = await _requestStoragePermission(context);
      if (!hasPermission) return;

      // Show downloading dialog with loading animation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoadingAnimationWidget.staggeredDotsWave(
                color: Colors.blue.shade600,
                size: 50,
              ),
              const SizedBox(height: 20),
              Text(
                'Downloading Image...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                fileName ?? 'image.jpg',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      final response = await http.get(Uri.parse(imageUrl));
      final directory = await getExternalStorageDirectory();
      final file = File('${directory!.path}/${fileName ?? 'image.jpg'}');
      
      await file.writeAsBytes(response.bodyBytes);
      
      if (!context.mounted) return;
      
      // Close download dialog
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Image saved to Downloads'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      
      // Close download dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Text('Download failed: $e'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<bool> _requestStoragePermission(BuildContext context) async {
    // Request storage permission - this shows native Android dialog
    final storageStatus = await Permission.storage.request();
    
    // Check if we have storage access
    bool hasPermission = storageStatus.isGranted;
    
    // For Android 13+, also try photos permission if available
    if (Platform.isAndroid && !hasPermission) {
      try {
        final photosStatus = await Permission.photos.request();
        hasPermission = photosStatus.isGranted;
      } catch (e) {
        // Ignore if photos permission is not available
      }
    }

    if (!hasPermission && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Storage permission required to save image'),
          backgroundColor: Colors.orange.shade600,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }

    return hasPermission;
  }
}

class VideoViewer extends StatefulWidget {
  final String videoUrl;
  final String? fileName;

  const VideoViewer({
    super.key,
    required this.videoUrl,
    this.fileName,
  });

  @override
  State<VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<VideoViewer> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade200,
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: widget.videoUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.black54,
                child: const Icon(
                  Icons.play_circle_filled,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.black54,
                child: const Icon(
                  Icons.play_circle_filled,
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Play button overlay
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.play_arrow,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showVideoPlayer(context),
                child: Container(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVideoPlayer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          videoUrl: widget.videoUrl,
          fileName: widget.fileName,
        ),
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String? fileName;

  const VideoPlayerScreen({
    super.key,
    required this.videoUrl,
    this.fileName,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.initialize().then((_) {
      setState(() {
        _isLoading = false;
      });
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
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.fileName ?? 'Video',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _downloadVideo(context),
          ),
        ],
      ),
      body: Center(
        child: _isLoading
            ? LoadingAnimationWidget.staggeredDotsWave(
                color: Colors.white,
                size: 50,
              )
            : AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
      ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            ),
    );
  }

  Future<void> _downloadVideo(BuildContext context) async {
    try {
      // Request storage permissions with proper explanation
      bool hasPermission = await _requestStoragePermission(context);
      if (!hasPermission) return;

      // Show downloading dialog with loading animation
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LoadingAnimationWidget.staggeredDotsWave(
                color: Colors.blue.shade600,
                size: 50,
              ),
              const SizedBox(height: 20),
              Text(
                'Downloading Video...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.fileName ?? 'video.mp4',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      final response = await http.get(Uri.parse(widget.videoUrl));
      final directory = await getExternalStorageDirectory();
      final file = File('${directory!.path}/${widget.fileName ?? 'video.mp4'}');
      
      await file.writeAsBytes(response.bodyBytes);
      
      if (!context.mounted) return;
      
      // Close download dialog
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Video saved to Downloads'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      
      // Close download dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Text('Download failed: $e'),
            ],
          ),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  Future<bool> _requestStoragePermission(BuildContext context) async {
    // Request storage permission - this shows native Android dialog
    final storageStatus = await Permission.storage.request();
    
    // Check if we have storage access
    bool hasPermission = storageStatus.isGranted;
    
    // For Android 13+, also try videos permission if available
    if (Platform.isAndroid && !hasPermission) {
      try {
        final videosStatus = await Permission.videos.request();
        hasPermission = videosStatus.isGranted;
      } catch (e) {
        // Ignore if videos permission is not available
      }
    }

    if (!hasPermission && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Storage permission required to save video'),
          backgroundColor: Colors.orange.shade600,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }

    return hasPermission;
  }
}

class DocumentViewer extends StatefulWidget {
  final String documentUrl;
  final String fileName;
  final String? mimeType;

  const DocumentViewer({
    super.key,
    required this.documentUrl,
    required this.fileName,
    this.mimeType,
  });

  @override
  State<DocumentViewer> createState() => _DocumentViewerState();
}

class _DocumentViewerState extends State<DocumentViewer> {
  bool _isDownloaded = false;
  String? _localFilePath;

  @override
  void initState() {
    super.initState();
    _checkIfFileExists();
  }

  Future<void> _checkIfFileExists() async {
    try {
      final directory = await getExternalStorageDirectory();
      final file = File('${directory!.path}/${widget.fileName}');
      
      if (await file.exists()) {
        setState(() {
          _isDownloaded = true;
          _localFilePath = file.path;
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }

  String _getShortFileName() {
    final name = widget.fileName;
    if (name.length <= 20) return name;
    
    // Show first 15 chars + ... + extension
    final extension = name.contains('.') ? name.split('.').last : '';
    final nameWithoutExt = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    
    if (nameWithoutExt.length <= 12) {
      return name;
    }
    
    return '${nameWithoutExt.substring(0, 12)}...${extension.isNotEmpty ? '.$extension' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade200,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _handleTap(context),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  children: [
                    Icon(
                      _getFileIcon(),
                      size: 40,
                      color: Colors.blue.shade600,
                    ),
                    if (_isDownloaded)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getShortFileName(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isDownloaded ? Icons.open_in_new : Icons.download,
                      size: 16,
                      color: Colors.blue.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isDownloaded ? 'Open' : 'Download',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    if (_isDownloaded && _localFilePath != null) {
      _openLocalFile(context);
    } else {
      _downloadAndOpen(context);
    }
  }

  Future<void> _openLocalFile(BuildContext context) async {
    try {
      final result = await OpenFile.open(_localFilePath!);
      
      if (context.mounted) {
        if (result.type == ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Document opened'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Could not open: ${result.message}')),
                ],
              ),
              backgroundColor: Colors.orange.shade600,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Text('Error opening file: $e'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  IconData _getFileIcon() {
    if (widget.mimeType?.contains('pdf') == true) return Icons.picture_as_pdf;
    if (widget.mimeType?.contains('word') == true) return Icons.description;
    if (widget.mimeType?.contains('excel') == true || widget.mimeType?.contains('sheet') == true) {
      return Icons.table_chart;
    }
    if (widget.mimeType?.contains('powerpoint') == true || widget.mimeType?.contains('presentation') == true) {
      return Icons.slideshow;
    }
    return Icons.insert_drive_file;
  }

  Future<void> _downloadAndOpen(BuildContext context) async {
    try {
      // Request storage permissions with proper explanation
      bool hasPermission = await _requestStoragePermission(context);
      if (!hasPermission) return;

      // Show downloading dialog with loading animation
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LoadingAnimationWidget.staggeredDotsWave(
                  color: Colors.blue.shade600,
                  size: 50,
                ),
                const SizedBox(height: 20),
                Text(
                  'Downloading Document...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.fileName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }

      final response = await http.get(Uri.parse(widget.documentUrl));
      final directory = await getExternalStorageDirectory();
      final file = File('${directory!.path}/${widget.fileName}');
      
      await file.writeAsBytes(response.bodyBytes);
      
      // Update state to show file is now cached
      setState(() {
        _isDownloaded = true;
        _localFilePath = file.path;
      });
      
      // Try to open the file
      final result = await OpenFile.open(file.path);
      
      if (context.mounted) {
        // Close download dialog
        Navigator.of(context).pop();
        
        if (result.type == ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Document opened successfully'),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              duration: const Duration(seconds: 1),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Document saved but could not open: ${result.message}')),
                ],
              ),
              backgroundColor: Colors.orange.shade600,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Text('Download failed: $e'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  Future<bool> _requestStoragePermission(BuildContext context) async {
    // Request storage permission - this shows native Android dialog
    final storageStatus = await Permission.storage.request();
    
    // Check if we have storage access (only use permissions declared in manifest)
    bool hasPermission = storageStatus.isGranted;

    if (!hasPermission && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Storage permission required to save document'),
          backgroundColor: Colors.orange.shade600,
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }

    return hasPermission;
  }
}