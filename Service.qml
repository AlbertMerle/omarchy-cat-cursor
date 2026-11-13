import QtQuick
import Quickshell.Io

// Thin Omarchy shell hook. The cat itself still runs as its own Quickshell
// process via the user systemd unit installed by ./install.sh.
Item {
  Process {
    command: ["systemctl", "--user", "start", "cat-cursor.service"]
    running: true
  }
}
