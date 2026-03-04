import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI
import Qt.labs.folderlistmodel

Page {
    id: root
    padding: 20
    
    property var theme
    EToast { id: toast; theme: root.theme; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: 10 }
    property string textureDir: shaderCompiler.ensureTextureDir()
    FolderListModel {
        id: textureFolderModel
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.bmp", "*.gif", "*.webp"]
        showDirs: false
        showDotAndDotDot: false
        folder: "file:///" + textureDir
    }

    ShaderCompiler {
        id: shaderCompiler
    }

    readonly property string shaderHeader: "#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float width;
    float height;
    float tar;
    vec3    iResolution;
    float   iTime;
    float   iTimeDelta;
    int     iFrame;
    float   iFrameRate;
    float   iChannelTime[4];
    vec3    iChannelResolution[4];
    vec4    iMouse;
    vec4    iDate;
    float   iSampleRate;
};
layout(binding = 1) uniform sampler2D iChannel0;
layout(binding = 2) uniform sampler2D iChannel1;
layout(binding = 3) uniform sampler2D iChannel2;
layout(binding = 4) uniform sampler2D iChannel3;
"

    readonly property string shaderFooter: "
void main(void) {
    vec2 fragCoord = vec2(qt_TexCoord0.x * iResolution.x, (1.0 - qt_TexCoord0.y) * iResolution.y);
    mainImage(fragColor, fragCoord);
}
"

    readonly property string shaderFooterNorm: "
