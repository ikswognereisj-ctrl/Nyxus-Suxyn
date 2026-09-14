// NYXUS Suxyn — the shell's translation loader (TRK-1920, closes TRK-1581).
// © 2026 JOSEPH A. SIERENGOWSKI · NYX-J5W-2026-SIERENGOWSKI-LOCKED
//
// ── WHY THIS EXISTS ─────────────────────────────────────────────────────────
// TRK-1578 wrapped 1299 user-visible strings in qsTr() and TRK-1580 taught the
// bake to compile shell/i18n/<lang>.po into ~/.config/quickshell/i18n/<lang>.qm.
// Both are correct. Neither did anything, because a .qm is only ever read by a
// QTranslator and NOTHING INSTALLS ONE:
//
//   * `nm -D /usr/bin/qs` has no QTranslator / installTranslator symbol —
//     Quickshell never constructs one (re-verified 2026-08-22, quickshell
//     0.3.0-2, Qt 6.11.1).
//   * Quickshell builds its engine on plain QQmlEngine + QQmlComponent, NOT
//     QQmlApplicationEngine — verified in the same symbol table. That matters,
//     because QQmlApplicationEngine is the ONE Qt class that loads a catalogue
//     on its own (an `i18n/qml_<locale>.qm` beside the loaded file; the "/i18n"
//     literal is in libQt6Qml.so.6 and belongs to it). qs cannot reach it.
//   * Measured, not assumed: a probe config with `i18n/es.qm` AND
//     `i18n/qml_es.qm` sitting next to shell.qml printed the SOURCE strings.
//   * QML has no API to install a translator, and qsTr() is compiled to a
//     QQmlTranslation by the QML compiler — it cannot be shadowed from QML, so
//     a JS-side catalogue would mean rewriting all 1299 call sites.
//
// ── WHAT THIS IS ────────────────────────────────────────────────────────────
// A QGenericPlugin. Qt itself loads generic plugins named in the
// QT_QPA_GENERIC_PLUGINS environment variable, from inside QGuiApplication's
// constructor — i.e. after QCoreApplication::instance() exists and long before
// any QML is parsed. That is a Qt-level hook that needs no cooperation from
// Quickshell at all: no patch, no fork, no upstream request.
//
// create() installs the QTranslator and returns an inert QObject (Qt warns
// "No such plugin for spec" on a null return; the object costs nothing and
// keeps the shell log clean). The plugin is deliberately silent and free when
// the language is English — the default path allocates nothing.
//
// ── THE LANGUAGE, AND WHERE THE CATALOGUE IS ────────────────────────────────
// Same resolution order as nyxus_i18n.py so the shell and the Python/GTK apps
// agree on one answer, and so Settings ▸ Personal ▸ Language — which already
// writes ~/.config/nyxus/locale.conf via write_user_locale() — now moves the
// shell too:
//
//     $NYXUS_LANG → ~/.config/nyxus/locale.conf → $LANGUAGE → $LANG
//
// The catalogue is $XDG_CONFIG_HOME/quickshell/i18n/<lang>.qm, which is exactly
// where build-iso.sh's TRK-1580 step writes it. NYXUS_SHELL_I18N_DIR overrides
// the directory; the gate (13t97) uses it to prove translation against a
// scratch copy without touching the user's config.
//
// ── THE CONTEXT RULE ────────────────────────────────────────────────────────
// QML's qsTr() context is the .qml BASE NAME and QTranslator matches it
// EXACTLY, with no fallback to a context-less entry (TRK-1579 measured this).
// Every entry in shell/i18n/*.po therefore carries msgctxt = the file's base
// name. Nothing in this file needs to know that — but a catalogue that loses
// its msgctxt will load fine here and translate nothing, so it is written down
// where the loader lives.
//
// Build with scripts/build-shell-translator.sh. Do not add dependencies: this
// links Qt6Core and Qt6Gui only, both of which the shell already needs.

#include <QtGui/qgenericplugin.h>

#include <QByteArray>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QIODevice>
#include <QLatin1String>
#include <QObject>
#include <QString>
#include <QTranslator>

