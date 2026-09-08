# RemotiveTopology hackathon — day-2 setup. Run this ONCE per box, after copying this
# folder over from day-1 (see participant/INSTRUCTIONS.md step 4).
#
#   source ~/aws-hackathon/participant/setup-day2.sh
#
# It does three things and then prints a self-check:
#
#   1. Authentication — sources the sibling `remotive-auth`, which puts the service-account
#      token in this shell and in ~/.ssh/environment (so every future SSH session, including
#      the non-interactive commands Kiro/VS Code Remote-SSH run, has it too).
#   2. Kiro context — symlinks the examples checkout's `.kiro` at this folder's `.kiro`, so the
#      hackathon steering and specs load in the workspace where you actually edit code. A
#      symlink keeps a single source of truth here in aws-hackathon: edit once, rsync again,
#      and the examples repo picks it up with no files copied into it.
#   3. Keeps `git status` in the examples repo quiet by adding `.kiro/` to its local
#      .git/info/exclude (a local-only git file, not repo content).
#
# Safe to re-run: it is idempotent and never overwrites a real .kiro directory.
#
# MUST be sourced, not executed — step 1 needs to export into your current shell.

# --- locate this folder (works from any copy path) ----------------------------------------
if [ -n "${BASH_SOURCE:-}" ]; then
  _s2_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
else
  echo "setup-day2.sh: please run this with bash and 'source', e.g."
  echo "  source ~/aws-hackathon/participant/setup-day2.sh"
  return 1 2>/dev/null || exit 1
fi

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  echo "setup-day2.sh: this script must be SOURCED so it can set the token in your shell:"
  echo "  source ${BASH_SOURCE[0]}"
  exit 1
fi

_s2_hackathon="$(cd "${_s2_here}/.." && pwd)"                       # ~/aws-hackathon
_s2_examples="${REMOTIVE_EXAMPLES_DIR:-$HOME/remotivelabs-topology-examples}"

echo "RemotiveTopology hackathon — day-2 setup"
echo "  hackathon folder : ${_s2_hackathon}"
echo "  examples repo    : ${_s2_examples}"
echo

# --- 1. authentication --------------------------------------------------------------------
if [ -f "${_s2_here}/remotive-auth" ]; then
  # shellcheck disable=SC1090,SC1091
  . "${_s2_here}/remotive-auth"
else
  echo "  ! remotive-auth not found next to this script — did the folder copy finish?"
fi

# --- 2. Kiro context: .kiro symlink into the examples checkout -----------------------------
_s2_link="${_s2_examples}/.kiro"
_s2_target="${_s2_hackathon}/.kiro"

if [ ! -d "${_s2_examples}" ]; then
  echo "  ! examples repo not found at ${_s2_examples}"
  echo "    set REMOTIVE_EXAMPLES_DIR=/path/to/remotivelabs-topology-examples and source again"
elif [ ! -d "${_s2_target}" ]; then
  echo "  ! no .kiro found at ${_s2_target} — did the folder copy include hidden files?"
elif [ -L "${_s2_link}" ] || [ ! -e "${_s2_link}" ]; then
  ln -sfn "${_s2_target}" "${_s2_link}"
else
  echo "  ! ${_s2_link} exists and is a real directory — leaving it alone."
  echo "    Move it aside and source this script again to use the hackathon context:"
  echo "      mv ${_s2_link} ${_s2_link}.bak"
fi

# --- 3. somewhere to keep your own artifacts ----------------------------------------------
# RemotiveStudio can only save dashboards inside its workspace, and the workspace has to be the
# examples repo for the Files sidebar to show the platform files. So give the repo a `dashboards`
# entry that actually lives here in aws-hackathon — Save As into it and your work is kept with
# the hackathon folder, not in the examples checkout.
_s2_dashboards="${_s2_hackathon}/participant/dashboards"
mkdir -p "${_s2_dashboards}"
_s2_dash_link="${_s2_examples}/dashboards"
if [ -d "${_s2_examples}" ] && { [ -L "${_s2_dash_link}" ] || [ ! -e "${_s2_dash_link}" ]; }; then
  ln -sfn "${_s2_dashboards}" "${_s2_dash_link}"
fi

# --- 4. keep the examples repo's git status quiet ------------------------------------------
# Note: no trailing slashes. `.kiro` and `dashboards` are SYMLINKS, and git does not match a
# symlink against a directory pattern (`.kiro/`), so that variant would leave them visible.
_s2_exclude="${_s2_examples}/.git/info/exclude"
if [ -d "${_s2_examples}/.git/info" ]; then
  for _s2_pat in '.kiro' 'dashboards' '*.dashboard.json'; do
    if ! grep -qxF "${_s2_pat}" "${_s2_exclude}" 2>/dev/null; then
      printf '%s\n' "${_s2_pat}" >>"${_s2_exclude}"
    fi
  done
  unset _s2_pat
fi

# --- self-check ----------------------------------------------------------------------------
echo
if [ -n "${REMOTIVE_CLOUD_AUTH_TOKEN:-}" ]; then
  echo "  [ok]   cloud token   : set (org=${REMOTIVE_CLOUD_ORGANIZATION:-?}), also in ~/.ssh/environment"
else
  echo "  [FAIL] cloud token   : not set — check ${_s2_here}/service-account.json"
fi

if [ "$(readlink -f "${_s2_link}" 2>/dev/null)" = "$(readlink -f "${_s2_target}" 2>/dev/null)" ]; then
  echo "  [ok]   Kiro context  : ${_s2_link} -> ${_s2_target}"
else
  echo "  [FAIL] Kiro context  : ${_s2_link} does not point at ${_s2_target}"
fi

if [ "$(readlink -f "${_s2_dash_link}" 2>/dev/null)" = "$(readlink -f "${_s2_dashboards}" 2>/dev/null)" ]; then
  echo "  [ok]   dashboards    : ${_s2_dash_link} -> ${_s2_dashboards}"
else
  echo "  [warn] dashboards    : ${_s2_dash_link} not linked — Studio saves will land in the repo"
fi

if [ -d "${_s2_examples}/.git" ]; then
  if git -C "${_s2_examples}" status --short 2>/dev/null | grep -qE '\.kiro|dashboards|\.dashboard\.json'; then
    echo "  [FAIL] git status    : hackathon entries show up as untracked in the examples repo"
  else
    echo "  [ok]   git status    : examples repo clean of hackathon entries (excluded locally)"
  fi
fi

if [ -e /dev/kvm ]; then
  echo "  [ok]   /dev/kvm      : present (Android/Cuttlefish can boot)"
else
  echo "  [warn] /dev/kvm      : missing — Cuttlefish will not boot. Launch the instance with"
  echo "                         --cpu-options NestedVirtualization=enabled on c8i/m8i/r8i."
fi

echo
echo "  Next: open ${_s2_examples} in Kiro (Remote-SSH) and start the lab:"
echo "        ${_s2_here}/LAB.md"
echo

unset _s2_here _s2_hackathon _s2_examples _s2_link _s2_target _s2_exclude \
  _s2_dashboards _s2_dash_link
