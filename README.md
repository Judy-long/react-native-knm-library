
# react-native-knm-library

## Getting started

`$ npm install react-native-knm-library --save`

### Mostly automatic installation

`$ react-native link react-native-knm-library`

### Manual installation


#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-knm-library` and add `GWKnmLibrary.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libGWKnmLibrary.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

#### Android

1. Open up `android/app/src/main/java/[...]/MainActivity.java`
  - Add `import com.reactlibrary.GWKnmLibraryPackage;` to the imports at the top of the file
  - Add `new GWKnmLibraryPackage()` to the list returned by the `getPackages()` method
2. Append the following lines to `android/settings.gradle`:
  	```
  	include ':react-native-knm-library'
  	project(':react-native-knm-library').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-knm-library/android')
  	```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
  	```
      compile project(':react-native-knm-library')
  	```


## Usage
```javascript
import GWKnmLibrary from 'react-native-knm-library';

// TODO: What to do with the module?
GWKnmLibrary;
```
  