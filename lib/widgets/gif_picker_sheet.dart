import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/theme/app_colors.dart';
import '../services/local/local_storage_service.dart';

const String _giphyApiKey = 'CoNhilLoOuTHk4KjZCBxC4kOVGTW7v5F';

class GifPickerSheet extends StatefulWidget {
  final Function(String gifUrl) onGifSelected;

  const GifPickerSheet({super.key, required this.onGifSelected});

  @override
  State<GifPickerSheet> createState() => _GifPickerSheetState();
}

class _GifPickerSheetState extends State<GifPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<String> _trendingGifs = [];
  List<String> _searchResults = [];
  List<String> _savedGifs = [];

  bool _isLoadingTrending = false;
  bool _isSearching = false;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSaved(); // ✅ حمّل المحفوظات بعد التهيئة
    _loadTrending();
  }

  Future<void> _loadSaved() async {
    await LocalStorageService.instance.init();
    if (mounted) {
      setState(() {
        _savedGifs = LocalStorageService.instance.getSavedGifs();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
  setState(() => _isLoadingTrending = true);
  try {
    final res = await http.get(Uri.parse(
        'https://api.giphy.com/v1/gifs/trending?api_key=$_giphyApiKey&limit=30&rating=g'));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final List gifs = data['data'];
      if (mounted) {
        setState(() {
          _trendingGifs = gifs
              .map<String>((g) => g['images']['fixed_height_small']['url'] as String? ?? '')
              .where((url) => url.isNotEmpty)
              .toList();
        });
      }
    }
  } catch (_) {}
  if (mounted) setState(() => _isLoadingTrending = false);
}

Future<void> _search(String query) async {
  if (query.trim().isEmpty) return;
  if (query == _lastQuery) return;
  _lastQuery = query;
  setState(() => _isSearching = true);
  try {
    final res = await http.get(Uri.parse(
        'https://api.giphy.com/v1/gifs/search?api_key=$_giphyApiKey&q=${Uri.encodeComponent(query)}&limit=30&rating=g'));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final List gifs = data['data'];
      if (mounted) {
        setState(() {
          _searchResults = gifs
              .map<String>((g) => g['images']['fixed_height_small']['url'] as String? ?? '')
              .where((url) => url.isNotEmpty)
              .toList();
        });
      }
    }
  } catch (_) {}
  if (mounted) setState(() => _isSearching = false);
}

  void _onGifTap(String url) {
    widget.onGifSelected(url);
    Navigator.pop(context);
  }

  Future<void> _toggleSave(String url) async {
    await LocalStorageService.instance.init();
    setState(() {
      if (_savedGifs.contains(url)) {
        _savedGifs.remove(url);
      } else {
        _savedGifs.insert(0, url); // الأحدث أولاً
      }
    });
    await LocalStorageService.instance.saveGifs(_savedGifs);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: const [
                Icon(Icons.gif, size: 36, color: AppColors.primary),
                SizedBox(width: 8),
                Text(
                  'GIF & ملصقات',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'ابحث عن GIF...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                   ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _lastQuery = '';
                          });
                          _tabController.animateTo(0);
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark? AppColors.darkCard : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onSubmitted: (q) {
                if (q.trim().isNotEmpty) {
                  _tabController.animateTo(1);
                  _search(q);
                }
              },
              onChanged: (q) {
                setState(() {});
                if (q.trim().isNotEmpty) {
                  _tabController.animateTo(1);
                  _search(q);
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: '🔥 الأبرز'),
              Tab(text: '🔍 نتائج'),
              Tab(text: '⭐ محفوظة'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGifGrid(
                  gifs: _trendingGifs,
                  isLoading: _isLoadingTrending,
                  emptyMessage: 'لا يوجد GIFs',
                ),
                _buildGifGrid(
                  gifs: _searchResults,
                  isLoading: _isSearching,
                  emptyMessage: _lastQuery.isEmpty
                     ? 'ابحث عن GIF أعلاه'
                      : 'لا توجد نتائج لـ "$_lastQuery"',
                ),
                _buildGifGrid(
                  gifs: _savedGifs,
                  isLoading: false,
                  emptyMessage: 'لا توجد GIFs محفوظة\nاضغط مطولاً على أي GIF لحفظه',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Powered by GIPHY',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGifGrid({
    required List<String> gifs,
    required bool isLoading,
    required String emptyMessage,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (gifs.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 1,
      ),
      itemCount: gifs.length,
      itemBuilder: (context, index) {
        final url = gifs[index];
        final isSaved = _savedGifs.contains(url);

        return GestureDetector(
          onTap: () => _onGifTap(url),
          onLongPress: () async {
            await _toggleSave(url);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    isSaved? 'تم إزالة GIF من المحفوظات' : 'تم حفظ GIF ⭐'),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.grey.shade200,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
              if (isSaved)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.star, size: 14, color: Colors.amber),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}