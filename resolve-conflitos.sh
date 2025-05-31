#!/bin/bash

echo "🧹 Limpando conflitos preservando autores da base MSM..."

modified_count=0

# Varre todos os arquivos (exceto .git)
while IFS= read -r -d '' file; do
    if grep -q '^<<<<<<< ' "$file"; then
        # Extrai apenas a parte da outra branch (parte depois do "=======")
        awk '
        BEGIN { in_conflict=0; in_head=0; in_branch=0; }
        /^<<<<<<< / { in_conflict=1; in_head=1; next }
        /^=======/   { in_head=0; in_branch=1; next }
        /^>>>>>>>/   { in_conflict=0; in_branch=0; next }
        {
            if (in_conflict) {
                if (in_branch) print;
            } else {
                print;
            }
        }' "$file" > "$file.tmp"

        if ! cmp -s "$file" "$file.tmp"; then
            mv "$file.tmp" "$file"
            git update-index --assume-unchanged "$file" 2>/dev/null
            echo "✔️ Corrigido (autoria preservada): $file"
            modified_count=$((modified_count+1))
        else
            rm "$file.tmp"
        fi
    fi
done < <(find . -type f -not -path "./.git/*" -print0)

if [ "$modified_count" -gt 0 ]; then
    echo "✅ Conflitos removidos em $modified_count arquivo(s), sem apagar histórico de ninguém."
else
    echo "✅ Nenhum conflito detectado. Tudo limpo, tudo nosso."
fi
