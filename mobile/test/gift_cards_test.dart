import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/app.dart';
import 'package:orleu_mobile/core/api/token_store.dart';

import 'app_flow_test.dart' show booking;
import 'support/fake_api.dart';

final paidBooking = {...booking, 'financials': {'price': 20000, 'depositAmount': 6000, 'paid': 5000, 'refunded': 0, 'netPaid': 5000, 'remaining': 15000, 'paymentStatus': 'PARTIAL'}};

class Env {
  String role;
  bool replay = false;
  Handler? redeemOverride;
  var cards = <Map<String, Object?>>[];
  late final FakeAdapter adapter;

  Env({this.role = 'BUSINESS_OWNER', bool paid = false}) {
    adapter = FakeAdapter({
      ...businessRoutes(bookings: [paid ? paidBooking : booking]),
      'GET /api/v1/me': (_) => ok({'id': 'u1', 'email': 'a@b.kz', 'fullName': 'A', 'locale': 'en', 'memberships': [{'businessId': 'b1', 'role': role}]}),
      'GET /api/v1/businesses/b1/gift-cards': (_) => ok(cards),
      'POST /api/v1/businesses/b1/gift-cards': (o) {
        final d = o.data as Map;
        cards = [{'id': 'g1', 'codeLast4': 'K7M2', 'initialAmount': double.parse(d['amount']), 'balance': double.parse(d['amount']), 'currency': 'KZT', 'status': 'ACTIVE', 'buyerName': d['buyerName'], 'expired': false}];
        return (status: 201, body: {'card': cards.first, 'code': replay ? null : 'ABCD-EFGH-JK2M', 'codeShown': !replay});
      },
      'POST /api/v1/businesses/b1/gift-cards/g1/void': (_) { cards = [{...cards.first, 'status': 'VOID'}]; return ok(cards.first); },
      'POST /api/v1/businesses/b1/bookings/k1/gift-card-payments': (o) => redeemOverride?.call(o) ?? (status: 201, body: booking),
    });
  }
}

Future<void> openApp(WidgetTester tester, Env e) async {
  setPhone(tester, 420, 1400);
  final store = MemoryTokenStore()..access = 'a'..refresh = 'r';
  await tester.pumpWidget(ProviderScope(overrides: overridesFor(e.adapter, store), child: const OrleuApp()));
  await tester.pumpAndSettle();
}

