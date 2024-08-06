import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  List<Anime> animes = await Anime.getAnimes();
  MyApp.animes = animes;
  runApp(MyApp());
}

class Anime {
  final String title;
  final String genre;
  final String year;
  final String imageUrl;
  final String url;

  Anime({
    required this.title,
    required this.genre,
    required this.year,
    required this.imageUrl,
    required this.url,
  });

  factory Anime.fromJson(Map<String, dynamic> json) {
    return Anime(
      title: json['titles'][0]['title'],
      genre: json['genres'][0]['name'],
      year: json['year'].toString(),
      imageUrl: json['images']['jpg']['image_url'],
      url: json['url'],
    );
  }

  static Future<List<Anime>> getAnimes() async {
    var url = Uri.https('api.jikan.moe', '/v4/top/anime', {'q': '{http}'});

    var response = await http.get(url);

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body)['data'];
      List<Anime> animes =
          body.map((dynamic item) => Anime.fromJson(item)).toList();
      return animes;
    } else {
      throw Exception('Failed to load animes');
    }
  }
}

class MyApp extends StatelessWidget {
  static List<Anime> animes = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  Set<Anime> _favorites = {};
  String _searchQuery = '';

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleFavorite(Anime anime) {
    setState(() {
      if (_favorites.contains(anime)) {
        _favorites.remove(anime);
      } else {
        _favorites.add(anime);
      }
    });
  }

  void _addAnime(Anime anime) {
    setState(() {
      MyApp.animes.add(anime);
    });
  }

  List<Widget> get _widgetOptions {
    return [
      HomePage(
        animes: MyApp.animes,
        toggleFavorite: _toggleFavorite,
        favorites: _favorites,
        searchQuery: _searchQuery,
        onSearchChanged: (query) {
          setState(() {
            _searchQuery = query;
          });
        },
      ),
      FavoritesPage(
        favorites: _favorites,
        toggleFavorite: _toggleFavorite,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        onTap: _onItemTapped,
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final newAnime = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => AddAnimePage(
                            addAnime: _addAnime,
                          )),
                );
                if (newAnime != null) {
                  _addAnime(newAnime);
                }
              },
              child: Icon(Icons.add),
            )
          : null,
    );
  }
}

class HomePage extends StatelessWidget {
  final List<Anime> animes;
  final Set<Anime> favorites;
  final Function(Anime) toggleFavorite;
  final String searchQuery;
  final Function(String) onSearchChanged;

  HomePage({
    required this.animes,
    required this.favorites,
    required this.toggleFavorite,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filteredAnimes = animes
        .where((anime) =>
            anime.title.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          decoration: InputDecoration(
            hintText: 'Buscar...',
            border: InputBorder.none,
          ),
          onChanged: onSearchChanged,
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView.builder(
          itemCount: filteredAnimes.length,
          itemBuilder: (context, index) {
            final anime = filteredAnimes[index];
            final isFavorite = favorites.contains(anime);
            return GestureDetector(
              onTap: () async {
                final url = anime.url;
                if (await canLaunch(url)) {
                  await launch(url);
                } else {
                  throw 'Could not launch $url';
                }
              },
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                color: Colors.blue[50],
                margin: EdgeInsets.symmetric(vertical: 10),
                child: ListTile(
                  contentPadding: EdgeInsets.all(10.0),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: Image.network(anime.imageUrl,
                        width: 72, height: 100, fit: BoxFit.cover),
                  ),
                  title: Text(anime.title,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${anime.genre} - ${anime.year}'),
                  trailing: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : null,
                    ),
                    onPressed: () {
                      toggleFavorite(anime);
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  final Set<Anime> favorites;
  final Function(Anime) toggleFavorite;

  FavoritesPage({required this.favorites, required this.toggleFavorite});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Favoritos'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView.builder(
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            final anime = favorites.elementAt(index);

            return GestureDetector(
              onTap: () async {
                final url = anime.url;
                if (await canLaunch(url)) {
                  await launch(url);
                } else {
                  throw 'Could not launch $url';
                }
              },
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15.0),
                ),
                color: Colors.blue[50],
                margin: EdgeInsets.symmetric(vertical: 10),
                child: ListTile(
                  contentPadding: EdgeInsets.all(10.0),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: Image.network(anime.imageUrl,
                        width: 72, height: 100, fit: BoxFit.cover),
                  ),
                  title: Text(anime.title,
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${anime.genre} - ${anime.year}'),
                  trailing: IconButton(
                    icon: Icon(
                      Icons.favorite,
                      color: Colors.red,
                    ),
                    onPressed: () {
                      toggleFavorite(anime);
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AddAnimePage extends StatelessWidget {
  final Function(Anime) addAnime;

  AddAnimePage({required this.addAnime});

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _genreController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Adicionar Anime'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Título'),
            ),
            TextField(
              controller: _genreController,
              decoration: InputDecoration(labelText: 'Gênero'),
            ),
            TextField(
              controller: _yearController,
              decoration: InputDecoration(labelText: 'Ano'),
            ),
            TextField(
              controller: _imageUrlController,
              decoration: InputDecoration(labelText: 'URL da Imagem'),
            ),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(labelText: 'URL do Anime'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                final newAnime = Anime(
                  title: _titleController.text,
                  genre: _genreController.text,
                  year: _yearController.text,
                  imageUrl: _imageUrlController.text,
                  url: _urlController.text,
                );
                Navigator.pop(context, newAnime);
              },
              child: Text('Adicionar Anime'),
            ),
          ],
        ),
      ),
    );
  }
}
