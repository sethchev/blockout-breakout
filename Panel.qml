import Quickshell
import QtQuick
import qs.Commons

Item {
  id: root

  property bool opened: false
  property bool closingFromHost: false
  readonly property string selfId: "sethchev.blockout-breakout"
  property var shell: null

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property color accent: Color.accent
  property color urgent: Color.urgent
  property string fontFamily: Style.font.menuFamily

  property int score: 0
  property int lives: 3
  property int level: 1
  property int bricksLeft: 0
  property string phase: "ready" // ready, playing, paused, won, lost
  property bool leftHeld: false
  property bool rightHeld: false
  property real paddleX: 0.5
  property real ballX: 0.5
  property real ballY: 0.78
  property real ballVX: 0.32
  property real ballVY: -0.42
  property var bricks: []
  property int specialBrickIndex: -1
  property int specialBrickHealth: 0
  property bool giftActive: false
  property real giftX: 0
  property real giftY: 0
  property bool launchersActive: false
  property var bullets: []
  property real lastShotMs: 0

  readonly property int brickRows: 6
  readonly property int brickColumns: 10
  readonly property int brickCount: root.brickRows * root.brickColumns
  readonly property int maxLevels: 10
  readonly property real paddleWidth: 0.095744
  readonly property real paddleHeight: 0.025
  // Ball size is measured against the playfield height so its rendered width
  // and height remain equal even when the window is not square.
  readonly property real ballSize: 0.0242
  readonly property real giftSize: 0.028
  readonly property real giftFallSpeed: 0.204
  readonly property real bulletSpeed: 0.8
  readonly property real speedMultiplier: 1.02 * 1.05 * 1.05

  function open(payloadJson) {
    root.closingFromHost = false
    root.opened = true
    root.resetGame()
    win.visible = true
    Qt.callLater(function() {
      keyCatcher.forceActiveFocus()
    })
  }

  function close() {
    if (!root.opened && !win.visible) return
    root.closingFromHost = true
    root.opened = false
    root.stopGame()
    win.visible = false
    root.closingFromHost = false
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.selfId)
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  function resetBricks() {
    var next = []
    for (var i = 0; i < root.brickCount; i++) next.push(true)
    root.bricks = next
    root.bricksLeft = root.brickCount
    root.specialBrickIndex = Math.floor(Math.random() * root.brickCount)
    root.specialBrickHealth = 3
  }

  function resetGame() {
    root.level = 1
    root.score = 0
    root.lives = 3
    root.paddleX = 0.5
    root.giftActive = false
    root.launchersActive = false
    root.bullets = []
    root.lastShotMs = 0
    root.resetBricks()
    root.resetBall()
    root.phase = "ready"
  }

  function levelSpeedMultiplier() {
    return root.speedMultiplier * Math.pow(1.1, root.level - 1)
  }

  function resetBall() {
    var speed = root.levelSpeedMultiplier()
    root.ballX = 0.5
    root.ballY = 0.78
    root.ballVX = (Math.random() > 0.5 ? 1 : -1) * 0.32 * speed
    root.ballVY = -0.42 * speed
  }

  function advanceLevel() {
    root.bullets = []
    if (root.level >= root.maxLevels) {
      root.phase = "won"
      return
    }
    root.level++
    root.resetBricks()
    root.resetBall()
    root.phase = "playing"
  }

  function stopGame() {
    root.leftHeld = false
    root.rightHeld = false
  }

  function launch() {
    if (root.phase === "playing") root.phase = "paused"
    else if (root.phase === "ready" || root.phase === "paused") root.phase = "playing"
  }

  function brickRect(index) {
    var col = index % root.brickColumns
    var row = Math.floor(index / root.brickColumns)
    var gap = 0.008
    var width = (0.88 - gap * (root.brickColumns - 1)) / root.brickColumns
    return { x: 0.06 + col * (width + gap), y: 0.12 + row * 0.055, w: width, h: 0.038 }
  }

  function spawnGift(index) {
    var block = root.brickRect(index)
    root.giftX = block.x + block.w / 2
    root.giftY = block.y + block.h / 2
    root.giftActive = true
  }

  function damageBrick(index) {
    if (index < 0 || index >= root.brickCount || !root.bricks[index])
      return { hit: false, destroyed: false, levelEnded: false }

    if (index === root.specialBrickIndex && root.specialBrickHealth > 1) {
      root.specialBrickHealth--
      return { hit: true, destroyed: false, levelEnded: false }
    }

    var updated = root.bricks.slice(0)
    updated[index] = false
    root.bricks = updated
    root.bricksLeft--

    var brickRow = Math.floor(index / root.brickColumns)
    root.score += root.brickRows - brickRow
    if (index === root.specialBrickIndex) {
      root.specialBrickHealth = 0
      root.spawnGift(index)
    }

    var rowCleared = true
    var rowStart = brickRow * root.brickColumns
    for (var column = 0; column < root.brickColumns; column++) {
      if (updated[rowStart + column]) {
        rowCleared = false
        break
      }
    }
    if (rowCleared) root.score += 10

    if (root.bricksLeft <= 0) {
      root.advanceLevel()
      return { hit: true, destroyed: true, levelEnded: true }
    }
    return { hit: true, destroyed: true, levelEnded: false }
  }

  function fireLaunchers() {
    if (!root.launchersActive || root.phase !== "playing") return
    var now = Date.now()
    if (now - root.lastShotMs < 180) return
    root.lastShotMs = now
    var next = root.bullets.slice(0)
    var offset = root.paddleWidth * 0.48
    next.push({ x: root.paddleX - offset, y: 0.885 })
    next.push({ x: root.paddleX + offset, y: 0.885 })
    root.bullets = next
  }

  function updateGift(dt) {
    if (!root.giftActive) return
    root.giftY += root.giftFallSpeed * dt
    var aspect = playfield.width / Math.max(1, playfield.height)
    var halfWidth = root.giftSize / (2 * aspect)
    var halfHeight = root.giftSize / 2
    var paddleLeft = root.paddleX - root.paddleWidth / 2
    var paddleRight = root.paddleX + root.paddleWidth / 2
    if (root.giftY + halfHeight >= 0.89
        && root.giftY - halfHeight <= 0.89 + root.paddleHeight
        && root.giftX + halfWidth >= paddleLeft
        && root.giftX - halfWidth <= paddleRight) {
      root.giftActive = false
      root.launchersActive = true
      return
    }
    if (root.giftY - halfHeight > 1) root.giftActive = false
  }

  function updateBullets(dt) {
    if (root.bullets.length === 0) return false
    var aspect = playfield.width / Math.max(1, playfield.height)
    var halfWidth = 0.003 / aspect
    var halfHeight = 0.009
    var nextBullets = []
    for (var bulletIndex = 0; bulletIndex < root.bullets.length; bulletIndex++) {
      var bullet = root.bullets[bulletIndex]
      var nextY = bullet.y - root.bulletSpeed * dt
      var hitIndex = -1
      for (var brickIndex = root.brickCount - 1; brickIndex >= 0; brickIndex--) {
        if (!root.bricks[brickIndex]) continue
        var block = root.brickRect(brickIndex)
        if (bullet.x + halfWidth < block.x || bullet.x - halfWidth > block.x + block.w
            || nextY + halfHeight < block.y || nextY - halfHeight > block.y + block.h) continue
        hitIndex = brickIndex
        break
      }
      if (hitIndex >= 0) {
        var result = root.damageBrick(hitIndex)
        if (result.levelEnded) {
          root.bullets = []
          return true
        }
      } else if (nextY + halfHeight > 0) {
        nextBullets.push({ x: bullet.x, y: nextY })
      }
    }
    root.bullets = nextBullets
    return false
  }

  function update(dt) {
    var paddleSpeed = 0.78
    if (root.leftHeld) root.paddleX -= paddleSpeed * dt
    if (root.rightHeld) root.paddleX += paddleSpeed * dt
    root.paddleX = Math.max(root.paddleWidth / 2, Math.min(1 - root.paddleWidth / 2, root.paddleX))

    if (root.phase !== "playing") return

    root.updateGift(dt)
    if (root.updateBullets(dt)) return

    var oldX = root.ballX
    var oldY = root.ballY
    var nextX = oldX + root.ballVX * dt
    var nextY = oldY + root.ballVY * dt
    var radiusY = root.ballSize / 2
    var aspect = playfield.width / Math.max(1, playfield.height)
    var radiusX = radiusY / aspect

    if (nextX < radiusX) { nextX = radiusX; root.ballVX = Math.abs(root.ballVX) }
    if (nextX > 1 - radiusX) { nextX = 1 - radiusX; root.ballVX = -Math.abs(root.ballVX) }
    if (nextY < radiusY) { nextY = radiusY; root.ballVY = Math.abs(root.ballVY) }

    var paddleY = 0.89
    var paddleLeft = root.paddleX - root.paddleWidth / 2
    var paddleRight = root.paddleX + root.paddleWidth / 2
    var paddleRadius = root.paddleHeight / 2
    var paddleCenterY = paddleY + paddleRadius

    // Work in playfield-height units so the circular ball and the paddle's
    // semicircular ends stay circular in the collision math too. Normalized X
    // coordinates are wider on screen and therefore need the aspect factor.
    var lineLeft = paddleLeft * aspect + paddleRadius
    var lineRight = paddleRight * aspect - paddleRadius
    var nextWorldX = nextX * aspect
    var closestWorldX = Math.max(lineLeft, Math.min(lineRight, nextWorldX))
    var dx = nextWorldX - closestWorldX
    var dy = nextY - paddleCenterY
    var collisionRadius = paddleRadius + radiusY
    var distanceSquared = dx * dx + dy * dy
    if (distanceSquared <= collisionRadius * collisionRadius) {
      var distance = Math.sqrt(distanceSquared)
      var normalX = distance > 0.000001 ? dx / distance : 0
      var normalY = distance > 0.000001 ? dy / distance : -1
      var worldVX = root.ballVX * aspect
      var worldVY = root.ballVY
      var incomingSpeed = Math.sqrt(worldVX * worldVX + worldVY * worldVY)
      var approachSpeed = worldVX * normalX + worldVY * normalY
      if (approachSpeed < 0) {
        // Move the ball back to the capsule surface before reflecting it so a
        // shallow hit cannot remain embedded and bounce repeatedly.
        nextWorldX = closestWorldX + normalX * collisionRadius
        nextX = nextWorldX / aspect
        nextY = paddleCenterY + normalY * collisionRadius
        worldVX -= 2 * approachSpeed * normalX
        worldVY -= 2 * approachSpeed * normalY

        // Keep the familiar player-controlled deflection, then restore the
        // incoming speed so angled curved-end hits never speed up or slow down.
        worldVX += (nextX - root.paddleX) * aspect * 0.45
        var reflectedSpeed = Math.sqrt(worldVX * worldVX + worldVY * worldVY)
        root.ballVX = worldVX / reflectedSpeed * incomingSpeed / aspect
        root.ballVY = worldVY / reflectedSpeed * incomingSpeed
      }
    }

    for (var i = 0; i < root.brickCount; i++) {
      if (!root.bricks[i]) continue
      var b = root.brickRect(i)
      if (nextX + radiusX < b.x || nextX - radiusX > b.x + b.w
          || nextY + radiusY < b.y || nextY - radiusY > b.y + b.h) continue
      var result = root.damageBrick(i)
      if (result.levelEnded) return
      if (oldY + radiusY <= b.y || oldY - radiusY >= b.y + b.h) root.ballVY *= -1
      else root.ballVX *= -1
      break
    }

    if (nextY > 1.02) {
      root.lives--
      root.giftActive = false
      root.launchersActive = false
      root.bullets = []
      if (root.lives <= 0) {
        root.phase = "lost"
      } else {
        root.resetBall()
        root.phase = "ready"
      }
      return
    }
    root.ballX = nextX
    root.ballY = nextY
  }

  Timer {
    id: gameTimer
    interval: 16
    running: root.opened && root.phase === "playing"
    repeat: true
    onTriggered: root.update(interval / 1000)
  }

  Component.onCompleted: root.resetGame()

  FloatingWindow {
    id: win
    visible: root.opened
    title: "blockout breakout"
    color: root.background
    implicitWidth: root.implicitWidth
    implicitHeight: root.implicitHeight
    minimumSize: Qt.size(620, 420)
    onVisibleChanged: {
      if (!visible && !root.closingFromHost && root.opened)
        root.close()
    }

    Shortcut {
      sequence: "Space"
      enabled: root.opened
      onActivated: root.launch()
    }

    FocusScope {
      id: keyCatcher
      anchors.fill: parent
      focus: root.opened
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Left || event.key === Qt.Key_A) { root.leftHeld = true; event.accepted = true }
      else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) { root.rightHeld = true; event.accepted = true }
      else if (event.key === Qt.Key_Alt) { root.fireLaunchers(); event.accepted = true }
      else if (event.key === Qt.Key_R) { root.resetGame(); event.accepted = true }
      else if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
    }
    Keys.onReleased: function(event) {
      if (event.key === Qt.Key_Left || event.key === Qt.Key_A) { root.leftHeld = false; event.accepted = true }
      else if (event.key === Qt.Key_Right || event.key === Qt.Key_D) { root.rightHeld = false; event.accepted = true }
    }

    Rectangle {
      anchors.fill: parent
      color: root.background
      border.color: root.border
      border.width: 1
      radius: Style.cornerRadius
    }

    Column {
      anchors.fill: parent
      anchors.margins: Style.spacing.panelPadding
      spacing: Style.spacing.sm

      Row {
        width: parent.width
        spacing: Style.spacing.lg
        Text { text: "BLOCKOUT BREAKOUT"; color: root.accent; font.family: root.fontFamily; font.bold: true; font.pixelSize: Style.font.heading }
        Text { text: "SCORE " + root.score; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
        Text { text: "LEVEL " + root.level + "/" + root.maxLevels; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
        Text { text: "LIVES " + root.lives; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
        Text { text: "←/A  →/D   SPACE pause/start   ALT fire   R restart   ESC close"; color: root.foreground; opacity: 0.65; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
      }

      Item {
        id: playfield
        width: parent.width
        height: Math.max(260, parent.height - 42)
        clip: true

        Rectangle { anchors.fill: parent; color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.025); border.color: root.border; border.width: 1 }

        Repeater {
          model: root.brickCount
          delegate: Rectangle {
            required property int index
            property var block: root.brickRect(index)
            property bool isSpecial: index === root.specialBrickIndex
            x: block.x * playfield.width
            y: block.y * playfield.height
            width: block.w * playfield.width
            height: block.h * playfield.height
            visible: root.bricks[index] === true
            radius: isSpecial ? 4 : 2
            color: isSpecial ? "#8edfff" : ["#e06c75", "#d19a66", "#e5c07b", "#98c379", "#61afef", "#c678dd"][Math.floor(index / root.brickColumns)]
            border.color: isSpecial ? "#e8fbff" : "transparent"
            border.width: isSpecial ? 2 : 0
            opacity: 0.9

            Rectangle {
              visible: parent.isSpecial
              x: 4
              y: 3
              width: parent.width * 0.55
              height: 2
              radius: 1
              color: "#ffffff"
              opacity: 0.75
            }
            Text {
              visible: parent.isSpecial
              anchors.centerIn: parent
              text: root.specialBrickHealth === 1 ? "✦" : "❄"
              color: "#ffffff"
              font.pixelSize: Math.max(10, parent.height * 0.55)
              font.bold: true
            }
          }
        }

        Item {
          visible: root.giftActive
          width: root.giftSize * playfield.height
          height: width
          x: root.giftX * playfield.width - width / 2
          y: root.giftY * playfield.height - height / 2

          Rectangle {
            anchors.fill: parent
            radius: 2
            color: root.urgent
            border.color: "#fff2b2"
            border.width: 1
          }
          Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.max(2, parent.width * 0.22)
            height: parent.height
            color: "#ffd166"
          }
          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Math.max(2, parent.height * 0.22)
            color: "#ffd166"
          }
        }

        Rectangle {
          x: (root.paddleX - root.paddleWidth / 2) * playfield.width
          y: 0.89 * playfield.height
          width: root.paddleWidth * playfield.width
          height: root.paddleHeight * playfield.height
          radius: height / 2
          color: root.accent
        }

        Rectangle {
          visible: root.launchersActive
          width: 0.011 * playfield.height
          height: 0.035 * playfield.height
          x: (root.paddleX - root.paddleWidth / 2) * playfield.width - width / 2
          y: 0.89 * playfield.height - height * 0.65
          radius: width / 2
          color: root.urgent
          border.color: root.foreground
          border.width: 1
        }

        Rectangle {
          visible: root.launchersActive
          width: 0.011 * playfield.height
          height: 0.035 * playfield.height
          x: (root.paddleX + root.paddleWidth / 2) * playfield.width - width / 2
          y: 0.89 * playfield.height - height * 0.65
          radius: width / 2
          color: root.urgent
          border.color: root.foreground
          border.width: 1
        }

        Repeater {
          model: root.bullets
          delegate: Rectangle {
            required property var modelData
            width: 0.006 * playfield.height
            height: 0.018 * playfield.height
            x: modelData.x * playfield.width - width / 2
            y: modelData.y * playfield.height - height / 2
            radius: width / 2
            color: "#ffd166"
          }
        }

        Rectangle {
          width: root.ballSize * playfield.height
          height: width
          x: root.ballX * playfield.width - width / 2
          y: root.ballY * playfield.height - height / 2
          radius: width / 2
          color: root.foreground
        }

        Rectangle {
          anchors.centerIn: parent
          width: Math.min(parent.width * 0.8, 520)
          height: messageColumn.height + Style.spacing.lg * 2
          visible: root.phase !== "playing"
          color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.92)
          border.color: root.accent
          border.width: 1
          radius: Style.cornerRadius
          Column {
            id: messageColumn
            anchors.centerIn: parent
            spacing: Style.spacing.xs
            Text { width: parent.parent.width - Style.spacing.lg * 2; horizontalAlignment: Text.AlignHCenter; text: root.phase === "ready" ? "READY?" : root.phase === "paused" ? "PAUSED" : root.phase === "won" ? "YOU WIN!" : "GAME OVER"; color: root.accent; font.family: root.fontFamily; font.bold: true; font.pixelSize: Style.font.heading }
            Text { width: parent.parent.width - Style.spacing.lg * 2; horizontalAlignment: Text.AlignHCenter; text: root.phase === "ready" ? "Press SPACE to launch level " + root.level : root.phase === "paused" ? "Press SPACE to resume" : "Press R to play again"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
            Text { width: parent.parent.width - Style.spacing.lg * 2; horizontalAlignment: Text.AlignHCenter; visible: root.phase === "lost" || root.phase === "won"; text: "FINAL SCORE " + root.score; color: root.foreground; font.family: root.fontFamily; font.bold: true; font.pixelSize: Style.font.body }
          }
        }
      }
    }
  }

  }

  implicitWidth: 920
  implicitHeight: 620
}
