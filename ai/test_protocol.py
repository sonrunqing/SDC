"""Fast boundary checks: python -m unittest discover -s ai -p 'test_*.py'."""
import unittest
from play import validate_action


class ProtocolChecks(unittest.TestCase):
    def test_valid_gestures(self):
        for action in ({"op": "snapshot"}, {"op": "tap", "at": [0, 1]},
                       {"op": "swipe", "from": [0, 0], "to": [1, 1], "hold_ms": 400},
                       {"op": "touch_sequence", "events": [
                           {"ms": 0, "finger": 0, "type": "down", "at": [.1, .7]},
                           {"ms": 10, "finger": 1, "type": "down", "at": [.9, .6]},
                           {"ms": 100, "finger": 0, "type": "move", "at": [.1, .5]},
                           {"ms": 200, "finger": 1, "type": "up", "at": [.9, .6]}]}):
            validate_action(action)

    def test_rejects_invalid_before_input(self):
        for action in ([], {"op": "teleport"}, {"op": "tap", "at": [1.1, 0]},
                       {"op": "tap", "at": [True, 0]}, {"op": "wait", "ms": {}},
                       {"op": "wait", "ms": float("nan")},
                       {"op": "touch_sequence", "events": [
                           {"ms": 0, "type": "down", "at": [.1, .7]},
                           {"ms": -1, "type": "up", "at": [.1, .7]}]},
                       {"op": "touch_sequence", "events": [
                           {"ms": 0, "finger": 2, "type": "move", "at": [.1, .7]}]}):
            with self.subTest(action=action), self.assertRaises(ValueError):
                validate_action(action)


if __name__ == "__main__":
    unittest.main()
