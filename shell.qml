import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root
    property real px: 0
    property real py: 0
    property bool ready: false
    property bool left: false
    property double moved: Date.now()
    property double upward: 0
    property double downward: 0
    property double fast: 0
    property double sampleTime: Date.now()
    property double attacked: 0
    property int tick: 0
    property string state: "idle"
    property bool mapped: true
    Timer { id: remap; interval: 80; onTriggered: root.mapped = true }
    Process {
        command: ["python3", Qt.resolvedUrl("layers.py").toString().replace("file://", "")]
        running: true
        stdout: SplitParser { onRead: line => { root.mapped = false; remap.restart(); } }
    }
    property var frames: ({idle: [25,130,132,180,8], run: [17,355,135,180,9], fly: [20,580,135,180,7], attack: [20,810,132,180,5], sleep: [25,1000,132,180,5], dash: [695,810,137,180,4], fall: [1090,155,145,180,3]})
    property var bounds: {"idle": [[30, 148, 127, 137], [157, 147, 132, 138], [289, 149, 129, 136], [427, 149, 121, 136], [554, 150, 121, 135], [685, 143, 132, 142], [817, 139, 132, 146], [949, 150, 120, 135]], "run": [[24, 380, 128, 131], [152, 380, 135, 133], [292, 384, 129, 119], [427, 378, 128, 120], [562, 381, 130, 120], [692, 382, 129, 117], [828, 381, 134, 130], [962, 381, 135, 130], [1097, 381, 124, 133]], "fly": [[36, 619, 115, 130], [160, 613, 130, 136], [290, 602, 129, 141], [430, 587, 124, 118], [562, 584, 133, 114], [703, 613, 118, 130], [832, 633, 124, 118]], "attack": [[24, 845, 128, 114], [152, 835, 132, 125], [284, 831, 132, 132], [416, 835, 131, 123], [548, 835, 132, 123]], "sleep": [[32, 1075, 125, 89], [157, 1074, 132, 90], [289, 1077, 132, 87], [426, 1047, 124, 117], [561, 1035, 124, 129]], "dash": [[696, 856, 128, 94], [835, 854, 131, 96], [970, 857, 130, 93], [1107, 857, 130, 93]], "fall": [[1093, 173, 120, 140], [970, 606, 114, 148], [1103, 659, 118, 100]]}
    property var crop: bounds[state][Math.max(0, index) % bounds[state].length]
    property int sw: Math.max(1, Math.round(crop[2] * 0.25))
    property int sh: Math.max(1, Math.round(crop[3] * 0.25))
    // Fixed layer size: resizing every animation frame waits on a configure and
    // makes the pointer chase choppy. 34×37 is the largest frame.
    property int boxW: 34
    property int boxH: 37
    property int seq: 0
    property var frame: frames[state]
    property int index: state === "idle" ? 0 : (tick >= 0) && state === "attack" ? Math.min(4, Math.floor((Date.now()-attacked)/85)) : Math.floor(tick / (state === "sleep" ? 18 : state === "dash" ? 3 : 5)) % frame[4]
    IpcHandler {
        target: "cat"
        function attack(): void { root.attacked = Date.now() }
    }
    Process {
        command: ["python3", "-u", Qt.resolvedUrl("tracker.py").toString().replace("file://", "")]
        running: true
        stdout: SplitParser {
            onRead: line => {
                let p = JSON.parse(line), dx = p.x-root.px, dy = p.y-root.py;
                let now = Date.now(), dt = Math.max(1, now-root.sampleTime);
                if (root.ready && Math.sqrt(dx*dx+dy*dy)*1000/dt > 1200) root.fast = now;
                root.sampleTime = now;
                if (dx*dx+dy*dy > 1) {
                    root.moved = Date.now();
                    if (Math.abs(dx)>1) root.left = dx<0;
                    if (dy < -2 && Math.abs(dy)>Math.abs(dx)*0.6) root.upward = now;
                    if (dy > 2 && Math.abs(dy)>Math.abs(dx)*0.6) root.downward = now;
                }
                if (p.x !== root.px || p.y !== root.py) root.seq = (root.seq + 1) % 100000;
                root.px=p.x; root.py=p.y; root.ready=true;
            }
        }
    }
    Timer {
        interval: 16; running: true; repeat: true
        onTriggered: {
            root.tick++;
            let now=Date.now();
            root.state = now-root.attacked<425 ? "attack" : now-Math.max(root.moved, root.attacked)>300000 ? "sleep" : now-root.moved>150 ? "idle" : now-root.fast<100 ? "dash" : now-root.downward<120 && root.downward>root.upward ? "fall" : now-root.upward<120 ? "fly" : "run";
        }
    }
    Variants {
        model: Quickshell.screens
        PanelWindow {
            id: panel
            required property var modelData
            screen: modelData
            visible: root.mapped && root.ready && root.px >= modelData.x && root.py >= modelData.y && root.px < modelData.x + modelData.width && root.py < modelData.y + modelData.height
            anchors { top: true; left: true }
            margins {
                left: Math.round(root.px - modelData.x - root.boxW / 2)
                top: Math.round(root.py - modelData.y - (root.boxH - 16))
            }
            implicitWidth: root.boxW
            implicitHeight: root.boxH
            color: "transparent"
            surfaceFormat.opaque: false
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "cat-cursor"
            mask: Region {}
            Image {
                // seq keeps the item dirty so the new margin is committed this
                // frame. The shift stays under 0.01 px.
                x: Math.round((root.boxW - width) / 2) + (root.seq % 1000) * 0.00001
                y: root.boxH - height
                width: root.sw
                height: root.sh
                source: "cat-mister-actions.png"
                sourceClipRect: Qt.rect(root.crop[0], root.crop[1], root.crop[2], root.crop[3])
                smooth: false
                mirror: root.left
                cache: true
            }
        }
    }
}
