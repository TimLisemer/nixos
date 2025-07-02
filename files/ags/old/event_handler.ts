import { reset_runningid } from 'app_bar';
import {
    getFocusedMonitor,
    getActiveWorkspace,
    shouldIgnoreApp,
    moveToHighestWorkspace,
} from './custom_hyprland_functions';

export async function handleEvents(name: string, data: string) {
    if (name === 'openwindow') {
        const focusedMonitor = getFocusedMonitor();

        const parts = data.split(',');
        const windowTitle = parts[2]; // Title is the third element


        if (shouldIgnoreApp(windowTitle)) {
            console.log(`Ignoring window for ${windowTitle}`);
            return;
        }

        if (focusedMonitor === 'DP-2' || focusedMonitor === 'HDMI-A-1') {
            console.log(`Window opened on ${focusedMonitor}, leaving it on the active workspace.`);
        } else if (focusedMonitor === 'HDMI-A-2') {
            const activeWorkspace = getActiveWorkspace(focusedMonitor);

            if (activeWorkspace === 2 || activeWorkspace === 3) {
                await moveToHighestWorkspace();
            } else {
                console.log(`Window opened on ${focusedMonitor} - workspace: ${activeWorkspace}, leaving it on the active workspace.`);
            }
        } else {
            console.log(`Unknown monitor: ${focusedMonitor}`);
        }
    }else if (name === 'closewindow') {
        reset_runningid();
    }else if (name === 'openwindow') {
        reset_runningid();
    }
}
