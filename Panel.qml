import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "OmaDi.sysmon"
  ipcTarget: "OmaDi.sysmon"
  // manageIpc: false so this panel owns the single IpcHandler the target permits.
  manageIpc: false

  property var stats: ({})
  property real prevRx: 0
  property real prevTx: 0
  property real prevSampleTime: 0
  property real downRate: 0
  property real upRate: 0
  property bool hasRate: false

  readonly property real cpuTemp: Model.num(stats.cpu_temp_c, -1)
  readonly property real cpuPct: Model.num(stats.cpu_pct, -1)
  readonly property real memPct: Model.num(stats.mem_pct, -1)
  readonly property real diskPct: Model.num(stats.disk_pct, -1)
  readonly property string tempGlyph: Model.tempIcon(root.cpuTemp)
  readonly property bool hasData: root.cpuTemp >= 0 || root.cpuPct >= 0
  readonly property string tooltipSummary: root.hasData
    ? (Model.formatTemp(root.cpuTemp) + " · CPU " + Model.formatPct(root.cpuPct) + " · Disk " + Model.formatPct(root.diskPct))
    : "Hardware monitor"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statsProc.running) statsProc.running = true
  }

  function updateStats(raw) {
    var next = Model.parseStats(raw)
    // Ignore empty payloads so a slow sample never blanks the dashboard.
    if (next.cpu_temp_c === -1 && next.cpu_pct === -1 && next.mem_pct === -1 && next.disk_pct === -1) return
    var t = Model.throughputState(
      { prevRx: root.prevRx, prevTx: root.prevTx, prevSampleTime: root.prevSampleTime },
      next, Date.now()
    )
    root.prevRx = t.prevRx
    root.prevTx = t.prevTx
    root.prevSampleTime = t.prevSampleTime
    root.downRate = t.downRate
    root.upRate = t.upRate
    root.hasRate = t.hasRate
    stats = next
  }

  IpcHandler {
    target: "OmaDi.sysmon"

    function open() { root.open() }
    function close() { root.close() }
    function show() { root.open() }
    function hide() { root.close() }
    function toggle() { root.toggle() }
  }

  onOpenedChanged: {
    if (opened) refresh()
  }

  Process {
    id: statsProc
    command: ["omadi-sysmon-stats"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.updateStats(text) }
  }

  Timer { interval: 2000; running: root.opened; repeat: true; onTriggered: root.refresh() }
  // Slow background refresh so the tooltip summary stays fresh while closed.
  Timer { interval: 15000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: Model.barIcon()
    slotSize: Style.bar.iconSlot
    tooltipText: root.tooltipSummary
    onPressed: function(b) {
      if (b === Qt.RightButton) root.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero: icon · title/status · temp ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, heroTemp.implicitHeight)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.tempGlyph
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: heroTemp.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Hardware"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              textFormat: Text.PlainText
              text: ("CPU " + Model.formatPct(root.cpuPct) + " · LOAD " + (stats.load1 || "--")).toUpperCase()
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          Text {
            id: heroTemp
            textFormat: Text.PlainText
            text: Model.formatTemp(root.cpuTemp)
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        // ---------- Usage bars ----------
        Column {
          width: parent.width
          spacing: Style.space(10)

          UsageBar { label: "CPU"; pct: root.cpuPct }
          UsageBar { label: "MEM"; pct: root.memPct; detail: (stats.mem_used && stats.mem_total) ? (stats.mem_used + " / " + stats.mem_total) : "" }
          UsageBar { label: "DISK"; pct: root.diskPct; detail: stats.disk_avail || "" }
        }

        // ---------- Details ----------
        Row {
          width: parent.width
          spacing: Style.space(20)

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair { label: "Fan"; value: Model.formatRpm(stats.fan_rpm) }
            InfoPair { label: "Battery"; value: Model.formatTemp(Model.num(stats.batt_temp_c, -1)) }
            InfoPair { label: "GPU temp"; value: Model.formatTemp(Model.num(stats.gpu_temp_c, -1)) }
          }

          Column {
            width: (parent.width - parent.spacing) / 2
            spacing: Style.spacing.labelGap
            InfoPair { label: "Download"; value: root.hasRate ? Model.formatRate(root.downRate) : "--" }
            InfoPair { label: "Upload"; value: root.hasRate ? Model.formatRate(root.upRate) : "--" }
            InfoPair { label: "Battery V"; value: stats.batt_voltage || "--" }
          }
        }

        PanelSeparator {
          foreground: root.bar.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: "DISK"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          InfoPair { label: "Mount"; value: stats.disk_mount || "/" }
          InfoPair { label: "Free"; value: stats.disk_avail || "--" }
          InfoPair { label: "Transferred"; value: "↓ " + Model.formatBytes(stats.net_rx_bytes) + "  ↑ " + Model.formatBytes(stats.net_tx_bytes) }
        }
      }
    }
  }

  component UsageBar: Column {
    property string label: ""
    property real pct: -1
    property string detail: ""
    width: parent.width
    spacing: Style.space(4)

    Row {
      width: parent.width
      spacing: Style.space(8)
      Text {
        textFormat: Text.PlainText
        text: label
        color: root.bar.foreground
        opacity: 0.6
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
        width: Style.space(44)
      }
      Item {
        width: parent.width - Style.space(44) - pctText.implicitWidth - parent.spacing * 2
        implicitHeight: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
        Rectangle {
          anchors.fill: parent
          radius: height / 2
          color: Qt.rgba(root.bar.foreground.r, root.bar.foreground.g, root.bar.foreground.b, 0.12)
        }
        Rectangle {
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          height: parent.height
          radius: height / 2
          color: root.bar.foreground
          width: Math.max(height, parent.width * Model.fraction(pct))
          Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        }
      }
      Text {
        id: pctText
        textFormat: Text.PlainText
        text: Model.formatPct(pct) + (detail !== "" ? " · " + detail : "")
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.bodySmall
      }
    }
  }

  component InfoPair: Row {
    property string label: ""
    property string value: ""

    width: parent.width
    spacing: Style.space(8)

    InfoLabel { text: label }
    Item { width: Math.max(0, parent.width - parent.children[0].implicitWidth - parent.children[2].implicitWidth - parent.spacing * 2); height: 1 }
    InfoValue { text: value }
  }

  component InfoLabel: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    opacity: 0.6
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  component InfoValue: Text {
    textFormat: Text.PlainText
    color: root.bar.foreground
    font.family: root.bar.fontFamily
    font.pixelSize: Style.font.bodySmall
  }
}
