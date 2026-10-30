import 'dart:math';
import '../models/transaction.dart';

/// Synthetic debug ledger, never real user data. Covers 24 calendar months
/// through [now], with daily activity, recurring bills, a raise, and outliers.
/// Amounts are illustrative currency units; no currency conversion is implied.
/// Fixed RNG and an explicit clock make the data reproducible in tests.
List<LedgerTransaction> generateDemoTransactions({required DateTime now}) {
  final random = Random(42);
  final entries = <LedgerTransaction>[];
  var id = 1;

  const groceryMerchants = [
    "Trader Joe's",
    'Whole Foods',
    'Safeway',
    'Sprouts Market',
  ];
  const diningMerchants = [
    'Chipotle',
    'Sweetgreen',
    'Corner Cafe',
    'Pizzeria Roma',
    'Thai Basil',
    'Blue Bottle Coffee',
    'Ramen House',
    'Bagel Corner',
  ];
  const generalMerchants = ['Amazon', 'Target', 'Home Depot', 'IKEA'];
  const transportMerchants = ['Uber', 'Lyft'];
  const entertainmentMerchants = [
    'AMC Theatres',
    'Steam',
    'PlayStation Store',
    'Ticketmaster',
  ];
  const healthMerchants = [
    'CVS Pharmacy',
    'Walgreens',
    'City Dental',
    'Riverside Urgent Care',
  ];
  const travelMerchants = ['Delta Airlines', 'Airbnb', 'Marriott Hotels'];
  const subscriptions = [
    ('Spotify', 11.99),
    ('Netflix', 15.49),
    ('Iron Peak Gym', 42.0),
  ];
  const utilityMerchant = 'Riverside Water Co.';
  const giftOccasions = ['Birthday gift', 'Holiday gift'];

  void addIfPast(
    DateTime date,
    String merchant,
    String category,
    double amount,
    TransactionType type,
  ) {
    if (date.isAfter(now)) return;
    entries.add(
      LedgerTransaction(
        id: id++,
        merchant: merchant,
        category: category,
        date: date,
        amount: amount,
        type: type,
      ),
    );
  }

  for (var monthsAgo = 23; monthsAgo >= 0; monthsAgo--) {
    final month = DateTime(now.year, now.month - monthsAgo);
    final monthYear = month.year;
    final monthNum = month.month;
    final daysInMonth = DateTime(monthYear, monthNum + 1, 0).day;
    DateTime onDay(int day) =>
        DateTime(monthYear, monthNum, day.clamp(1, daysInMonth));
    // The last ~3 months get much denser daily coverage.
    final isRecent = monthsAgo <= 2;

    // Guaranteed daily coverage makes every analysis period eligible,
    // including early January and seven-day windows across month boundaries.
    // Several entries on one date still represent only one active day.
    for (var day = 1; day <= daysInMonth; day++) {
      addIfPast(
        onDay(day),
        'Daily commute / local errands',
        'Transport',
        day.isEven ? 4.50 : 7.25,
        TransactionType.expense,
      );
    }
    // Deliberate spikes and extra income provide evidence for comparisons.
    if (monthsAgo % 6 == 3) {
      addIfPast(
        onDay(18),
        'Emergency appliance replacement',
        'General',
        1800,
        TransactionType.expense,
      );
    }
    if (monthsAgo % 4 == 2) {
      addIfPast(
        onDay(24),
        'Freelance project milestone',
        'Wage',
        1250,
        TransactionType.income,
      );
    }
    // A modest raise kicks in for the more recent half of the year.
    final payrollBase = monthsAgo <= 5 ? 1750.0 : 1600.0;
    addIfPast(
      onDay(1),
      'Employer Payroll',
      'Salary',
      payrollBase + random.nextInt(120),
      TransactionType.income,
    );
    addIfPast(
      onDay(15),
      'Employer Payroll',
      'Salary',
      payrollBase + random.nextInt(120),
      TransactionType.income,
    );
    // Smaller recurring biweekly allowance, every month.
    addIfPast(
      onDay(8),
      'Family Allowance',
      'Allowance',
      50.0 + random.nextInt(80),
      TransactionType.income,
    );
    addIfPast(
      onDay(22),
      'Family Allowance',
      'Allowance',
      50.0 + random.nextInt(80),
      TransactionType.income,
    );
    addIfPast(
      onDay(1),
      'Maple Court Apartments',
      'Housing',
      1450,
      TransactionType.expense,
    );
    addIfPast(
      onDay(3),
      'Metro Transit',
      'Transport',
      45,
      TransactionType.expense,
    );
    addIfPast(
      onDay(10),
      utilityMerchant,
      'Utilities',
      25.0 + random.nextInt(35),
      TransactionType.expense,
    );
    for (final sub in subscriptions) {
      addIfPast(
        onDay(5),
        sub.$1,
        'Subscriptions',
        sub.$2,
        TransactionType.expense,
      );
    }
    // Groceries: weekly all year.
    for (var day = 4; day <= daysInMonth; day += 7) {
      addIfPast(
        onDay(day),
        groceryMerchants[random.nextInt(groceryMerchants.length)],
        'Groceries',
        38.0 + random.nextInt(55),
        TransactionType.expense,
      );
    }
    // Dining: near-daily on weekdays for the recent stretch, every few days otherwise.
    if (isRecent) {
      for (var day = 1; day <= daysInMonth; day++) {
        final date = onDay(day);
        if (date.weekday > DateTime.friday) continue;
        if (random.nextDouble() >= 0.85) continue;
        addIfPast(
          date,
          diningMerchants[random.nextInt(diningMerchants.length)],
          'Dining',
          9.0 + random.nextInt(28),
          TransactionType.expense,
        );
      }
      // Weekend dining, less frequent.
      for (var day = 1; day <= daysInMonth; day++) {
        final date = onDay(day);
        if (date.weekday <= DateTime.friday) continue;
        if (random.nextDouble() >= 0.5) continue;
        addIfPast(
          date,
          diningMerchants[random.nextInt(diningMerchants.length)],
          'Dining',
          9.0 + random.nextInt(28),
          TransactionType.expense,
        );
      }
    } else {
      for (var day = 2; day <= daysInMonth; day += 4) {
        addIfPast(
          onDay(day),
          diningMerchants[random.nextInt(diningMerchants.length)],
          'Dining',
          9.0 + random.nextInt(28),
          TransactionType.expense,
        );
      }
    }
    // Transport: several times a week for the recent stretch, existing cadence otherwise.
    if (isRecent) {
      for (var day = 1; day <= daysInMonth; day++) {
        if (random.nextDouble() >= 0.45) continue;
        addIfPast(
          onDay(day),
          transportMerchants[random.nextInt(transportMerchants.length)],
          'Transport',
          12.0 + random.nextInt(18),
          TransactionType.expense,
        );
      }
    } else {
      for (var day = 10; day <= daysInMonth; day += 11) {
        addIfPast(
          onDay(day),
          transportMerchants[random.nextInt(transportMerchants.length)],
          'Transport',
          12.0 + random.nextInt(18),
          TransactionType.expense,
        );
      }
    }
    for (var day = 8; day <= daysInMonth; day += 13) {
      addIfPast(
        onDay(day),
        generalMerchants[random.nextInt(generalMerchants.length)],
        'General',
        18.0 + random.nextInt(120),
        TransactionType.expense,
      );
    }
    // Entertainment: most months.
    if (random.nextDouble() < 0.7) {
      addIfPast(
        onDay(14 + random.nextInt(10)),
        entertainmentMerchants[random.nextInt(entertainmentMerchants.length)],
        'Entertainment',
        15.0 + random.nextInt(55),
        TransactionType.expense,
      );
    }
    // Health: about every other month.
    if (random.nextDouble() < 0.5) {
      addIfPast(
        onDay(6 + random.nextInt(18)),
        healthMerchants[random.nextInt(healthMerchants.length)],
        'Health',
        20.0 + random.nextInt(130),
        TransactionType.expense,
      );
    }
    // Travel: a handful of trips across the year.
    if (random.nextDouble() < 0.2) {
      addIfPast(
        onDay(10 + random.nextInt(15)),
        travelMerchants[random.nextInt(travelMerchants.length)],
        'Travel',
        180.0 + random.nextInt(470),
        TransactionType.expense,
      );
    }
    // Freelance/hourly wage income: roughly a third of months.
    if (random.nextDouble() < 0.35) {
      addIfPast(
        onDay(20 + random.nextInt(8)),
        'Freelance client',
        'Wage',
        150.0 + random.nextInt(500),
        TransactionType.income,
      );
    }
    // Occasional gift income: a few times a year.
    if (random.nextDouble() < 0.15) {
      addIfPast(
        onDay(12 + random.nextInt(12)),
        giftOccasions[random.nextInt(giftOccasions.length)],
        'Gift',
        20.0 + random.nextInt(130),
        TransactionType.income,
      );
    }
    // Year-end bonus.
    if (monthNum == 12) {
      addIfPast(
        onDay(20),
        'Employer Payroll',
        'Bonus',
        900.0 + random.nextInt(600),
        TransactionType.income,
      );
    }
  }

  entries.sort((a, b) => b.date.compareTo(a.date));
  return entries;
}