void main(void) {
    vec2 fragCoord = vec2(qt_TexCoord0.x, 1.0 - qt_TexCoord0.y);
    mainImage(fragColor, fragCoord);
}
"

    // === Buffer & Code Management ===
    
    // Store code for each buffer
    property var shaderData: {
        "Image": "// Image Shader\nvoid mainImage( out vec4 fragColor, in vec2 fragCoord )\n{\n    // Normalized pixel coordinates (from 0 to 1)\n    vec2 uv = fragCoord/iResolution.xy;\n\n    // Time varying pixel color\n    vec3 col = 0.5 + 0.5*cos(iTime+uv.xyx+vec3(0,2,4));\n\n    // Output to screen\n    fragColor = vec4(col,1.0);\n}",
        "Buffer A": "// Buffer A\nvoid mainImage( out vec4 fragColor, in vec2 fragCoord )\n{\n    fragColor = vec4(0.0);\n}",
        "Buffer B": "// Buffer B\nvoid mainImage( out vec4 fragColor, in vec2 fragCoord )\n{\n    fragColor = vec4(0.0);\n}",
        "Buffer C": "// Buffer C\nvoid mainImage( out vec4 fragColor, in vec2 fragCoord )\n{\n    fragColor = vec4(0.0);\n}",
        "Buffer D": "// Buffer D\nvoid mainImage( out vec4 fragColor, in vec2 fragCoord )\n{\n    fragColor = vec4(0.0);\n}",
        "Common": "// Common\n"
    }
    
    property string currentBufferName: "Image"
    property var channelSources: {
        "Image": [ {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""} ],
        "Common": [ {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""} ],
        "Buffer A": [ {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""} ],
        "Buffer B": [ {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""} ],
        "Buffer C": [ {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""} ],
        "Buffer D": [ {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""} ]
    }

    function ensureChannelSources(name) {
        if (!channelSources[name]) {
            channelSources[name] = [
                {kind:"none", value:""},
                {kind:"none", value:""},
                {kind:"none", value:""},
                {kind:"none", value:""}
            ];
        }
    }
    
    // Define sort order: Common -> Buffers -> Image
    function getBufferOrder(name) {
        if (name === "Common") return 0;
        if (name === "Buffer A") return 1;
        if (name === "Buffer B") return 2;
        if (name === "Buffer C") return 3;
        if (name === "Buffer D") return 4;
        if (name === "Image") return 99;
        return 50;
    }

    function addBuffer(name) {
        // Check if already exists
        for (var i = 0; i < bufferModel.count; i++) {
            if (bufferModel.get(i).name === name) return;
        }
        
        // Find insertion index based on order
        var newOrder = getBufferOrder(name);
        var insertIndex = bufferModel.count;
        
        for (var j = 0; j < bufferModel.count; j++) {
            var existingName = bufferModel.get(j).name;
            var existingOrder = getBufferOrder(existingName);
            if (newOrder < existingOrder) {
                insertIndex = j;
                break;
            }
        }
        
        bufferModel.insert(insertIndex, { "name": name });
        ensureChannelSources(name)
    }
    
    function isBufferActive(name) {
        for (var i = 0; i < bufferModel.count; i++) {
            if (bufferModel.get(i).name === name) return true;
        }
        return false;
    }
    
    function switchBuffer(newIndex) {
        if (newIndex < 0 || newIndex >= bufferModel.count) return;
        
        // Save current code
        shaderData[currentBufferName] = codeEditor.text;
        
        // Switch
        var newName = bufferModel.get(newIndex).name;
        currentBufferName = newName;
        ensureChannelSources(newName)
        
        // Load new code
        if (shaderData[newName] !== undefined) {
            codeEditor.text = shaderData[newName];
        } else {
            codeEditor.text = "// Code for " + newName;
        }
    }
    
    function saveCurrentCode() {
        shaderData[currentBufferName] = codeEditor.text;
    }

    function textureDropdownModel(channelIdx) {
        var m = [{text: "None", kind: "none", value: ""}]
        var files = shaderCompiler.listTextures(textureDir)
        for (var i = 0; i < files.length; ++i) m.push(files[i])
        // append existing buffers only
        for (var j = 0; j < bufferModel.count; ++j) {
            var bname = bufferModel.get(j).name
            if (bname !== "Image") m.push({ text: bname + " (output)", kind: "buffer", value: bname })
        }
        return m
    }

    function getSelectedIndex(bufferName, chIdx, model) {
        if (!channelSources[bufferName]) return 0
        var sel = channelSources[bufferName][chIdx]
        if (!sel || !model) return 0
        for (var i = 0; i < model.length; ++i) {
            var it = model[i]
            if (sel.kind === it.kind) {
                if (sel.kind === "none") return i
                if (sel.value === it.value) return i
            }
        }
        return 0
    }
    
    function deleteBuffer(index) {
        if (index < 0 || index >= bufferModel.count) return;
        
        var name = bufferModel.get(index).name;
        if (name === "Image") return; // Cannot delete Image buffer
        
        // If we are deleting the current buffer, switch to Image first
        if (currentBufferName === name) {
            switchBuffer(0); // Image is always index 0 if sorted, or find it
            // Actually Image might not be index 0 if "Common" is there.
            // But we can find Image index.
            for (var k=0; k<bufferModel.count; k++) {
                if (bufferModel.get(k).name === "Image") {
                    switchBuffer(k);
                    break;
                }
            }
        }
        
        bufferModel.remove(index);
        // Optionally clear data, but keeping it might be safe too.
        // delete shaderData[name]; 
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

    function compileShaders() {
        saveCurrentCode();

        var common = shaderData["Common"] || "";

        function build(name) {
            var code = shaderData[name] || "";
            var footer = shaderFooter;
            var src = shaderHeader + "\n" + stripRuntimeHeader(common) + "\n" + stripRuntimeHeader(code) + "\n" + footer;
            return shaderCompiler.compile(src, name);
        }

        // Compile chain buffers in order if active
        var activeNames = [];
        for (var i=0; i<bufferModel.count; ++i) activeNames.push(bufferModel.get(i).name);

        function isActive(n) { return activeNames.indexOf(n) >= 0; }

        function bufferSrcByName(n) {
            if (n === "Buffer A") return bufferASrc;
            if (n === "Buffer B") return bufferBSrc;
            if (n === "Buffer C") return bufferCSrc;
            if (n === "Buffer D") return bufferDSrc;
            return null;
        }

        function assignChannelsFor(bufferName, effect, texSources) {
            // texSources: array of 4 ShaderEffectSource for file textures (0..3)
            for (var ch=0; ch<4; ++ch) {
                var sel = channelSources[bufferName][ch]
                var prop = "iChannel" + ch
                if (sel && sel.kind === "buffer" && sel.value) {
                    effect[prop] = bufferSrcByName(sel.value)
                } else if (sel && sel.kind === "file") {
                    var val = sel.value ? sel.value : ""
                    texSources[ch].sourceItem.source = val
                    effect[prop] = val !== "" ? texSources[ch] : null
                } else {
                    // fallback for ch0: previous buffer output
                    if (ch === 0) {
                        if (bufferName === "Buffer B") effect[prop] = bufferASrc
                        else if (bufferName === "Buffer C") effect[prop] = bufferBSrc
                        else if (bufferName === "Buffer D") effect[prop] = bufferCSrc
                        else if (bufferName === "Image") {
                            if (isActive("Buffer D")) effect[prop] = bufferDSrc;
                            else if (isActive("Buffer C")) effect[prop] = bufferCSrc;
                            else if (isActive("Buffer B")) effect[prop] = bufferBSrc;
                            else if (isActive("Buffer A")) effect[prop] = bufferASrc;
                            else effect[prop] = null;
                        }
                        else effect[prop] = null
                    } else {
                        effect[prop] = null
                    }
                }
            }
            var res = []
            for (var ch=0; ch<4; ++ch) {
                var s = effect["iChannel" + ch]
                if (s && s.sourceItem) {
                    var w = s.sourceItem.width * shaderDisplay.screen_scale
                    var h = s.sourceItem.height * shaderDisplay.screen_scale
                    var ar = h > 0 ? (w / h) : 0
                    res[ch] = Qt.vector3d(w, h, ar)
                } else {
                    res[ch] = Qt.vector3d(0, 0, 0)
                }
            }
            effect.iChannelResolution = res
        }

        // Buffer A
        if (isActive("Buffer A")) {
            var aUrl = build("Buffer A");
            if (aUrl.toString() !== "") bufferAEff.fragmentShader = aUrl;
            assignChannelsFor("Buffer A", bufferAEff, [texA0Src, texA1Src, texA2Src, texA3Src])
        }

        // Buffer B
        if (isActive("Buffer B")) {
            var bUrl = build("Buffer B");
            if (bUrl.toString() !== "") bufferBEff.fragmentShader = bUrl;
            assignChannelsFor("Buffer B", bufferBEff, [texB0Src, texB1Src, texB2Src, texB3Src])
        }

        // Buffer C
        if (isActive("Buffer C")) {
            var cUrl = build("Buffer C");
            if (cUrl.toString() !== "") bufferCEff.fragmentShader = cUrl;
            assignChannelsFor("Buffer C", bufferCEff, [texC0Src, texC1Src, texC2Src, texC3Src])
        }

        // Buffer D
        if (isActive("Buffer D")) {
            var dUrl = build("Buffer D");
            if (dUrl.toString() !== "") bufferDEff.fragmentShader = dUrl;
            assignChannelsFor("Buffer D", bufferDEff, [texD0Src, texD1Src, texD2Src, texD3Src])
        }

        var imgUrl = build("Image");
        if (imgUrl.toString() !== "") {
            shaderDisplay.fragmentShader = imgUrl;
            // assign image channels, with fallback chain mapping for channel0
            assignChannelsFor("Image", shaderDisplay, [texImg0Src, texImg1Src, texImg2Src, texImg3Src])
            shaderDisplay.iTime = 0
            shaderDisplay.iFrame = 0
            toast.show("编译成功")
        }
        else {
            toast.show("编译失败: " + shaderCompiler.lastError())
        }
    }

    function loadPreset(config) {
        function resetWorkspace() {
            // Clear buffer effects
            bufferAEff.fragmentShader = ""
            bufferBEff.fragmentShader = ""
            bufferCEff.fragmentShader = ""
            bufferDEff.fragmentShader = ""
            shaderDisplay.fragmentShader = ""
            // Reset buffer model to base (Image)
            while (bufferModel.count > 0) bufferModel.remove(0)
            bufferModel.append({ name: "Image" })
            // Reset channels for all
            channelSources["Image"] = [ {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""} ]
            channelSources["Buffer A"] = [ {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""} ]
            channelSources["Buffer B"] = [ {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""} ]
            channelSources["Buffer C"] = [ {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""} ]
            channelSources["Buffer D"] = [ {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""} ]
            // Reset code
            shaderData["Common"] = shaderData["Common"] || ""
            shaderData["Buffer A"] = shaderData["Buffer A"] || ""
            shaderData["Buffer B"] = shaderData["Buffer B"] || ""
            shaderData["Buffer C"] = shaderData["Buffer C"] || ""
            shaderData["Buffer D"] = shaderData["Buffer D"] || ""
            shaderData["Image"] = shaderData["Image"] || ""
            currentBufferName = "Image"
            codeEditor.text = shaderData["Image"]
            bufferTabs.currentIndex = 0
        }
        function readTextFile(url) {
            try {
                var xhr = new XMLHttpRequest()
                xhr.open("GET", url, false)
                xhr.send()
                if (xhr.status === 200 || xhr.status === 0) return xhr.responseText
            } catch (e) {}
            return ""
        }
        function normalizeFileUrl(p) {
            if (!p || typeof p !== "string") return ""
            if (p.startsWith("qrc:")) return p
            if (p.startsWith("file:")) return p
            var s = p.replace(/\\/g, "/")
            if (/^[A-Za-z]:\//.test(s)) return "file:///" + s
            var base = shaderCompiler.ensureTextureDir().replace("/textures", "/presets")
            return "file:///" + base + "/" + s
        }
        function compileFragIfNeeded(path, bufferName) {
            var url = normalizeFileUrl(path)
            if (url.endsWith(".qsb")) return url
            if (url.endsWith(".frag")) {
                var xhr = new XMLHttpRequest()
                xhr.open("GET", url, false)
                xhr.send()
                if (xhr.status === 200 || xhr.status === 0) {
                    var sanitized = stripRuntimeHeader(xhr.responseText)
                    var footer = shaderFooter
                    var src = shaderHeader + "\n" + sanitized + "\n" + footer
                    var out = shaderCompiler.compile(src, bufferName)
                    return out ? out.toString() : ""
                }
                return ""
            }
            return url
        }
        function compileSourceIfPresent(code, bufferName) {
            if (!code || code.length === 0) return ""
            var out = shaderCompiler.compile(code, bufferName)
            return out ? out.toString() : ""
        }
        function compileWithCommon(code, common, bufferName) {
            var footer = shaderFooter
            var src = shaderHeader + "\n" + stripRuntimeHeader(common || "") + "\n" + stripRuntimeHeader(code || "") + "\n" + footer
            var out = shaderCompiler.compile(src, bufferName)
            return out ? out.toString() : ""
        }
        // Helper: map name->effect
        function effectFor(name) {
            if (name === "Buffer A") return bufferAEff
            if (name === "Buffer B") return bufferBEff
            if (name === "Buffer C") return bufferCEff
            if (name === "Buffer D") return bufferDEff
            if (name === "Image") return shaderDisplay
            return null
        }
        function texSrcListFor(name) {
            if (name === "Buffer A") return [texA0Src, texA1Src, texA2Src, texA3Src]
            if (name === "Buffer B") return [texB0Src, texB1Src, texB2Src, texB3Src]
            if (name === "Buffer C") return [texC0Src, texC1Src, texC2Src, texC3Src]
            if (name === "Buffer D") return [texD0Src, texD1Src, texD2Src, texD3Src]
            if (name === "Image") return [texImg0Src, texImg1Src, texImg2Src, texImg3Src]
            return [null, null, null, null]
        }
        function bufferSrcByName(n) {
            if (n === "Buffer A") return bufferASrc
            if (n === "Buffer B") return bufferBSrc
            if (n === "Buffer C") return bufferCSrc
            if (n === "Buffer D") return bufferDSrc
            return null
        }
        function setChannelsFor(name, channels) {
            // Update UI model
            if (channels) {
                if (!channelSources[name]) {
                    channelSources[name] = [
                        {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""}, {kind:"none", value:""}
                    ]
                }
                for (var k=0; k<4; ++k) {
                    if (channels[k]) {
                        channelSources[name][k] = { kind: channels[k].kind, value: channels[k].value, text: channels[k].text || "" }
                    }
                }
            }

            var eff = effectFor(name)
            var texSrcs = texSrcListFor(name)
            if (!eff || !texSrcs) return
            for (var ch=0; ch<4; ++ch) {
                var sel = channels && channels[ch] ? channels[ch] : { kind: "none" }
                var prop = "iChannel" + ch
                if (sel.kind === "buffer" && sel.value) {
                    eff[prop] = bufferSrcByName(sel.value)
                } else if (sel.kind === "file" && sel.value) {
                    var texImage = texSrcs[ch].sourceItem
                    texImage.source = sel.value
                    eff[prop] = texSrcs[ch]
                } else {
                    eff[prop] = null
                }
            }
            var res = []
            for (var ch=0; ch<4; ++ch) {
                var s = eff["iChannel" + ch]
                if (s && s.sourceItem) {
                    var w = s.sourceItem.width * shaderDisplay.screen_scale
                    var h = s.sourceItem.height * shaderDisplay.screen_scale
                    var ar = h > 0 ? (w / h) : 0
                    res[ch] = Qt.vector3d(w, h, ar)
                } else {
                    res[ch] = Qt.vector3d(0, 0, 0)
                }
            }
            eff.iChannelResolution = res
        }

        resetWorkspace()
        if (config.commonCode || config.commonPath) {
            addBuffer("Common")
            var cc = config.commonCode ? config.commonCode : readTextFile(normalizeFileUrl(config.commonPath))
            if (cc && cc.length > 0) shaderData["Common"] = stripRuntimeHeader(cc)
        }
        // Single-pass preset
        if (config.fragmentShader || config.code) {
            var commonCode = config.commonCode ? config.commonCode : (config.commonPath ? readTextFile(normalizeFileUrl(config.commonPath)) : "")
            var imgUrl
            if (config.code) {
                imgUrl = compileWithCommon(config.code, commonCode, "Image")
            } else {
                if (commonCode && commonCode.length > 0 && config.fragmentShader) {
                    var imgSrc = readTextFile(normalizeFileUrl(config.fragmentShader))
                    imgUrl = compileWithCommon(imgSrc, commonCode, "Image")
                } else {
                    imgUrl = compileFragIfNeeded(config.fragmentShader, "Image")
                }
            }
            if (imgUrl && imgUrl !== "") shaderDisplay.fragmentShader = imgUrl
            // Load code into editor
            var imgCode = config.code ? config.code : (config.fragmentShader ? readTextFile(normalizeFileUrl(config.fragmentShader)) : "")
            if (imgCode && imgCode.length > 0) {
                shaderData["Image"] = stripRuntimeHeader(imgCode)
                currentBufferName = "Image"
                codeEditor.text = shaderData["Image"]
                bufferTabs.currentIndex = 0
            }
            if (config.textures) setChannelsFor("Image", [
                config.textures.iChannel0 ? {kind:"file", value: config.textures.iChannel0} : {kind:"none"},
                config.textures.iChannel1 ? {kind:"file", value: config.textures.iChannel1} : {kind:"none"},
                config.textures.iChannel2 ? {kind:"file", value: config.textures.iChannel2} : {kind:"none"},
                config.textures.iChannel3 ? {kind:"file", value: config.textures.iChannel3} : {kind:"none"},
            ])
            return
        }

        // Multi-buffer preset
        if (config.buffers) {
            var names = Object.keys(config.buffers)
            // Ensure buffers are active
            if (config.buffers["Buffer A"]) addBuffer("Buffer A")
            if (config.buffers["Buffer B"]) addBuffer("Buffer B")
            if (config.buffers["Buffer C"]) addBuffer("Buffer C")
            if (config.buffers["Buffer D"]) addBuffer("Buffer D")
            var commonCode2 = config.commonCode ? config.commonCode : (config.commonPath ? readTextFile(normalizeFileUrl(config.commonPath)) : "")
            // Apply fragment shaders
            if (config.buffers["Buffer A"]) {
                var aUrl
                if (config.buffers["Buffer A"].code) {
                    aUrl = compileWithCommon(config.buffers["Buffer A"].code, commonCode2, "BufferA")
                } else if (commonCode2 && commonCode2.length > 0 && config.buffers["Buffer A"].fragmentShader) {
                    var aSrc = readTextFile(normalizeFileUrl(config.buffers["Buffer A"].fragmentShader))
                    aUrl = compileWithCommon(aSrc, commonCode2, "BufferA")
                } else {
                    aUrl = compileFragIfNeeded(config.buffers["Buffer A"].fragmentShader, "BufferA")
                }
                if (aUrl) bufferAEff.fragmentShader = aUrl
                var aCode = config.buffers["Buffer A"].code ? config.buffers["Buffer A"].code : readTextFile(normalizeFileUrl(config.buffers["Buffer A"].fragmentShader))
                if (aCode && aCode.length > 0) shaderData["Buffer A"] = stripRuntimeHeader(aCode)
            }
            if (config.buffers["Buffer B"]) {
                var bUrl
                if (config.buffers["Buffer B"].code) {
                    bUrl = compileWithCommon(config.buffers["Buffer B"].code, commonCode2, "BufferB")
                } else if (commonCode2 && commonCode2.length > 0 && config.buffers["Buffer B"].fragmentShader) {
                    var bSrc = readTextFile(normalizeFileUrl(config.buffers["Buffer B"].fragmentShader))
                    bUrl = compileWithCommon(bSrc, commonCode2, "BufferB")
                } else {
                    bUrl = compileFragIfNeeded(config.buffers["Buffer B"].fragmentShader, "BufferB")
                }
                if (bUrl) bufferBEff.fragmentShader = bUrl
                var bCode = config.buffers["Buffer B"].code ? config.buffers["Buffer B"].code : readTextFile(normalizeFileUrl(config.buffers["Buffer B"].fragmentShader))
                if (bCode && bCode.length > 0) shaderData["Buffer B"] = stripRuntimeHeader(bCode)
            }
            if (config.buffers["Buffer C"]) {
                var cUrl2
                if (config.buffers["Buffer C"].code) {
                    cUrl2 = compileWithCommon(config.buffers["Buffer C"].code, commonCode2, "BufferC")
                } else if (commonCode2 && commonCode2.length > 0 && config.buffers["Buffer C"].fragmentShader) {
                    var cSrc = readTextFile(normalizeFileUrl(config.buffers["Buffer C"].fragmentShader))
                    cUrl2 = compileWithCommon(cSrc, commonCode2, "BufferC")
                } else {
                    cUrl2 = compileFragIfNeeded(config.buffers["Buffer C"].fragmentShader, "BufferC")
                }
                if (cUrl2) bufferCEff.fragmentShader = cUrl2
                var cCode = config.buffers["Buffer C"].code ? config.buffers["Buffer C"].code : readTextFile(normalizeFileUrl(config.buffers["Buffer C"].fragmentShader))
                if (cCode && cCode.length > 0) shaderData["Buffer C"] = stripRuntimeHeader(cCode)
            }
            if (config.buffers["Buffer D"]) {
                var dUrl2
                if (config.buffers["Buffer D"].code) {
                    dUrl2 = compileWithCommon(config.buffers["Buffer D"].code, commonCode2, "BufferD")
                } else if (commonCode2 && commonCode2.length > 0 && config.buffers["Buffer D"].fragmentShader) {
                    var dSrc = readTextFile(normalizeFileUrl(config.buffers["Buffer D"].fragmentShader))
                    dUrl2 = compileWithCommon(dSrc, commonCode2, "BufferD")
                } else {
                    dUrl2 = compileFragIfNeeded(config.buffers["Buffer D"].fragmentShader, "BufferD")
                }
                if (dUrl2) bufferDEff.fragmentShader = dUrl2
                var dCode = config.buffers["Buffer D"].code ? config.buffers["Buffer D"].code : readTextFile(normalizeFileUrl(config.buffers["Buffer D"].fragmentShader))
                if (dCode && dCode.length > 0) shaderData["Buffer D"] = stripRuntimeHeader(dCode)
            }
            if (config.buffers["Image"]) {
                var iUrl
                if (config.buffers["Image"].code) {
                    iUrl = compileWithCommon(config.buffers["Image"].code, commonCode2, "Image")
                } else if (commonCode2 && commonCode2.length > 0 && config.buffers["Image"].fragmentShader) {
                    var iSrc = readTextFile(normalizeFileUrl(config.buffers["Image"].fragmentShader))
                    iUrl = compileWithCommon(iSrc, commonCode2, "Image")
                } else {
                    iUrl = compileFragIfNeeded(config.buffers["Image"].fragmentShader, "Image")
                }
                if (iUrl) shaderDisplay.fragmentShader = iUrl
                var iCode = config.buffers["Image"].code ? config.buffers["Image"].code : readTextFile(normalizeFileUrl(config.buffers["Image"].fragmentShader))
                if (iCode && iCode.length > 0) shaderData["Image"] = stripRuntimeHeader(iCode)
                currentBufferName = "Image"
                codeEditor.text = shaderData["Image"]
                for (var idx=0; idx<bufferModel.count; ++idx) { if (bufferModel.get(idx).name === "Image") { bufferTabs.currentIndex = idx; break; } }
            }
        
            // Apply channels
            if (config.buffers["Buffer A"]) setChannelsFor("Buffer A", config.buffers["Buffer A"].channels)
            if (config.buffers["Buffer B"]) setChannelsFor("Buffer B", config.buffers["Buffer B"].channels)
            if (config.buffers["Buffer C"]) setChannelsFor("Buffer C", config.buffers["Buffer C"].channels)
            if (config.buffers["Buffer D"]) setChannelsFor("Buffer D", config.buffers["Buffer D"].channels)
            if (config.buffers["Image"]) setChannelsFor("Image", config.buffers["Image"].channels)
        }
        
        // Force UI update
        channelSources = channelSources
    }

    background: Rectangle { color: theme.primaryColor }

    // Model for active buffers
    ListModel {
        id: bufferModel
        ListElement { name: "Image" }
    }

    // Model for available textures
    ListModel {
        id: textureModel
        ListElement { text: "None"; source: "" }
        ListElement { text: "Texture 1"; source: "qrc:/new/prefix1/fonts/pic/01.jpg" }
        ListElement { text: "Texture 2"; source: "qrc:/new/prefix1/fonts/pic/02.jpg" }
        ListElement { text: "Texture 3"; source: "qrc:/new/prefix1/fonts/pic/020.jpg" }
        ListElement { text: "Avatar"; source: "qrc:/new/prefix1/fonts/pic/avatar.png" }
    }

    SplitView {
        anchors.fill: parent
        orientation: Qt.Horizontal
        
        handle: Rectangle {
            implicitWidth: 6
            color: theme.secondaryColor
            
            Rectangle {
                width: 1
                height: parent.height
                color: theme.borderColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // Left Panel: Shader Display and Empty Area
        Item {
            SplitView.preferredWidth: parent.width * 0.4
            SplitView.minimumWidth: 300
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Upper Section: Shader Preview
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: parent.height * 0.5 
                    
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 0
                        
                        // Shader View
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            
                            EShadertoy {
                                id: shaderDisplay
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                showHud: true
                                running: true
                            }
                            // Offscreen buffer chain (A->B->C->D)
                            Item {
                                id: offscreenChain
                                anchors.fill: shaderDisplay
                                visible: true

                                // Buffer A
        ShaderEffect {
            id: bufferAEff
            anchors.fill: parent
            fragmentShader: "" // set dynamically
            property vector3d iResolution: shaderDisplay.iResolution
            property real iTime: shaderDisplay.iTime
            property real iTimeDelta: shaderDisplay.iTimeDelta
            property int iFrame: shaderDisplay.iFrame
            property real iFrameRate: shaderDisplay.iFrameRate
            property vector4d iMouse: shaderDisplay.iMouse
            property var iChannel0
            property var iChannel1
            property var iChannel2
            property var iChannel3
            property var source: iChannel0
            property var iChannelTime: [0,1,2,3]
            property var iChannelResolution: [shaderDisplay.iResolution, shaderDisplay.iResolution, shaderDisplay.iResolution, shaderDisplay.iResolution]
            property vector4d iDate: shaderDisplay.iDate
            property real iSampleRate: shaderDisplay.iSampleRate
            property real tar: shaderDisplay.tar
        }
                                // Texture sources for A
                                Image { id: texA0; anchors.fill: parent; visible: false }
                                Image { id: texA1; anchors.fill: parent; visible: false }
                                Image { id: texA2; anchors.fill: parent; visible: false }
                                Image { id: texA3; anchors.fill: parent; visible: false }
                                ShaderEffectSource { id: texA0Src; sourceItem: texA0; hideSource: true; live: true }
                                ShaderEffectSource { id: texA1Src; sourceItem: texA1; hideSource: true; live: true }
                                ShaderEffectSource { id: texA2Src; sourceItem: texA2; hideSource: true; live: true }
                                ShaderEffectSource { id: texA3Src; sourceItem: texA3; hideSource: true; live: true }
                                ShaderEffectSource { id: bufferASrc; sourceItem: bufferAEff; hideSource: true; live: true; smooth: false; recursive: true }

                                // Buffer B
        ShaderEffect {
            id: bufferBEff
            anchors.fill: parent
            fragmentShader: ""
            property vector3d iResolution: shaderDisplay.iResolution
            property real iTime: shaderDisplay.iTime
            property real iTimeDelta: shaderDisplay.iTimeDelta
            property int iFrame: shaderDisplay.iFrame
            property real iFrameRate: shaderDisplay.iFrameRate
            property vector4d iMouse: shaderDisplay.iMouse
            property var iChannel0: bufferASrc
            property var iChannel1
            property var iChannel2
            property var iChannel3
            property var source: iChannel0
            property var iChannelTime: [0,1,2,3]
            property var iChannelResolution: [shaderDisplay.iResolution, shaderDisplay.iResolution, shaderDisplay.iResolution, shaderDisplay.iResolution]
            property vector4d iDate: shaderDisplay.iDate
            property real iSampleRate: shaderDisplay.iSampleRate
            property real tar: shaderDisplay.tar
        }
                                // Texture sources for B (channels 1..3)
                                Image { id: texB0; anchors.fill: parent; visible: false }
                                Image { id: texB1; anchors.fill: parent; visible: false }
                                Image { id: texB2; anchors.fill: parent; visible: false }
                                Image { id: texB3; anchors.fill: parent; visible: false }
                                ShaderEffectSource { id: texB0Src; sourceItem: texB0; hideSource: true; live: true }
                                ShaderEffectSource { id: texB1Src; sourceItem: texB1; hideSource: true; live: true }
                                ShaderEffectSource { id: texB2Src; sourceItem: texB2; hideSource: true; live: true }
                                ShaderEffectSource { id: texB3Src; sourceItem: texB3; hideSource: true; live: true }
                                ShaderEffectSource { id: bufferBSrc; sourceItem: bufferBEff; hideSource: true; live: true; smooth: false }

                                // Buffer C
        ShaderEffect {
            id: bufferCEff
            anchors.fill: parent
            fragmentShader: ""
            property vector3d iResolution: shaderDisplay.iResolution
            property real iTime: shaderDisplay.iTime
            property real iTimeDelta: shaderDisplay.iTimeDelta
            property int iFrame: shaderDisplay.iFrame
            property real iFrameRate: shaderDisplay.iFrameRate
            property vector4d iMouse: shaderDisplay.iMouse
            property var iChannel0: bufferBSrc
            property var iChannel1
            property var iChannel2
            property var iChannel3
            property var source: iChannel0
            property var iChannelTime: [0,1,2,3]
            property var iChannelResolution: [shaderDisplay.iResolution, shaderDisplay.iResolution, shaderDisplay.iResolution, shaderDisplay.iResolution]
            property vector4d iDate: shaderDisplay.iDate
            property real iSampleRate: shaderDisplay.iSampleRate
            property real tar: shaderDisplay.tar
        }
                                // Texture sources for C (channels 1..3)
                                Image { id: texC0; anchors.fill: parent; visible: false }
                                Image { id: texC1; anchors.fill: parent; visible: false }
                                Image { id: texC2; anchors.fill: parent; visible: false }
                                Image { id: texC3; anchors.fill: parent; visible: false }
                                ShaderEffectSource { id: texC0Src; sourceItem: texC0; hideSource: true; live: true }
                                ShaderEffectSource { id: texC1Src; sourceItem: texC1; hideSource: true; live: true }
                                ShaderEffectSource { id: texC2Src; sourceItem: texC2; hideSource: true; live: true }
                                ShaderEffectSource { id: texC3Src; sourceItem: texC3; hideSource: true; live: true }
                                ShaderEffectSource { id: bufferCSrc; sourceItem: bufferCEff; hideSource: true; live: true; smooth: false }

                                // Buffer D
        ShaderEffect {
            id: bufferDEff
            anchors.fill: parent
            fragmentShader: ""
            property vector3d iResolution: shaderDisplay.iResolution
            property real iTime: shaderDisplay.iTime
            property real iTimeDelta: shaderDisplay.iTimeDelta
            property int iFrame: shaderDisplay.iFrame
            property real iFrameRate: shaderDisplay.iFrameRate
            property vector4d iMouse: shaderDisplay.iMouse
            property var iChannel0: bufferCSrc
            property var iChannel1
            property var iChannel2
            property var iChannel3
            property var source: iChannel0
            property var iChannelTime: [0,1,2,3]
            property var iChannelResolution: [shaderDisplay.iResolution, shaderDisplay.iResolution, shaderDisplay.iResolution, shaderDisplay.iResolution]
            property vector4d iDate: shaderDisplay.iDate
            property real iSampleRate: shaderDisplay.iSampleRate
            property real tar: shaderDisplay.tar
        }
                                // Texture sources for D (channels 1..3)
                                Image { id: texD0; anchors.fill: parent; visible: false }
                                Image { id: texD1; anchors.fill: parent; visible: false }
                                Image { id: texD2; anchors.fill: parent; visible: false }
                                Image { id: texD3; anchors.fill: parent; visible: false }
                                ShaderEffectSource { id: texD0Src; sourceItem: texD0; hideSource: true; live: true }
                                ShaderEffectSource { id: texD1Src; sourceItem: texD1; hideSource: true; live: true }
                                ShaderEffectSource { id: texD2Src; sourceItem: texD2; hideSource: true; live: true }
                                ShaderEffectSource { id: texD3Src; sourceItem: texD3; hideSource: true; live: true }
                                ShaderEffectSource { id: bufferDSrc; sourceItem: bufferDEff; hideSource: true; live: true; smooth: false }
                                // Image page extra channels 1..3
                                Image { id: texImg0; anchors.fill: parent; visible: false }
                                Image { id: texImg1; anchors.fill: parent; visible: false }
                                Image { id: texImg2; anchors.fill: parent; visible: false }
                                Image { id: texImg3; anchors.fill: parent; visible: false }
                                ShaderEffectSource { id: texImg0Src; sourceItem: texImg0; hideSource: true; live: true }
                                ShaderEffectSource { id: texImg1Src; sourceItem: texImg1; hideSource: true; live: true }
                                ShaderEffectSource { id: texImg2Src; sourceItem: texImg2; hideSource: true; live: true }
                                ShaderEffectSource { id: texImg3Src; sourceItem: texImg3; hideSource: true; live: true }
                            }
                        }
                    }
                }
                
                // Lower Section: Empty for now
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: theme.primaryColor
                    
                    Text {
                        anchors.centerIn: parent
                        text: "Description / Inputs (Empty)"
                        color: theme.textColor
                        opacity: 0.4
                    }
                }
            }
        }

        // Right Panel: Editor & Config
        Item {
            SplitView.fillWidth: true
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Toolbar
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: theme.secondaryColor
                    z: 10 // Ensure dropdown is above editor

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 4
                        spacing: 0
                        
                        TabBar {
                            id: bufferTabs
                            Layout.preferredWidth: implicitWidth
                            Layout.maximumWidth: parent.width - 150
                            Layout.fillHeight: true
                            background: Rectangle { color: "transparent" }
                            contentHeight: 40
                            
                            Repeater {
                                model: bufferModel
                                TabButton {
                                    id: tabBtn
                                    text: name
                                    width: implicitWidth + 30 // Extra space for close button
                                    
                                    contentItem: Item {
                                        implicitWidth: row.implicitWidth
                                        implicitHeight: row.implicitHeight
                                        
                                        RowLayout {
                                            id: row
                                            anchors.centerIn: parent
                                            spacing: 4
                                            
                                            Text {
                                                text: tabBtn.text
                                                font: tabBtn.font
                                                color: tabBtn.checked ? theme.textColor : theme.textColor
                                                opacity: tabBtn.checked ? 1.0 : 0.6
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            
                                            Text {
                                                text: "\uf00d" // X icon
                                                font.family: "Font Awesome 6 Free"
                                                font.pixelSize: 10
                                                color: tabBtn.checked ? theme.textColor : theme.textColor
                                                opacity: 0.6
                                                visible: tabBtn.text !== "Image" // Cannot delete Image
                                                
                                                MouseArea {
                                                    anchors.fill: parent
                                                    anchors.margins: -4
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        root.deleteBuffer(index)
                                                    }
                                                    onEntered: parent.opacity = 1.0
                                                    onExited: parent.opacity = 0.6
                                                }
                                            }
                                        }
                                    }
                                    
                                    background: Rectangle {
                                        color: parent.checked ? theme.primaryColor : theme.secondaryColor
                                        Rectangle {
                                            width: parent.width
                                            height: 2
                                            anchors.top: parent.top
                                            color: parent.checked ? theme.focusColor : "transparent"
                                        }
                                    }
                                }
                            }
                            
                            onCurrentIndexChanged: {
                                root.switchBuffer(currentIndex)
                            }
                        }
                        
                        // Add Buffer Dropdown
                        EDropdown {
                            id: addBufferDropdown
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 32
                            headerHeight: 32
                            Layout.alignment: Qt.AlignVCenter
                            radius: 4
                            title: " Add"
                            fontSize: 14
                            backgroundVisible: true
                            headerColor: theme.primaryColor
                            
                            // Dynamically generate model based on what's missing
                            property var allBuffers: ["Common", "Buffer A", "Buffer B", "Buffer C", "Buffer D"]
                            // Bind to bufferModel.count to force update when buffers change
                            property int _trigger: bufferModel.count 
                            
                            model: {
                                // Use the trigger to ensure re-evaluation
                                var t = _trigger; 
                                var m = [];
                                for (var i=0; i<allBuffers.length; i++) {
                                    if (!root.isBufferActive(allBuffers[i])) {
                                        m.push({text: allBuffers[i], value: allBuffers[i]});
                                    }
                                }
                                return m;
                            }
                            
                            onSelectionChanged: function(index, item) {
                                if (item && item.value) {
                                    root.addBuffer(item.value);
                                    // Reset selection to show title again
                                    selectedIndex = -1;
                                }
                            }
                        }
                        
                        Item { Layout.fillWidth: true }
                        
                        EButton {
                            text: "Compile"
                            iconCharacter: "\uf04b"
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 32
                            Layout.alignment: Qt.AlignVCenter
                            Layout.rightMargin: 8
                            buttonColor: theme.focusColor
                            textColor: "#ffffff"
                            radius: 4
                            fontSize: 12
                            onClicked: {
                                root.compileShaders()
                            }
                        }
                    }
                }

                // Code Editor
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: theme.primaryColor
                    
                    ScrollView {
                        id: editorScroll
                        anchors.fill: parent
                        clip: true
                        
                        TextArea {
                            id: codeEditor
                            // Initialize with Image code
                            Component.onCompleted: text = root.shaderData["Image"]
                            
                            font.family: "Consolas, monospace"
                            font.pixelSize: 14
                            color: theme.textColor
                            selectionColor: theme.focusColor
                            selectedTextColor: "#ffffff"
                            background: null
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            
                            // Line numbers
                            leftPadding: 40
                            
                            Rectangle {
                                width: 36
                                height: parent.height
                                color: theme.secondaryColor
                                anchors.left: parent.left
                                anchors.top: parent.top
                                
                                Column {
                                    width: parent.width
                                    y: -codeEditor.cursorRectangle.y + codeEditor.cursorRectangle.y 
                                }
                                // border.color: theme.borderColor // Removing border as requested
                                // border.width: 1
                                anchors.leftMargin: -40
                            }
                        }
                    }
                }

                // Channel Config Panel
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160
                    color: theme.secondaryColor
                    
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        
                        Text {
                            text: "iChannels Config (" + root.currentBufferName + ")"
                            color: theme.textColor
                            font.bold: true
                            font.pixelSize: 12
                        }
                        
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 10
                            
                            Repeater {
                                model: 4
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: theme.primaryColor
                                    radius: 4
                                    // border.color: theme.borderColor // Removing border
                                    
                                    property int channelIndex: index
                                    property string currentSource: ""
                                    
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 4
                                        
                                        RowLayout {
                                            Text { 
                                                text: "iChannel" + channelIndex 
                                                color: theme.textColor
                                                opacity: 0.6
                                                font.pixelSize: 11
                                            }
                                            Item { Layout.fillWidth: true }
                                        }
                                        
                                        // Preview
                                        Rectangle {
                                            Layout.alignment: Qt.AlignHCenter
                                            width: 48
                                            height: 48
                                            color: "#000000"
                                            // border.color: theme.borderColor // Removing border
                                            
                                            Image {
                                                anchors.fill: parent
                                                anchors.margins: 1
                                                fillMode: Image.PreserveAspectFit
                                                source: (channelSources[currentBufferName] && channelSources[currentBufferName][channelIndex] && channelSources[currentBufferName][channelIndex].kind === "file") ? channelSources[currentBufferName][channelIndex].value : ""
                                                visible: source !== ""
                                            }
                                            
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Empty"
                                                color: theme.textColor
                                                opacity: 0.4
                                                font.pixelSize: 10
                                                visible: !(channelSources[currentBufferName] && channelSources[currentBufferName][channelIndex] && channelSources[currentBufferName][channelIndex].kind === "file" && channelSources[currentBufferName][channelIndex].value !== "")
                                            }
                                        }
                                        
                                        // Selector
                                        EDropdown {
                                            id: channelDropdown
                                            Layout.fillWidth: true
                                            height: 24
                                            headerHeight: 24
                                            radius: 2
                                            title: "Select..."
                                            popupDirection: 1 // Up
                                            z: opened ? 100 : 1
                                            property var channelModel: textureDropdownModel(channelIndex)
                                            model: channelModel
                                            selectedIndex: root.getSelectedIndex(currentBufferName, channelIndex, channelModel)
                                            
                                            Connections {
                                                target: root
                                                function onCurrentBufferNameChanged() {
                                                    channelDropdown.selectedIndex = Qt.binding(function() { 
                                                        return root.getSelectedIndex(root.currentBufferName, channelIndex, channelDropdown.channelModel) 
                                                    })
                                                }
                                            }

                                            onSelectionChanged: function(idx, item) {
                                                if (channelSources[currentBufferName]) {
                                                    channelSources[currentBufferName][channelIndex] = { kind: item.kind, value: item.value, text: item.text }
                                                    // Force update for preview images and other bindings
                                                    root.channelSources = root.channelSources
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
