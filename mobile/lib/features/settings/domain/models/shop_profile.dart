class ShopProfile {
  final String name;
  final String address;
  final String phone;
  final String gst;
  final String upiId;
  final String logoUrl;
  final String customTerms;
  final String whatsappCustomNote;
  /// 'general' (default) or 'laundry'
  final String shopType;

  ShopProfile({
    this.name = '',
    this.address = '',
    this.phone = '',
    this.gst = '',
    this.upiId = '',
    this.logoUrl = '',
    this.customTerms = '',
    this.whatsappCustomNote = '',
    this.shopType = 'general',
  });

  ShopProfile copyWith({
    String? name,
    String? address,
    String? phone,
    String? gst,
    String? upiId,
    String? logoUrl,
    String? customTerms,
    String? whatsappCustomNote,
    String? shopType,
  }) {
    return ShopProfile(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      gst: gst ?? this.gst,
      upiId: upiId ?? this.upiId,
      logoUrl: logoUrl ?? this.logoUrl,
      customTerms: customTerms ?? this.customTerms,
      whatsappCustomNote: whatsappCustomNote ?? this.whatsappCustomNote,
      shopType: shopType ?? this.shopType,
    );
  }
}
