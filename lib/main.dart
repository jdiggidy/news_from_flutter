import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:rss_dart/dart_rss.dart';
import 'package:rxdart/rxdart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:news_from_flutter/rss_feed_model.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RSS Reader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<RssFeedModel> _feeds = [];
  final BehaviorSubject<List<RssFeedModel>> _feedsSubject =
      BehaviorSubject<List<RssFeedModel>>.seeded([]);

  Stream<List<RssFeedModel>> get feedsStream => _feedsSubject.stream;

  @override
  void initState() {
    super.initState();
    _loadInitialFeeds();
  }

  @override
  void dispose() {
    _feedsSubject.close();
    super.dispose();
  }

  Future<void> _loadInitialFeeds() async {
    _feeds.addAll([
      RssFeedModel(name: 'Flutter Blog', url: 'https://medium.com/feed/flutter'),
      RssFeedModel(name: 'Dart News', url: 'https://medium.com/feed/@dart'),
    ]);

    await _updateFeeds();
  }

  Future<void> _updateFeeds() async {
    final List<Future<void>> futures = [];

    for (var feed in _feeds) {
      futures.add(_fetchFeed(feed));
    }

    await Future.wait(futures);
    _feedsSubject.add(_feeds);
  }

  Future<void> _fetchFeed(RssFeedModel feed) async {
    try {
      final response = await http.get(Uri.parse(feed.url));
      if (response.statusCode == 200) {
        final parsedFeed = RssFeed.parse(response.body);
        feed.postCount = parsedFeed.items.length;
        feed.items = parsedFeed.items;
      } else {
        if (kDebugMode) {
          print('Failed to load feed: ${feed.name}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading feed: ${feed.name}, $e');
      }
    }
  }

  Future<void> _addFeed(String url) async {
    final newFeed = RssFeedModel(name: 'New Feed', url: url);
    _feeds.add(newFeed);
    await _fetchFeed(newFeed);
    _feedsSubject.add(_feeds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RSS Reader'),
      ),
      body: StreamBuilder<List<RssFeedModel>>(
        stream: feedsStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final feeds = snapshot.data!;
            return ListView.builder(
              itemCount: feeds.length,
              itemBuilder: (context, index) {
                final feed = feeds[index];
                return ListTile(
                  title: Text(feed.name),
                  subtitle: Text('${feed.postCount} posts'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FeedDetailPage(feed: feed),
                      ),
                    );
                  },
                );
              },
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newFeedUrl = await _addFeedDialog(context);
          if (newFeedUrl != null && newFeedUrl.isNotEmpty) {
            await _addFeed(newFeedUrl);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<String?> _addFeedDialog(BuildContext context) async {
    String? newFeedUrl = '';
     await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New RSS Feed'),
        content: TextField(
          decoration: const InputDecoration(labelText: 'Enter RSS feed URL'),
          onChanged: (value) => newFeedUrl = value.trim(),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Add'),
            onPressed: () {
              Navigator.of(context).pop(newFeedUrl);
            },
          ),
        ],
      ),
    );

    return newFeedUrl;
  }
}

class FeedDetailPage extends StatelessWidget {
  final RssFeedModel feed;

  const FeedDetailPage({super.key, required this.feed});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(feed.name),
      ),
      body: feed.items != null
          ? ListView.builder(
              itemCount: feed.items!.length,
              itemBuilder: (context, index) {
                final item = feed.items![index];
                return ListTile(
                  title: Text(item.title ?? ''),
                  subtitle: Text(item.pubDate ?? ''),
                  onTap: () {
                    _launchURL(item.link ?? '');
                  },
                );
              },
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  void _launchURL(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }
}
