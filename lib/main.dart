import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
    <DeviceOrientation>[DeviceOrientation.portraitUp],
  );
  runApp(const ScrollMoreApp());
}

class ScrollMoreApp extends StatelessWidget {
  const ScrollMoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const VideoFeedScreen(),
    );
  }
}

class VideoItemData {
  const VideoItemData({
    required this.url,
    required this.title,
    required this.source,
    required this.trustScore,
  });

  final String url;
  final String title;
  final String source;
  final int trustScore;
}

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  static const List<VideoItemData> _videos = <VideoItemData>[
    VideoItemData(
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      title: 'Behind the scenes: how animation pipelines scale creatively',
      source: 'Open Media Lab',
      trustScore: 92,
    ),
    VideoItemData(
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      title: 'Concept art timelapse and visual storytelling in 3D worlds',
      source: 'Creator Stream',
      trustScore: 89,
    ),
    VideoItemData(
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      title: 'Creative campaign breakdown: pacing, hooks, and retention tips',
      source: 'Growth Daily',
      trustScore: 94,
    ),
    VideoItemData(
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      title: 'Nature reel with cinematic transitions and color grading',
      source: 'Travel Motion',
      trustScore: 90,
    ),
    VideoItemData(
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
      title: 'Short film clip showcasing dramatic lighting and sound design',
      source: 'Film Threads',
      trustScore: 95,
    ),
    VideoItemData(
      url:
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
      title: 'VFX scene study: compositing practical and digital elements',
      source: 'Studio Notes',
      trustScore: 91,
    ),
  ];

  final PageController _pageController = PageController();
  final Map<int, VideoPlayerController> _controllers =
      <int, VideoPlayerController>{};
  final Map<int, int> _likesBySource = <int, int>{};

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _prepareWindow(centerIndex: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final VideoPlayerController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _prepareWindow({required int centerIndex}) async {
    final List<int> keep = <int>[centerIndex - 1, centerIndex, centerIndex + 1];

    for (final int index in keep) {
      await _ensureController(index);
    }

    final Set<int> keepSet = keep.toSet();
    final List<int> obsolete = _controllers.keys
        .where((int index) => !keepSet.contains(index))
        .toList();

    for (final int index in obsolete) {
      await _controllers.remove(index)?.dispose();
    }

    _pauseAllExcept(centerIndex);

    final VideoPlayerController? current = _controllers[centerIndex];
    if (current != null && current.value.isInitialized && !current.value.isPlaying) {
      await current.play();
    }
  }

  Future<void> _ensureController(int index) async {
    if (_controllers[index] != null) {
      return;
    }

    final VideoItemData item = _videos[_sourceIndex(index)];
    final VideoPlayerController controller = VideoPlayerController.networkUrl(
      Uri.parse(item.url),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );

    _controllers[index] = controller;

    await controller.initialize();
    await controller.setLooping(true);
    await controller.setVolume(1);
    await controller.setPlaybackSpeed(1);

    if (!mounted) {
      await controller.dispose();
      _controllers.remove(index);
      return;
    }

    setState(() {});
  }

  void _pauseAllExcept(int indexToKeep) {
    for (final MapEntry<int, VideoPlayerController> entry in _controllers.entries) {
      if (entry.key != indexToKeep && entry.value.value.isPlaying) {
        entry.value.pause();
      }
    }
  }

  int _sourceIndex(int feedIndex) {
    final int len = _videos.length;
    return ((feedIndex % len) + len) % len;
  }

  void _handlePageChanged(int pageIndex) {
    _currentIndex = pageIndex;
    unawaited(_prepareWindow(centerIndex: pageIndex));
    setState(() {});
  }

  void _handleLike(int feedIndex) {
    final int sourceIndex = _sourceIndex(feedIndex);
    setState(() {
      _likesBySource[sourceIndex] = (_likesBySource[sourceIndex] ?? 0) + 1;
    });
  }

  int _likesFor(int feedIndex) {
    return _likesBySource[_sourceIndex(feedIndex)] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _handlePageChanged,
        itemBuilder: (BuildContext context, int index) {
          final VideoItemData item = _videos[_sourceIndex(index)];
          return VideoFeedItem(
            key: ValueKey<int>(index),
            data: item,
            controller: _controllers[index],
            isActive: index == _currentIndex,
            likeCount: _likesFor(index),
            onLike: () => _handleLike(index),
          );
        },
      ),
    );
  }
}

class VideoFeedItem extends StatefulWidget {
  const VideoFeedItem({
    super.key,
    required this.data,
    required this.controller,
    required this.isActive,
    required this.likeCount,
    required this.onLike,
  });

