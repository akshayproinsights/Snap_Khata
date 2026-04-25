class ShopProfile {
  final String name;
  final String address;
  final String phone;
  final String gst;
  final String upiId;

  ShopProfile({
    this.name = '',
    this.address = '',
    this.phone = '',
    this.gst = '',
    this.upiId = '',
  });

  ShopProfile copyWith({
    String? name,
    String? address,
    String? phone,
    String? gst,
    String? upiId,
  }) {
    return ShopProfile(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      gst: gst ?? this.gst,
      upiId: upiId ?? this.upiId,
    );
  }
}
