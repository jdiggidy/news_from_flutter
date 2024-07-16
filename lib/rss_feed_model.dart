import 'package:rss_dart/dart_rss.dart';

class RssFeedModel {
  final String name;
  final String url;
  int postCount;
  List<RssItem>? items;

  RssFeedModel({
    required this.name,
    required this.url,
    this.postCount = 0,
    this.items,
  });

}

class RssPost {
  final String title;
  final String link;
  final String description;

  RssPost({
    required this.title,
    required this.link,
    required this.description
  });
}
