import json
from pathlib import Path

src = Path("assets/_province_with_district_and_sub_district.json")
dst = Path("assets/thai_admin.json")

data = json.loads(src.read_text(encoding="utf-8"))

out = []
for p in data:
    province_name = p.get("name_th") or p.get("province") or ""
    districts = []
    for d in p.get("districts", []):
        name = d.get("name_th") or d.get("district") or ""
        if name:
            districts.append(name)
    # กันซ้ำ + sort
    districts = sorted(list(dict.fromkeys(districts)))
    if province_name and districts:
        out.append({"province": province_name, "districts": districts})

# sort จังหวัด
out = sorted(out, key=lambda x: x["province"])
dst.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")

print("Wrote:", dst, "provinces:", len(out))