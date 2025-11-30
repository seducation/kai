import 'package:flutter/material.dart';

// --- Data Model (The "Base") ---
class NewsItem {
  final String sourceName;
  final String sourceIcon; // Using simple string for mock logic
  final String timeAgo;
  final String? headline;
  final String bodyText;
  final String? imageUrl;
  final String linkUrl; // The URL to navigate to (mocked)

  NewsItem({
    required this.sourceName,
    required this.sourceIcon,
    required this.timeAgo,
    this.headline,
    required this.bodyText,
    this.imageUrl,
    this.linkUrl = "https://example.com/article-123", // Default mock URL
  });
}

// --- Mock Data Service ---
class DataService {
  static List<NewsItem> getNews() {
    return [
      NewsItem(
        sourceName: "Tech Today",
        sourceIcon: "laptop",
        timeAgo: "3 hours ago",
        headline: "The Future of AI in App Development",
        bodyText: "Generative AI is revolutionizing how developers create and build applications. From code generation to automated testing, the possibilities are endless.",
        imageUrl: "https://images.unsplash.com/photo-1678483787713-49d38def9543?auto=format&fit=crop&w=800&q=80", // Placeholder for AI/tech image
        linkUrl: "https://example.com/ai-in-dev",
      ),
      NewsItem(
        sourceName: "Flutter Weekly",
        sourceIcon: "flutter",
        timeAgo: "1 day ago",
        headline: "What to Expect in the Next Flutter Update",
        bodyText: "The Flutter team has been teasing some exciting new features. We break down what you can expect in the upcoming release, including performance improvements and new widgets.",
        imageUrl: "https://images.unsplash.com/photo-1617040619263-44c29b4c0a2a?auto=format&fit=crop&w=800&q=80", // Placeholder for Flutter logo/UI
        linkUrl: "https://example.com/flutter-update-news",
      ),
      NewsItem(
        sourceName: "Design Trends",
        sourceIcon: "palette",
        timeAgo: "5 days ago",
        headline: "The Rise of Glassmorphism in UI Design",
        bodyText: "Glassmorphism is the latest design trend to take the UI world by storm. We explore its origins, best practices, and how to implement it in your own projects.",
        imageUrl: "https://images.unsplash.com/photo-1516233758813-a44d82a13848?auto=format&fit=crop&w=800&q=80", // Placeholder for abstract design/glass
        linkUrl: "https://example.com/glassmorphism-trends",
      ),
    ];
  }
}

class SrvFeatureTabscreen extends StatelessWidget {
  const SrvFeatureTabscreen({super.key});

  @override
  Widget build(BuildContext context) {
    final newsItems = DataService.getNews();

    return Container(
      color: Colors.white,
      child: ListView.separated(
        itemCount: newsItems.length,
        separatorBuilder: (ctx, i) => const Divider(height: 1, color: Color(0xFFE0E0E0)),
        itemBuilder: (context, index) {
          return NewsCard(item: newsItems[index]);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NEWS CARD (with Navigation logic)
// ---------------------------------------------------------------------------

class NewsCard extends StatelessWidget {
  final NewsItem item;

  const NewsCard({super.key, required this.item});

  // Function to handle the navigation when the card is tapped
  void _openDetail(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DetailPage(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the card content in GestureDetector for the tap event
    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                _buildSourceIcon(item.sourceIcon),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.sourceName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
                Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
              ],
            ),
            
            const SizedBox(height: 12),

            // Content Row (Text + Image/Link Preview)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.headline != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            item.headline!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.3,
                              color: Colors.blue,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      Text(
                        item.bodyText,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                          height: 1.4,
                        ),
                        maxLines: item.headline == null ? 4 : 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            item.timeAgo,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          const SizedBox(width: 8),
                          // The "blue link" text
                          Text(
                            item.linkUrl.split('/')[2].replaceAll('www.', ''), // Display domain
                            style: const TextStyle(
                              fontSize: 12, 
                              color: Colors.blueAccent,
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (item.imageUrl != null) ...[
                  const SizedBox(width: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      item.imageUrl!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 100,
                        height: 100,
                        color: Colors.grey[200],
                        child: Icon(Icons.image, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left actions (Reaction/Comments mockup)
                Row(
                  children: [
                    Icon(Icons.favorite_border, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 24),
                    Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey[600]),
                  ],
                ),
                // Right actions (Share/Bookmark)
                Row(
                  children: [
                     Icon(Icons.share_outlined, size: 20, color: Colors.grey[600]),
                     const SizedBox(width: 24),
                     Icon(Icons.bookmark_border, size: 20, color: Colors.grey[600]),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceIcon(String type) {
    IconData icon;
    Color color;
    
    switch (type) {
      case 'laptop':
        icon = Icons.laptop;
        color = Colors.blueGrey;
        break;
      case 'flutter':
        icon = Icons.flutter_dash;
        color = Colors.blue;
        break;
      case 'palette':
        icon = Icons.palette;
        color = Colors.deepOrange;
        break;
      default:
        icon = Icons.article;
        color = Colors.blue;
    }

    return Stack(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star, size: 6, color: Colors.white)
              ),
            ),
          ),
        )
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// DETAIL PAGE (The Mockup)
// ---------------------------------------------------------------------------

class DetailPage extends StatelessWidget {
  final NewsItem item;

  const DetailPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(item.linkUrl.split('/')[2].replaceAll('www.', ''), style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Featured Media (Video or Article Image)
            if (item.imageUrl != null)
              Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(item.imageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. Headline
                  Text(
                    item.headline ?? "Detailed Article: ${item.sourceName}",
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Author/Source Info
                  Row(
                    children: [
                      _buildSourceIcon(item.sourceIcon),
                      const SizedBox(width: 8),
                      Text(
                        item.sourceName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      const Text(
                        " • 5 min read",
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                  const Divider(height: 30, color: Color(0xFFE0E0E0)),

                  // 4. Detailed Body Content Mockup
                  Text(
                    item.bodyText,
                    style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "This is the expanded content section, simulating the full page view you requested, similar to a Medium article or YouTube video description. Here, you would find paragraphs of text, more images, comments, and related videos, depending on the platform being mimicked.",
                    style: TextStyle(fontSize: 16, color: Colors.grey[800], height: 1.5),
                  ),
                  const SizedBox(height: 30),

                  // 5. Related/Action Section Mockup
                  const Text(
                    "Related Content",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  _buildRelatedItem("More from ${item.sourceName}", Icons.arrow_forward_ios),
                  _buildRelatedItem("View Comments (1.2K)", Icons.comment),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceIcon(String type) {
    IconData icon;
    Color color;
    
    switch (type) {
      case 'laptop':
        icon = Icons.laptop;
        color = Colors.blueGrey;
        break;
      case 'flutter':
        icon = Icons.flutter_dash;
        color = Colors.blue;
        break;
      case 'palette':
        icon = Icons.palette;
        color = Colors.deepOrange;
        break;
      default:
        icon = Icons.article;
        color = Colors.blue;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
  
  Widget _buildRelatedItem(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, color: Colors.blueAccent)),
          Icon(icon, size: 16, color: Colors.grey[600]),
        ],
      ),
    );
  }
}
