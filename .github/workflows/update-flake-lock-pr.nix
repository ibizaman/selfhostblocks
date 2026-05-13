{
  gh,
  writeShellApplication,
}:
writeShellApplication {
  name = "update-flake-lock-pr";
  runtimeInputs = [
    gh
  ];
  text = ''
    branch=ci/nixpkgs-update
    if [ "''${GITHUB_EVENT_NAME:-}" = "schedule" ]; then
      branch=ci/nixpkgs-update-auto
    fi

    goto_future=no
    if [ -n "''${1:-}" ]; then
      goto_future=yes
    fi

    main () {
      PR=$(get_pr)

      if [ -z "$PR" ]; then
        create_pr
        exit 0
      fi

      case "$(get_pr_check_status "$PR")" in
        pending)
          echo "Checks are running on PR $PR, nothing to do yet."
          exit 0
          ;;

        succeeded)
          echo "Checks succeeded, nothing to do."
          exit 0
          ;;

        failing)
          echo "Checks failed, updating PR to midpoint commit."

          local CURRENT_COMMIT
          local LAST_WORKING_COMMIT
          local FAILING_COMMIT
          local NEW_COMMIT

          CURRENT_COMMIT="$(get_main_branch_commit)"
          if [ "$goto_future" = "no" ]; then
            LAST_WORKING_COMMIT="$CURRENT_COMMIT"
            FAILING_COMMIT="$(get_pr_commit "$PR")"
          else
            LAST_WORKING_COMMIT="$(get_pr_commit "$PR")"
            FAILING_COMMIT="$(get_latest_nixpkgs_commit)"
          fi
          NEW_COMMIT="$(midpoint_commit "$LAST_WORKING_COMMIT" "$FAILING_COMMIT")"

          if [ "$NEW_COMMIT" = "$LAST_WORKING_COMMIT" ] || [ "$NEW_COMMIT" = "$FAILING_COMMIT" ]; then
            NEW_COMMIT="$(get_latest_nixpkgs_commit)"
          fi

          if [ "$NEW_COMMIT" = "$FAILING_COMMIT" ]; then
            echo "Latest nixpkgs commit is still same failing commit, will retry later."
            exit 0
          fi

          update_pr "$PR" "$CURRENT_COMMIT" "$NEW_COMMIT"
          exit 0
          ;;
      esac
    }

    get_main_branch_commit() {
      git fetch origin main

      git show origin/main:flake.lock \
        | jq -r '.nodes.nixpkgs.locked.rev'
    }

    midpoint_commit() {
      local good="$1"
      local bad="$2"

      mkdir -p .cache
      if [ ! -d .cache/nixpkgs.git ]; then
        git clone --mirror https://github.com/NixOS/nixpkgs.git .cache/nixpkgs.git
      else
        git --git-dir=.cache/nixpkgs.git fetch origin
      fi

      local commits=()

      mapfile -t commits < <(
        git --git-dir=.cache/nixpkgs.git \
          rev-list \
          --reverse \
          --ancestry-path \
          "''${good}..''${bad}"
      )

      local count="''${#commits[@]}"

      if [ "$count" -eq 0 ]; then
        echo "$bad"
        return
      fi

      local midpoint_index=$((count / 2))

      echo "''${commits[$midpoint_index]}"
    }

    get_latest_nixpkgs_commit () {
      git ls-remote https://github.com/NixOS/nixpkgs nixos-unstable | cut -f1
    }

    get_pr () {
      gh pr list \
        --head "$branch" \
        --state open \
        --json number \
        --jq '.[0].number // empty'
    }

    create_pr() {
      local test_commit

      test_commit="$(get_latest_nixpkgs_commit)"
      echo "Creating PR on nixpkgs' latest commit $test_commit"

      git checkout -B "$branch"

      nix flake lock \
        --override-input nixpkgs "github:NixOS/nixpkgs/$test_commit"

      git add flake.lock

      git commit -m "update nixpkgs to $test_commit"

      git push -u origin "$branch" --force

      current_commit="$(get_main_branch_commit)"
      gh pr create \
        --title "update nixpkgs to $test_commit" \
        --body "$(printf "%s\n\n%s" "Automated nixpkgs update. Latest tries:" " - https://github.com/NixOS/nixpkgs/compare/$current_commit...$test_commit")" \
        --label automerge-merge
    }

    append_pr_body() {
      local pr="$1"
      local text="$2"

      local current_body

      current_body="$(gh pr view "$pr" --json body --jq .body)"

      gh pr edit "$pr" \
        --body "$(printf '%s%b' "$current_body" "$text")"
    }

    update_pr() {
      local pr="$1"
      local current_commit="$2"
      local test_commit="$3"

      echo "Updating PR to nixpkgs' commit $test_commit"

      git checkout "$branch"

      nix flake lock \
        --override-input nixpkgs "github:NixOS/nixpkgs/$test_commit"

      git add flake.lock

      git commit -m "update nixpkgs to $test_commit"

      git push --force-with-lease origin "$branch"

      local future_text
      if [ "$goto_future" = "yes" ]; then
        future_text="bisected in the future"
      else
        future_text="bisected in the past"
      fi

      gh pr edit "$pr" \
        --title "update nixpkgs to $test_commit"

      append_pr_body "$pr" \
        " ❌\n - https://github.com/NixOS/nixpkgs/compare/$current_commit...$test_commit ($future_text)"
    }

    get_pr_check_status() {
      local pr="$1"

      local status
      status="$(gh pr checks "$pr" --json state --jq '.[].state' || true)"

      if echo "$status" | grep -qE 'PENDING|QUEUED|IN_PROGRESS'; then
        echo "pending"
        return
      fi

      if echo "$status" | grep -qE 'FAILURE|TIMED_OUT|CANCELLED'; then
        echo "failing"
        return
      fi

      echo "success"
    }

    get_pr_commit() {
      local pr="$1"

      git fetch origin "$branch"

      git show "origin/$branch:flake.lock" \
        | jq -r '.nodes.nixpkgs.locked.rev'
    }

    main
  '';
}
