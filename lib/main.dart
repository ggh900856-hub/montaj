import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_video/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_video/return_code.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MontajApp());
}

class MontajApp extends StatelessWidget {
  const MontajApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'استوديو المونتاج الاحترافي',
      locale: const Locale('ar'),
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0B0C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE7E8EA),
          surface: Color(0xFF16181B),
          onSurface: Color(0xFFF2F3F5),
        ),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const StudioPage(),
    );
  }
}

class StylePreset {
  const StylePreset({
    required this.id,
    required this.label,
    required this.hold,
    required this.contrast,
    required this.saturation,
    required this.letterbox,
  });

  final String id;
  final String label;
  final double hold;
  final double contrast;
  final double saturation;
  final bool letterbox;
}

// قائمة القوالب الاحترافية الموسعة الشاملة لأغلب تخصصات المونتاج
const styles = <StylePreset>[
  StylePreset(id: 'reels', label: 'ريلز سريع', hold: 1.3, contrast: 1.12, saturation: 1.18, letterbox: false),
  StylePreset(id: 'cinematic', label: 'سينمائي كلاسيك', hold: 2.8, contrast: 1.05, saturation: 0.88, letterbox: true),
  StylePreset(id: 'ad', label: 'إعلان تسويقي', hold: 1.6, contrast: 1.16, saturation: 1.12, letterbox: false),
  StylePreset(id: 'vlog', label: 'فلوج يومي', hold: 2.0, contrast: 1.02, saturation: 1.05, letterbox: false),
  StylePreset(id: 'gaming', label: 'ألعاب وحماس', hold: 1.1, contrast: 1.20, saturation: 1.25, letterbox: false),
  StylePreset(id: 'documentary', label: 'وثائقي واقعي', hold: 3.5, contrast: 1.00, saturation: 0.82, letterbox: true),
  StylePreset(id: 'fashion', label: 'أزياء وموضة', hold: 1.5, contrast: 1.10, saturation: 1.10, letterbox: false),
  StylePreset(id: 'travel', label: 'رحلات وسفر', hold: 2.2, contrast: 1.08, saturation: 1.20, letterbox: false),
  StylePreset(id: 'cooking', label: 'طبخ وأكلات', hold: 1.8, contrast: 1.14, saturation: 1.28, letterbox: false),
  StylePreset(id: 'vintage', label: 'كلاسيك قديم (سبعينات)', hold: 2.4, contrast: 0.95, saturation: 0.75, letterbox: false),
  StylePreset(id: 'action', label: 'حركة وسرعة', hold: 0.9, contrast: 1.18, saturation: 1.05, letterbox: false),
  StylePreset(id: 'cyberpunk', label: 'مستقبلي نيون', hold: 1.7, contrast: 1.25, saturation: 1.40, letterbox: false),
  StylePreset(id: 'wedding', label: 'حفلات زفاف', hold: 2.6, contrast: 1.02, saturation: 0.95, letterbox: false),
  StylePreset(id: 'nature', label: 'طبيعة وهدوء', hold: 3.0, contrast: 1.04, saturation: 1.22, letterbox: false),
  StylePreset(id: 'corporate', label: 'شركات رسمي', hold: 2.5, contrast: 1.06, saturation: 0.98, letterbox: false),
  StylePreset(id: 'blackandwhite', label: 'أبيض وأسود فاخر', hold: 2.3, contrast: 1.22, saturation: 0.00, letterbox: true),
];

class Shot {
  Shot({required this.path, required this.isImage, required this.name, required this.duration});
  final String path;
  final bool isImage;
  final String name;
  final double duration;
}

class StudioPage extends StatefulWidget {
  const StudioPage({super.key});

  @override
  State<StudioPage> createState() => _StudioPageState();
}

class _StudioPageState extends State<StudioPage> {
  final _picker = ImagePicker();
  final List<Shot> _shots = [];

  int _style = 0;
  int _aspect = 0;
  int _index = 0;
  bool _playing = false;
  bool _exporting = false;
  String _status = '';
  VideoPlayerController? _video;
  Timer? _timer;
  bool _alive = true;

