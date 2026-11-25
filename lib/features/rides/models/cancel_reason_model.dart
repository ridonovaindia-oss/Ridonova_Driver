class CancelReasonModel {
  final String code;
  final String label;

  CancelReasonModel({required this.code, required this.label});

  factory CancelReasonModel.fromJson(Map<String, dynamic> json) {
    return CancelReasonModel(
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'label': label,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CancelReasonModel &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          label == other.label;

  @override
  int get hashCode => code.hashCode ^ label.hashCode;

  /// Safe offline fallback list in case backend endpoint is slow or unreachable
  static List<CancelReasonModel> get fallbackReasons => [
        CancelReasonModel(
          code: 'rider_no_show',
          label: 'Rider did not show up at pickup point',
        ),
        CancelReasonModel(
          code: 'rider_not_reachable',
          label: 'Rider not reachable / not answering calls',
        ),
        CancelReasonModel(
          code: 'rider_requested_cancel',
          label: 'Rider requested to cancel',
        ),
        CancelReasonModel(
          code: 'heavy_traffic',
          label: 'Heavy traffic or blocked road',
        ),
        CancelReasonModel(
          code: 'vehicle_breakdown',
          label: 'Vehicle issue / Flat tyre',
        ),
        CancelReasonModel(
          code: 'emergency',
          label: 'Personal emergency',
        ),
        CancelReasonModel(
          code: 'unsafe_location',
          label: 'Unsafe or prohibited drop location',
        ),
        CancelReasonModel(
          code: 'other',
          label: 'Other reason',
        ),
      ];
}
