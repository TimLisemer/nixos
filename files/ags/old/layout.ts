import {
  Workspaces,
  Clock,
  Notification,
  Media,
  Volume,
  SysTray,
} from "./widgets";
import { AppBar } from "./app_bar";
import Widget from "resource:///com/github/Aylur/ags/widget.js";
import { type Gtk } from "types/@girs/gtk-3.0/gtk-3.0";

export function Left(monitor: number) {
  return Widget.Box({
    spacing: 8,
    children: [Workspaces(monitor), SysTray(), Media()],
  });
}

export function Center() {
  return Widget.Box({
    spacing: 8,
    children: [Notification(), AppBar()],
  });
}

export function Right() {
  return Widget.Box({
    hpack: "end",
    spacing: 8,
    children: [Volume(), Clock()],
  });
}

export function Bar(monitor = 0): Gtk.Window {
return Widget.Window({
    name: `bar-${monitor}`,
    class_name: "bar",
    monitor,
    anchor: ["bottom", "left", "right"],
    exclusivity: "exclusive",
    child: Widget.CenterBox({
      start_widget: Left(monitor),
      center_widget: Center(),
      end_widget: Right(),
    }),
  });
}