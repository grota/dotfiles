"""Rebuild the PM venv with an explicit target extra list (supports removal).

Mirrors sync_venv/_commit_selection (fresh generation via Venv.apply, stamp
via Venv.expected_stamp, commit via Facts.record_state) but takes TARGET as
the full desired set instead of unioning onto the recorded one.

Usage: run with the install's SELECTED venv python, cwd at the repo root:

    <selected-venv>/bin/python rebuild_without_extra.py all edge-tts telegram

The target list is argv (no default) so removal is deliberate, never a
forgotten constant.
"""
import sys

sys.path.insert(0, "/home/grota/.hermes/hermes-agent")


def main() -> None:
    target = sorted(set(sys.argv[1:]))
    if not target:
        raise SystemExit("usage: rebuild_without_extra.py <extra> [<extra> ...]")
    from pm import receipt
    from pm.environments import flush_before_selecting
    from pm.install import _venv_install_lock, venv_is_current
    from pm.lock import Facts
    from pm.paths import repo_root, runtime_facts_path
    from pm.registry import get_package

    root = repo_root()
    print("repo root:", root, flush=True)
    before = (Facts(runtime_facts_path()).get("venv") or {}).get("extras")
    print("recorded extras before:", before, flush=True)
    print("target extras:", target, flush=True)

    token = receipt.begin("sync")
    outcome = "failed"
    try:
        package = get_package("venv")
        with _venv_install_lock(patient=True):
            from hermes_cli.runtime_state import recover_publication

            recover_publication(root)
            result = package.apply(list(target), explicit=True)
            print("built generation:", result.get("environment"), flush=True)
            stamp = package.expected_stamp(list(target))
            print("new stamp:", stamp[:16], flush=True)
            if result.get("environment") is not None:
                flush_before_selecting()
            facts = Facts(runtime_facts_path())
            facts.record_state(
                "venv",
                stamp,
                list(target),
                environment=result.get("environment"),
                resolved_lock=result.get("resolved_lock"),
            )
            print("selection recorded", flush=True)
        try:
            receipt.record_feature_list(list(target))
            receipt.record_venv_rebuild(True, "extra set rebuilt via Venv.apply")
        except Exception as exc:
            print("receipt note failed (ignored):", exc, flush=True)
        outcome = "ok"
    finally:
        try:
            receipt.finalize(outcome, 0 if outcome == "ok" else 1, token=token)
        except Exception as exc:
            print("receipt finalize failed (ignored):", exc, flush=True)

    if outcome != "ok":
        raise SystemExit(1)
    print("venv_is_current:", venv_is_current(), flush=True)
    after = (Facts(runtime_facts_path()).get("venv") or {}).get("extras")
    print("recorded extras after:", after, flush=True)


if __name__ == "__main__":
    main()
