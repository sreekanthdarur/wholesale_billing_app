class AppConstants {
  static const appName = 'Wholesale Billing App';

  static const invoiceTypes = [
    'Cash',
    'Lakshmi Traders',
    'UPI',
    'Wholesale',
  ];

  static const units = [
    'kg',
    'g',
    'ltr',
    'pcs',
  ];

  static const defaultCustomers = [
    'Cash',
    'Lakshmi Traders',
    'Ramesh Kirana',
    'Sai Traders',
  ];

  static const noiseWords = [
    'amma',
    'anna',
    'sir',
    'madam',
    'please',
    'ok',
    'okay',
    'hello',
    'test',
  ];

  static const itemAliases = {
    'Rice': ['rice', 'biyyam', 'akki', 'chawal'],
    'Sugar': ['sugar', 'cheeni', 'panchadara', 'sakkare'],
    'Toor Dal': [
      'toor dal',
      'tur dal',
      'dal',
      'daal',
      'kandi pappu',
      'arhar dal',
      'togari bele'
    ],
    'Oil': ['oil', 'nune', 'tel', 'enne'],
    'Tamarind': ['tamarind', 'tamrin', 'imli', 'chintapandu', 'hunasehannu'],
  };

  static const itemDefaults = {
    'Rice': {'unit': 'kg', 'rate': 52.0},
    'Sugar': {'unit': 'kg', 'rate': 45.0},
    'Toor Dal': {'unit': 'kg', 'rate': 130.0},
    'Oil': {'unit': 'ltr', 'rate': 120.0},
    'Tamarind': {'unit': 'kg', 'rate': 160.0},
  };
}
