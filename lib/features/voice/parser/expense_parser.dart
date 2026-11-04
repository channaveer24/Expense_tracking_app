// Offline, rule-based parser that turns one spoken sentence into one or more
// expenses. Pure Dart (no Flutter imports) so it is fully unit-testable.
//
// Pipeline:
//   1. normalise   – lower-case, "₹40"/"40rs"/"forty rupees" -> "40 rs"
//   2. clauses     – split on conjunctions (and / also / then / , ...)
//   3. segments    – stitch clauses so every segment owns exactly one amount
//                    ("i also spent on the petrol" + "there i spent 210 rs")
//   4. classify    – description, category, Need/Want, payment method, date

import '../../../core/constants/categories.dart';
import '../../../data/models/expense.dart';

class ExpenseParser {
  ExpenseParser({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  // ---------------------------------------------------------------- keywords

  /// keyword -> category. Multi-word keys are matched first (longest wins),
  /// so "table lamp" beats "table" and "movie ticket" beats "ticket".
  static const Map<String, String> categoryKeywords = {
    // Transportation
    'metro': 'Transportation', 'cab': 'Transportation', 'cabs': 'Transportation',
    'auto': 'Transportation', 'autos': 'Transportation', 'uber': 'Transportation',
    'ola': 'Transportation', 'rapido': 'Transportation', 'bus': 'Transportation',
    'train': 'Transportation', 'taxi': 'Transportation', 'flight': 'Transportation',
    'parking': 'Transportation', 'toll': 'Transportation', 'fare': 'Transportation',
    'travel': 'Transportation', 'rickshaw': 'Transportation', 'ticket': 'Transportation',
    'tickets': 'Transportation', 'metro card': 'Transportation', 'bus pass': 'Transportation',
    // Bike
    'petrol': 'Bike', 'fuel': 'Bike', 'diesel': 'Bike', 'bike': 'Bike',
    'bike service': 'Bike', 'servicing': 'Bike', 'puncture': 'Bike', 'helmet': 'Bike',
    'tyre': 'Bike', 'tire': 'Bike', 'engine oil': 'Bike', 'scooty': 'Bike',
    // Housing
    'rent': 'Housing', 'house rent': 'Housing', 'home rent': 'Housing',
    'curd': 'Housing', 'milk': 'Housing', 'vegetables': 'Housing', 'vegetable': 'Housing',
    'veggies': 'Housing', 'tharkari': 'Housing', 'masala': 'Housing', 'grocery': 'Housing',
    'groceries': 'Housing', 'chapati': 'Housing', 'rice': 'Housing', 'dal': 'Housing',
    'atta': 'Housing', 'eggs': 'Housing', 'egg': 'Housing', 'bread': 'Housing',
    'fruits': 'Housing', 'fruit': 'Housing', 'water': 'Housing', 'water can': 'Housing',
    'cylinder': 'Housing', 'gas cylinder': 'Housing', 'maintenance': 'Housing',
    'big basket': 'Housing', 'bigbasket': 'Housing', 'blinkit': 'Housing', 'zepto': 'Housing',
    'onion': 'Housing', 'onions': 'Housing', 'tomato': 'Housing', 'tomatoes': 'Housing',
    'oil': 'Housing', 'ghee': 'Housing', 'sugar': 'Housing', 'salt': 'Housing',
    'paneer': 'Housing', 'butter': 'Housing', 'flour': 'Housing',
    // Medical
    'medicine': 'Medical', 'medicines': 'Medical', 'tablet': 'Medical', 'tablets': 'Medical',
    'doctor': 'Medical', 'hospital': 'Medical', 'pharmacy': 'Medical', 'clinic': 'Medical',
    'checkup': 'Medical', 'check up': 'Medical', 'lab test': 'Medical', 'medical': 'Medical',
    'injection': 'Medical', 'chemist': 'Medical', 'dentist': 'Medical',
    // Entertainment
    'movie': 'Entertainment', 'movies': 'Entertainment', 'movie ticket': 'Entertainment',
    'cinema': 'Entertainment', 'netflix': 'Entertainment', 'prime': 'Entertainment',
    'hotstar': 'Entertainment', 'ott': 'Entertainment', 'otts': 'Entertainment',
    'spotify': 'Entertainment', 'game': 'Entertainment', 'games': 'Entertainment',
    'concert': 'Entertainment', 'party': 'Entertainment', 'outing': 'Entertainment',
    'trip': 'Entertainment', 'youtube premium': 'Entertainment',
    // Utilities
    'electricity': 'Utilities', 'current bill': 'Utilities', 'power bill': 'Utilities',
    'wifi': 'Utilities', 'wi-fi': 'Utilities', 'internet': 'Utilities',
    'broadband': 'Utilities', 'recharge': 'Utilities', 'mobile recharge': 'Utilities',
    'phone bill': 'Utilities', 'bill': 'Utilities', 'table': 'Utilities',
    'chair': 'Utilities', 'furniture': 'Utilities', 'bucket': 'Utilities',
    'dth': 'Utilities', 'gas bill': 'Utilities', 'bulb': 'Utilities', 'fan': 'Utilities',
    // Personal
    'toothbrush': 'Personal', 'tooth brush': 'Personal', 'toothpaste': 'Personal',
    'soap': 'Personal', 'shampoo': 'Personal', 'haircut': 'Personal', 'hair cut': 'Personal',
    'salon': 'Personal', 'clothes': 'Personal', 'shirt': 'Personal', 'tshirt': 'Personal',
    't-shirt': 'Personal', 'pant': 'Personal', 'pants': 'Personal', 'jeans': 'Personal',
    'shoes': 'Personal', 'deodorant': 'Personal', 'razor': 'Personal', 'perfume': 'Personal',
    'cream': 'Personal', 'gym': 'Personal',
    // Investment
    'book': 'Investment', 'books': 'Investment', 'course': 'Investment',
    'lamp': 'Investment', 'table lamp': 'Investment', 'stocks': 'Investment',
    'stock': 'Investment', 'sip': 'Investment', 'mutual fund': 'Investment',
    'mutual funds': 'Investment', 'gold': 'Investment', 'fd': 'Investment',
    'laptop': 'Investment', 'udemy': 'Investment', 'certification': 'Investment',
    'notebook': 'Investment', 'headphones': 'Investment', 'keyboard': 'Investment',
    // Misc
    'tea': 'Misc', 'chai': 'Misc', 'coffee': 'Misc', 'snacks': 'Misc', 'snack': 'Misc',
    't&c': 'Misc', 'tnc': 'Misc', 'cigarette': 'Misc', 'cigarettes': 'Misc',
    'chocolate': 'Misc', 'juice': 'Misc', 'coke': 'Misc', 'cocacola': 'Misc',
    'coca cola': 'Misc', 'pepsi': 'Misc', 'chips': 'Misc', 'biscuit': 'Misc',
    'biscuits': 'Misc', 'ice cream': 'Misc', 'chewing gum': 'Misc', 'chewinggum': 'Misc',
    'food': 'Misc', 'lunch': 'Misc', 'dinner': 'Misc', 'breakfast': 'Misc',
    'swiggy': 'Misc', 'zomato': 'Misc', 'pizza': 'Misc', 'burger': 'Misc',
    'restaurant': 'Misc', 'samosa': 'Misc', 'cake': 'Misc', 'cool drink': 'Misc',
    'soft drink': 'Misc', 'pani puri': 'Misc', 'biryani': 'Misc',
  };

  static const Map<String, String> paymentKeywords = {
    'cash': 'Cash',
    'card': 'Card',
    'credit card': 'Card',
    'debit card': 'Card',
    'upi': 'UPI',
    'gpay': 'UPI',
    'google pay': 'UPI',
    'phonepe': 'UPI',
    'phone pe': 'UPI',
    'paytm': 'UPI',
  };

  /// Words that never form part of a description.
  static const Set<String> _stop = {
    'i', "i've", 'ive', 'im', "i'm", 'have', 'has', 'had', 'spent', 'spend', 'spends',
    'spending', 'paid', 'pay', 'paying', 'bought', 'buy', 'buying', 'purchased',
    'purchase', 'got', 'get', 'gave', 'give', 'given', 'on', 'the', 'a', 'an', 'for',
    'of', 'to', 'from', 'at', 'in', 'my', 'me', 'we', 'our', 'it', 'its', 'was',
    'is', 'were', 'that', 'this', 'there', 'here', 'then', 'also', 'and', 'some',
    'worth', 'rs', 'total', 'today', 'yesterday', 'just', 'did', 'do', 'done', 'made',
    'make', 'by', 'using', 'via', 'through', 'with', 'amount', 'around', 'about',
    'approximately', 'approx', 'only', 'which', 'cost', 'costs', 'costing', 'again',
    'another', 'more', 'um', 'uh', 'so', 'like', 'booked', 'ordered', 'order',
    'rupees', 'rupee', 'inr', 'mode', 'payment', 'need', 'want', 'needed', 'wanted',
    'day', 'before', 'expense', 'expenses', 'added', 'add', 'log', 'went', 'took',
    'paise', 'na', 'ok', 'okay', 'too', 'as', 'well', 'be', 'been',
    'will', 'would', 'should', 'can', 'could', 'all', 'both', 'each', 'every',
    'everything', 'them', 'those', 'these', 'items', 'things', 'overall', 'altogether',
  };

  /// Prepositions dropped when they glue the amount into the description
  /// ("book for 300 rs for my brother" -> "book for my brother").
  static const Set<String> _amountGlue = {
    'for', 'of', 'worth', 'at', 'about', 'around', 'approx', 'approximately',
    'costing', 'cost', 'costs', 'is', 'was', 'rs', 'just', 'only', 'like',
  };

  static const _units = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
    'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12,
    'thirteen': 13, 'fourteen': 14, 'fifteen': 15, 'sixteen': 16, 'seventeen': 17,
    'eighteen': 18, 'nineteen': 19, 'twenty': 20, 'thirty': 30, 'forty': 40,
    'fourty': 40, 'fifty': 50, 'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
  };
  static const _scales = {'hundred': 100, 'thousand': 1000, 'lakh': 100000, 'lakhs': 100000};

  // ----------------------------------------------------------------- public

  List<Expense> parse(String input) {
    final text = normalise(input);
    if (text.trim().isEmpty) return const [];

    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final globalDate = _dateOffset(text);

    final segments = _segments(text);
    if (segments.isEmpty) return const [];

    // A trailing clause like "and i paid everything by cash" with no item of
    // its own applies its payment method to every expense.
    String? globalPayment;
    final trailing = segments.removeLast();
    if (trailing.amount == null) {
      globalPayment = _payment(trailing.text);
      if (segments.isEmpty) return const [];
      if (_hasContent(trailing.text) && segments.isNotEmpty) {
        segments.last.text = '${segments.last.text} ${trailing.text}';
      }
    } else {
      segments.add(trailing);
    }

    return [
      for (final s in segments)
        if (s.amount != null && s.amount! > 0) _toExpense(s, today, globalDate, globalPayment),
    ];
  }

  // ------------------------------------------------------------- normalise

  static String normalise(String input) {
    var t = ' ${input.toLowerCase()} ';
    t = t.replaceAll('₹', ' rs ');
    t = t.replaceAll('/-', ' rs ');
    // 1,105 / 1,00,000 -> 1105 / 100000 (before commas become clause breaks)
    t = t.replaceAllMapped(RegExp(r'(\d),(?=\d{2,3}\b)'), (m) => m[1]!);
    t = t.replaceAllMapped(RegExp(r'(\d),(?=\d{2})'), (m) => m[1]!);
    // 40rs / rs40 / 2k
    t = t.replaceAllMapped(RegExp(r'(\d)\s*k\b'), (m) => '${m[1]}000');
    t = t.replaceAllMapped(RegExp(r'(\d)([a-z])'), (m) => '${m[1]} ${m[2]}');
    t = t.replaceAllMapped(RegExp(r'([a-z])(\d)'), (m) => '${m[1]} ${m[2]}');
    t = t.replaceAll(RegExp(r'\b(rs\.?|rupees?|inr|bucks|rupaye|rupay)(?=\s|$|[,.;!?])'), 'rs');
    t = t.replaceAll(RegExp(r'\brs\s*\.'), 'rs ');
    t = _wordsToNumbers(t);
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// "two hundred and fifty rupees" -> "250 rupees".
  static String _wordsToNumbers(String t) {
    final tokens = t.split(RegExp(r'\s+'));
    final out = <String>[];
    var i = 0;
    while (i < tokens.length) {
      final w = tokens[i];
      if (!_units.containsKey(w) && !(_scales.containsKey(w) && out.isNotEmpty && out.last == 'a')) {
        out.add(w);
        i++;
        continue;
      }
      if (_scales.containsKey(w)) out.removeLast(); // "a hundred" -> 100
      var total = 0, current = 0, j = i;
      var consumed = false;
      while (j < tokens.length) {
        final x = tokens[j];
        if (_units.containsKey(x)) {
          current += _units[x]!;
        } else if (x == 'hundred') {
          current = (current == 0 ? 1 : current) * 100;
        } else if (_scales.containsKey(x)) {
          total += (current == 0 ? 1 : current) * _scales[x]!;
          current = 0;
        } else if (x == 'and' &&
            consumed &&
            j + 1 < tokens.length &&
            _units.containsKey(tokens[j + 1]) &&
            (tokens[j - 1] == 'hundred' || _scales.containsKey(tokens[j - 1]))) {
          // "two hundred and fifty" – keep going
        } else {
          break;
        }
        consumed = true;
        j++;
      }
      out.add('${total + current}');
      i = j;
    }
    return out.join(' ');
  }

  // -------------------------------------------------------------- segments

  static final _clauseSplit = RegExp(
      r'\s*(?:[,;!?]|\.(?!\d)|\band then\b|\bafter that\b|\band\b|\balso\b|\bthen\b|\bplus\b|\bas well as\b)\s*');
  static final _numberRe = RegExp(r'\b\d+(?:\.\d+)?\b');

  List<_Seg> _segments(String text) {
    final markedOnly = RegExp(r'\b\d+(?:\.\d+)?\s+rs\b|\brs\s+\d+').hasMatch(text);
    final clauses = text.split(_clauseSplit).where((c) => c.trim().isNotEmpty).toList();

    final segs = <_Seg>[];
    var pending = '';

    for (final clause in clauses) {
      final amounts = _amounts(clause, markedOnly);
      if (amounts.isEmpty) {
        final lastNeedsItem = segs.isNotEmpty && !_hasContent(segs.last.text);
        if (lastNeedsItem && _hasContent(clause)) {
          segs.last.text = '${segs.last.text} $clause';
        } else {
          pending = '$pending $clause';
        }
        continue;
      }
      if (amounts.length == 1) {
        segs.add(_Seg('$pending $clause', amounts.first.value));
        pending = '';
        continue;
      }
      // Several amounts inside one clause: "tea 40 coffee 50" or "40 on tea 50 on coffee".
      final itemFirst = _hasContent(clause.substring(0, amounts.first.start));
      for (var k = 0; k < amounts.length; k++) {
        final a = amounts[k];
        final int from, to;
        if (itemFirst) {
          from = k == 0 ? 0 : amounts[k - 1].end;
          to = k == amounts.length - 1 ? clause.length : a.end;
        } else {
          from = k == 0 ? 0 : a.start;
          to = k == amounts.length - 1 ? clause.length : amounts[k + 1].start;
        }
        segs.add(_Seg('${k == 0 ? pending : ''} ${clause.substring(from, to)}', a.value));
      }
      pending = '';
    }

    if (pending.trim().isNotEmpty) segs.add(_Seg(pending, null));
    return segs;
  }

  List<_Amount> _amounts(String clause, bool markedOnly) {
    final result = <_Amount>[];
    for (final m in _numberRe.allMatches(clause)) {
      final before = clause.substring(0, m.start).trimRight();
      final after = clause.substring(m.end).trimLeft();
      final marked = before.endsWith('rs') || after.startsWith('rs');
      if (markedOnly && !marked && !_looksLikeAmount(before, after)) continue;
      result.add(_Amount(double.parse(m[0]!), m.start, m.end));
    }
    return result;
  }

  static const _amountBefore = {
    'spent', 'paid', 'pay', 'for', 'of', 'worth', 'cost', 'costs', 'costing', 'is', 'was', 'at', 'around', 'about',
  };
  static const _amountAfter = {'on', 'for', 'towards', 'in', 'to'};

  /// When some numbers carry "rs", an unmarked number still counts if it sits
  /// where money usually sits ("900 on a table", "paid 50") – but "2 books" does not.
  static bool _looksLikeAmount(String before, String after) {
    final prev = before.isEmpty ? '' : before.split(' ').last;
    final next = after.isEmpty ? '' : after.split(' ').first;
    return after.isEmpty || _amountBefore.contains(prev) || _amountAfter.contains(next);
  }

  // ------------------------------------------------------------- classify

  Expense _toExpense(_Seg s, DateTime today, int? globalDate, String? globalPayment) {
    final text = s.text.trim();
    final description = _description(text, s.amount!);
    final category = _category(text) ?? 'Misc';
    var type = kCategoryDefaultType[category] ?? 'Want';
    if (RegExp(r'\b(it was|its|it is|as) a (need|necessity)\b|\bneeded\b').hasMatch(text)) type = 'Need';
    if (RegExp(r'\b(it was|its|it is|as) a (want|luxury)\b|\bjust wanted\b').hasMatch(text)) type = 'Want';
    final payment = _payment(text) ?? globalPayment ?? 'UPI';
    final offset = _dateOffset(text) ?? globalDate ?? 0;
    return Expense(
      date: today.subtract(Duration(days: offset)),
      amount: s.amount!,
      description: description.isEmpty ? category : description,
      category: category,
      paymentMethod: payment,
      type: type,
    );
  }

  static List<MapEntry<String, String>>? _sortedCategoryKeys;

  static String? _category(String text) {
    _sortedCategoryKeys ??= categoryKeywords.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final e in _sortedCategoryKeys!) {
      if (_containsWord(text, e.key)) return e.value;
    }
    return null;
  }

  static String? _payment(String text) {
    final keys = paymentKeywords.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      if (_containsWord(text, k)) return paymentKeywords[k];
    }
    return null;
  }

