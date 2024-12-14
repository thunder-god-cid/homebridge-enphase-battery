# homebridge-enphase-battery-redux
## Whoa yeah let's get some batteries into homekit!

### How It Works, Allegedly

#### Book 1: Getting Keys
You need to set up a developer account here: https://developer-v4.enphase.com

Put in whatever, you *do not* need to pay for anything. the Watt plan is fine.

Create a new application, call it whatever, again, doesn't matter.

What you want is to get an *API Key* as well as a *Client ID* and *Client Secret*. **All of that comes from the Application you just created.**

You also need your *Site ID* and *User ID* from Enphase. **This is from *your* system, https://enlighten.enphaseenergy.com/web/[Site ID]/.**

The Site ID is probably right at the bottom.

The User ID is Hamburger menu -> Account -> Access Control.

#### Book 2: I Cheat For You
OKAY COOL you got all that, congrats, that took me like six hours and you maybe ten minutes. you're welcome.

Now, you take all that and ram it into enphase-auth.sh. This takes your client ID, Client Secret, and API key, then throws a web page to log in. **Log in with your Enphase Credentials** to generate an authorized key that provides access to *your* system through *that* key to *your* application. Not mine, not anyone else's. Maybe don't share that. I dunno, i ain't your boss.

You log in, and then you'll see an error page, because it loops back to Localhost. That's the point - the URL includes the auth code. It will look like: http://localhost/?code=SOMETHING. Take SOMETHING and put that in the script, and it will generate a LONGER SOMETHING, which is a base64 encoded accessToken.

And then it'll give you the stanza you put in to config.js. 

That _should_ be it, but please see the FAQ if something breaks.

#### Book 3: Config settings or whatever

So now you got all that, you need to do this with it in your json config


    "platform": "EnphaseBatteryRedux",
    "name": "EnphaseBattery",
    "systemId": "[your system id goes here]",
    "apiKey": "[your api key goes here]",
    "accessToken": "[guess what goes here? it's your access token]"

that should be it!

### How it works in Homekit!

well, it's not perfect, but you get 

1. an occupancy sensor: this shows the Storm Watch status. a NO MOTION means no storm watch.
2. A contact sensor. OPEN means it's charging.
3. A light; this is your grid connection. LIT means you've got a grid connection. 