  final VideoItemData data;
  final VideoPlayerController? controller;
  final bool isActive;
  final int likeCount;
  final VoidCallback onLike;

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> {
  static const double _edgeHoldZone = 96;
  static const double _movementSlop = 14;
  static const Duration _holdDelay = Duration(milliseconds: 220);

  final List<HeartBurstData> _heartBursts = <HeartBurstData>[];

  Timer? _holdTimer;
  Offset? _pointerDownPosition;
  bool _speedBoostActive = false;

  @override
  void didUpdateWidget(covariant VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isActive != oldWidget.isActive && !widget.isActive) {
      widget.controller?.pause();
      _setSpeedBoost(false);
    }

    if (widget.isActive && widget.controller != null && widget.controller!.value.isInitialized) {
      widget.controller!.play();
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _togglePlayPause() {
    final VideoPlayerController? controller = widget.controller;
    if (controller == null || !widget.isActive || !controller.value.isInitialized) {
      return;
    }

    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  void _onDoubleTap(TapDownDetails details) {
    widget.onLike();

    final HeartBurstData burst = HeartBurstData(
      id: DateTime.now().microsecondsSinceEpoch,
      position: details.localPosition,
    );

    setState(() => _heartBursts.add(burst));

    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _heartBursts.removeWhere((HeartBurstData item) => item.id == burst.id);
      });
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.isActive) {
      return;
    }

    final Size size = MediaQuery.of(context).size;
    final bool inEdge = event.localPosition.dx <= _edgeHoldZone ||
        event.localPosition.dx >= size.width - _edgeHoldZone;

    if (!inEdge) {
      return;
    }

    _pointerDownPosition = event.localPosition;
    _holdTimer?.cancel();
    _holdTimer = Timer(_holdDelay, () {
      if (mounted) {
        _setSpeedBoost(true);
      }
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    final Offset? start = _pointerDownPosition;
    if (start == null) {
      return;
    }
    final double movement = (event.localPosition - start).distance;
    if (movement > _movementSlop) {
      _cancelHoldTimer();
      _setSpeedBoost(false);
    }
  }

  void _onPointerUpOrCancel() {
    _cancelHoldTimer();
    _setSpeedBoost(false);
  }

  void _cancelHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _pointerDownPosition = null;
  }

  void _setSpeedBoost(bool enabled) {
    if (_speedBoostActive == enabled) {
      return;
    }

    final VideoPlayerController? controller = widget.controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    _speedBoostActive = enabled;
    controller.setPlaybackSpeed(enabled ? 2.0 : 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (_) => _onPointerUpOrCancel(),
      onPointerCancel: (_) => _onPointerUpOrCancel(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePlayPause,
        onDoubleTapDown: _onDoubleTap,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(
              color: Colors.black,
              child: Center(
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: widget.controller ?? ValueNotifier<VideoPlayerValue>(
                    VideoPlayerValue.uninitialized(),
                  ),
                  builder: (BuildContext context, VideoPlayerValue value, Widget? child) {
                    final VideoPlayerController? controller = widget.controller;
                    if (controller == null || !value.isInitialized) {
                      return const SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(strokeWidth: 2.6),
                      );
                    }

                    final Size size = value.size;
                    return FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: VideoPlayer(controller),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: widget.isActive ? 1 : 0.85,
                duration: const Duration(milliseconds: 220),
                child: VideoOverlay(
                  title: widget.data.title,
                  source: widget.data.source,
                  trustScore: widget.data.trustScore,
                  likeCount: widget.likeCount,
                ),
              ),
            ),
            ..._heartBursts.map(
              (HeartBurstData burst) => Positioned.fill(
                child: IgnorePointer(
                  child: HeartBurst(
                    key: ValueKey<int>(burst.id),
                    position: burst.position,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoOverlay extends StatelessWidget {
  const VideoOverlay({
    super.key,
    required this.title,
    required this.source,
    required this.trustScore,
    required this.likeCount,
  });

  final String title;
  final String source;
  final int trustScore;
  final int likeCount;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      shadows: <Shadow>[
                        Shadow(blurRadius: 8, color: Colors.black54),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    source,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      shadows: <Shadow>[
                        Shadow(blurRadius: 8, color: Colors.black54),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Trust: $trustScore',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                const Icon(Icons.favorite_border, size: 30),
                const SizedBox(height: 6),
                Text(
                  _formatCount(likeCount),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }
}

class HeartBurstData {
  const HeartBurstData({required this.id, required this.position});

  final int id;
  final Offset position;
}

class HeartBurst extends StatefulWidget {
  const HeartBurst({super.key, required this.position});

  final Offset position;

  @override
  State<HeartBurst> createState() => _HeartBurstState();
}

class _HeartBurstState extends State<HeartBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..forward();

    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ).drive(Tween<double>(begin: 0.2, end: 1.35));

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.85, curve: Curves.easeOut),
    ).drive(Tween<double>(begin: 1, end: 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Stack(
          children: <Widget>[
            Positioned(
              left: widget.position.dx - 34,
              top: widget.position.dy - 34,
              child: Opacity(
                opacity: _opacity.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: const Icon(
                    Icons.favorite,
                    color: Color(0xFFFF2D55),
                    size: 68,
                    shadows: <Shadow>[
                      Shadow(color: Colors.black45, blurRadius: 10),
                    ],
                  ),
                ),
              ),
            ),
            ...List<Widget>.generate(6, (int i) {
              final double angle = (math.pi * 2 / 6) * i;
              final double distance = 20 + 22 * _controller.value;
              final Offset offset = Offset(
                math.cos(angle) * distance,
                math.sin(angle) * distance,
              );

              return Positioned(
                left: widget.position.dx + offset.dx - 4,
                top: widget.position.dy + offset.dy - 4,
                child: Opacity(
                  opacity: (1 - _controller.value).clamp(0.0, 1.0),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF5E7E),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}
