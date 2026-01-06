import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/agent_base.dart';
import '../core/step_types.dart';

/// Agent for fetching and processing web content.
/// Transparently logs all network operations.
class WebCrawlerAgent extends AgentBase {
  /// HTTP client for requests
  final http.Client _client;

  /// Request timeout
  final Duration timeout;

  WebCrawlerAgent({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    super.logger,
  })  : _client = client ?? http.Client(),
        super(name: 'WebCrawler');

  @override
  Future<R> onRun<R>(dynamic input) async {
    if (input is CrawlRequest) {
      return await crawl(input) as R;
    } else if (input is String) {
      return await crawl(CrawlRequest(url: input)) as R;
    }
    throw ArgumentError('Expected CrawlRequest or String');
  }

  /// Crawl a URL and extract content
  Future<CrawlResult> crawl(CrawlRequest request) async {
    // Step 1: Validate URL
    final isValid = await execute<bool>(
      action: StepType.check,
      target: 'validating URL: ${request.url}',
      task: () async => _isValidUrl(request.url),
    );

    if (!isValid) {
      throw ArgumentError('Invalid URL: ${request.url}');
    }

    // Step 2: Fetch the content
    final response = await execute<http.Response>(
      action: StepType.fetch,
      target: request.url,
      task: () async => await _fetch(request.url),
      metadata: {'method': 'GET'},
    );

    // Step 3: Process the response
    final content = await execute<WebContent>(
      action: StepType.extract,
      target: 'processing ${response.bodyBytes.length} bytes',
      task: () async => _processResponse(response, request),
    );

    // Step 4: Store if requested
    if (request.store) {
      await execute<void>(
        action: StepType.store,
        target: 'caching result',
        task: () async => _cache(request.url, content),
      );
    }

    return CrawlResult(
      url: request.url,
      content: content,
      statusCode: response.statusCode,
      fetchedAt: DateTime.now(),
    );
  }

  /// Validate URL format
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (_) {
      return false;
    }
  }

  /// Fetch URL content
  Future<http.Response> _fetch(String url) async {
    return await _client.get(Uri.parse(url)).timeout(timeout);
  }

  /// Process HTTP response into WebContent
  WebContent _processResponse(http.Response response, CrawlRequest request) {
    final contentType = response.headers['content-type'] ?? 'text/html';
    final encoding = _getEncoding(contentType);
    final body = encoding.decode(response.bodyBytes);

    return WebContent(
      html: body,
      contentType: contentType,
      title: _extractTitle(body),
      text: request.extractText ? _extractText(body) : null,
      links: request.extractLinks ? _extractLinks(body, request.url) : null,
    );
  }

  /// Get encoding from content-type header
  Encoding _getEncoding(String contentType) {
    final match = RegExp(r'charset=([^\s;]+)').firstMatch(contentType);
    if (match != null) {
      try {
        return Encoding.getByName(match.group(1)!) ?? utf8;
      } catch (_) {}
    }
    return utf8;
  }

  /// Extract page title
  String _extractTitle(String html) {
    final match = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false)
        .firstMatch(html);
    return match?.group(1)?.trim() ?? 'Untitled';
  }

  /// Extract text content (simple)
  String _extractText(String html) {
    // Remove script and style tags
    var text =
        html.replaceAll(RegExp(r'<script[^>]*>.*?</script>', dotAll: true), '');
    text =
        text.replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '');
    // Remove all HTML tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    // Clean up whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }

  /// Extract links from HTML
  List<String> _extractLinks(String html, String baseUrl) {
    final links = <String>[];
    // Match href attributes with various quote styles
    final pattern = RegExp("href=[\"']([^\"']+)[\"']", caseSensitive: false);

    for (final match in pattern.allMatches(html)) {
      final href = match.group(1);
      if (href != null && href.isNotEmpty) {
        // Resolve relative URLs
        final resolved = _resolveUrl(href, baseUrl);
        if (resolved != null) {
          links.add(resolved);
        }
      }
    }

    return links.toSet().toList();
  }

  /// Resolve relative URL
  String? _resolveUrl(String href, String baseUrl) {
    try {
      final base = Uri.parse(baseUrl);
      final resolved = base.resolve(href);
      if (resolved.scheme == 'http' || resolved.scheme == 'https') {
        return resolved.toString();
      }
    } catch (_) {}
    return null;
  }

  /// Cache content (placeholder)
  Future<void> _cache(String url, WebContent content) async {
    // TODO: Implement actual caching
  }

  /// Close the client
  void dispose() {
    _client.close();
  }
}

/// Request for web crawling
class CrawlRequest {
  final String url;
  final bool extractText;
  final bool extractLinks;
  final bool store;
  final Map<String, String>? headers;

  const CrawlRequest({
    required this.url,
    this.extractText = true,
    this.extractLinks = false,
    this.store = false,
    this.headers,
  });
}

/// Extracted web content
class WebContent {
  final String html;
  final String contentType;
  final String title;
  final String? text;
  final List<String>? links;

  const WebContent({
    required this.html,
    required this.contentType,
    required this.title,
    this.text,
    this.links,
  });
}

/// Result of crawling
class CrawlResult {
  final String url;
  final WebContent content;
  final int statusCode;
  final DateTime fetchedAt;

  const CrawlResult({
    required this.url,
    required this.content,
    required this.statusCode,
    required this.fetchedAt,
  });
}
