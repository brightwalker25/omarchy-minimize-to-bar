import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// Shelf of minimized windows.
//
// "Minimizing" is a move to Hyprland's `special:minimized` workspace. Nothing
// ever toggles that workspace visible, so a stashed window keeps running with
// its surface off screen -- the compositor equivalent of a taskbar minimize.
//
// Each stashed window shows as its app icon alone; hovering one slides its
// title out beside the icon. Left-click restores it to the current workspace
// and focuses it, middle-click closes it.
BarWidget {
  id: root
  moduleName: "brightwalker25.minimize"

  readonly property string stash: "special:minimized"
  readonly property int maxLabelWidth: Number(setting("maxLabelWidth", 180))
  readonly property bool alwaysShowLabels: setting("alwaysShowLabels", false) === true
  readonly property int iconSize: Number(setting("iconSize", Style.bar.iconCanvas))

  // Bumped once a refreshToplevels() round-trip has had time to land. The
  // model's own `values` signal is not enough on its own: a title change
  // mutates lastIpcObject in place without the list changing, so the entry
  // binding needs a dependency that can be poked explicitly.
  property int serial: 0

  readonly property var entries: {
    root.serial
    var out = []
    var values = Hyprland.toplevels ? Hyprland.toplevels.values : []
    for (var i = 0; i < values.length; i++) {
      var ipc = values[i].lastIpcObject
      if (!ipc || !ipc.workspace) continue
      if (String(ipc.workspace.name) !== root.stash) continue
      out.push({
        address: String(ipc.address || ""),
        title: String(ipc.title || ipc.class || "Window"),
        appId: String(ipc.class || ipc.initialClass || "")
      })
    }
    return out
  }

  function reload() {
    Hyprland.refreshToplevels()
    settle.restart()
  }

  // The window class is only a good icon name by coincidence; prefer the icon
  // the matching desktop entry declares and keep the class as the fallback.
  function iconFor(appId) {
    var name = appId
    try {
      var entry = DesktopEntries.byId(appId)
      if (entry && entry.icon) name = entry.icon
    } catch (e) {}
    var lib = root.bar && root.bar.shell ? root.bar.shell.appLibrary : null
    if (lib) return lib.iconSource(name)
    return Quickshell.iconPath(name, true)
  }

  function dispatch(lua) {
    return "hyprctl dispatch " + Util.shellQuote(lua)
  }

  // "+0" is the current workspace, so a window comes back where the user is
  // now rather than wherever it happened to be stashed from.
  function restore(address) {
    if (!root.bar) return
    root.bar.run(root.dispatch('hl.dsp.window.move({ window = "address:' + address + '", workspace = "+0" })')
      + " && " + root.dispatch('hl.dsp.focus({ window = "address:' + address + '" })'))
  }

  function closeWindow(address) {
    if (!root.bar) return
    root.bar.run(root.dispatch('hl.dsp.window.close({ window = "address:' + address + '" })'))
  }

  visible: entries.length > 0
  implicitWidth: visible ? shelf.implicitWidth : 0
  implicitHeight: visible ? shelf.implicitHeight : 0

  Component.onCompleted: root.reload()

  // refreshToplevels() is a request, not a read: the model repopulates a beat
  // later, so recompute once it has landed instead of immediately.
  Timer {
    id: settle
    interval: 120
    onTriggered: root.serial++
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = String(event.name || "")
      if (name.indexOf("window") !== -1 || name.indexOf("workspace") !== -1) root.reload()
    }
  }

  IpcHandler {
    target: "brightwalker25.minimize"

    function reload(): void {
      root.broadcast("reload")
    }
  }

  component MinimizedItem: Item {
    id: item

    required property var modelData

    // Vertical bars are 28px wide with no room to grow sideways, so they stay
    // icon-only and lean on the shared tooltip instead.
    // A chip that appears underneath a stationary pointer -- exactly what
    // happens when SUPER + M adds one while the mouse is resting over the bar
    // -- arrives already "hovered" and would expand without the user ever
    // moving onto it. Such a chip stays collapsed until the pointer leaves it
    // once; one created clear of the pointer is armed immediately and behaves
    // normally. (The shell ships PointerMoveGate for this same class of bug.)
    property bool armed: false
    Component.onCompleted: item.armed = !hover.hovered

    readonly property bool expanded: !root.vertical
      && (root.alwaysShowLabels || (hover.hovered && item.armed))
    readonly property real labelWidth: Math.min(root.maxLabelWidth, label.implicitWidth)

    implicitHeight: root.barSize
    implicitWidth: root.vertical
      ? root.barSize
      : Style.space(6) + root.iconSize + (expanded ? Style.space(4) + labelWidth : 0) + Style.space(6)

    Behavior on implicitWidth {
      NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    Row {
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      anchors.leftMargin: root.vertical ? Math.round((root.barSize - root.iconSize) / 2) : Style.space(6)
      spacing: item.expanded ? Style.space(4) : 0

      Image {
        width: root.iconSize
        height: root.iconSize
        anchors.verticalCenter: parent.verticalCenter
        fillMode: Image.PreserveAspectFit
        // Decode at physical pixels; the logical size leaves PNG icons
        // upscaled and blurry on a fractionally scaled panel.
        sourceSize.width: Math.round(root.iconSize * Screen.devicePixelRatio)
        sourceSize.height: Math.round(root.iconSize * Screen.devicePixelRatio)
        source: root.iconFor(item.modelData.appId)
        opacity: hover.hovered ? 1.0 : 0.75

        Behavior on opacity {
          NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
      }

      Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        width: item.expanded ? item.labelWidth : 0
        clip: true
        visible: width > 0
        text: item.modelData.title
        color: root.bar ? root.bar.barForeground : Color.bar.text
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        opacity: 0.85
      }
    }

    // HoverHandler rather than MouseArea.containsMouse: the chip resizes under
    // the pointer as it expands, and containsMouse then fails to clear when the
    // pointer moves off it along the bar, stranding the title open. The tray
    // widget reveals its drawer through a HoverHandler for the same reason.
    HoverHandler {
      id: hover
      cursorShape: Qt.PointingHandCursor

      // A horizontal bar shows the title inline, so a tooltip would only repeat
      // it. A vertical bar has no room to expand, so there it is the only label.
      onHoveredChanged: {
        if (!hovered) item.armed = true
        if (!root.bar) return
        if (hovered && root.vertical) root.bar.showTooltip(item, item.modelData.title)
        else root.bar.hideTooltip(item)
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton

      onClicked: function(mouse) {
        if (mouse.button === Qt.MiddleButton) root.closeWindow(item.modelData.address)
        else root.restore(item.modelData.address)
      }
    }
  }

  Grid {
    id: shelf
    anchors.centerIn: parent
    columns: root.vertical ? 1 : root.entries.length
    rows: root.vertical ? root.entries.length : 1
    spacing: Style.space(2)

    Repeater {
      model: root.entries
      delegate: MinimizedItem {}
    }
  }
}