  static const aspects = [
    ('ريلز تيك توك (9:16)', 720, 1280),
    ('يوتيوب أفقي (16:9)', 1280, 720),
    ('انستقرام مربع (1:1)', 1080, 1080),
  ];

  StylePreset get style => styles[_style];

  @override
  void dispose() {
    _alive = false;
    _timer?.cancel();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _add({required bool images}) async {
    if (_shots.length >= 8) {
      _toast('الحد الأقصى ٨ لقطات فقط');
      return;
    }
    try {
      final picked = images ? await _picker.pickMultiImage() : await _picker.pickMultiVideo();
      if (picked.isEmpty) return;
      
      final room = 8 - _shots.length;
      for (final file in picked.take(room)) {
        final path = file.path;
        final duration = images ? style.hold : await _probe(path);
        if (!mounted) return;
        setState(() {
          _shots.add(Shot(
            path: path,
            isImage: images,
            name: file.name,
            duration: duration < 0.4 ? 2.0 : duration,
          ));
        });
      }
    } catch (_) {
      _toast('تأكد من تفعيل صلاحية الوصول لمعرض الصور');
    }
  }

  Future<double> _probe(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final raw = session.getMediaInformation()?.getDuration();
      final value = double.tryParse(raw ?? '') ?? 0;
      if (value > 0.3) return value;
    } catch (_) {}
    return 3.0;
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _stop() async {
    _timer?.cancel();
    _timer = null;
    final video = _video;
    _video = null;
    await video?.pause();
    await video?.dispose();
    if (_alive && mounted) setState(() => _playing = false);
  }

  Future<void> _play() async {
    if (_shots.isEmpty) return;
    await _stop();
    if (!mounted) return;
    setState(() {
      _playing = true;
      _index = _index.clamp(0, _shots.length - 1);
    });
    await _showCurrent();
  }

  Future<void> _showCurrent() async {
    if (!_playing || _shots.isEmpty) return;
    final shot = _shots[_index];
    final hold = shot.isImage ? style.hold : (shot.duration < style.hold ? shot.duration : style.hold);
    
    if (!shot.isImage) {
      final controller = VideoPlayerController.file(File(shot.path));
      _video = controller;
      try {
        await controller.initialize();
        await controller.setLooping(false);
        await controller.play();
        if (mounted) setState(() {});
      } catch (_) {
        _toast('تعذر معاينة الملف ${shot.name}');
      }
    } else if (mounted) {
      setState(() {});
    }
    
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: (hold * 1000).round()), () async {
      if (!_alive || !_playing) return;
      await _video?.pause();
      await _video?.dispose();
      _video = null;
      if (!_alive) return;
      if (_index >= _shots.length - 1) {
        if (mounted) setState(() => _playing = false);
        return;
      }
      setState(() => _index += 1);
      await _showCurrent();
    });
  }

  Future<void> _export() async {
    if (_shots.isEmpty || _exporting) return;
    setState(() {
      _exporting = true;
      _status = 'جاري دمج ومعالجة وتطبيق فلاتر القالب...';
    });
    await _stop();
    
    try {
      final dir = await getTemporaryDirectory();
      final size = aspects[_aspect];
      final width = size.$2;
      final height = size.$3;
      
      final outPath = '${dir.path}/montaj_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final List<String> args = [];
      
      for (final shot in _shots) {
        final duration = shot.isImage ? style.hold : (shot.duration < style.hold ? shot.duration : style.hold);
        if (shot.isImage) {
          args.addAll(['-loop', '1', '-t', '$duration', '-i', shot.path]);
        } else {
          args.addAll(['-ss', '0', '-t', '$duration', '-i', shot.path]);
        }
      }
      
      String filterComplex = '';
      for (var i = 0; i < _shots.length; i++) {
        filterComplex += '[$i:v]scale=$width:$height:force_original_aspect_ratio=decrease,pad=$width:$height:(ow-iw)/2:(oh-ih)/2,setsar=1';
        filterComplex += ',eq=contrast=${style.contrast}:saturation=${style.saturation}';
        if (style.letterbox) {
          filterComplex += ',drawbox=y=0:h=$height/10:color=black:t=fill,drawbox=y=h-h/10:h=$height/10:color=black:t=fill';
        }
        filterComplex += '[v$i];';
      }
      
      for (var i = 0; i < _shots.length; i++) {
        filterComplex += '[v$i]';
      }
      filterComplex += 'concat=n=${_shots.length}:v=1:a=0[outv]';
      
      args.addAll([
        '-filter_complex', filterComplex,
        '-map', '[outv]',
        '-pix_fmt', 'yuv420p',
        '-vsync', '2',
        '-y', outPath
      ]);
      
      final session = await FFmpegKit.executeWithArguments(args);
      final returnCode = await session.getReturnCode();
      
      if (ReturnCode.isSuccess(returnCode)) {
        setState(() => _status = 'اكتمل المونتاج! جاري التصدير للحفظ والمشاركة...');
        await Share.shareXFiles([XFile(outPath)], text: 'فيديو احترافي بواسطة تطبيقي');
      } else {
        _toast('فشلت معالجة الفيديو بـ FFmpeg');
      }
    } catch (_) {
      _toast('حدث خطأ أثناء حفظ الفيديو');
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
          _status = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('استوديو المونتاج الاحترافي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), 
        centerTitle: true
      ),
      body: _exporting
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center, 
                children: [
                  const CircularProgressIndicator(color: Colors.white), 
                  const SizedBox(height: 16), 
                  Text(_status, style: const TextStyle(color: Colors.grey))
                ]
              )
            )
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Expanded(
                    flex: 4,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16181B), 
                        borderRadius: BorderRadius.circular(12), 
                        border: Border.all(color: Colors.white10)
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Center(
                        child: _shots.isEmpty
                            ? const Text('أضف لقطات للبدء', style: TextStyle(color: Colors.grey))
                            : (_shots[_index].isImage
                                ? Image.file(File(_shots[_index].path), fit: BoxFit.contain)
                                : (_video != null && _video!.value.isInitialized 
                                    ? AspectRatio(aspectRatio: _video!.value.aspectRatio, child: VideoPlayer(_video!)) 
                                    : const CircularProgressIndicator(color: Colors.white))),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F2225)), 
                          icon: const Icon(Icons.image, size: 16), 
                          label: const Text('صور'), 
                          onPressed: () => _add(images: true)
                        )
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F2225)), 
                          icon: const Icon(Icons.movie, size: 16), 
                          label: const Text('فيديو'), 
                          onPressed: () => _add(images: false)
                        )
                      ),
                    ]
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                            children: [
                              const Text('القالب السينمائي:'),
                              DropdownButton<int>(
                                value: _style, 
                                underline: const SizedBox(), 
                                dropdownColor: const Color(0xFF16181B), 
                                items: List.generate(styles.length, (i) => DropdownMenuItem(value: i, child: Text(styles[i].label))), 
                                onChanged: (v) { if (v != null) setState(() => _style = v); }
                              ),
                            ]
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                            children: [
                              const Text('أبعاد الفيديو:'),
                              DropdownButton<int>(
                                value: _aspect, 
                                underline: const SizedBox(), 
                                dropdownColor: const Color(0xFF16181B), 
                                items: List.generate(aspects.length, (i) => DropdownMenuItem(value: i, child: Text(aspects[i].$1))), 
                                onChanged: (v) { if (v != null) setState(() => _aspect = v); }
                              ),
                            ]
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24)), 
                                  onPressed: _shots.isEmpty || _exporting ? null : _play, 
                                  child: Text(_playing ? 'إيقاف المعاينة' : 'تشغيل معاينة')
                                )
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black), 
                                  onPressed: _shots.isEmpty || _exporting ? null : _export, 
                                  child: const Text('تصدير وحفظ', style: TextStyle(fontWeight: FontWeight.bold))
                                )
                              ),
                            ]
                          )
                        ]
                      ),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
