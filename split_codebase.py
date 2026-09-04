import re
import os

with open("mobiboss_flutter_codebase_bundle.dart", "r") as f:
    content = f.read()

# Pattern to match:
# // ==========================================
# // FILE: <filename>
# // ==========================================

pattern = re.compile(r"// ==========================================\n// FILE: (.+?)\n// ==========================================\n\n(.*?)?(?=(?:// ==========================================\n// FILE: |\Z))", re.DOTALL)

matches = pattern.findall(content)

for filename, filecontent in matches:
    print(f"Creating {filename}")
    dir_name = os.path.dirname(filename)
    if dir_name:
        os.makedirs(dir_name, exist_ok=True)
    with open(filename, "w") as f:
        f.write(filecontent.strip() + "\n")
print("Done")
