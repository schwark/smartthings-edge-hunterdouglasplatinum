# SmartThings Edge Driver for Hunter Douglas Platinum Shades

This is a Edge driver for Hunter Douglas Platinum Shades running on a gateway. This is NOT for PowerRise shades as they use a completely different hub.

## Driver Installation

1. Click on [Driver Invite Link](https://bestow-regional.api.smartthings.com/invite/VD2NLgQwpNj5)
2. Login to your SmartThings Account
3. Follow the flow to Accept Terms
4. Enroll your Hub
5. Install the Driver from the Available Drivers Button


## App Configuration

1. Now go to your SmartThings app and **Add a Device** > **Scan Nearby**.

2. After a couple of minutes, a number of new devices should show up for your **Shades**  and **Scenes** defined in your [Hunter Douglas Platinum App](https://apps.apple.com/us/app/platinum-app/id556728718) that is automatically added

The shades show up as SmartThings shades, and the scenes show up as switches - that are always off - you turn them on to run the scene, and they will turn themselves off right after the scene is executed (so they will never really be on). This is to simulate button like behavior using switches - since switches are better supported by voice assistants like Alexa.
