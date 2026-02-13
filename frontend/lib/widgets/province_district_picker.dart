import 'package:flutter/material.dart';
import '../data/thai_admin.dart';

class ProvinceDistrictValue {
  final String? province;
  final String? district;
  const ProvinceDistrictValue({this.province, this.district});
}

class ProvinceDistrictPicker extends StatefulWidget {
  final ProvinceDistrictValue value;
  final void Function(ProvinceDistrictValue v) onChanged;

  final String provinceLabel;
  final String districtLabel;

  const ProvinceDistrictPicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.provinceLabel = 'จังหวัด',
    this.districtLabel = 'อำเภอ/เขต',
  });

  @override
  State<ProvinceDistrictPicker> createState() => _ProvinceDistrictPickerState();
}

class _ProvinceDistrictPickerState extends State<ProvinceDistrictPicker> {
  List<ThaiAdmin> admin = [];
  List<String> provinces = [];
  List<String> districts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    admin = await ThaiAdminRepository.load();
    provinces = admin.map((e) => e.province).toList()..sort();

    // ถ้ามี province เดิมอยู่แล้ว ให้เติม districts ให้พร้อม
    if (widget.value.province != null) {
      final found = admin.firstWhere((x) => x.province == widget.value.province);
      districts = List<String>.from(found.districts)..sort();
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: widget.value.province,
            decoration: InputDecoration(
              labelText: widget.provinceLabel,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.map_outlined),
            ),
            items: provinces
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              final found = admin.firstWhere((x) => x.province == v);
              final nextDistricts = List<String>.from(found.districts)..sort();

              setState(() {
                districts = nextDistricts;
              });

              widget.onChanged(ProvinceDistrictValue(
                province: v,
                district: null, // reset district เมื่อเปลี่ยนจังหวัด
              ));
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: widget.value.district,
            decoration: InputDecoration(
              labelText: widget.districtLabel,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
              ),
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.location_city_outlined),
            ),
            items: districts
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: widget.value.province == null
                ? null
                : (v) {
                    widget.onChanged(ProvinceDistrictValue(
                      province: widget.value.province,
                      district: v,
                    ));
                  },
          ),
        ),
      ],
    );
  }
}
