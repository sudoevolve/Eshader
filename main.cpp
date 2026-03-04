#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QIcon>
#include "ShaderCompiler.h"

int main(int argc, char *argv[]) {
        // 设置OpenGL后端确保shader适配性
    qputenv("QSG_RHI_BACKEND", "opengl");
    qputenv("QML_XHR_ALLOW_FILE_READ", "1");
    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/new/prefix1/fonts/icon.ico"));

    qmlRegisterType<ShaderCompiler>("EvolveUI", 1, 0, "ShaderCompiler");

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [](){ QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("EvolveUI", "Main");
    return app.exec();
}
