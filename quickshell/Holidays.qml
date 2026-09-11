pragma Singleton
// Nyxus Suxyn — US observances, no network (TRK-3160).
//
// Computed locally: US federal holidays (observed weekday), US DST start/end
// (second Sunday of March / first Sunday of November, 02:00 local — the
// federal rule since 2007; Arizona/Hawaii stay on standard time in real life
// and are NOT special-cased here), and season hinges.
//
// Equinox/solstice dates are the COMMON calendar dates, not Meeus/NOAA
// instants: Mar 20, Jun 21 (first day of summer), Sep 22, Dec 21. They are
// labelled "approx" in the name so a 1-day drift is not a lie.
import Quickshell
import QtQuick

Singleton {
    id: hol

    function nthWeekday(y, m, weekday, n) {
        var first = new Date(y, m, 1);
        var delta = (weekday - first.getDay() + 7) % 7;
        return new Date(y, m, 1 + delta + (n - 1) * 7);
    }

    function lastWeekday(y, m, weekday) {
        var last = new Date(y, m + 1, 0);
        var delta = (last.getDay() - weekday + 7) % 7;
        return new Date(y, m, last.getDate() - delta);
    }

    function observed(y, m, d) {
        var dt = new Date(y, m, d);
        var w = dt.getDay();
        if (w === 6)
            return new Date(y, m, d - 1);
        if (w === 0)
            return new Date(y, m, d + 1);
        return dt;
    }

    function dayKey(d) {
        return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
    }

    function tableForYear(y) {
        var rows = [];
        function add(dt, kind, name) {
            rows.push({
                y: dt.getFullYear(), m: dt.getMonth(), d: dt.getDate(),
                kind: kind, name: name
            });
        }
        add(observed(y, 0, 1), "federal", "New Year's Day");
        add(nthWeekday(y, 0, 1, 3), "federal", "Martin Luther King Jr. Day");
        add(nthWeekday(y, 1, 1, 3), "federal", "Washington's Birthday");
        add(lastWeekday(y, 4, 1), "federal", "Memorial Day");
        add(observed(y, 5, 19), "federal", "Juneteenth");
        add(observed(y, 6, 4), "federal", "Independence Day");
        add(nthWeekday(y, 8, 1, 1), "federal", "Labor Day");
        add(nthWeekday(y, 9, 1, 2), "federal", "Columbus Day");
        add(observed(y, 10, 11), "federal", "Veterans Day");
        add(nthWeekday(y, 10, 4, 4), "federal", "Thanksgiving");
        add(observed(y, 11, 25), "federal", "Christmas");
        add(nthWeekday(y, 2, 0, 2), "dst", "Daylight saving begins");
        add(nthWeekday(y, 10, 0, 1), "dst", "Daylight saving ends");
        add(new Date(y, 2, 20), "season", "Spring equinox (approx)");
        add(new Date(y, 5, 21), "season", "First day of summer (approx)");
        add(new Date(y, 8, 22), "season", "Autumn equinox (approx)");
        add(new Date(y, 11, 21), "season", "Winter solstice (approx)");
        return rows;
    }

    function forDay(y, m, d) {
        var out = [];
        var rows = hol.tableForYear(y);
        for (var i = 0; i < rows.length; i++) {
            if (rows[i].y === y && rows[i].m === m && rows[i].d === d)
                out.push(rows[i]);
        }
        return out;
    }

    function namesForDay(y, m, d) {
        var list = hol.forDay(y, m, d);
        var names = [];
        for (var i = 0; i < list.length; i++)
            names.push(list[i].name);
        return names;
    }

    function hasKind(y, m, d, kind) {
        var list = hol.forDay(y, m, d);
        for (var i = 0; i < list.length; i++)
            if (list[i].kind === kind)
                return true;
        return false;
    }

    function hasAny(y, m, d) {
        return hol.forDay(y, m, d).length > 0;
    }
}
