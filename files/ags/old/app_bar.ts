import { Hyprland, Service, Widget } from "./imports";
import { type Application } from "types/service/applications";
const { query } = await Service.import("applications");

let focused_name: String = "";
let runningid: number = 0;

interface HardcodedApp {
  client_name: string;
}

// Updated list with client names where necessary
const hardcodedApps: HardcodedApp[] = [
  { client_name: "org.gnome.Nautilus" },
  { client_name: "org.mozilla.firefox" },
  { client_name: "Spotify" },
  { client_name: "WebCord" },
  { client_name: "com.github.flxzt.rnote" },
  { client_name: "geary" },
  { client_name: "gnome-terminal" },
  { client_name: "org.gnome.Calendar" },
];

// Function to focus an already running application
const focusApp = (clientName: string): boolean => {
  const running = Hyprland.clients.filter((client) => {
    return client.class.toLowerCase().includes(clientName.toLowerCase());
  });

  if (running.length <= 0) {
    focused_name = "";
    runningid = 0;
    return false;
  }
  if (running.length === 1) {
    Hyprland.messageAsync(`dispatch focuswindow address:${running[0].address}`);
    return true;
  }

  if (running.length === runningid) {
    runningid = 0;
  }

  if (focused_name !== clientName) {
    focused_name = clientName;
    runningid = 0;
  }

  Hyprland.messageAsync(`dispatch focuswindow address:${running[runningid].address}`);
  runningid += 1;
  return true;
};

// Function to launch an application
const launchApp = async (app: Application): Promise<void> => {
  await app.launch();
};

// Create a button with custom click behavior and dot indicators
const createAppButton = (app: Application, clientName: string) => {
  const indicators = Widget.Box({
    vpack: "end",
    hpack: "center",
    children: Array(5).fill(null).map(() => Widget.Box({ class_name: "indicator", visible: false })),
  });

  return Widget.Button({
    on_primary_click: async () => {
      const appFocused = await focusApp(clientName);
      if (!appFocused) {
        await launchApp(app);
      }
    },
    on_secondary_click: async () => {
      await launchApp(app);
      print("Trying to launch App: " + clientName);
    },
    child: Widget.Box({
      class_name: "box",
      child: Widget.Overlay({
        child: Widget.Icon({
          icon: app.icon_name || "",
          size: 30,
        }),
        pass_through: true,
        overlays: [indicators],
      }),
    }),
    tooltip_text: app.name,
    setup: (button) => {
      button.hook(Hyprland, () => {
        const running = Hyprland.clients.filter((client) => {
          return client.class.toLowerCase().includes(clientName.toLowerCase());
        });

        const focused = running.find((client) => client.address === Hyprland.active.client.address);
        const index = running.findIndex((c) => c === focused);

        for (let i = 0; i < 5; ++i) {
          const indicator = button.child.child.overlays[0].children[i];
          indicator.visible = i < running.length;
          if (i === index) {
            indicator.toggleClassName("focused_app", true);
          } else {
            indicator.toggleClassName("focused_app", false);
          }
        }

        if (running.length >= 1) {
          button.set_tooltip_text(running[0].title);
        } else {
          button.set_tooltip_text(app.name);
        }
      });
    },
  });
};

export function AppBar() {
  const applications = hardcodedApps.map((appConfig) => {
    // Query the application list based on the client name
    const appList = query(appConfig.client_name);
    const app: Application = appList[0];

    // Create a button for the application
    return createAppButton(app, appConfig.client_name);
  });

  // Filter out clients that are NOT in the hardcodedApps
  const nonListedClients = Hyprland.clients.filter((client) => {
    return !hardcodedApps.some((appConfig) => 
      client.class.toLowerCase().includes(appConfig.client_name.toLowerCase())
    );
  });

  // Create AppButtons for non-listed clients using client.title
  const nonListedClientButtons = nonListedClients.map((client) => {
    // Query the application list based on the client's class
    const appList = query(client.initialTitle);
    const app: Application = appList[0];

    // Log the client title
    print("Running without applist: ", client.title);

    // Create a button for the non-listed client using the app and client.title
    return createAppButton(app, client.initialTitle);
  });

  // Combine the two sets of buttons
  const allButtons = [...applications, ...nonListedClientButtons];

  // Return the Widget with all created application buttons
  return Widget.Box({
    children: allButtons,
    spacing: 6,
  });
}










export function reset_runningid(){
  runningid = 0;
}