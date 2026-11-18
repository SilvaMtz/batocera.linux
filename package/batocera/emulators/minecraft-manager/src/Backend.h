#pragma once

#include <QObject>
#include <QStringList>
#include <QVariant>

// Runs batocera-minecraft-mods --json <args> without blocking the screen and
// hands its JSON result to QML. MINECRAFT_MODS_CMD replaces the command, for
// trying the app against test data, e.g.
//   MINECRAFT_MODS_CMD="python3 batocera-minecraft-mods --data /tmp/test"
class Backend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int running READ running NOTIFY runningChanged)

public:
    explicit Backend(QObject *parent = nullptr);

    // Starts the command; finished(id, result) follows. result is the parsed
    // JSON, or {"error": "..."} if the command couldn't run or said nothing.
    Q_INVOKABLE int run(const QStringList &args);
    int running() const { return m_running; }

signals:
    void finished(int id, const QVariant &result);
    void runningChanged();

private:
    void done(int id, const QVariant &result);

    QStringList m_command;
    int m_nextId = 1;
    int m_running = 0;
};
