import 'order_response_status.dart';
import 'user_summary.dart';

class OrderResponse {
  const OrderResponse({
    required this.id,
    required this.status,
    required this.proposedPrice,
    required this.executor,
    this.message,
  });

  final int id;
  final OrderResponseStatus status;
  final int proposedPrice;
  final String? message;
  final UserSummary executor;

  factory OrderResponse.fromJson(Map<String, dynamic> json) => OrderResponse(
        id: json['id'] as int,
        status: orderResponseStatusFromApi(json['status'] as String),
        proposedPrice: json['proposed_price'] as int,
        message: json['message'] as String?,
        executor: UserSummary.fromJson(json['executor'] as Map<String, dynamic>),
      );
}