  static int? _dateOffset(String text) {
    if (text.contains('day before yesterday')) return 2;
    if (_containsWord(text, 'yesterday')) return 1;
    if (_containsWord(text, 'today')) return 0;
    return null;
  }

  static bool _containsWord(String text, String key) =>
      RegExp('(?:^|[^a-z0-9&])${RegExp.escape(key)}(?:\$|[^a-z0-9&])').hasMatch(text);

  static bool _isFiller(String w) =>
      _stop.contains(w) ||
      paymentKeywords.containsKey(w) ||
      {'pe', 'pay', 'google', 'credit', 'debit'}.contains(w) ||
      RegExp(r'^\d+(\.\d+)?$').hasMatch(w);

  static bool _hasContent(String text) =>
      text.split(RegExp(r'\s+')).any((w) => w.isNotEmpty && !_isFiller(w));

  /// Keeps the span between the first and last meaningful word, so
  /// "booked the cab for parents from hotel to home 184 rs" ->
  /// "Cab for parents from hotel to home".
  static String _description(String text, double amount) {
    var words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    // Remove the amount and the words that glue it into the phrase.
    final cleaned = <String>[];
    for (var i = 0; i < words.length; i++) {
      final w = words[i];
      if (RegExp(r'^\d+(\.\d+)?$').hasMatch(w) && double.parse(w) == amount) {
        while (cleaned.isNotEmpty && _amountGlue.contains(cleaned.last)) {
          cleaned.removeLast();
        }
        while (i + 1 < words.length && {'rs', 'only'}.contains(words[i + 1])) {
          i++;
        }
        continue;
      }
      if (w == 'rs') continue;
      cleaned.add(w);
    }
    words = cleaned;

    // Drop payment / date phrases entirely.
    final joined = words
        .join(' ')
        .replaceAll(RegExp(r'\b(by|using|via|through|with|in|on)?\s*(cash|upi|card|credit card|debit card|gpay|google pay|phonepe|phone pe|paytm)\b'), ' ')
        .replaceAll(RegExp(r'\b(day before yesterday|yesterday|today)\b'), ' ')
        .replaceAll(RegExp(r'\b(it was|its|it is|as) a (need|want|necessity|luxury)\b'), ' ');
    words = joined.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    final first = words.indexWhere((w) => !_isFiller(w));
    if (first < 0) return '';
    final last = words.lastIndexWhere((w) => !_isFiller(w));
    var span = words.sublist(first, last + 1);

    // If the span still contains verb-y filler runs ("petrol there i have spent tea"),
    // keep only meaningful words.
    final fillerRun = span.where(_isFiller).length;
    if (fillerRun > 3) span = span.where((w) => !_isFiller(w)).toList();

    span = span.where((w) => !{'the', 'a', 'an'}.contains(w)).toList();
    final d = span.join(' ');
    if (d.isEmpty) return '';
    return d[0].toUpperCase() + d.substring(1);
  }
}

class _Seg {
  _Seg(this.text, this.amount);
  String text;
  final double? amount;
}

class _Amount {
  _Amount(this.value, this.start, this.end);
  final double value;
  final int start;
  final int end;
}
