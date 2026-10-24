const test = require("node:test");
const assert = require("node:assert/strict");
const { pluginPath, compileFunction } = require("./helpers.js");

const calendarPath = pluginPath("NotchyCalendarController.qml");

function createCalendar(events) {
    const now = Date.parse("2026-10-24T08:00:00Z");
    class FakeDate extends Date {
        constructor(...args) {
            super(...(args.length > 0 ? args : [now]));
        }
        static now() {
            return now;
        }
    }
    const reminders = [];
    const loads = [];
    const CalendarService = {
        calendarAvailable: true,
        loadEvents(start, end) { loads.push({ start, end }); },
        getEventsForDate() { return events; }
    };
    const root = {
        nextEvent: null,
        _flashedEventKey: "",
        reminderRequested(text) { reminders.push(text); }
    };
    root._refreshNextEvent = compileFunction(calendarPath, "_refreshNextEvent", root, { CalendarService, Date: FakeDate });
    return { root, reminders, loads, CalendarService, now };
}

test("日历选择最近非全天未来日程，临近提醒只发送一次", () => {
    const base = Date.parse("2026-10-24T08:00:00Z");
    const { root, reminders, loads } = createCalendar([
        { title: "过去", start: new Date(base - 60000), allDay: false },
        { title: "全天", start: new Date(base + 300000), allDay: true },
        { title: "较远日程", start: new Date(base + 3600000), allDay: false },
        { title: "临近日程", start: new Date(base + 600000), allDay: false, calendar: "本机" }
    ]);
    root._refreshNextEvent();
    assert.equal(root.nextEvent.title, "临近日程");
    assert.equal(reminders.length, 1);
    assert.equal(reminders[0], "临近：临近日程");
    root._refreshNextEvent();
    assert.equal(reminders.length, 1);
    assert.equal(loads.length, 2);
});

test("日历不可用时清空下一日程", () => {
    const { root, CalendarService } = createCalendar([]);
    root.nextEvent = { title: "旧日程" };
    CalendarService.calendarAvailable = false;
    root._refreshNextEvent();
    assert.equal(root.nextEvent, null);
});
