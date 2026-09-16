import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pubget/core/widgets/message_delivery_indicator.dart';
import 'package:pubget/features/groups/models/chat_models.dart';

void main() {
  testWidgets('delivery indicator uses red, amber, and green language', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              MessageDeliveryIndicator(
                sendState: ChatSendState.failed,
                deliveryState: ChatDeliveryState.notDelivered,
              ),
              MessageDeliveryIndicator(
                sendState: ChatSendState.sent,
                deliveryState: ChatDeliveryState.delivered,
              ),
              MessageDeliveryIndicator(
                sendState: ChatSendState.sent,
                deliveryState: ChatDeliveryState.read,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Not delivered'), findsOneWidget);
    expect(find.bySemanticsLabel('Delivered'), findsOneWidget);
    expect(find.bySemanticsLabel('Read'), findsOneWidget);
  });
}
