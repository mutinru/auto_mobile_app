enum OrderResponseStatus { pending, accepted, rejected }

OrderResponseStatus orderResponseStatusFromApi(String value) => switch (value) {
      'accepted' => OrderResponseStatus.accepted,
      'rejected' => OrderResponseStatus.rejected,
      _ => OrderResponseStatus.pending,
    };
