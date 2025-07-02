import { Hyprland } from "imports";
import { handleEvents } from "event_handler";
import { setHyprlandKeywords } from "custom_hyprland_functions"; // Adjust the import path

async function initializeApp() {
    const windows = await setHyprlandKeywords();

    App.config({
        style: "./style.css",
        windows: windows, // This should now correctly match the Window[] type
    });

    Hyprland.connect('event', (hyprlandInstance: typeof Hyprland, eventName: string, eventData: string) => {
        handleEvents(eventName, eventData);
    });
}

// Call the initialize function
initializeApp();
