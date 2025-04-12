## Configuring MusiK Plasmoid
> [!NOTE]
> YOU CAN JUST SKIP THIS STEP IF YOU ARE USING THE GUI TO CONFIGURE THE PLASMOID.

After adding the plasmoid to the panel, open `~/.config/plasma-org.kde.plasma.desktop-appletsrc`. This is where the plasmoid's configuration is stored.

The GUI is more user-friendly, but editing the file directly will save you time.

Look for this section in the file:
```ini
[Containments][2][Applets][415]
immutability=1
plugin=com.rudraksh.musik
```
This will give you the `id` (used by the panel) of the plasmoid. In this case, it's `415`. It will be different for you.

Then look for the section
```ini
[Containments][2][Applets][415][Configuration][General]

Here the `415` is the plasmoid id.
```

Replace the contents or add the following lines to the section:
```ini
[Containments][2][Applets][<REPLACE WITH ID>][Configuration][General]
accentedProgressBar=true
afterArtistName=4
afterPlayerControls=48
afterSongName=-5
beforeAlbumCover=4
beforePlayerControls=10
beforeSongName=5
fullPlayerArtistNameFont=Hubot Sans Expanded ExtraBold,10,-1,5,800,0,0,0,0,0,1,1,0.59375,0,0,1,Regular
fullPlayerArtistNameSpacing=0.6
fullPlayerArtistNameUseCustomFont=true
fullPlayerSongNameFont=Hubot Sans Cn,19,-1,5,700,0,0,0,0,0,0,1,0,0,0,1,Bold
fullPlayerSongNameUseCustomFont=true
maxSongWidthInPanel=230
panelIcon=
showHoverBackground=true
textScrollingBehaviour=1
timerFont=Inter Display,10,-1,5,600,0,0,0,0,0,0,1,0,0,0,1,SemiBold
timerUseCustomFont=true
```

Update the font names according to your system.

Notice that this is the same as the GUI settings. Just that we configured the entire plasmoid in one go.