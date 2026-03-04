import QtQuick
import QtQml.Models
import QtQuick.Effects

Rectangle {
    id: root
    width: 320
    height: 180
    color: "black"
    radius: 12
    clip: true
    layer.enabled: true
    layer.smooth: true
    property bool showHud: true
    property url backgroundImage: ""

    property url fragmentShader: ""

    property alias screen_scale: shader.screen_scale
    property alias defaultResolution: shader.defaultResolution
    property alias iResolution: shader.iResolution
    property alias iTime: shader.iTime
    property alias iTimeDelta: shader.iTimeDelta
    property alias iFrame: shader.iFrame
    property alias iFrameRate: shader.iFrameRate
    property alias iMouse: shader.iMouse
    property alias iChannel0: shader.iChannel0
    property alias iChannel1: shader.iChannel1
    property alias iChannel2: shader.iChannel2
    property alias iChannel3: shader.iChannel3
    property alias iChannelTime: shader.iChannelTime
    property alias iChannelResolution: shader.iChannelResolution
    property alias iDate: shader.iDate
    property alias iSampleRate: shader.iSampleRate
    property alias tar: shader.tar
    property alias zoom: shader.zoom

    property alias running: shader.running
    property alias interactive: shader.interactive
    property alias interacting: shader.interacting
    property alias sampleSource: shader.sampleSource

    Item {
        id: backgroundContainer
        anchors.fill: parent
        visible: false
        Rectangle { id: backgroundRect; anchors.fill: parent; color: "black"; visible: !backgroundImg.visible }
        Image {
            id: backgroundImg
            anchors.fill: parent
            source: root.backgroundImage
            fillMode: Image.PreserveAspectFit
            smooth: true
            visible: source !== "" && source !== null
            asynchronous: true
            cache: false
            mipmap: true
            antialiasing: true
        }
    }

    ShaderEffect {
        id: shader
        anchors.fill: parent
        opacity: 0
        implicitWidth: 320
        implicitHeight: 180
        fragmentShader: root.fragmentShader
        property real screen_scale: Screen.devicePixelRatio
        readonly property vector3d defaultResolution: Qt.vector3d(shader.width * screen_scale, shader.height * screen_scale, shader.width / shader.height)
        readonly property vector3d  iResolution: defaultResolution
        property real       iTime: 0
        property real       iTimeDelta: 100
        property int        iFrame: 10
        property real       iFrameRate
        property vector4d   iMouse: Qt.vector4d(0, 0, 0, 0)
        property var        iChannel0: autoSrc
        property var        iChannel1
        property var        iChannel2
        property var        iChannel3
        property var        source: iChannel0
        property var        iChannelTime: [0, 1, 2, 3]
        property var        iChannelResolution: [defaultResolution, defaultResolution, defaultResolution, defaultResolution]
        property vector4d   iDate: Qt.vector4d(0, 0, 0, 0)
        property real       iSampleRate: 44100
        property real       tar: 0.0
        property real       zoom: 1.0

        property bool running: true
        property bool interactive: true
        property bool interacting: false
        property var        sampleSource: null

        ShaderEffectSource {
            id: autoSrc
            sourceItem: sampleSource ? sampleSource : backgroundMasked
            hideSource: false
            live: true
            smooth: true
            recursive: false
        }

        Timer {
            running: shader.running
            triggeredOnStart: true
            interval: 16; repeat: true
            property double lastTickMs: 0
            onTriggered: {
                const now = Date.now();
                const dtMs = lastTickMs > 0 ? (now - lastTickMs) : 16;
                lastTickMs = now;
                shader.iTimeDelta = dtMs / 1000.0;
                shader.iTime += shader.iTimeDelta;
                shader.iFrameRate = 1000.0 / dtMs;
                shader.iFrame += 1;
            }
        }
        Timer {
            running: shader.running
            interval: 100
            repeat: true
            onTriggered: {
                var date = new Date();
                const startOfDay = new Date(date);
                startOfDay.setHours(0, 0, 0, 0);
                const millisecondsSinceStartOfDay = date - startOfDay;
                const secondsSinceStartOfDay = Math.floor(millisecondsSinceStartOfDay / 1000);
                shader.iDate = Qt.vector4d(date.getFullYear(), date.getMonth() + 1, date.getDate(), secondsSinceStartOfDay)
            }
        }

        WheelHandler {
            enabled: shader.interactive
            onWheel: function(w) {
                const step = 1 + (w.angleDelta.y / 120) * 0.1;
                shader.zoom = Math.max(0.3, Math.min(3.0, shader.zoom * step));
                w.accepted = true
            }
        }
    }

    Item {
        id: shaderMask
        anchors.fill: parent
        layer.enabled: true
        visible: false
        Rectangle { anchors.fill: parent; radius: root.radius; color: "black" }
    }

    MultiEffect {
        id: backgroundMasked
        source: backgroundContainer
        anchors.fill: parent
        maskEnabled: true
        maskSource: shaderMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        visible: true
    }

    MultiEffect {
        id: shaderMasked
        source: shader
        anchors.fill: parent
        maskEnabled: true
        maskSource: shaderMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
        visible: true
    }

    MouseArea {
        id: inputOverlay
        anchors.fill: parent
        enabled: shader.interactive
        hoverEnabled: true
        propagateComposedEvents: false
        onPressed: function(mouse) {
            shader.interacting = true
            const scale = shader.screen_scale
            shader.iMouse = Qt.vector4d(mouse.x * scale,
                                        shader.height * scale - mouse.y * scale,
                                        shader.iMouse.z,
                                        shader.iMouse.w)
            mouse.accepted = true
        }
        onPositionChanged: function (mouse) {
            if (!shader.interacting) { mouse.accepted = false; return }
            const scale = shader.screen_scale
            shader.iMouse = Qt.vector4d(mouse.x * scale,
                                        shader.height * scale - mouse.y * scale,
                                        shader.iMouse.z,
                                        shader.iMouse.w)
            mouse.accepted = true
        }
        onClicked: function (mouse) {
            shader.tar = shader.tar === 0 ? 1 : 0
            const scale = shader.screen_scale
            shader.iMouse = Qt.vector4d(shader.iMouse.x,
                                        shader.iMouse.y,
                                        mouse.x * scale,
                                        shader.height * scale - mouse.y * scale)
            mouse.accepted = true
        }
        onReleased: function(mouse) {
            shader.interacting = false
            mouse.accepted = true
        }
    }

    FontLoader { id: iconFont; source: "qrc:/new/prefix1/fonts/fontawesome-free-6.7.2-desktop/otfs/Font Awesome 6 Free-Solid-900.otf" }

    Rectangle {
        id: hud
        visible: root.showHud
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 28
        color: theme ? theme.primaryColor : "#2b2b2b"
        opacity: 0.88
        radius: 8
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        anchors.bottomMargin: 4

        Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 4
            anchors.bottomMargin: 4
            spacing: 14

            Text { text: "\uf2ea"; font.family: iconFont.name; color: theme ? theme.textColor : "#e0e0e0"; font.pixelSize: 16; TapHandler { onTapped: { shader.iTime = 0; shader.iFrame = 0 } } }
            Text { text: shader.running ? "\uf04c" : "\uf04b"; font.family: iconFont.name; color: theme ? theme.textColor : "#e0e0e0"; font.pixelSize: 16; TapHandler { onTapped: { shader.running = !shader.running } } }
            Text { text: Number(shader.iTime).toFixed(2); color: theme ? theme.textColor : "#e0e0e0"; font.pixelSize: 14 }
            Text { text: (shader.iFrameRate > 0 ? shader.iFrameRate.toFixed(1) : (1 / Math.max(shader.iTimeDelta, 1e-6)).toFixed(1)) + " fps"; color: theme ? theme.textColor : "#e0e0e0"; font.pixelSize: 14 }
            Text { text: Math.round(shader.width) + " x " + Math.round(shader.height); color: theme ? theme.textColor : "#e0e0e0"; font.pixelSize: 14 }
            Text {
                text: "\uf04e"; font.family: iconFont.name; color: theme ? theme.textColor : "#e0e0e0"; font.pixelSize: 16
                TapHandler {
                    onTapped: {
                        const list = (theme && theme.availableShaders) ? theme.availableShaders : []
                        if (!list || list.length === 0) return
                        let idx = (theme && typeof theme.currentShaderIndex === "number") ? theme.currentShaderIndex : 0
                        idx = (idx + 1) % list.length
                        if (theme) theme.currentShaderIndex = idx
                        root.fragmentShader = list[idx]
                    }
                }
            }
        }
    }
}
