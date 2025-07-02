import { Hyprland } from "./imports";
const { spawn_command_line_sync } = imports.gi.GLib;
import { Bar } from 'layout';
import { type Gtk } from "types/@girs/gtk-3.0/gtk-3.0";

export function getFocusedMonitor(): string {
    return Hyprland.active.monitor.name;
}

function getMaxMonitorWorkspaceId(monitorName: string): number {
    // Find the highest workspace ID associated with the monitor
    const workspaces = Hyprland.workspaces.filter(ws => ws.monitor === monitorName);
    const maxWorkspaceId = Math.max(...workspaces.map(ws => ws.id));
    return maxWorkspaceId;
}

export function getFreeMonitorWorkspaceId(monitorName: string): number {
    const workspaces = Hyprland.workspaces.filter(ws => ws.monitor === monitorName);
    const workspaceIds = workspaces.map(ws => ws.id).sort((a, b) => a - b);
    
    for (let i = 1; i <= workspaceIds.length + 1; i++) {
        if (!workspaceIds.includes(i)) {
            return i;
        }
    }
    
    return workspaceIds.length + 1;
}

export function getFreeWorkspaceId(): number {
    const allWorkspaces = Hyprland.workspaces;
    const workspaceIds = allWorkspaces.map(ws => ws.id).sort((a, b) => a - b);
    
    for (let i = 1; i <= workspaceIds.length + 1; i++) {
        if (!workspaceIds.includes(i)) {
            return i;
        }
    }
    
    return workspaceIds.length + 1;
}

export function getActiveWorkspace(monitorName: string): number {
    const activeMonitor = Hyprland.monitors.find(mon => mon.name === monitorName);
    if (activeMonitor) {
        return Hyprland.active.workspace.id;
    } else {
        throw new Error(`Monitor ${monitorName} not found.`);
    }
}

export function shouldIgnoreApp(windowTitle: string): boolean {
    const ignoreApps = /Discord|WebCord|VenCord|Spotify/;
    return ignoreApps.test(windowTitle);
}

export async function moveToHighestWorkspace(): Promise<void> {
    const focusedMonitor = getFocusedMonitor();
    const maxWorkspaceId = getMaxMonitorWorkspaceId(focusedMonitor);
    console.log(`Moving window to workspace ${maxWorkspaceId} on ${focusedMonitor}.`);
    await Hyprland.messageAsync(`dispatch movetoworkspace ${maxWorkspaceId}`);
}

export async function createEmptyWorkspace(): Promise<void> {
    const freeWorkspaceId = getFreeWorkspaceId();
    await Hyprland.messageAsync(`dispatch workspace ${freeWorkspaceId}`);
}

export function printClientList() {
    const clients = Hyprland.clients;
    print("Clients List:");
    clients.forEach((client) => print(`Class: ${client.class} Address: ${client.address} Title: ${client.title}`));
    print("")
}

export async function setHyprlandKeywords(): Promise<Gtk.Window[]> {
    if (getHostname() === "tim-pc") {
        print("Initializing Hyprland for tim-pc");

        await Promise.all([
            Hyprland.messageAsync(`keyword monitor HDMI-A-2, preferred, 0x0, auto`),
            Hyprland.messageAsync(`keyword monitor DP-2, highrr, 1920x0, 1.25`),
            Hyprland.messageAsync(`keyword monitor HDMI-A-1, preferred, auto, auto`)
        ]);

        Hyprland.message(`keyword workspace 1, monitor:DP-2, default:true, persistent:true`);
        Hyprland.message(`keyword workspace 2, monitor:HDMI-A-2, default:true, persistent:true`);
        Hyprland.message(`keyword workspace 3, monitor:HDMI-A-2, default:false, persistent:true`);
        Hyprland.message(`keyword workspace 4, monitor:HDMI-A-2, default:false, persistent:true`);
        Hyprland.message(`keyword workspace 5, monitor:HDMI-A-1, default:true, persistent:true`);

        /*
        await Promise.all([
            Hyprland.messageAsync(`keyword workspace 1, monitor:DP-2, default:true, persistent:true`),
            Hyprland.messageAsync(`keyword workspace 2, monitor:HDMI-A-2, default:true, persistent:true`),
            Hyprland.messageAsync(`keyword workspace 3, monitor:HDMI-A-2, default:true, persistent:true`),
            Hyprland.messageAsync(`keyword workspace 4, monitor:HDMI-A-2, default:true, persistent:true`),
            Hyprland.messageAsync(`keyword workspace 5, monitor:HDMI-A-1, default:true, persistent:true`)
        ]);
        */

        await Promise.all([
            Hyprland.messageAsync(`keyword windowrulev2 workspace 2, title:^(.*(Discord|WebCord|VenCord).*)$`),
            Hyprland.messageAsync(`keyword windowrulev2 workspace 3, title:^(.*Spotify.*)$`)
        ]);        
        
        Hyprland.message(`dispatch workspace 2`);
        Hyprland.message(`dispatch workspace 5`);
        Hyprland.message(`dispatch workspace 1`);
        Hyprland.message(`dispatch workspace 3`);
        Hyprland.message(`dispatch workspace 4`);

        Hyprland.message(`dispatch workspace 1`);
        Hyprland.message(`dispatch workspace 2`);
        Hyprland.message(`dispatch workspace 3`);
        Hyprland.message(`dispatch workspace 4`);
        Hyprland.message(`dispatch workspace 5`);

        Hyprland.message(`dispatch workspace 1`);
        Hyprland.message(`dispatch workspace 2`);
        Hyprland.message(`dispatch workspace 3`);
        Hyprland.message(`dispatch workspace 4`);
        Hyprland.message(`dispatch workspace 5`);
        /*
        Hyprland.message(`dispatch workspace 3`);
        Hyprland.message(`dispatch workspace 4`);
        */
        

        return [Bar(0), Bar(1), Bar(2)];

    } else if (getHostname() === "tim-laptop") {
        print("Initializing Hyprland for tim-laptop");

        // Asynchronous call for the laptop
        await Hyprland.messageAsync(`keyword monitor eDP-1, preferred, auto, 1`);

        return [Bar(0)];

    } else {
        print("Failed to initialize Hyprland for this unknown Hostname: ", getHostname());
        return []; // Return an empty array if hostname is unknown
    }
}


function getHostname(): string {
    const [ok, stdout] = spawn_command_line_sync('hostname');
    
    if (ok) {
      return String.fromCharCode(...stdout).trim();
    } else {
      throw new Error('Failed to get hostname');
    }
  }