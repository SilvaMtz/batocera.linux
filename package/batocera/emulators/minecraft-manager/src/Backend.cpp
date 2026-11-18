#include "Backend.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QVariantMap>

Backend::Backend(QObject *parent)
    : QObject(parent)
{
    const QString custom = qEnvironmentVariable("MINECRAFT_MODS_CMD");
    m_command = custom.isEmpty() ? QStringList{QStringLiteral("batocera-minecraft-mods")}
                                 : QProcess::splitCommand(custom);
}

int Backend::run(const QStringList &args)
{
    const int id = m_nextId++;
    auto *process = new QProcess(this);
    process->setProgram(m_command.first());
    process->setArguments(m_command.mid(1) + QStringList{QStringLiteral("--json")} + args);

    connect(process, &QProcess::finished, this, [this, process, id](int, QProcess::ExitStatus) {
        const QByteArray out = process->readAllStandardOutput();
        QJsonParseError parseError;
        const QJsonDocument doc = QJsonDocument::fromJson(out, &parseError);
        if (parseError.error == QJsonParseError::NoError && doc.isObject()) {
            done(id, doc.object().toVariantMap());
        } else {
            QString detail = QString::fromUtf8(process->readAllStandardError()).trimmed();
            if (detail.isEmpty())
                detail = QString::fromUtf8(out).trimmed();
            done(id, QVariantMap{{QStringLiteral("error"),
                                  QStringLiteral("The mod tool failed: %1").arg(detail.right(400))}});
        }
        process->deleteLater();
    });
    connect(process, &QProcess::errorOccurred, this, [this, process, id](QProcess::ProcessError error) {
        if (error != QProcess::FailedToStart)
            return;  // other errors still end in finished()
        done(id, QVariantMap{{QStringLiteral("error"),
                              QStringLiteral("Can't run %1: %2").arg(m_command.first(), process->errorString())}});
        process->deleteLater();
    });

    ++m_running;
    emit runningChanged();
    process->start();
    return id;
}

void Backend::done(int id, const QVariant &result)
{
    --m_running;
    emit runningChanged();
    emit finished(id, result);
}