// $NYXUS_LANG → ~/.config/nyxus/locale.conf → $LANGUAGE → $LANG, reduced to a
// bare language tag ("es_ES.UTF-8" → "es", "es:en" → "es"). Kept byte-for-byte
// equivalent to nyxus_i18n.py's resolver: two readers disagreeing about the
// active language is worse than neither working.
static QString nyxusResolveLang()
{
    QByteArray env = qgetenv("NYXUS_LANG");
    if (!env.isEmpty())
        return QString::fromLocal8Bit(env).section(QLatin1Char(':'), 0, 0)
                   .section(QLatin1Char('.'), 0, 0).section(QLatin1Char('_'), 0, 0);

    QFile conf(QDir::homePath() + QLatin1String("/.config/nyxus/locale.conf"));
    if (conf.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QString body = QString::fromUtf8(conf.readAll()).trimmed();
        if (!body.isEmpty())
            return body.section(QLatin1Char(':'), 0, 0).section(QLatin1Char('.'), 0, 0)
                       .section(QLatin1Char('_'), 0, 0);
    }

    env = qgetenv("LANGUAGE");
    if (env.isEmpty())
        env = qgetenv("LANG");
    return QString::fromLocal8Bit(env).section(QLatin1Char(':'), 0, 0)
               .section(QLatin1Char('.'), 0, 0).section(QLatin1Char('_'), 0, 0);
}

static QString nyxusCatalogueDir()
{
    const QByteArray override = qgetenv("NYXUS_SHELL_I18N_DIR");
    if (!override.isEmpty())
        return QString::fromLocal8Bit(override);

    const QByteArray xdg = qgetenv("XDG_CONFIG_HOME");
    const QString base = xdg.isEmpty() ? (QDir::homePath() + QLatin1String("/.config"))
                                       : QString::fromLocal8Bit(xdg);
    return base + QLatin1String("/quickshell/i18n");
}

class NyxusTranslatorPlugin : public QGenericPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QGenericPluginFactoryInterface_iid FILE "nyxustranslator.json")

public:
    QObject *create(const QString &key, const QString &spec) override;
};

QObject *NyxusTranslatorPlugin::create(const QString &key, const QString &spec)
{
    Q_UNUSED(key)
    Q_UNUSED(spec)

    QCoreApplication *app = QCoreApplication::instance();
    if (!app)
        return nullptr; // Cannot happen from QGuiApplication's ctor; refuse anyway.

    // The returned object is what stops Qt warning about a null plugin spec.
    // Parented to the application, so it dies with it.
    QObject *sentinel = new QObject(app);
    sentinel->setObjectName(QStringLiteral("nyxusTranslatorPlugin"));

    const QString lang = nyxusResolveLang();
    if (lang.isEmpty() || lang == QLatin1String("C") || lang == QLatin1String("POSIX")
        || lang == QLatin1String("en")) {
        // English is the source language: the catalogue would be a no-op and
        // every lookup would cost a miss. Nothing to say about it either.
        return sentinel;
    }

    const QString path = nyxusCatalogueDir() + QLatin1Char('/') + lang + QLatin1String(".qm");
    if (!QFileInfo::exists(path)) {
        // Loud on purpose. A requested language with no catalogue means the
        // user asked for something and silently got English — the exact class
        // of failure this whole lane exists to stop.
        qWarning("nyxus-translator: language '%s' requested but no catalogue at %s "
                 "— the shell stays English",
                 qPrintable(lang), qPrintable(path));
        return sentinel;
    }

    QTranslator *translator = new QTranslator(app);
    if (!translator->load(path)) {
        qWarning("nyxus-translator: %s exists but QTranslator refused it "
                 "— the shell stays English",
                 qPrintable(path));
        delete translator;
        return sentinel;
    }
    if (!app->installTranslator(translator)) {
        qWarning("nyxus-translator: installTranslator refused %s", qPrintable(path));
        delete translator;
        return sentinel;
    }

    qInfo("nyxus-translator: '%s' installed from %s", qPrintable(lang), qPrintable(path));
    return sentinel;
}

#include "nyxustranslator.moc"
