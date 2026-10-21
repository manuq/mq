# Bash completion for mq, the wrapper around ~/.local/share/just/manuq.just.
# Completes recipe and module names, then file names for recipe arguments,
# for example: mq emacs <TAB>
_mq_complete() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    local recipes
    recipes=$(just --justfile ~/.local/share/just/manuq.just --summary 2>/dev/null) || return

    # Module recipes are listed as module::recipe, but mq runs them as
    # "mq module recipe", so complete them as two separate words.
    local top=() modules=() r
    for r in $recipes; do
        if [[ $r == *::* ]]; then
            [[ " ${modules[*]} " == *" ${r%%::*} "* ]] || modules+=("${r%%::*}")
        else
            top+=("$r")
        fi
    done

    if ((COMP_CWORD == 1)); then
        mapfile -t COMPREPLY < <(compgen -W "${top[*]} ${modules[*]}" -- "$cur")
        return
    fi

    local first=${COMP_WORDS[1]}
    if ((COMP_CWORD == 2)) && [[ " ${modules[*]} " == *" $first "* ]]; then
        local sub=()
        for r in $recipes; do
            [[ $r == "$first"::* ]] && sub+=("${r#"$first"::}")
        done
        mapfile -t COMPREPLY < <(compgen -W "${sub[*]}" -- "$cur")
        return
    fi

    # Recipe arguments: fall back to bash's default file name completion.
    compopt -o default
    COMPREPLY=()
}
complete -F _mq_complete mq
