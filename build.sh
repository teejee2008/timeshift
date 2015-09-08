
make 2>&1 | grep -E --color=never 'error:|.vala:.*warning:' | grep -E --color=always "error:|$"