Future<void> openGiftCards(WidgetTester tester, Env e) async {
  await openApp(tester, e);
  await tester.tap(find.text('More').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Gift cards'));
  await tester.pumpAndSettle();
}

void main() {
  restoreTests();
  testWidgets('selling shows the code once and the card appears with its balance', (tester) async {
    final e = Env();
    await openGiftCards(tester, e);
    expect(find.text('No gift cards sold yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sellGiftCard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirmSell')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('formError')), findsOneWidget, reason: 'no amount: refused locally, inside the dialog');
    await tester.enterText(find.byKey(const Key('giftAmount')), '15000');
    await tester.enterText(find.byKey(const Key('giftBuyer')), 'Dana');
    await tester.tap(find.byKey(const Key('confirmSell')));
    await tester.pumpAndSettle();
    final post = e.adapter.calls.firstWhere((c) => c.method == 'POST' && c.path.endsWith('/gift-cards'));
    expect(post.data, {'amount': '15000', 'method': 'CASH', 'buyerName': 'Dana'});
    expect(post.headers['Idempotency-Key'], matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(tester.widget<SelectableText>(find.byKey(const Key('giftCode'))).data, 'ABCD-EFGH-JK2M');
    await tester.tap(find.byKey(const Key('doneSell')));
    await tester.pumpAndSettle();
    expect(find.text('•••• K7M2'), findsOneWidget);
  });

  testWidgets('when the server replays an earlier sale the lost code is explained, not invented', (tester) async {
    final e = Env()..replay = true;
    await openGiftCards(tester, e);
    await tester.tap(find.byKey(const Key('sellGiftCard')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('giftAmount')), '5000');
    await tester.tap(find.byKey(const Key('confirmSell')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('giftCodeLost')), findsOneWidget);
    expect(find.byKey(const Key('giftCode')), findsNothing);
  });

  testWidgets('only owners and admins see Void, and it asks for confirmation', (tester) async {
    final e = Env()..cards = [{'id': 'g1', 'codeLast4': 'K7M2', 'initialAmount': 5000, 'balance': 5000, 'currency': 'KZT', 'status': 'ACTIVE', 'expired': false}];
    await openGiftCards(tester, e);
    await tester.tap(find.byKey(const Key('void-g1')));
    await tester.pumpAndSettle();
    expect(e.adapter.calls.any((c) => c.path.endsWith('/void')), isFalse, reason: 'nothing sent before confirming');
    await tester.tap(find.byKey(const Key('confirmVoid')));
    await tester.pumpAndSettle();
    expect(e.adapter.calls.any((c) => c.path.endsWith('/gift-cards/g1/void')), isTrue);
    expect(find.text('Void'), findsOneWidget);
  });

  testWidgets('a receptionist can sell but not void', (tester) async {
    final e = Env(role: 'RECEPTIONIST')..cards = [{'id': 'g1', 'codeLast4': 'K7M2', 'initialAmount': 5000, 'balance': 5000, 'currency': 'KZT', 'status': 'ACTIVE', 'expired': false}];
    await openGiftCards(tester, e);
    expect(find.byKey(const Key('sellGiftCard')), findsOneWidget);
    expect(find.byKey(const Key('void-g1')), findsNothing);
  });

  Future<void> openPaySheet(WidgetTester tester, Env e) async {
    await openApp(tester, e);
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haircut').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('giftPayAction')));
    await tester.tap(find.byKey(const Key('giftPayAction')));
    await tester.pumpAndSettle();
  }

  testWidgets('paying a booking with a gift card sends the code, amount and an idempotency key', (tester) async {
    final e = Env();
    await openPaySheet(tester, e);
    await tester.tap(find.byKey(const Key('giftPaySave')));
    await tester.pumpAndSettle();
    expect(find.text('Enter the 12-character code'), findsOneWidget, reason: 'no code yet');
    await tester.enterText(find.byKey(const Key('giftPayCode')), 'abcd-efgh-jk2m');
    await tester.enterText(find.byKey(const Key('giftPayAmount')), '6000');
    await tester.tap(find.byKey(const Key('giftPaySave')));
    await tester.pumpAndSettle();
    final call = e.adapter.calls.firstWhere((c) => c.path.endsWith('/gift-card-payments'));
    expect(call.data, {'code': 'abcd-efgh-jk2m', 'amount': '6000'});
    expect(call.headers['Idempotency-Key'], matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(find.text('Payment recorded'), findsOneWidget);
  });

  testWidgets('an unusable card or a low balance is explained inside the sheet', (tester) async {
    final e = Env()..redeemOverride = (_) => err(409, 'GIFT_CARD_INSUFFICIENT');
    await openPaySheet(tester, e);
    await tester.enterText(find.byKey(const Key('giftPayCode')), 'ABCDEFGHJK2M');
    await tester.tap(find.byKey(const Key('giftPaySave')));
    await tester.pumpAndSettle();
    expect(find.text('The gift card balance is too low for this amount.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}

class RestoreEnv extends Env {
  double restorable;
  RestoreEnv({this.restorable = 5000}) : super(paid: true) {
    adapter.routes['GET /api/v1/businesses/b1/bookings/k1/gift-card-restorable'] = (_) => ok({'total': restorable, 'cards': []});
    adapter.routes['POST /api/v1/businesses/b1/bookings/k1/gift-card-refunds'] = (o) => redeemOverride?.call(o) ?? (status: 201, body: booking);
  }
}

void restoreTests() {
  Future<void> openReturn(WidgetTester tester, Env e) async {
    await openApp(tester, e);
    await tester.tap(find.text('Calendar').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Haircut').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('giftReturnAction')));
    await tester.tap(find.byKey(const Key('giftReturnAction')));
    await tester.pumpAndSettle();
  }

  testWidgets('returning value to the card: prefilled with what the server says can go back, exact body and key', (tester) async {
    final e = RestoreEnv();
    await openReturn(tester, e);
    expect((tester.widget(find.byKey(const Key('giftReturnAmount'))) as TextFormField).controller!.text, '5000');
    await tester.enterText(find.byKey(const Key('giftReturnAmount')), '3000');
    await tester.tap(find.byKey(const Key('giftReturnSave')));
    await tester.pumpAndSettle();
    final call = e.adapter.calls.firstWhere((c) => c.path.endsWith('/gift-card-refunds'));
    expect(call.data, {'amount': '3000'});
    expect(call.headers['Idempotency-Key'], matches(RegExp(r'^[0-9a-f]{32}$')));
    expect(find.text('Value returned to the gift card'), findsOneWidget);
  });

  testWidgets('more than can go back is refused locally; nothing to return is explained', (tester) async {
    final e = RestoreEnv();
    await openReturn(tester, e);
    await tester.enterText(find.byKey(const Key('giftReturnAmount')), '5001');
    await tester.tap(find.byKey(const Key('giftReturnSave')));
    await tester.pumpAndSettle();
    expect(find.text('Enter an amount up to the remaining balance'), findsOneWidget);
    expect(e.adapter.calls.any((c) => c.path.endsWith('/gift-card-refunds')), isFalse);
  });

  testWidgets('a booking not paid with a gift card shows an explanation instead of a form', (tester) async {
    final e = RestoreEnv(restorable: 0);
    await openReturn(tester, e);
    expect(find.byKey(const Key('giftNothing')), findsOneWidget);
    expect(find.byKey(const Key('giftReturnSave')), findsNothing);
  });
}
