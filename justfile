format:
    nix fmt -- $(fd '^[^.]*\.nix$' .)

# Run checks (default: fast). Usage: just check [fast|all|--all|--fast]
check mode="fast": format
    @case "{{mode}}" in \
        all|--all) just check-all ;; \
        fast|--fast) just check-fast ;; \
        *) echo "Unknown mode: '{{mode}}'. Valid options are: fast, all" >&2; exit 1 ;; \
    esac

check-fast:
    nix flake check --quiet --show-trace

check-all:
    nix build ".#all-checks" --no-link -L
