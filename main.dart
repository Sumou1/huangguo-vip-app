import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

const List<String> _siteBases = [
  'https://huangguoai.com',
  'https://ctb09.ir95e08v.cc',
];

void main() {
  runApp(const HuangguoVIPApp());
}

class HuangguoVIPApp extends StatelessWidget {
  const HuangguoVIPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '黄果短剧 VIP版',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Map<String, dynamic>> _dramas = [];
  bool _loading = true;
  int _currentPage = 1;
  final int _totalPages = 144;
  String _filterStatus = 'all';
  String _filterSort = 'hot';
  bool _isVIP = true;

  final List<String> _apiBases = _siteBases;

  @override
  void initState() {
    super.initState();
    _loadVIPStatus();
    _loadDramas();
  }

  Future<void> _loadVIPStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isVIP = prefs.getBool('isVIP') ?? true;
    });
  }

  Future<void> _loadDramas() async {
    setState(() => _loading = true);

    for (final apiBase in _apiBases) {
      try {
        final params = <String, String>{
          'page': _currentPage.toString(),
          if (_filterSort == 'hot') 'sort': 'hot',
          if (_filterSort == 'new') 'sort': 'new',
          if (_filterStatus == 'completed') 'is_finished': '1',
          if (_filterStatus == 'unfinished') 'is_finished': '0',
        };

        final uri = Uri.parse('$apiBase/api/videos').replace(queryParameters: params);
        final response = await http.get(
          uri,
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == 1 && data['data'] != null) {
            final items = data['data']['items'] as List<dynamic>?;
            if (items != null) {
              setState(() {
                _dramas.clear();
                for (final item in items) {
                  _dramas.add({
                    'id': item['id'],
                    'title': item['title'] ?? '',
                    'cover': item['cover'] ?? '',
                    'score': (item['score'] ?? 0).toDouble(),
                    'episodes': item['episode_count'] ?? item['total_episodes'] ?? 1,
                    'isFinished': item['is_finished'] == true || item['is_finished'] == 1,
                    'tags': item['tags'] ?? [],
                    'desc': item['description'] ?? '',
                  });
                }
                _loading = false;
              });
              return;
            }
          }
        }
      } catch (e) {
        print('API error: $e');
        continue;
      }
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('黄果短剧'),
            if (_isVIP)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'VIP',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HistoryPage()),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 3 / 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              padding: const EdgeInsets.all(8),
              itemCount: _dramas.length + (_currentPage < _totalPages ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _dramas.length) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _currentPage++;
                        });
                        _loadDramas();
                      },
                      child: const Text('加载更多'),
                    ),
                  );
                }
                final drama = _dramas[index];
                return DramaCard(
                  drama: drama,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailPage(
                        dramaId: drama['id'],
                        episodeCount: int.tryParse('${drama['episodes']}'),
                        isFinished: drama['isFinished'] as bool?,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('筛选条件'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('状态'),
            Row(
              children: [
                FilterChip(
                  label: const Text('全部'),
                  selected: _filterStatus == 'all',
                  onSelected: (selected) {
                    setState(() => _filterStatus = 'all');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('已完结'),
                  selected: _filterStatus == 'completed',
                  onSelected: (selected) {
                    setState(() => _filterStatus = 'completed');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('连载中'),
                  selected: _filterStatus == 'unfinished',
                  onSelected: (selected) {
                    setState(() => _filterStatus = 'unfinished');
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('排序'),
            Row(
              children: [
                FilterChip(
                  label: const Text('热门'),
                  selected: _filterSort == 'hot',
                  onSelected: (selected) {
                    setState(() => _filterSort = 'hot');
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('最新'),
                  selected: _filterSort == 'new',
                  onSelected: (selected) {
                    setState(() => _filterSort = 'new');
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _currentPage = 1);
              _loadDramas();
              Navigator.pop(context);
            },
            child: const Text('应用'),
          ),
        ],
      ),
    );
  }
}

class DramaCard extends StatelessWidget {
  final Map<String, dynamic> drama;
  final VoidCallback onTap;

  const DramaCard({super.key, required this.drama, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Image.network(
                drama['cover'],
                fit: BoxFit.cover,
                headers: const {
                  'Referer': 'https://huangguoai.com/',
                  'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
                },
                errorBuilder: (context, error, stackTrace) {
                  return Image.network(
                    'https://huangguoai.com/static/web/images/cover-placeholder.png?v=20261121008',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: const Color(0xFF303030),
                      child: const Center(
                        child: Icon(Icons.movie_outlined, color: Colors.white70, size: 36),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drama['title'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          drama['score'].toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10, color: Colors.black),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        drama['isFinished'] ? '全${drama['episodes']}集' : '更新至${drama['episodes']}集',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailPage extends StatefulWidget {
  final int dramaId;
  final int? episodeCount;
  final bool? isFinished;

  const DetailPage({
    super.key,
    required this.dramaId,
    this.episodeCount,
    this.isFinished,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  Map<String, dynamic>? _drama;
  List<int> _episodes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loading = true);

    for (final siteBase in _siteBases) {
      try {
        final response = await http.get(
          Uri.parse('$siteBase/video/${widget.dramaId}/'),
          headers: {
            'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
            'Referer': '$siteBase/',
          },
        ).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) continue;

        final match = RegExp(r'<script[^>]*id="videoInitialData"[^>]*>(.*?)</script>')
            .firstMatch(response.body);
        if (match == null) continue;

        final data = json.decode(match.group(1)!) as Map<String, dynamic>;
        final tracking = data['tracking'] as Map<String, dynamic>?;
        final rawTrackingEpisodes = data['trackingEpisodes'];
        final trackingEpisodes = rawTrackingEpisodes is Map
            ? Map<String, dynamic>.from(rawTrackingEpisodes)
            : <String, dynamic>{};
        final rawSources = data['epPlaySrcs'];
        final epPlaySrcs = rawSources is Map
            ? Map<String, dynamic>.from(rawSources)
            : <String, dynamic>{};
        final totalEp = int.tryParse(
              '${tracking?['total_episode'] ?? data['total_episode'] ?? widget.episodeCount ?? trackingEpisodes.length}',
            ) ??
            widget.episodeCount ??
            trackingEpisodes.length;
        final sourceEpisodes = epPlaySrcs.keys
            .map((key) => int.tryParse(key.toString()))
            .whereType<int>()
            .toSet();
        final episodesFromTracking = trackingEpisodes.keys
            .map((key) => int.tryParse(key.toString()))
            .whereType<int>()
            .toSet();
        final episodes = (sourceEpisodes.isNotEmpty
                ? sourceEpisodes
                : episodesFromTracking)
            .toList()
          ..sort();
        if (episodes.isEmpty && totalEp > 0) {
          episodes.addAll(
            List<int>.generate(totalEp.clamp(0, 500).toInt(), (i) => i + 1),
          );
        }

        if (!mounted) return;
        setState(() {
          _drama = {
            'id': widget.dramaId,
            'siteBase': siteBase,
            'title': data['title'] ?? '',
            'cover': data['posterSrc'] ?? data['coverSrc'] ?? '',
            'desc': data['description'] ?? '',
            'tags': data['tags'] ?? [],
            'totalEpisodes': totalEp,
            'availableEpisodes': episodes.length,
            'isFinished': widget.isFinished ??
                (data['is_finished'] == true || data['is_finished'] == 1),
            'epPlaySrcs': epPlaySrcs,
            'score': data['score'] ?? 0,
          };
          _episodes = episodes;
          _loading = false;
        });
        return;
      } catch (e) {
        debugPrint('Detail load failed for $siteBase: $e');
      }
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_drama?['title'] ?? '加载中...'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _drama == null
              ? const Center(child: Text('加载失败'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.network(
                        _drama!['cover'],
                        headers: const {
                          'Referer': 'https://huangguoai.com/',
                          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
                        },
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _drama!['title'],
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  _drama!['isFinished'] ? '已完结' : '连载中',
                                  style: const TextStyle(color: Colors.amber),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  _drama!['isFinished']
                                      ? '全${_drama!['totalEpisodes']}集'
                                      : '更新至${_drama!['availableEpisodes']}集',
                                ),
                                const SizedBox(width: 16),
                                Text('${_drama!['score']}分'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: (_drama!['tags'] as List<dynamic>)
                                  .map((tag) => Chip(
                                        label: Text(tag.toString()),
                                        backgroundColor: Colors.amber.withOpacity(0.2),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                            Text(_drama!['desc']),
                            const SizedBox(height: 24),
                            const Text(
                              '剧集列表',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _episodes
                                  .map((ep) => ElevatedButton(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PlayerPage(
                                              dramaId: widget.dramaId,
                                              episode: ep,
                                              episodes: _episodes,
                                              epPlaySrcs: _drama!['epPlaySrcs'],
                                              dramaTitle: _drama!['title'],
                                            ),
                                          ),
                                        ),
                                        child: Text('第$ep集'),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class PlayerPage extends StatefulWidget {
  final int dramaId;
  final int episode;
  final List<int> episodes;
  final Map<String, dynamic> epPlaySrcs;
  final String dramaTitle;

  const PlayerPage({
    super.key,
    required this.dramaId,
    required this.episode,
    required this.episodes,
    required this.epPlaySrcs,
    required this.dramaTitle,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  VideoPlayerController? _controller;
  WebViewController? _webViewController;
  bool _loading = true;
  String? _errorMessage;
  double _playbackSpeed = 1;
  Timer? _timer;

  int get _episodeIndex => widget.episodes.indexOf(widget.episode);
  bool get _hasPreviousEpisode => _episodeIndex > 0;
  bool get _hasNextEpisode =>
      _episodeIndex >= 0 && _episodeIndex < widget.episodes.length - 1;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_saveProgress());
    });
  }

  Uri? _videoUri() {
    final source = widget.epPlaySrcs[widget.episode.toString()];
    String? sourceUrl;
    if (source is String) {
      sourceUrl = source;
    } else if (source is Map) {
      sourceUrl = (source['url'] ?? source['src'] ?? source['file'])?.toString();
    } else if (source is List) {
      sourceUrl = source
          .whereType<String>()
          .cast<String?>()
          .firstWhere(
            (value) => value != null && value.trim().isNotEmpty,
            orElse: () => null,
          );
    }
    if (sourceUrl == null || sourceUrl.trim().isEmpty) return null;
    final parsed = Uri.tryParse(sourceUrl.trim().replaceAll('&amp;', '&'));
    if (parsed == null) return null;
    final uri = parsed.hasScheme
        ? parsed
        : Uri.parse(_siteBases.first).resolveUri(parsed);
    if ((uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  Future<void> _initializePlayer() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _webViewController = null;
    });

    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();

    final uri = _videoUri();
    if (uri == null) {
      await _enableWebPlaybackFallback();
      return;
    }

    final controller = VideoPlayerController.networkUrl(
      uri,
      httpHeaders: const {
        'User-Agent':
            'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
        'Referer': 'https://huangguoai.com/',
      },
    );
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted || !identical(_controller, controller)) {
        await controller.dispose();
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final savedSeconds = prefs.getDouble(
        'progress_${widget.dramaId}_${widget.episode}',
      );
      if (savedSeconds != null && savedSeconds > 0) {
        final resumeAt = Duration(seconds: savedSeconds.floor());
        final duration = controller.value.duration;
        await controller.seekTo(
          duration > Duration.zero && resumeAt > duration ? duration : resumeAt,
        );
      }
      await controller.play();
      if (mounted && identical(_controller, controller)) {
        setState(() => _loading = false);
      }
    } catch (error) {
      debugPrint('Player initialization failed: $error');
      await controller.dispose();
      if (mounted && identical(_controller, controller)) {
        _controller = null;
        await _enableWebPlaybackFallback();
      }
    }
  }

  Future<void> _enableWebPlaybackFallback() async {
    final siteBase = _siteBases.first;
    final episodePath = widget.episode <= 1
        ? '/video/${widget.dramaId}/'
        : '/video/${widget.dramaId}/ep-${widget.episode}/';
    try {
      final webController = WebViewController.fromPlatformCreationParams(
        WebKitWebViewControllerCreationParams(
          allowsInlineMediaPlayback: true,
          mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
        ),
      );
      await webController.setJavaScriptMode(JavaScriptMode.unrestricted);
      await webController.setBackgroundColor(Colors.black);
      await webController.setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) async {
            try {
              await webController.runJavaScript('''
                  (() => {
                    const style = document.createElement('style');
                    style.textContent = `
                      html, body { margin: 0 !important; height: 100% !important; background: #000 !important; overflow: hidden !important; }
                      body * { visibility: hidden !important; }
                      .hg-web-play { visibility: visible !important; position: fixed !important; inset: 0 !important; z-index: 2147483647 !important; width: 100vw !important; height: 100vh !important; margin: 0 !important; padding: 0 !important; }
                      .hg-web-play * { visibility: visible !important; }
                      .hg-web-play__viewport { width: 100% !important; height: 100% !important; }
                    `;
                    document.head.appendChild(style);
                  })();
                ''');
            } catch (_) {}
          },
          onNavigationRequest: (request) {
            final host = Uri.tryParse(request.url)?.host ?? '';
            return host == 'huangguoai.com' || host == 'ctb09.ir95e08v.cc'
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      );
      await webController.loadRequest(Uri.parse('$siteBase$episodePath'));
      if (!mounted) return;
      setState(() {
        _webViewController = webController;
        _loading = false;
        _errorMessage = null;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_drama_id', widget.dramaId);
      await prefs.setInt('last_episode', widget.episode);
    } catch (error) {
      debugPrint('Web playback fallback failed: $error');
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = '播放页加载失败，请检查网络后重试';
        });
      }
    }
  }

  Future<void> _saveProgress() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final seconds = controller.value.position.inSeconds.toDouble();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(
        'progress_${widget.dramaId}_${widget.episode}',
        seconds,
      );
      await prefs.setInt('last_drama_id', widget.dramaId);
      await prefs.setInt('last_episode', widget.episode);
    } catch (error) {
      debugPrint('Unable to save playback progress: $error');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_saveProgress());
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _seekBy(Duration offset) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final position = controller.value.position + offset;
    final duration = controller.value.duration;
    final target = position < Duration.zero
        ? Duration.zero
        : (duration > Duration.zero && position > duration ? duration : position);
    await controller.seekTo(target);
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
    if (mounted) setState(() {});
  }

  void _openEpisode(int episode) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => PlayerPage(
          dramaId: widget.dramaId,
          episode: episode,
          episodes: widget.episodes,
          epPlaySrcs: widget.epPlaySrcs,
          dramaTitle: widget.dramaTitle,
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.dramaTitle} · 第 ${widget.episode} 集'),
      ),
      body: ColoredBox(
        color: Colors.black,
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: _PlayerError(
                            message: _errorMessage!,
                            onRetry: _initializePlayer,
                          ),
                        )
                      : _webViewController != null
                          ? WebViewWidget(controller: _webViewController!)
                          : Center(child: _buildVideo()),
            ),
            if (!_loading && _errorMessage == null && _webViewController == null)
              _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideo() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return _PlayerError(
        message: '播放器尚未准备好',
        onRetry: _initializePlayer,
      );
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        if (value.hasError) {
          return _PlayerError(
            message: '播放中断，请检查视频地址或网络后重试',
            onRetry: _initializePlayer,
          );
        }
        final ratio = value.aspectRatio;
        return AspectRatio(
          aspectRatio: ratio.isFinite && ratio > 0 ? ratio : 16 / 9,
          child: VideoPlayer(controller),
        );
      },
    );
  }

  Widget _buildControls() {
    final controller = _controller!;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              colors: VideoProgressColors(
                playedColor: Colors.amber,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white24,
              ),
            ),
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, child) => Row(
                children: [
                  Text(
                    '${_formatDuration(value.position)} / ${_formatDuration(value.duration)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '上一集',
                    onPressed: _hasPreviousEpisode
                        ? () => _openEpisode(widget.episodes[_episodeIndex - 1])
                        : null,
                    icon: const Icon(Icons.skip_previous),
                  ),
                  IconButton(
                    tooltip: '下一集',
                    onPressed: _hasNextEpisode
                        ? () => _openEpisode(widget.episodes[_episodeIndex + 1])
                        : null,
                    icon: const Icon(Icons.skip_next),
                  ),
                ],
              ),
            ),
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: controller,
              builder: (context, value, child) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: '后退 10 秒',
                    onPressed: () => _seekBy(const Duration(seconds: -10)),
                    icon: const Icon(Icons.replay_10),
                  ),
                  IconButton.filled(
                    tooltip: value.isPlaying ? '暂停' : '播放',
                    onPressed: _togglePlayback,
                    icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                  ),
                  IconButton(
                    tooltip: '前进 10 秒',
                    onPressed: () => _seekBy(const Duration(seconds: 10)),
                    icon: const Icon(Icons.forward_10),
                  ),
                  PopupMenuButton<double>(
                    tooltip: '播放速度',
                    initialValue: _playbackSpeed,
                    onSelected: (speed) async {
                      await controller.setPlaybackSpeed(speed);
                      if (mounted) setState(() => _playbackSpeed = speed);
                    },
                    itemBuilder: (context) => [
                      for (final speed in [0.75, 1.0, 1.25, 1.5, 2.0])
                        PopupMenuItem(
                          value: speed,
                          child: Text('${speed}×'),
                        ),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('${_playbackSpeed}×'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PlayerError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDramaId = prefs.getInt('last_drama_id');
    final lastEpisode = prefs.getInt('last_episode');

    if (lastDramaId != null && lastEpisode != null) {
      setState(() {
        _history = [
          {
            'dramaId': lastDramaId,
            'episode': lastEpisode,
          }
        ];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('观看历史'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('last_drama_id');
              await prefs.remove('last_episode');
              setState(() => _history.clear());
            },
          ),
        ],
      ),
      body: _history.isEmpty
          ? const Center(child: Text('暂无观看历史'))
          : ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final item = _history[index];
                return ListTile(
                  title: Text('短剧 ID: ${item['dramaId']}'),
                  subtitle: Text('第${item['episode']}集'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailPage(dramaId: item['dramaId']),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
