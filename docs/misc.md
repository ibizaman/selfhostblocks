<!-- Read these docs at https://shb.skarabox.com -->
# Miscellaneous {#misc}

Here goes meta-discussions around the repository and other topics not related directly to the usage of SHB.

## Lock file update {#misc-lock-file-update}

*SHB has an unusual strategy to keep up with its flake inputs. This section explains why.*

SHB only depends on `nixpkgs` as far as flake inputs goes.
There are others but they only matter for tasks around taking care of the repository itself.
So only the `nixpkgs` input is important for downstream consumers of SHB.

To keep up to date with nixpkgs unstable,
initially a job was updating the nixpkgs input by simply updating the lock file and creating a PR.
Now, this job failed most of the time because the tip of unstable often breaks modules and packages, resulting in failing SHB tests.
To fix this, we usually needed to choose a commit around 2 weeks prior to the latest unstable commit.
This usually did not lead to successful tests but the reason was then not
because of failing packages but because nixpkgs modules evolved and SHB needs to adapt to that.
The net effect was SHB was lagging too far behind unstable and updating it was becoming annoying.

The new strategy now is as follows. On every job run:

- If there is no PR, update nixpkgs input to latest unstable commit and create a PR which auto-merges when tests are successful.
- If there is a PR:
  - If the checks succeeded, do nothing because the PR will auto-merge.
  - If the checks are pending, do nothing yet.
  - If the checks failed, bisect and update nixpkgs input to between the commit on main and the commit in the PR.

The effect here is as long as the tests are failing, we'll try a commit further in the past from nixpkgs unstable
and closer to the tip of main branch.

This could be made smarter by distinguishing between types of failures.
We will see if this is needed.

One can also run the bisect manually with `nix run .#update-flake-lock-pr`.
This will create a PR on a different branch than the one used for the automated workflow.
It accepts also one argument `future` which instead of trying a commit in between the tip of SHB main and the PR's failing one,
it tries a commit between the PR's failing one and the nixpkgs unstable latest commit.
