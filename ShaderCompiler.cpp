#include "ShaderCompiler.h"
#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QStandardPaths>
#include <QProcess>
#include <QDebug>
#include <QLibraryInfo>
#include <QUrl>
#include <QCoreApplication>

ShaderCompiler::ShaderCompiler(QObject *parent) : QObject(parent) {}

QUrl ShaderCompiler::compile(const QString &source, const QString &bufferName)
{
    m_lastError.clear();

    // 1) Write source to a temp .frag file
    const QString tempPath = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    QDir dir(tempPath);
    if (!dir.exists()) dir.mkpath(".");

    const qint64 ts = QDateTime::currentMSecsSinceEpoch();
    const QString inFile = QString("%1/Eshader_%2_%3.frag").arg(tempPath, bufferName).arg(ts);
    const QString outFile = QString("%1/Eshader_%2_%3.frag.qsb").arg(tempPath, bufferName).arg(ts);

    {
        QFile f(inFile);
        if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            m_lastError = "Could not write input shader file: " + inFile;
            qWarning() << m_lastError;
            return QUrl();
        }
        
        QByteArray data = source.toUtf8();
        // If no version directive is present, prepend a modern GLSL version (OpenGL 3.3 Core)
        // to ensure features like texelFetch are supported and prevent "legacy ES" fallback.
        if (!source.trimmed().startsWith("#version")) {
            data.prepend("#version 330 core\n");
        }
        
        f.write(data);
        f.close();
    }

    // 2) Locate qsb executable
    QString qsbPath = QStandardPaths::findExecutable("qsb");
    if (qsbPath.isEmpty()) {
        const QString binPath = QLibraryInfo::path(QLibraryInfo::BinariesPath);
        const QString candidate = binPath + QDir::separator() + "qsb" + (QStringLiteral(".exe"));
        if (QFile::exists(candidate)) qsbPath = candidate;
    }

    if (qsbPath.isEmpty()) {
        m_lastError = "qsb executable not found in PATH or Qt binaries.";
        qWarning() << m_lastError;
        return QUrl();
    }

    // 3) Invoke qsb to generate a multi-target .qsb
    QStringList args;
    args << "--glsl" << "330,300 es";
    args << "--hlsl" << "50";
    args << "--msl" << "12";
    args << "-o" << outFile << inFile;

    QProcess proc;
    proc.start(qsbPath, args);
    if (!proc.waitForFinished(15000)) {
        m_lastError = "qsb process timeout or failed to start.";
        qWarning() << m_lastError;
        return QUrl();
    }

    if (proc.exitStatus() != QProcess::NormalExit || proc.exitCode() != 0) {
        m_lastError = QString::fromUtf8(proc.readAllStandardError());
        if (m_lastError.trimmed().isEmpty()) m_lastError = "qsb failed with unknown error.";
        qWarning() << "qsb error:" << m_lastError;
        return QUrl();
    }

    if (!QFile::exists(outFile)) {
        m_lastError = "Compiled .qsb not produced.";
        qWarning() << m_lastError;
        return QUrl();
    }

    qDebug() << "Shader compiled successfully to:" << outFile;
    return QUrl::fromLocalFile(outFile);
}

QString ShaderCompiler::lastError() const
{
    return m_lastError;
}

QString ShaderCompiler::ensureTextureDir()
{
    QStringList candidates;
    candidates << QDir::cleanPath(QDir::currentPath() + "/textures");
    candidates << QDir::cleanPath(QCoreApplication::applicationDirPath() + "/textures");
    candidates << QDir::cleanPath(QFileInfo(QStringLiteral(__FILE__)).absolutePath() + "/textures");

    QString dirPath;
    for (const QString &p : candidates) {
        QDir d(p);
        if (d.exists()) { dirPath = p; break; }
    }
    if (dirPath.isEmpty()) dirPath = candidates.first();
    QDir d(dirPath);
    if (!d.exists()) d.mkpath(".");
    QString normalized = dirPath;
    normalized.replace(QLatin1Char('\\'), QLatin1Char('/'));
    return normalized;
}

QVariantList ShaderCompiler::listTextures(const QString &directory)
{
    QString dirPath = directory;
    if (dirPath.isEmpty()) dirPath = ensureTextureDir();
    QDir d(dirPath);
    if (!d.exists()) return QVariantList{};

    QStringList filters;
    filters << "*.png" << "*.jpg" << "*.jpeg" << "*.bmp" << "*.gif" << "*.webp";
    QFileInfoList files = d.entryInfoList(filters, QDir::Files | QDir::Readable, QDir::Name);

    QVariantList out;
    for (const QFileInfo &fi : files) {
        QVariantMap m;
        m.insert("text", fi.fileName());
        m.insert("kind", QStringLiteral("file"));
        m.insert("value", QUrl::fromLocalFile(fi.absoluteFilePath()).toString());
        out.append(m);
    }
    return out;
}
