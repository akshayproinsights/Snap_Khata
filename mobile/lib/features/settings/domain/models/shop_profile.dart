class ShopProfile {
  final String name;
  final String address;
  final String phone;
  final String gst;

  ShopProfile({
    this.name = '',
    this.address = '',
    this.phone = '',
    this.gst = '',
  });

  ShopProfile copyWith({
    String? name,
    String? address,
    String? phone,
    String? gst,
  }) {
    return ShopProfile(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      gst: gst ?? this.gst,
    );
  }
}
