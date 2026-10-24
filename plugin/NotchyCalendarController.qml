import QtQuick
import qs.Services

// 下一日程查询与临近提醒。
QtObject {
    id: root

    signal reminderRequested(string text)

    property var nextEvent: null
    property string _flashedEventKey: ""

    function _refreshNextEvent() {
        if (!CalendarService.calendarAvailable) {
            nextEvent = null;
            return;
        }
        const now = new Date();
        CalendarService.loadEvents(now, new Date(now.getTime() + 2 * 86400000));
        let best = null;
        for (let d = 0; d < 2; d++) {
            const day = new Date(now.getTime() + d * 86400000);
            const evs = CalendarService.getEventsForDate(day) || [];
            for (let i = 0; i < evs.length; i++) {
                const ev = evs[i];
                if (!ev || ev.allDay)
                    continue;
                const st = ev.start ? new Date(ev.start) : null;
                if (!st || isNaN(st.getTime()) || st <= now)
                    continue;
                if (!best || st < best.start)
                    best = {
                        title: ev.title || "日程",
                        start: st,
                        calendar: ev.calendar ?? ""
                    };
            }
        }
        nextEvent = best;
        // 临近 15 分钟药丸提醒（同一事件只闪一次）
        if (best) {
            const mins = (best.start.getTime() - now.getTime()) / 60000;
            const key = best.title + "@" + best.start.getTime();
            if (mins <= 15 && mins > 0 && root._flashedEventKey !== key) {
                root._flashedEventKey = key;
                root.reminderRequested("临近：" + best.title);
            }
        }
    }

    property var refreshTimer: Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root._refreshNextEvent()
    }
}
