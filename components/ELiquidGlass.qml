import QtQuick
import QtQuick.Effects
import EvolveUI

Rectangle {
    id: root
    width: 320
    height: 180
    radius: 12
    color: "transparent"
    clip: true
    layer.enabled: true
    layer.smooth: true

    property url backgroundImage: "qrc:/new/prefix1/fonts/pic/01.jpg"
    property url fragmentShader: ""
    property bool running: true
    property bool interactive: true
    property var sampleSource: null

    ShaderCompiler { id: shaderCompiler }

    readonly property string shaderHeaderLG: "#version 440\nlayout(location = 0) in vec2 qt_TexCoord0;\nlayout(location = 0) out vec4 fragColor;\n\nlayout(std140, binding = 0) uniform buf {\n    mat4 qt_Matrix;\n    float qt_Opacity;\n    float shapeWidth;\n    float shapeHeight;\n    float tar;\n    float blurOffsetScale;\n    float radius;\n    float lens_refraction;\n    float sharp;\n    float chromaticAberration;\n    vec3    iResolution;\n    float   iTime;\n    float   iTimeDelta;\n    int     iFrame;\n    float   iFrameRate;\n    float   iChannelTime[4];\n    vec3    iChannelResolution[4];\n    vec4    iMouse;\n    vec4    iDate;\n    float   iSampleRate;\n    vec2    dragReleaseDir;\n    float   dragReleaseAmp;\n    float   dragReleaseTime;\n    float   pressStartTime;\n    float   pressing;\n    float   lastMoveTime;\n    vec2    dragVel;\n    float   effectsEnabled;\n};\nlayout(binding = 1) uniform sampler2D iChannel0;\nlayout(binding = 2) uniform sampler2D iChannel1;\nlayout(binding = 3) uniform sampler2D iChannel2;\nlayout(binding = 4) uniform sampler2D iChannel3;\n"

    readonly property string shaderFooterLG: "\nvoid main(void) {\n    vec2 fragCoord = vec2(qt_TexCoord0.x * iResolution.x, qt_TexCoord0.y * iResolution.y);\n    mainImage(fragColor, fragCoord);\n}\n"

    function stripRuntimeHeader(s) {
        if (!s || s.length === 0) return "";
        var out = s;
        out = out.replace(/^[\t ]*#version[^\n]*\n/mg, "");
        out = out.replace(/^[\t ]*layout\s*\(\s*location\s*=\s*\d+\s*\)\s*in\s+[^;]*qt_TexCoord0[^;]*;\s*$/mg, "");
        out = out.replace(/^[\t ]*layout\s*\(\s*location\s*=\s*\d+\s*\)\s*out\s+[^;]*fragColor[^;]*;\s*$/mg, "");
        out = out.replace(/layout\s*\(\s*std140\s*,\s*binding\s*=\s*0\s*\)\s*uniform\s+buf\s*\{[\s\S]*?\};/mg, "");
        out = out.replace(/^[\t ]*layout\s*\(\s*binding\s*=\s*1\s*\)\s*uniform\s+sampler2D\s+iChannel0\s*;\s*$/mg, "");
        out = out.replace(/^[\t ]*layout\s*\(\s*binding\s*=\s*2\s*\)\s*uniform\s+sampler2D\s+iChannel1\s*;\s*$/mg, "");
        out = out.replace(/^[\t ]*layout\s*\(\s*binding\s*=\s*3\s*\)\s*uniform\s+sampler2D\s+iChannel2\s*;\s*$/mg, "");
        out = out.replace(/^[\t ]*layout\s*\(\s*binding\s*=\s*4\s*\)\s*uniform\s+sampler2D\s+iChannel3\s*;\s*$/mg, "");
        out = out.replace(/void\s+main\s*\([\s\S]*?\)\s*\{[\s\S]*?mainImage\s*\([\s\S]*?\);[\s\S]*?\}/mg, "");
        return out;
    }

    property alias shapeScaleX: shader.shapeWidth
    property alias shapeScaleY: shader.shapeHeight
    property alias shapeRadius: shader.radius
    property alias blurOffsetScale: shader.blurOffsetScale
    property alias effectsEnabled: shader.effectsEnabled
    property alias lens_refraction: shader.lens_refraction
    property alias chromaticAberration: shader.chromaticAberration

    property real screen_scale: Screen.devicePixelRatio
    readonly property vector3d defaultResolution: Qt.vector3d(shader.width * screen_scale,
                                                             shader.height * screen_scale,
                                                             shader.width / shader.height)

    Item {
        id: backgroundContainer
        anchors.fill: parent
        visible: false
        Rectangle { anchors.fill: parent; color: "black"; visible: !backgroundImg.visible }
        Image {
            id: backgroundImg
            anchors.fill: parent
            source: root.backgroundImage
            sourceSize.width: Math.max(1, Math.round(root.width * root.screen_scale))
            sourceSize.height: Math.max(1, Math.round(root.height * root.screen_scale))
            fillMode: Image.PreserveAspectFit
            smooth: true
            asynchronous: true
            cache: false
            mipmap: true
            antialiasing: true
            visible: source !== "" && source !== null
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

    ShaderEffect {
        id: shader
        anchors.fill: parent
        opacity: 0
        fragmentShader: root.fragmentShader

        property vector3d iResolution: defaultResolution
        property real     iTime: 0
        property real     iTimeDelta: 100
        property int      iFrame: 0
        property real     iFrameRate: 0
        property vector4d iMouse: Qt.vector4d(0, 0, 0, 0)
        property vector4d iDate: Qt.vector4d(0, 0, 0, 0)
        property real     iSampleRate: 44100
        property real     tar: 0.0
        property var      iChannelTime: [0, 0, 0, 0]
        property var      iChannelResolution: [defaultResolution, defaultResolution, defaultResolution, defaultResolution]

        property real shapeWidth: 0.30
        property real shapeHeight: 0.30
        property real radius: 0.1
        property real blurOffsetScale: 0.2
        property real lens_refraction: 0.10
        property real sharp: 0.1
        property real chromaticAberration: 0.02
        property real effectsEnabled: 1.0

        property vector2d dragReleaseDir: Qt.vector2d(0, 0)
        property real     dragReleaseAmp: 0.0
        property real     dragReleaseTime: 0.0
        property real     pressStartTime: 0.0
        property real     pressing: 0.0
        property real     lastMoveTime: 0.0
        property vector2d prevMouse: Qt.vector2d(0, 0)
        property vector2d dragVel: Qt.vector2d(0, 0)
        property vector2d dragVelSmooth: Qt.vector2d(0, 0)

        property var iChannel0: autoSrc
        property var iChannel1: autoSrc
        property var iChannel2: autoSrc
        property var iChannel3: autoSrc
        property var source: iChannel0

        ShaderEffectSource {
            id: autoSrc
            sourceItem: root.sampleSource ? root.sampleSource : backgroundMasked
            hideSource: false
            live: true
            smooth: true
            recursive: false
            textureSize: Qt.size(Math.round(shader.width * root.screen_scale), Math.round(shader.height * root.screen_scale))
        }

        Timer {
            running: root.running
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
            running: root.running
            interval: 1000; repeat: true
            onTriggered: {
                var date = new Date();
                const startOfDay = new Date(date);
                startOfDay.setHours(0, 0, 0, 0);
                const millisecondsSinceStartOfDay = date - startOfDay;
                const secondsSinceStartOfDay = Math.floor(millisecondsSinceStartOfDay / 1000);
                shader.iDate = Qt.vector4d(date.getFullYear(), date.getMonth() + 1, date.getDate(), secondsSinceStartOfDay);
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: false
        preventStealing: true
        acceptedButtons: Qt.LeftButton
        propagateComposedEvents: false
        onPressed: function(mouse) {
            const scale = root.screen_scale
            shader.iMouse = Qt.vector4d(mouse.x * scale,
                                        mouse.y * scale,
                                        mouse.x * scale,
                                        mouse.y * scale)
            shader.dragReleaseAmp = 0.0
            shader.pressStartTime = shader.iTime
            shader.pressing = 1.0
            shader.lastMoveTime = shader.iTime
            shader.prevMouse = Qt.vector2d(mouse.x * scale, mouse.y * scale)
            shader.dragVel = Qt.vector2d(0, 0)
            shader.dragVelSmooth = Qt.vector2d(0, 0)
            mouse.accepted = true
        }
        onPositionChanged: function (mouse) {
            if (!pressed) { mouse.accepted = false; return }
            const scale = root.screen_scale
            const curX = mouse.x * scale
            const curY = mouse.y * scale
            const prevX = shader.prevMouse.x
            const prevY = shader.prevMouse.y
            const dt = Math.max(1e-6, shader.iTime - shader.lastMoveTime)
            const dx = curX - prevX
            const dy = curY - prevY
            const iry = shader.iResolution.y
            const vx = (dx / dt) / iry
            const vy = (dy / dt) / iry
            const tau = 0.08
            const alpha = Math.max(0.0, Math.min(1.0, 1.0 - Math.exp(-dt / tau)))
            const svx = shader.dragVelSmooth.x * (1.0 - alpha) + vx * alpha
            const svy = shader.dragVelSmooth.y * (1.0 - alpha) + vy * alpha
            shader.dragVelSmooth = Qt.vector2d(svx, svy)
            shader.dragVel = shader.dragVelSmooth
            shader.prevMouse = Qt.vector2d(curX, curY)
            shader.iMouse = Qt.vector4d(curX, curY, shader.iMouse.z, shader.iMouse.w)
            shader.lastMoveTime = shader.iTime
            mouse.accepted = true
        }
        onReleased: function(mouse) {
            const dx = shader.iMouse.x - shader.iMouse.z
            const dy = shader.iMouse.y - shader.iMouse.w
            const len = Math.hypot(dx, dy)
            const speedAmp = Math.hypot(shader.dragVelSmooth.x, shader.dragVelSmooth.y) * 0.03
            const amp = Math.min(0.25, speedAmp)
            shader.dragReleaseDir = len > 1e-6 ? Qt.vector2d(dx / len, dy / len) : Qt.vector2d(1, 0)
            shader.dragReleaseAmp = amp
            shader.dragReleaseTime = shader.iTime
            shader.pressStartTime = shader.iTime
            shader.pressing = 0.0
            shader.dragVel = Qt.vector2d(0, 0)
            shader.dragVelSmooth = Qt.vector2d(0, 0)
            shader.iMouse = Qt.vector4d(shader.iMouse.x,
                                        shader.iMouse.y,
                                        0,
                                        0)
            mouse.accepted = true
        }
        onClicked: function (mouse) {
            shader.tar = shader.tar === 0 ? 1 : 0
            mouse.accepted = true
        }
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
    Component.onCompleted: {
        var base = shaderCompiler.ensureTextureDir()
        var frag = base.replace("/textures", "/components/liquidglass/liquidglass.frag")
        var url = "file:///" + frag
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url, false)
        xhr.send()
        if (xhr.status === 200 || xhr.status === 0) {
            var sanitized = stripRuntimeHeader(xhr.responseText)
            var src = shaderHeaderLG + "\n" + sanitized + "\n" + shaderFooterLG
            var out = shaderCompiler.compile(src, "LiquidGlass")
            if (out) root.fragmentShader = out.toString()
        }
    }
}
