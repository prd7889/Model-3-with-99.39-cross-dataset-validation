import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'model_classifier.dart';

void main() => runApp(const OctClassifierApp());

class OctClassifierApp extends StatefulWidget {
  const OctClassifierApp({super.key});

  @override
  State<OctClassifierApp> createState() => _OctClassifierAppState();
}

class _OctClassifierAppState extends State<OctClassifierApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme(Brightness brightness) {
    setState(() {
      _themeMode = brightness == Brightness.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OCT Sort',
      themeMode: _themeMode,
      theme: _appTheme(Brightness.light),
      darkTheme: _appTheme(Brightness.dark),
      home: ClassifierScreen(onToggleTheme: _toggleTheme),
    );
  }
}

ThemeData _appTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors = ColorScheme(
    brightness: brightness,
    primary: dark ? const Color(0xFFB7D8CB) : const Color(0xFF506D64),
    onPrimary: dark ? const Color(0xFF19372F) : const Color(0xFFF8FFFC),
    primaryContainer: dark ? const Color(0xFF2D403A) : const Color(0xFFDDEBE5),
    onPrimaryContainer: dark
        ? const Color(0xFFDDF3E9)
        : const Color(0xFF263C35),
    secondary: dark ? const Color(0xFFD8B9C7) : const Color(0xFF876777),
    onSecondary: dark ? const Color(0xFF442A36) : const Color(0xFFFFF8FA),
    secondaryContainer: dark
        ? const Color(0xFF4C3942)
        : const Color(0xFFF2DFE7),
    onSecondaryContainer: dark
        ? const Color(0xFFF4DCE6)
        : const Color(0xFF4B3440),
    tertiary: dark ? const Color(0xFFD9CFA6) : const Color(0xFF756B45),
    onTertiary: dark ? const Color(0xFF3B351D) : const Color(0xFFFFFCF1),
    tertiaryContainer: dark ? const Color(0xFF45412E) : const Color(0xFFF1EACD),
    onTertiaryContainer: dark
        ? const Color(0xFFF4ECCB)
        : const Color(0xFF3E3923),
    error: dark ? const Color(0xFFFFB4AB) : const Color(0xFF9A514D),
    onError: dark ? const Color(0xFF690005) : Colors.white,
    errorContainer: dark ? const Color(0xFF56302E) : const Color(0xFFF7DEDC),
    onErrorContainer: dark ? const Color(0xFFFFDAD6) : const Color(0xFF552522),
    surface: dark ? const Color(0xFF202422) : const Color(0xFFFFFCF8),
    onSurface: dark ? const Color(0xFFE4E9E5) : const Color(0xFF29312E),
    surfaceContainerHighest: dark
        ? const Color(0xFF303633)
        : const Color(0xFFECEFEB),
    onSurfaceVariant: dark ? const Color(0xFFBCC6C0) : const Color(0xFF5E6964),
    outline: dark ? const Color(0xFF68736E) : const Color(0xFFA8B2AC),
    outlineVariant: dark ? const Color(0xFF3E4743) : const Color(0xFFDCE2DE),
    shadow: Colors.transparent,
    scrim: dark ? Colors.black : const Color(0xFF29312E),
    inverseSurface: dark ? const Color(0xFFE4E9E5) : const Color(0xFF303633),
    onInverseSurface: dark ? const Color(0xFF29312E) : const Color(0xFFF1F5F2),
    inversePrimary: dark ? const Color(0xFF506D64) : const Color(0xFFB7D8CB),
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colors,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF171A19)
        : const Color(0xFFF7F5F1),
  );
  final border = BorderSide(color: colors.outlineVariant);
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      color: colors.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: border,
      ),
    ),
    dividerColor: colors.outlineVariant,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: border,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        elevation: const WidgetStatePropertyAll(0),
        side: WidgetStatePropertyAll(border),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: colors.inverseSurface,
      contentTextStyle: TextStyle(color: colors.onInverseSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

class SelectedImage {
  SelectedImage(this.file);

  final XFile file;
  Prediction? prediction;
  String? error;
}

class ClassifierScreen extends StatefulWidget {
  const ClassifierScreen({super.key, required this.onToggleTheme});

  final ValueChanged<Brightness> onToggleTheme;

  @override
  State<ClassifierScreen> createState() => _ClassifierScreenState();
}

class _ClassifierScreenState extends State<ClassifierScreen> {
  final _picker = ImagePicker();
  final _classifier = ModelClassifier();
  final List<SelectedImage> _images = [];
  bool _modelReady = false;
  bool _isClassifying = false;
  String? _modelError;
  int _completed = 0;
  int _viewIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      await _classifier.load();
      if (mounted) setState(() => _modelReady = true);
    } catch (error) {
      if (mounted) setState(() => _modelError = error.toString());
    }
  }

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 100);
      if (!mounted || picked.isEmpty) return;
      final existing = _images.map((item) => item.file.path).toSet();
      setState(() {
        for (final file in picked) {
          if (existing.add(file.path)) _images.add(SelectedImage(file));
        }
      });
    } catch (error) {
      if (mounted) _showMessage('Could not open gallery: $error');
    }
  }

  Future<void> _classifyAll() async {
    if (!_modelReady || _images.isEmpty || _isClassifying) return;
    setState(() {
      _isClassifying = true;
      _completed = 0;
      for (final item in _images) {
        item.prediction = null;
        item.error = null;
      }
    });
    for (final item in _images) {
      try {
        item.prediction = await _classifier.classify(item.file.path);
      } catch (error) {
        item.error = error.toString();
      }
      if (!mounted) return;
      setState(() => _completed++);
      await Future<void>.delayed(Duration.zero);
    }
    if (mounted) {
      setState(() => _isClassifying = false);
      _showMessage('Classification complete');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _classifier.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classified = _images.where((item) => item.prediction != null).length;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              children: [
                _Header(
                  imageCount: _images.length,
                  classifiedCount: classified,
                  onAdd: _isClassifying ? null : _pickImages,
                  onToggleTheme: () =>
                      widget.onToggleTheme(Theme.of(context).brightness),
                ),
                if (_modelError != null)
                  _ErrorBanner(message: 'Model failed to load: $_modelError'),
                if (_isClassifying)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: LinearProgressIndicator(
                      value: _images.isEmpty ? 0 : _completed / _images.length,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                if (_images.isNotEmpty) _buildToolbar(),
                Expanded(
                  child: _images.isEmpty
                      ? _EmptyState(onAdd: _pickImages)
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: _viewIndex == 0
                              ? _ItemView(
                                  key: const ValueKey('items'),
                                  items: _images,
                                  locked: _isClassifying,
                                  onRemove: (item) =>
                                      setState(() => _images.remove(item)),
                                )
                              : _FolderView(
                                  key: const ValueKey('folders'),
                                  items: _images,
                                  labels: _classifier.labels,
                                ),
                        ),
                ),
                if (_images.isNotEmpty) _buildBottomAction(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.grid_view_rounded),
                label: Text('Items'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.folder_copy_outlined),
                label: Text('Folders'),
              ),
            ],
            selected: {_viewIndex},
            onSelectionChanged: (selection) =>
                setState(() => _viewIndex = selection.first),
          ),
          const Spacer(),
          if (!_isClassifying)
            IconButton(
              tooltip: 'Clear all',
              onPressed: () => setState(() => _images.clear()),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    final enabled = _modelReady && !_isClassifying;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: enabled ? _classifyAll : null,
              icon: _isClassifying
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(
                _isClassifying
                    ? 'Classifying $_completed of ${_images.length}'
                    : _modelReady
                    ? 'Classify ${_images.length} image${_images.length == 1 ? '' : 's'}'
                    : 'Loading model…',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.imageCount,
    required this.classifiedCount,
    required this.onAdd,
    required this.onToggleTheme,
  });

  final int imageCount;
  final int classifiedCount;
  final VoidCallback? onAdd;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.visibility_outlined, color: colors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OCT SORT',
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  imageCount == 0
                      ? 'Image classifier'
                      : '$imageCount selected  •  $classifiedCount classified',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isDark ? 'Use light theme' : 'Use dark theme',
            onPressed: onToggleTheme,
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
          ),
          const SizedBox(width: 2),
          FilledButton.tonalIcon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  size: 38,
                  color: colors.onSecondaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Choose images to begin',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Select one or many images from your gallery.\nEverything stays on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 22),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Open gallery'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemView extends StatelessWidget {
  const _ItemView({
    super.key,
    required this.items,
    required this.locked,
    required this.onRemove,
  });

  final List<SelectedImage> items;
  final bool locked;
  final ValueChanged<SelectedImage> onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960
            ? 4
            : constraints.maxWidth >= 680
            ? 3
            : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _ImageCard(
            item: items[index],
            onRemove: locked ? null : () => onRemove(items[index]),
          ),
        );
      },
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({required this.item, this.onRemove});

  final SelectedImage item;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final prediction = item.prediction;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(item.file.path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => ColoredBox(
                    color: colors.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
                Positioned(
                  top: 7,
                  right: 7,
                  child: IconButton.filledTonal(
                    visualDensity: VisualDensity.compact,
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 17),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.basename(item.file.path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 7),
                if (prediction != null)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          prediction.label,
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '${(prediction.confidence * 100).toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  )
                else if (item.error != null)
                  Text(
                    'Could not classify',
                    style: TextStyle(
                      color: colors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Text(
                    'Ready to classify',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderView extends StatelessWidget {
  const _FolderView({
    super.key,
    required this.items,
    this.labels = classLabels,
  });

  final List<SelectedImage> items;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final groups = <int, List<SelectedImage>>{
      for (var i = 0; i < labels.length; i++) i: [],
    };
    for (final item in items) {
      final prediction = item.prediction;
      if (prediction != null && prediction.classIndex < labels.length) {
        groups[prediction.classIndex]?.add(item);
      }
    }
    if (!groups.values.any((group) => group.isNotEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'Classify the selected images to create category folders.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: labels.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final group = groups[index]!;
        final tint = index.isEven
            ? colors.secondaryContainer
            : colors.tertiaryContainer;
        final onTint = index.isEven
            ? colors.onSecondaryContainer
            : colors.onTertiaryContainer;
        return Card(
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: group.isEmpty ? colors.surfaceContainerHighest : tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.folder_outlined,
                color: group.isEmpty ? colors.onSurfaceVariant : onTint,
              ),
            ),
            title: Text(
              labels[index],
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${group.length} image${group.length == 1 ? '' : 's'}',
            ),
            children: [
              if (group.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    'No images in this category yet.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                )
              else
                SizedBox(
                  height: 116,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: group.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 9),
                    itemBuilder: (context, i) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.file(
                          File(group[i].file.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.error.withValues(alpha: 0.35)),
      ),
      child: Text(message, style: TextStyle(color: colors.onErrorContainer)),
    );
  }
}
