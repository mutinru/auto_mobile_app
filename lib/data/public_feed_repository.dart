import 'dart:convert';

import '../config/api_config.dart';
import '../models/feed_card.dart';
import '../models/public_order.dart';
import 'api_exception.dart';
import 'http_transport.dart';
import 'json_list.dart';

/// Витрина доступна без входа, поэтому ходит мимо ApiClient — прямо
/// транспортом (с его таймаутом); токена здесь нет по замыслу.
class PublicFeedRepository {
  Future<(FeedStats, List<FeedCard>)> fetchFeed() async {
    final response = await HttpTransport.request(
      'GET',
      Uri.parse('${ApiConfig.baseUrl}/public/feed'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final stats = FeedStats.fromJson(body['stats'] as Map<String, dynamic>);
    final cards = parseList(body['data'], FeedCard.fromJson, what: 'карточка');
    return (stats, cards);
  }

  Future<PublicOrder> fetchOrder(int id) async {
    final response = await HttpTransport.request(
      'GET',
      Uri.parse('${ApiConfig.baseUrl}/public/orders/$id'),
      headers: {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return PublicOrder.fromJson(body['data'] as Map<String, dynamic>);
  }
}
