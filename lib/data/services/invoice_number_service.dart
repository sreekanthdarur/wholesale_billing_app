class InvoiceNumberService {
  String generate(DateTime date, int sequence) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final s = sequence.toString().padLeft(4, '0');
    return 'INV-$y$m$d-$s';
  }
}
