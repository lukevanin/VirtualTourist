# VirtualTourist

Virtual Tourist project app for Udacity iOS Nanodegree

Mark locations of interest on a map by adding and removing pins. See photos for each location from Flickr.

<img src="Screenshots/iPhone/Portrait/1 Map.png" width="320">
<img src="Screenshots/iPhone/Portrait/2 Photos.png" width="320">
<img src="Screenshots/iPhone/Landscape/3 Photo.png" height="320">

## Features

1. Map: See all your pins. Hold down on the map to add a pin. Tap on a pin to show photos for the vicinity of the pin. Tap the *Edit* button to enter edit mode, then tap on pins to remove.
2. Photos: Tap on a photo to see a larger version. Tap *Load new collection* to load a new set of photos. Tap the *Edit* button to enter edit mode, then tap on a photo to remove it.
3. Photo: Pinch to zoom the image. Swipe to pan when zoomed.

## Technical details

### Core Data

Data is persisted using Core Data. The stack is encapuslated in CoreDataStack, which instantiates the managed object model, persistent store, and managed object contexts. It also manages auto-saving the data on a fixed interval. The stack is composed of three contexts. Changes are propogated through parent-child relationships:

1. **Background context (Private queue):** Saves directly to the persistent store on a fixed interval. Not available to the application.
2. **Main context (Main queue):** Used by the application for reading data which needs to be accessible in the UI.
3. **Change context (Private queue):** Used by the application to perform modifications on the data. Saving the context pushes the changes to the main context where they become available to the app.

Image data is also managed by Core Data using the external file attribute for the relevant properties.

### Photos

Photos are loaded in the background when the pin is added to the map. When the app launches it resumes downloading any images which were not

### Map

The photos screen displays an image for the map, instead of using an *MKMapView*. This is done for performance reasons, to enable the stretchy header to expand and contract when the collection view is temporarily scrolled beyond its limits. A normal MKMapView does not update fast enough for this interaction, and causes the display to become laggy. The image is generated using *MKMapSnapshotter*. The snapshot is created asynchrously. A side effect of using a snapshot is that the generated image does include annotations, and so the pin image is added explicitly.
