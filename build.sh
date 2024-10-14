#!/bin/bash

AUTHOR="Darshan Makwana"
SITE_TITLE="$AUTHOR"

INPUT_DIR="content"
OUTPUT_DIR="public"
LAYOUTS_DIR="layouts"
CSS_DIR="css"

rm -r "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR/$CSS_DIR"

cp -r "$CSS_DIR/." "$OUTPUT_DIR/$CSS_DIR/"

YEAR=$(date +%Y)
MENU_TITLES=()
MENU_FILES=()
MENU_RANK=()

for markdown_file in "$INPUT_DIR"/*.md; do

    filename=$(basename "$markdown_file" .md)
    output_file="$filename.html"

    title=""
    front_matter=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "---" ]]; then
            front_matter=$((front_matter + 1))
            continue
        fi
        if [[ $front_matter -eq 1 ]]; then
            if [[ "$line" =~ ^title:\ (.*) ]]; then
                title="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^rank:\ (.*) ]]; then
                rank="${BASH_REMATCH[1]}"
            fi
        else
            break
        fi
    done < "$markdown_file"

    [[ -z "$title" ]] && title="$filename"

    MENU_TITLES+=("$title")
    MENU_FILES+=("$output_file")
    MENU_RANK+=("$rank")
done

generate_menu_html() {
    local menu_html=""
    local i

    local indices=($(seq 0 $((${#MENU_FILES[@]} - 1))))

    IFS=$'\n' sorted_indices=($(for idx in "${indices[@]}"; do
        echo "$idx ${MENU_RANK[$idx]}"
    done | sort -k2 -n | awk '{print $1}'))

    for idx in "${sorted_indices[@]}"; do
        local output_file="${MENU_FILES[$idx]}"
        local title="${MENU_TITLES[$idx]}"
        menu_html+="<li><a href=\"$output_file\">$title</a></li>"
    done

    echo "$menu_html"
}

MENU_HTML=$(generate_menu_html)

process_includes() {

    local template="$1"
    local depth="${2:-0}"

    if [[ $depth -gt 10 ]]; then
        echo "Maximum template inclusion depth exceeded."
        echo "$template"
        return
    fi

    while [[ "$template" =~ \{\{\ TEM:\ ([^[:space:]}]+)\ \}\} ]]; do
        local include_name="${BASH_REMATCH[1]}"
        local include_file="$LAYOUTS_DIR/$include_name.html"
        if [[ -f "$include_file" ]]; then
            local include_content=$(cat "$include_file")
            # Recursively process includes in the included content
            include_content=$(process_includes "$include_content" $((depth + 1)))
            # Replace the placeholder with the include content
            template="${template//\{\{ TEM: $include_name \}\}/$include_content}"
        else
            echo "Include file $include_file not found. Skipping inclusion."
            # Remove the placeholder
            template="${template//\{\{ TEM: $include_name \}\}/}"
        fi
    done

    echo "$template"
}

process_template() {
    local template="$1"
    local title="$2"
    local content="$3"
    local date="$4"
    local author="$5"

    template=$(process_includes "$template")

    template="${template//\{\{ site_title \}\}/$SITE_TITLE}"
    template="${template//\{\{ title \}\}/$title}"
    template="${template//\{\{ .Date \}\}/$date}"
    template="${template//\{\{ content \}\}/$content}"
    template="${template//\{\{ replace . \"\{Year\}\" now.Year \| markdownify\}\}/$YEAR}"

    template=$(echo "$template" | sed -E "/\{\{ nav \}\}/c $MENU_HTML")

    footer_html="&copy; $YEAR $SITE_TITLE"
    template=$(echo "$template" | sed -E "/\{\{ footer \}\}/c $footer_html")

    echo "$template" | sed -E 's/\{\{.*\}\}//g'
}

for markdown_file in "$INPUT_DIR"/*.md; do

    filename=$(basename "$markdown_file" .md)
    output_file="$OUTPUT_DIR/$filename.html"

    title=""
    layout="default"
    date=""
    rank=0
    author="$AUTHOR"
    content=""
    front_matter=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "---" ]]; then
            front_matter=$((front_matter + 1))
            continue
        fi
        if [[ $front_matter -eq 1 ]]; then
            if [[ "$line" =~ ^title:\ (.*) ]]; then
                title="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^layout:\ (.*) ]]; then
                layout="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^date:\ (.*) ]]; then
                date="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^rank:\ (.*) ]]; then
                rank="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^author:\ (.*) ]]; then
                author="${BASH_REMATCH[1]}"
            fi
        elif [[ $front_matter -ge 2 ]]; then
            content+="$line"$'\n'
        fi
    done < "$markdown_file"

    [[ -z "$title" ]] && title="$filename"

    html_content=$(echo "$content" | pandoc -f markdown -t html)

    template_file="$LAYOUTS_DIR/$layout.html"
    if [[ ! -f "$template_file" ]]; then
        echo "Template $template_file not found for layout '$layout'. Defaulting to 'default.html'"
        template_file="$LAYOUTS_DIR/default.html"
    fi
    template=$(cat "$template_file")

    page_html=$(process_template "$template" "$title" "$html_content" "$date" "$author")

    echo "$page_html" > "$output_file"

    echo "Generated $output_file"
done