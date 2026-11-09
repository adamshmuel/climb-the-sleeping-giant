# Mockups

- A mockup's first call makes its folder and loads each generated model by its asset id into that folder. Never search the world by name for a model: a search for "tuft" grabbed the live meadow grass. Never move or change anything a world search finds.
- To retake an old shot, its avatar sits hidden in `ServerStorage.ArtLibrary.MockupAvatars.<folder>` and mockup parts are stored at Transparency 1: save each part's value in an attribute, show, shoot, put back. Use `Mockup_WakeUp.CamHelper.fov(device)` for the field of view, since the Studio window size changes.
- Look check "before" for added art: reparent the folder to ServerStorage (exact, survives into Play), count parts before and after. Gate cameras show cuff art only as a small detail; add close-ups (allowed) to judge it. (p5t15e3)
