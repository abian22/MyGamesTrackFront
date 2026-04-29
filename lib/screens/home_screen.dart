import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import '../widgets/game_card.dart';
import '../widgets/switch_app_bar.dart';

class HomeScreen extends StatefulWidget {
  final String uid;
  const HomeScreen({super.key, required this.uid});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Set<String> _favorites = {};
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';

  // Paginación
  static const int _pageSize = 20;
  final List<DocumentSnapshot> _docs = [];
  final List<DocumentSnapshot> _searchResults = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isSearchLoading = false;
  String? _loadError;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFavorites();
      _fetchGames();
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (_searchQuery.isNotEmpty) return;
        _fetchGames();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .get();
    final data = doc.data();
    if (data != null && data['favorites'] != null && mounted) {
      setState(() => _favorites = Set<String>.from(data['favorites']));
    }
  }

  Future<void> _fetchGames() async {
    if (_isLoading || !_hasMore) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    Query query = FirebaseFirestore.instance
        .collection('games')
        .orderBy(FieldPath.documentId)
        .limit(_pageSize);

    if (_lastDoc != null) {
      query = query.startAfterDocument(_lastDoc!);
    }

    try {
      final snapshot = await query.get();

      if (!mounted) return;

      final newDocs = snapshot.docs;
      setState(() {
        _isLoading = false;
        if (newDocs.length < _pageSize) _hasMore = false;
        if (newDocs.isNotEmpty) _lastDoc = newDocs.last;
        _docs.addAll(newDocs);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasMore = false;
        _loadError = 'No se pudieron cargar los juegos';
      });
    }
  }

  Future<void> _searchGamesRemote(String rawQuery) async {
    final query = rawQuery.toLowerCase().trim();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _searchResults.clear();
        _isSearchLoading = false;
      });
      return;
    }

    setState(() => _isSearchLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('games')
          .orderBy('tituloLower')
          .where('tituloLower', isGreaterThanOrEqualTo: query)
          .where('tituloLower', isLessThan: '$query\uf8ff')
          .limit(40)
          .get();

      if (!mounted || _searchQuery.toLowerCase().trim() != query) return;
      setState(() {
        _searchResults
          ..clear()
          ..addAll(snapshot.docs);
      });
    } catch (e) {
      if (mounted && _searchQuery.toLowerCase().trim() == query) {
        setState(() {
          _loadError = 'Error al buscar juegos';
        });
      }
    } finally {
      if (mounted && _searchQuery.toLowerCase().trim() == query) {
        setState(() => _isSearchLoading = false);
      }
    }
  }

  Future<void> _toggleFavorite(String gameId) async {
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(widget.uid);
    setState(() {
      _favorites.contains(gameId)
          ? _favorites.remove(gameId)
          : _favorites.add(gameId);
    });
    await userRef.update({'favorites': _favorites.toList()});
  }

  List<DocumentSnapshot> get _filteredDocs {
    final base = _searchQuery.isEmpty
        ? List<DocumentSnapshot>.from(_docs)
        : List<DocumentSnapshot>.from(_searchResults);

    base.sort((a, b) {
      final gameA = a.data() as Map<String, dynamic>;
      final gameB = b.data() as Map<String, dynamic>;
      final tituloA = (gameA['titulo'] ?? '').toString().toLowerCase().trim();
      final tituloB = (gameB['titulo'] ?? '').toString().toLowerCase().trim();

      if (tituloA.isEmpty && tituloB.isNotEmpty) return 1;
      if (tituloA.isNotEmpty && tituloB.isEmpty) return -1;
      return tituloA.compareTo(tituloB);
    });
    return base;
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final next = value;
    setState(() => _searchQuery = next);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _searchGamesRemote(next);
    });
    if (next.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearchLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredDocs;
    final searching = _searchQuery.isNotEmpty;

    return Scaffold(
      backgroundColor: kBgDark,
      appBar: const SwitchAppBar(title: 'GameTracker'),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar juego...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: Colors.white38),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white38),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: kCardDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Grid
          Expanded(
            child: filtered.isEmpty && !_isLoading && !_isSearchLoading
                ? Center(
                    child: Text(
                      _loadError ?? 'No se encontraron juegos',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  )
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: filtered.length +
                        ((!searching && _hasMore) || (searching && _isSearchLoading) ? 1 : 0),
                    itemBuilder: (context, i) {
                      // Loader al final
                      if (i == filtered.length) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: kSwitchRed));
                      }
                      final doc = filtered[i];
                      final game = doc.data() as Map<String, dynamic>;
                      return GameCard(
                        gameId: doc.id,
                        game: game,
                        isFavorite: _favorites.contains(doc.id),
                        onToggleFavorite: () => _toggleFavorite(doc.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}