import {
  Hyprland,
  Notifications,
  Mpris,
  Audio,
  Battery,
  Systemtray,
  Widget,
  Utils,
  Variable
} from "./imports";
import { createEmptyWorkspace } from './custom_hyprland_functions';

const date = Variable("", {
  poll: [1000, 'date "+%H:%M\n%b %e"'],
});

export function Workspaces(monitor: number) {
  const activeId = Hyprland.active.workspace.bind("id");
  const workspaces = Hyprland.bind("workspaces").as((ws) => {
    const workspaceButtons = ws
      .filter(({ monitorID }) => monitorID === monitor)
      .map(({ id }) =>
        Widget.Button({
          on_clicked: () => Hyprland.messageAsync(`dispatch workspace ${id}`),
          child: Widget.Label(`${id}`),
          class_name: activeId.as((i) => `${i === id ? "focused" : ""}`),
        })
      );

    workspaceButtons.push(
      Widget.Button({
        on_clicked: () => createEmptyWorkspace(),
        child: Widget.Label("+"),
        class_name: "create-new-workspace",
      })
    );

    return workspaceButtons;
  });

  return Widget.Box({
    class_name: "workspaces",
    children: workspaces,
  });
}

export function Clock() {
  return Widget.Label({
    class_name: "clock",
    label: date.bind(),
  });
}

export function Notification() {
  const popups = Notifications.bind("popups");
  return Widget.Box({
    class_name: "notification",
    visible: popups.as((p) => p.length > 0),
    children: [
      Widget.Icon({
        icon: "preferences-system-notifications-symbolic",
      }),
      Widget.Label({
        label: popups.as((p) => p[0]?.summary || ""),
      }),
    ],
  });
}

export function Media() {
  const label = Utils.watch("", Mpris, "player-changed", () => {
    if (Mpris.players[0]) {
      const { track_artists, track_title } = Mpris.players[0];
      return `${track_artists.join(", ")} - ${track_title}`;
    } else {
      return "Nothing is playing";
    }
  });

  return Widget.Button({
    class_name: "media",
    on_primary_click: () => Mpris.getPlayer("")?.playPause(),
    on_scroll_up: () => Mpris.getPlayer("")?.next(),
    on_scroll_down: () => Mpris.getPlayer("")?.previous(),
    child: Widget.Label({ label }),
  });
}

export function Volume() {
  const icons: Record<number, string> = {
    101: "overamplified",
    67: "high",
    34: "medium",
    1: "low",
    0: "muted",
  };

  function getIcon(): string {
    const icon = Audio.speaker.is_muted
      ? 0
      : [101, 67, 34, 1, 0].find(
          (threshold) => threshold <= Audio.speaker.volume * 100,
        );

    return `audio-volume-${icons[icon!]}-symbolic`;
  }

  const icon = Widget.Icon({
    icon: Utils.watch(getIcon(), Audio.speaker, getIcon),
  });

  const slider = Widget.Slider({
    hexpand: true,
    draw_value: false,
    on_change: ({ value }: { value: number }) => (Audio.speaker.volume = value),
    setup: (self: any) =>
      self.hook(Audio.speaker, () => {
        self.value = Audio.speaker.volume || 0;
      }),
  });

  return Widget.Box({
    class_name: "volume",
    css: "min-width: 180px",
    children: [icon, slider],
  });
}

export function BatteryLabel() {
  const value = Battery.bind("percent").as((p) => (p > 0 ? p / 100 : 0));
  const icon = Battery
    .bind("percent")
    .as((p) => `battery-level-${Math.floor(p / 10) * 10}-symbolic`);

  return Widget.Box({
    class_name: "battery",
    visible: Battery.bind("available"),
    children: [
      Widget.Icon({ icon }),
      Widget.LevelBar({
        widthRequest: 140,
        vpack: "center",
        value,
      }),
    ],
  });
}

export function SysTray() {
  const items = Systemtray.bind("items").as((items) =>
    items.map((item) =>
      Widget.Button({
        child: Widget.Icon({ icon: item.bind("icon") }),
        on_primary_click: (_: any, event: any) => item.activate(event),
        on_secondary_click: (_: any, event: any) => item.openMenu(event),
        tooltip_markup: item.bind("tooltip_markup"),
      }),
    ),
  );

  return Widget.Box({
    children: items,
  });
}

// Commented out Calendar function remains the same

/*
export function Calendar() {
  return Widget.Calendar({
    showDayNames: true,
    showDetails: true,
    showHeading: true,
    showWeekNumbers: true,
    detail: (self, y, m, d) => {
        return `<span color="white">${y}. ${m}. ${d}.</span>`
    },
    onDaySelected: ({ date: [y, m, d] }) => {
        print(`${y}. ${m}. ${d}.`)
    },
  });
}
  */