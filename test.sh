declare -A data=()

cnt=0
while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "---" ]]; then
        cnt=$((cnt + 1))
        continue
    fi
    if [[ $cnt -eq 1 ]]; then
        key=$(echo "$line" | cut -d ':' -f1)
        value=$(echo "$line" | cut -d ':' -f2-)
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        data["$key"]="$value"
    elif [[ $cnt -ge 2 ]]; then
        data["content"]+="$line"$'\n'
    fi
done < "./content/index.md"

for key in "${!data[@]}"; do
    echo "$key: ${data[$key]}"
done