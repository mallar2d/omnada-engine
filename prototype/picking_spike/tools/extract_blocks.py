"""Write the N-th ```gdscript block of a Markdown file to a path."""
import sys, re
md, index, out = sys.argv[1], int(sys.argv[2]), sys.argv[3]
blocks = re.findall(r"```gdscript\n(.*?)```", open(md, encoding="utf-8").read(), re.S)
open(out, "w", encoding="utf-8").write(blocks[index])
print(f"{out}: block {index} of {len(blocks)}, {blocks[index].count(chr(10))} lines")
