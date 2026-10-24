.pragma library

const tabs = [
    { id: "media", index: 0, label: "媒体", icon: "music_note" },
    { id: "notifications", index: 1, label: "通知", icon: "notifications" },
    { id: "clipboard", index: 2, label: "剪贴板", icon: "content_paste" },
    { id: "shelf", index: 3, label: "暂存架", icon: "inventory_2" },
    { id: "focus", index: 4, label: "专注", icon: "timer" },
    { id: "usage", index: 5, label: "用量", icon: "bar_chart" }
];

function indexOf(tabId) {
    for (let i = 0; i < tabs.length; i++) {
        if (tabs[i].id === tabId)
            return tabs[i].index;
    }
    return -1;
}
