import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI
import QtQuick.Dialogs
import Qt.labs.folderlistmodel

Page {
    id: root
    padding: 20
    background: Rectangle { color: "transparent" }
    
    signal presetSelected(var config)
    ShaderCompiler { id: shaderCompiler }
    function presetsDir() {
        var t = shaderCompiler.ensureTextureDir()
        return t.replace("/textures", "/presets")
    }

    Item {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 44
        Rectangle { anchors.fill: parent; color: "transparent" }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            spacing: 10
            EButton {
                text: "导入JSON"
                iconCharacter: "\uf56f"
                Layout.preferredWidth: 120
                Layout.preferredHeight: 32
                onClicked: importJsonDialog.open()
            }
            Item { Layout.fillWidth: true }
        }
    }

    FileDialog {
        id: importJsonDialog
        title: "选择配置JSON"
        fileMode: FileDialog.OpenFile
        nameFilters: ["JSON 文件 (*.json)"]
        onAccepted: {
            var url = importJsonDialog.selectedFile || importJsonDialog.currentFile
            if (!url) return
            loadJsonFromPath(url)
        }
    }

    function loadJsonFromPath(url) {
        try {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", url, false)
            xhr.send()
            if (xhr.status === 200 || xhr.status === 0) {
                var json = JSON.parse(xhr.responseText)
                root.presetSelected(json)
            }
        } catch (e) {
            console.error("导入JSON失败:" + e)
        }
    }

    ListModel { id: shaderModel }

    FolderListModel {
        id: presetsFolderModel
        folder: "file:///" + presetsDir()
        showDirs: true
        showFiles: false
        showDotAndDotDot: false
        nameFilters: ["*"]
        onCountChanged: refreshPresetModel()
    }

    function safeReadJson(url) {
        try {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", url, false)
            xhr.send()
            if (xhr.status === 200 || xhr.status === 0) return JSON.parse(xhr.responseText)
        } catch (e) {}
        return null
    }

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

    function refreshPresetModel() {
        shaderModel.clear()
        var base = presetsDir()
        for (var i = 0; i < presetsFolderModel.count; ++i) {
            var dirName = presetsFolderModel.get(i, "fileName")
            if (!dirName || dirName === "" ) continue
            var jsonRel = dirName + "/config.json"
            var jsonUrl = "file:///" + base + "/" + jsonRel
            var cfg = safeReadJson(jsonUrl)
            var displayName = (cfg && cfg.name) ? cfg.name : dirName
            shaderModel.append({ name: displayName, jsonRel: jsonRel, previewImage: "", fragRel: "" })
        }
    }
    Component.onCompleted: refreshPresetModel()

    GridView {
        id: grid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.top: topBar.bottom
        anchors.margins: 20
        cellWidth: 300
        cellHeight: 220
        model: shaderModel
        clip: true

        delegate: Item {
            width: grid.cellWidth
            height: grid.cellHeight
            
            ECard {
                anchors.fill: parent
                anchors.margins: 10
                padding: 0
                
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 0
                    
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        property url compiledThumb: ""
                        function presetsDir() {
                            var t = shaderCompiler.ensureTextureDir()
                            return t.replace("/textures", "/presets")
                        }
                        function compileThumb() {
                            var base = presetsDir()
                            function normUrl(p) {
                                if (!p || typeof p !== "string") return ""
                                if (p.startsWith("file:")) return p
                                if (p.startsWith("qrc:")) return p
                                return "file:///" + base + "/" + p
                            }
                            var jsonUrl = "file:///" + base + "/" + (model.jsonRel || "")
                            var xhrJ = new XMLHttpRequest(); xhrJ.open("GET", jsonUrl, false); xhrJ.send()
                            if (xhrJ.status === 200 || xhrJ.status === 0) {
                                var cfg
                                try { cfg = JSON.parse(xhrJ.responseText) } catch (e) { cfg = null }
                                if (!cfg) return
                                var ch = "#version 440\nlayout(location = 0) in vec2 qt_TexCoord0;\nlayout(location = 0) out vec4 fragColor;\nlayout(std140, binding = 0) uniform buf { mat4 qt_Matrix; float qt_Opacity; float width; float height; float tar; vec3 iResolution; float iTime; float iTimeDelta; int iFrame; float iFrameRate; float iChannelTime[4]; vec3 iChannelResolution[4]; vec4 iMouse; vec4 iDate; float iSampleRate; };\nlayout(binding = 1) uniform sampler2D iChannel0;\nlayout(binding = 2) uniform sampler2D iChannel1;\nlayout(binding = 3) uniform sampler2D iChannel2;\nlayout(binding = 4) uniform sampler2D iChannel3;\n"
                                var cf = "\nvoid main(void){ vec2 fragCoord = vec2(qt_TexCoord0.x * iResolution.x, (1.0 - qt_TexCoord0.y) * iResolution.y); mainImage(fragColor, fragCoord);}\n"
                                var commonSrc = ""
                                if (cfg.commonCode) commonSrc = cfg.commonCode
                                else if (cfg.commonPath) {
                                    var xhrC = new XMLHttpRequest(); xhrC.open("GET", normUrl(cfg.commonPath), false); xhrC.send()
                                    if (xhrC.status === 200 || xhrC.status === 0) commonSrc = xhrC.responseText
                                }
                                var fragCode = ""
                                if (cfg.code) fragCode = cfg.code
                                else {
                                    var fragPath = cfg.fragmentShader ? cfg.fragmentShader : (cfg.buffers && cfg.buffers.Image && cfg.buffers.Image.fragmentShader ? cfg.buffers.Image.fragmentShader : "")
                                    if (fragPath !== "") {
                                        var xhrF = new XMLHttpRequest(); xhrF.open("GET", normUrl(fragPath), false); xhrF.send()
                                        if (xhrF.status === 200 || xhrF.status === 0) fragCode = xhrF.responseText
                                    }
                                }
                                if (fragCode !== "") {
                                    var src = ch + stripRuntimeHeader(commonSrc) + "\n" + stripRuntimeHeader(fragCode) + cf
                                    var out2 = shaderCompiler.compile(src, model.name + "Thumb")
                                    if (out2) compiledThumb = out2.toString()
                                }
                            }
                        }
                        Component.onCompleted: compileThumb()
                        
                        EShadertoy {
                            anchors.fill: parent
                            fragmentShader: parent.compiledThumb
                            backgroundImage: model.previewImage ? model.previewImage : ""
                            running: false
                            showHud: false
                            interactive: false
                        }
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                var base = presetsDir()
                                var jsonUrl = "file:///" + base + "/" + (model.jsonRel || "")
                                loadJsonFromPath(jsonUrl)
                            }
                        }
                    }
                    
                    // Name
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        color: "transparent"
                        
                        Text {
                            anchors.centerIn: parent
                            text: model.name
                            color: theme.textColor
                            font.pixelSize: 16
                            font.bold: true
                        }
                    }
                }
            }
        }
    }

}
