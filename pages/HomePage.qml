import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EvolveUI

Page {
    id: window
    property alias animatedWindow: animationWrapper
    background: Rectangle { color: "transparent" }

    RowLayout {
        anchors.centerIn: parent
        spacing: 20

        ELiquidGlass {
            id: glass
            Layout.preferredWidth: 900
            Layout.preferredHeight: 600
            backgroundImage: "qrc:/new/prefix1/fonts/pic/01.jpg"
            running: true
            interactive: true
        }

        ColumnLayout {
            spacing: 10

            EButton {
                text: glass.running ? "暂停" : "开始"
                iconCharacter: glass.running ? "\uf04c" : "\uf04b"
                iconRotateOnClick: true
                onClicked: glass.running = !glass.running
            }

            ESwitchButton {
                id: jellySwitch
                text: checked ? "弹性效果：开" : "弹性效果：关"
                checked: false
                onToggled: glass.effectsEnabled = checked ? 1.0 : 0.0
                Component.onCompleted: glass.effectsEnabled = checked ? 1.0 : 0.0
            }

            ESlider {
                text: "模糊强度"
                itemSpacing: 8
                labelWidth: 80
                minimumValue: 0.00
                maximumValue: 2.00
                decimals: 2
                stepSize: 2
                showSpinBox: true
                value: 0.20
                onUserValueChanged: glass.blurOffsetScale = value
                Component.onCompleted: glass.blurOffsetScale = value
            }

            ESlider {
                text: "宽度缩放"
                itemSpacing: 8
                labelWidth: 80
                minimumValue: 0.10
                maximumValue: 2.00
                decimals: 2
                stepSize: 2
                showSpinBox: true
                value: 0.30
                onUserValueChanged: glass.shapeScaleX = value
                Component.onCompleted: glass.shapeScaleX = value
            }

            ESlider {
                text: "高度缩放"
                itemSpacing: 8
                labelWidth: 80
                minimumValue: 0.10
                maximumValue: 2.00
                decimals: 2
                stepSize: 2
                showSpinBox: true
                value: 0.30
                onUserValueChanged: glass.shapeScaleY = value
                Component.onCompleted: glass.shapeScaleY = value
            }

            ESlider {
                text: "玻璃圆角"
                itemSpacing: 8
                labelWidth: 80
                minimumValue: 0.00
                maximumValue: 0.30
                decimals: 2
                stepSize: 2
                showSpinBox: true
                value: 0.10
                onUserValueChanged: glass.shapeRadius = value
                Component.onCompleted: glass.shapeRadius = value
            }

            ESlider {
                text: "玻璃大小"
                itemSpacing: 8
                labelWidth: 80
                minimumValue: 0.10
                maximumValue: 2.00
                decimals: 2
                stepSize: 2
                showSpinBox: true
                value: 0.30
                onUserValueChanged: {
                    glass.shapeScaleX = value
                    glass.shapeScaleY = value
                }
                Component.onCompleted: {
                    glass.shapeScaleX = value
                    glass.shapeScaleY = value
                }
            }

            ESlider {
                text: "折射宽度"
                itemSpacing: 8
                labelWidth: 80
                minimumValue: 0.01
                maximumValue: 2.00
                decimals: 2
                stepSize: 2
                showSpinBox: true
                value: 0.15
                onUserValueChanged: glass.lens_refraction = value
                Component.onCompleted: glass.lens_refraction = value
            }

            ESlider {
                text: "色散强度"
                itemSpacing: 8
                labelWidth: 80
                minimumValue: 0.00
                maximumValue: 0.05
                decimals: 3
                stepSize: 3
                showSpinBox: true
                value: 0.010
                onUserValueChanged: glass.chromaticAberration = value
                Component.onCompleted: glass.chromaticAberration = value
            }
        }
    }

    EAnimatedWindow {
        id: animationWrapper
    }
}
