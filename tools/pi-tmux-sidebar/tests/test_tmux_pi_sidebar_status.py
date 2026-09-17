import os
import runpy
import types
import unittest

SIDEBAR_PATH = os.path.join(os.path.dirname(__file__), "..", "tmux-pi-sidebar")

SIDEBAR = runpy.run_path(
    SIDEBAR_PATH,
    run_name="tmux_pi_sidebar_status_test",
)


def make_pane(status="completed", title="π - Active task - src"):
    parts = [
        "main",         # 0  session
        "1",            # 1  window_index
        "name",         # 2  window_name
        "1",            # 3  pane_index
        "%test",        # 4  pane_id
        "12345",        # 5  pane_pid
        title,          # 6  title
        "omp",          # 7  command
        "/tmp",         # 8  path
        "Active task",  # 9  pi_name
        status,         # 10 pi_status
        "",             # 11 joust_active_until
        "",             # 12 slack_user
        "",             # 13 manual_unread
        "",             # 14 sidebar_kind
        "1",            # 15 pane_active
        "1",            # 16 window_active
        "1",            # 17 session_attached
        "0",            # 18 session_last_attached
        "",             # 19 freeze_state
        "",             # 20 freeze_resume_id
        "",             # 21 freeze_cwd
        "",             # 22 freeze_last_activity
        "",             # 23 freeze_summary
        "",             # 24 frozen_at
        "",             # 25 freeze_prompt_active
        "",             # 26 freeze_resume_started
    ]
    pane = SIDEBAR["Pane"](parts)
    pane.live_omp = True
    return pane


class ScreenBusyStatusTest(unittest.TestCase):
    def test_screen_spinner_overrides_completed_status(self):
        pane = make_pane()
        detect_screen_busy = SIDEBAR["detect_screen_busy"]
        function_globals = detect_screen_busy.__globals__
        original_run = function_globals["subprocess"].run
        function_globals["subprocess"].run = lambda *args, **kwargs: types.SimpleNamespace(
            returncode=0,
            stdout="\n    ⠏ 25m > GPT-6 Astra\n",
        )
        try:
            detect_screen_busy([pane])
        finally:
            function_globals["subprocess"].run = original_run

        self.assertTrue(pane.screen_busy)
        self.assertEqual(pane.display_status, "working")

    def test_idle_prompt_keeps_completed_status(self):
        pane = make_pane()
        detect_screen_busy = SIDEBAR["detect_screen_busy"]
        function_globals = detect_screen_busy.__globals__
        original_run = function_globals["subprocess"].run
        function_globals["subprocess"].run = lambda *args, **kwargs: types.SimpleNamespace(
            returncode=0,
            stdout="\n    π > GPT-6 Astra\n",
        )
        try:
            detect_screen_busy([pane])
        finally:
            function_globals["subprocess"].run = original_run

        self.assertFalse(pane.screen_busy)
        self.assertEqual(pane.display_status, "done")


if __name__ == "__main__":
    unittest.main()
