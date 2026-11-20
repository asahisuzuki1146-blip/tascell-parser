import re, sys
src = open('TascellC.rats').read()
src = src.replace(
    'public String start =\n    Spacing decl:ExternalDeclaration EOF\n    { yyValue = decl; }\n  ;',
    'public String start =\n    Spacing decls:ExternalDeclaration+ EOF\n    { StringBuilder sb = new StringBuilder();\n      for (Object d : decls.list()) sb.append(d).append("\\n");\n      yyValue = sb.toString(); }\n  ;'
)
open('TascellC.rats','w').write(src)
print("patched")
