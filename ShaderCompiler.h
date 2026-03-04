#ifndef SHADERCOMPILER_H
#define SHADERCOMPILER_H

#include <QObject>
#include <QString>
#include <QUrl>
#include <QVariant>

class ShaderCompiler : public QObject
{
    Q_OBJECT
public:
    explicit ShaderCompiler(QObject *parent = nullptr);

    Q_INVOKABLE QUrl compile(const QString &source, const QString &bufferName);
    Q_INVOKABLE QString lastError() const;
    Q_INVOKABLE QString ensureTextureDir();
    Q_INVOKABLE QVariantList listTextures(const QString &directory = QString());

private:
    QString m_lastError;
};

#endif // SHADERCOMPILER_H
