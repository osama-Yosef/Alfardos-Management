/// Business-rule violations raised by the accounting engine.
///
/// These are *expected* errors (bad input, insufficient balance) and carry a
/// user-facing Arabic message. They are never reported to Crashlytics.
enum AccountingError {
  emptyInvoice('يجب إضافة صنف واحد على الأقل إلى الفاتورة.'),
  invalidQuantity('الكمية يجب أن تكون أكبر من صفر.'),
  negativeAmount('لا يمكن أن تكون المبالغ سالبة.'),
  zeroAmount('المبلغ يجب أن يكون أكبر من صفر.'),
  discountExceedsTotal('الخصم لا يمكن أن يتجاوز إجمالي الفاتورة.'),
  paidExceedsTotal('المبلغ المدفوع لا يمكن أن يتجاوز صافي الفاتورة.'),
  creditRequiresParty('البيع أو الشراء الآجل يتطلب اختيار عميل أو مورد مسجل.'),
  cashboxRequired('يجب اختيار الخزنة.'),
  sameCashbox('لا يمكن التحويل إلى نفس الخزنة.'),
  insufficientCash('رصيد الخزنة غير كافٍ لتنفيذ هذه العملية.'),
  insufficientStock('الكمية المتوفرة في المخزون غير كافية.'),
  customerOverpayment('المبلغ أكبر من الرصيد المستحق على العميل.'),
  supplierOverpayment('المبلغ أكبر من الرصيد المستحق للمورد.'),
  inactiveAccount('الحساب المحدد غير نشط.'),
  notFound('السجل المطلوب غير موجود أو تم حذفه.'),
  alreadyPosted('تم حفظ هذه العملية مسبقاً.'),
  alreadyCancelled('هذه العملية ملغاة مسبقاً.'),
  cannotReverseReversal('لا يمكن إلغاء قيد عكسي.'),
  unbalancedPosting('خطأ داخلي: القيد المحاسبي غير متوازن. لم يتم حفظ العملية.'),
  tooManyLines('عدد الأصناف في الفاتورة كبير جداً. الحد الأقصى 150 صنفاً.');

  const AccountingError(this.message);
  final String message;
}

class AccountingException implements Exception {
  const AccountingException(this.error, [this.detail]);

  final AccountingError error;

  /// Optional context appended to the message, e.g. the product name.
  final String? detail;

  String get message => detail == null ? error.message : '${error.message} ($detail)';

  @override
  String toString() => 'AccountingException(${error.name}${detail == null ? '' : ': $detail'})';
}
